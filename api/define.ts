import { VercelRequest, VercelResponse } from '@vercel/node';
import { createClient } from '@supabase/supabase-js';
import Anthropic from '@anthropic-ai/sdk';
import { sanitizeLocale, sanitizePlatform, sanitizeSessionId } from './_validation';

/**
 * 環境変数(chat.ts と同一の名前ゆれ対応)。
 */
const supabaseUrl = process.env.SUPABASE_URL || '';
const supabaseKey =
  process.env.SUPABASE_SERVICE_KEY || process.env.SUPABASE_KEY || '';
const claudeApiKey =
  process.env.ANTHROPIC_API_KEY || process.env.CLAUDE_API_KEY || '';

// 辞書機能専用の軽い日次上限(会話回数の rate_limits とは別枠、T-31)。
// T-36のヒント機能と合算(仕様書: 「辞書(T-31)と合算の軽い日次上限」)。
// Premium は無制限。usage_logs(event='message_sent',
// metadata.feature in ('define','hint'))の本日合計件数で判定する
// (rate_limits のスキーマ変更はしない)。
// 単語単位モード・文単位モードのいずれも metadata.feature は 'define' で
// 統一し、このバケットを共有する(モードで分けると上限が実質無効化する)。
const FREE_DAILY_DEFINE_HINT_LIMIT = 30;

const DEFINE_SYSTEM_PROMPT = `You are a Japanese dictionary assistant helping a Filipino learner understand a word or phrase from a conversation.

Given a Japanese term (possibly inflected/conjugated) and the full sentence it appeared in, respond with ONLY a single-line minified JSON object with exactly these keys:
{"reading":"...","meaning_en":"...","meaning_fil":"...","example_ja":"...","example_en":"..."}

- reading: hiragana reading of the term (empty string if the term has no kanji)
- meaning_en: short, simple English meaning of the term AS USED in the given sentence
- meaning_fil: short, simple Tagalog meaning of the term AS USED in the given sentence
- example_ja: one short, natural Japanese example sentence using the term (different from the given sentence)
- example_en: English translation of example_ja

Tagalog quality guard (meaning_fil):
- Never invent a Tagalog word that does not actually exist. If you are not confident in a natural, real Tagalog equivalent, use a short, common, everyday Tagalog word or phrase instead of a longer or more literal one
- Do not force a word-for-word translation of Japanese honorific/formal expressions (keigo, humble/respectful forms, etc.) into Tagalog. Express only the core meaning in plain, simple Tagalog rather than trying to reproduce the nuance
- meaning_en must stay accurate and precise regardless of how meaning_fil turns out. meaning_en is the primary reference; meaning_fil is a supplementary aid

Output ONLY the JSON object. No markdown, no code fences, no explanation, no extra text.`;

// 文単位モード(mode: 'sentence')。シーンの推奨レベルに応じて難語の基準を
// 調整する(施策②: ふりがな抽出方式の廃止、AI側に難語選定を委ねる)。
const VALID_SCENE_LEVELS = new Set(['beginner', 'intermediate', 'advanced']);

const SCENE_LEVEL_GUIDANCE: { [level: string]: string } = {
  beginner:
    'This is a beginner-level scene: flag common everyday words that are still non-trivial for a beginner (basic verbs, adjectives, adverbs), not just rare or advanced vocabulary. A simple hiragana word like たのしい or だいじょうぶ is a valid choice if a beginner may not know it.',
  intermediate:
    'This is an intermediate-level scene: flag words a bit above basic daily conversation (compound verbs, less common adjectives/adverbs, moderately formal expressions).',
  advanced:
    'This is an advanced-level scene: flag only genuinely difficult or specialized vocabulary (idioms, formal/business expressions, uncommon kanji compounds).',
};

function buildSentenceSystemPrompt(sceneLevel: string): string {
  const guidance = SCENE_LEVEL_GUIDANCE[sceneLevel] || SCENE_LEVEL_GUIDANCE.beginner;
  return `You are a Japanese vocabulary coach helping a Filipino learner understand a sentence spoken by an AI conversation partner in a roleplay app.

Given a Japanese sentence, select UP TO 3 words or short phrases that this learner would likely NOT understand, and that not understanding them would make it hard to follow the conversation. Do not favor kanji words over hiragana/katakana words — treat all word types equally: a hiragana adjective or adverb the learner doesn't know is just as valid a choice as a kanji word or a katakana loanword.

${guidance}

Do NOT select:
- Particles (は, が, を, に, で, と, etc.) or auxiliary verbs/endings (です, ます, ました, etc.) in isolation
- Fixed, well-known greetings and set phrases (こんにちは, ありがとう, おはよう, さようなら, etc.)
- Numbers and counters
- Proper nouns that need no explanation (character names, well-known place names)

Selection rules:
- Return at most 3 words, ordered by how much they would block understanding (most important first)
- If fewer than 3 words qualify, return only those that do. Do not pad the list with easy words just to reach 3
- If no word qualifies, return an empty list

Respond with ONLY a single-line minified JSON object with exactly this shape:
{"words":[{"term":"...","reading":"...","meaning_en":"...","meaning_fil":"...","example_ja":"...","example_en":"..."}]}

For each selected word:
- term: the word or short phrase exactly as it appears in the sentence
- reading: hiragana reading of the term (empty string if the term has no kanji)
- meaning_en: short, simple English meaning of the term AS USED in the given sentence
- meaning_fil: short, simple Tagalog meaning of the term AS USED in the given sentence
- example_ja: one short, natural Japanese example sentence using the term (different from the given sentence)
- example_en: English translation of example_ja

Tagalog quality guard (meaning_fil):
- Never invent a Tagalog word that does not actually exist. If you are not confident in a natural, real Tagalog equivalent, use a short, common, everyday Tagalog word or phrase instead of a longer or more literal one
- Do not force a word-for-word translation of Japanese honorific/formal expressions (keigo, humble/respectful forms, etc.) into Tagalog. Express only the core meaning in plain, simple Tagalog rather than trying to reproduce the nuance
- meaning_en must stay accurate and precise regardless of how meaning_fil turns out. meaning_en is the primary reference; meaning_fil is a supplementary aid

Output ONLY the JSON object described above. No markdown, no code fences, no explanation, no extra text. If no word qualifies, output exactly {"words":[]}.`;
}

/**
 * POST /api/define
 *
 * AIメッセージ内の語句の意味を調べる(T-31)。
 * 会話回数(rate_limits)は消費しない。
 *
 * mode 未指定(既定): 単語単位モード。ユーザーが選択した1語の意味を返す。
 * Request body:
 * {
 *   "token": "supabase access token (JWT)",
 *   "term": "選択された語句",
 *   "context": "その語句が含まれるメッセージ全文",
 *   "sceneId": "1" (optional)
 * }
 * Response: { reading, meaning_en, meaning_fil, example_ja, example_en }
 *
 * mode: 'sentence' : 文単位モード。メッセージ全文を渡すと、AIが学習者に
 * とって難しい語を最大3つ選び、それぞれの詳細をまとめて返す(施策②)。
 * Request body:
 * {
 *   "token": "supabase access token (JWT)",
 *   "mode": "sentence",
 *   "context": "AIメッセージ全文",
 *   "sceneId": "1" (optional),
 *   "sceneLevel": "beginner" | "intermediate" | "advanced" (optional、既定 beginner)
 * }
 * Response: { words: [{ term, reading, meaning_en, meaning_fil, example_ja, example_en }, ...] }
 * (0〜3件。該当語が無ければ words: [] を返す。エラーにはしない)
 */
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const missing: string[] = [];
  if (!supabaseUrl) missing.push('SUPABASE_URL');
  if (!supabaseKey) missing.push('SUPABASE_SERVICE_KEY (or SUPABASE_KEY)');
  if (!claudeApiKey) missing.push('ANTHROPIC_API_KEY (or CLAUDE_API_KEY)');
  if (missing.length > 0) {
    return res.status(500).json({
      error: 'Server misconfiguration',
      message: `Missing environment variable(s): ${missing.join(', ')}`,
    });
  }

  const supabase = createClient(supabaseUrl, supabaseKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const anthropic = new Anthropic({ apiKey: claudeApiKey, maxRetries: 4 });

  try {
    const { token, term, context, sceneId, sceneLevel, locale, platform, mode, sessionId } =
      req.body || {};
    const isSentenceMode = mode === 'sentence';

    if (!token) {
      return res.status(401).json({ error: 'Missing authentication token' });
    }
    if (isSentenceMode) {
      // 文単位モード: context のみ必須(term は使用しない)。
      if (typeof context !== 'string' || !context.trim() || context.length > 2000) {
        return res.status(400).json({ error: 'Invalid context' });
      }
    } else {
      // 単語単位モード(既存、変更なし)。
      if (typeof term !== 'string' || !term.trim() || term.length > 50) {
        return res.status(400).json({ error: 'Invalid term' });
      }
      if (typeof context !== 'string' || context.length > 2000) {
        return res.status(400).json({ error: 'Invalid context' });
      }
    }

    const { data: userData, error: userErr } = await supabase.auth.getUser(token);
    if (userErr || !userData?.user) {
      return res.status(401).json({ error: 'Invalid or expired token' });
    }
    const userId = userData.user.id;

    // Premium ステータス取得(会話と同じ判定元。両モード共通)
    let isPremium = false;
    try {
      const { data, error } = await supabase
        .from('rate_limits')
        .select('is_premium')
        .eq('user_id', userId)
        .single();
      if (!error && data) {
        isPremium = data.is_premium === true;
      }
    } catch (err) {
      console.error('Error checking premium status:', err);
    }

    // 辞書専用の軽い日次上限(Premiumは無制限)。両モード共通のバケット
    // (metadata.feature = 'define')を消費する。
    if (!isPremium) {
      const startOfDayUtc = new Date();
      startOfDayUtc.setUTCHours(0, 0, 0, 0);
      const { count, error: countError } = await supabase
        .from('usage_logs')
        .select('id', { count: 'exact', head: true })
        .eq('user_id', userId)
        .eq('event', 'message_sent')
        .in('metadata->>feature', ['define', 'hint'])
        .gte('created_at', startOfDayUtc.toISOString());

      if (countError) {
        console.error('usage_logs count failed:', countError.code, countError.message);
      } else if ((count ?? 0) >= FREE_DAILY_DEFINE_HINT_LIMIT) {
        return res.status(429).json({
          error: 'Daily dictionary lookup limit reached',
        });
      }
    }

    let response;
    let level = 'beginner';
    if (isSentenceMode) {
      const requestedLevel =
        typeof sceneLevel === 'string' ? sceneLevel.trim().toLowerCase() : '';
      level = VALID_SCENE_LEVELS.has(requestedLevel) ? requestedLevel : 'beginner';

      response = await anthropic.messages.create({
        model: 'claude-haiku-4-5-20251001',
        max_tokens: 600,
        system: buildSentenceSystemPrompt(level),
        messages: [
          {
            role: 'user',
            content: `Sentence: ${context}`,
          },
        ],
      });
    } else {
      response = await anthropic.messages.create({
        model: 'claude-haiku-4-5-20251001',
        max_tokens: 200,
        system: DEFINE_SYSTEM_PROMPT,
        messages: [
          {
            role: 'user',
            content: `Term: ${term}\nContext sentence: ${context}`,
          },
        ],
      });
    }

    const content = response.content[0];
    const rawText = content.type === 'text' ? content.text : '';

    // モデルが指示に反してコードフェンスや前後の説明文を付けても落ちないよう、
    // JSONオブジェクト本体を抽出してからパースする(堅牢化、2026-07-17)。
    let jsonText = rawText.trim();
    const fence = jsonText.match(/```(?:json)?\s*([\s\S]*?)```/);
    if (fence) jsonText = fence[1].trim();
    if (!jsonText.startsWith('{')) {
      const start = jsonText.indexOf('{');
      const end = jsonText.lastIndexOf('}');
      if (start !== -1 && end > start) jsonText = jsonText.slice(start, end + 1);
    }

    let parsed: Record<string, unknown>;
    try {
      parsed = JSON.parse(jsonText);
    } catch (parseErr) {
      console.error('define: failed to parse model output:', rawText);
      return res.status(502).json({ error: 'Failed to parse dictionary response' });
    }

    // 使用ログ(失敗しても本処理は止めない)。既存の event 種別のみ使用し、
    // metadata.feature で辞書機能を識別する(turn_number は会話ターンではないため送らない)。
    // 両モードとも feature='define' で統一(上限バケットを共有するため)。
    try {
      const { error: logError } = await supabase.from('usage_logs').insert({
        user_id: userId,
        event: 'message_sent',
        session_id: sanitizeSessionId(sessionId),
        model: 'claude-haiku-4-5-20251001',
        is_premium: isPremium,
        input_tokens: response.usage.input_tokens,
        output_tokens: response.usage.output_tokens,
        cache_read_input_tokens: response.usage.cache_read_input_tokens,
        cache_creation_input_tokens: response.usage.cache_creation_input_tokens,
        platform: sanitizePlatform(platform),
        locale: sanitizeLocale(locale),
        metadata: isSentenceMode
          ? { feature: 'define', scene: sceneId ?? null, mode: 'sentence', sceneLevel: level }
          : { feature: 'define', scene: sceneId ?? null, term },
      });
      if (logError) {
        console.error('usage_logs insert failed:', logError.code, logError.message);
      }
    } catch (err) {
      console.error('Failed to log define usage:', err);
    }

    if (isSentenceMode) {
      const rawWords = Array.isArray((parsed as { words?: unknown }).words)
        ? ((parsed as { words: unknown[] }).words as Array<Record<string, unknown>>)
        : [];
      const words = rawWords.slice(0, 3).map((w) => ({
        term: typeof w.term === 'string' ? w.term : '',
        reading: typeof w.reading === 'string' ? w.reading : '',
        meaning_en: typeof w.meaning_en === 'string' ? w.meaning_en : '',
        meaning_fil: typeof w.meaning_fil === 'string' ? w.meaning_fil : '',
        example_ja: typeof w.example_ja === 'string' ? w.example_ja : '',
        example_en: typeof w.example_en === 'string' ? w.example_en : '',
      }));
      return res.status(200).json({ words });
    }

    return res.status(200).json({
      reading: parsed.reading ?? '',
      meaning_en: parsed.meaning_en ?? '',
      meaning_fil: parsed.meaning_fil ?? '',
      example_ja: parsed.example_ja ?? '',
      example_en: parsed.example_en ?? '',
    });
  } catch (error: any) {
    console.error('Define API error:', error);

    const status = error?.status;
    const isOverloaded =
      status === 529 ||
      error?.type === 'overloaded_error' ||
      error?.error?.error?.type === 'overloaded_error';
    if (isOverloaded || status === 503) {
      return res.status(503).json({
        error: 'The dictionary lookup is busy right now. Please try again in a moment.',
      });
    }

    return res.status(500).json({
      error: 'Internal server error',
      message: error?.message || 'Unknown error',
    });
  }
}
