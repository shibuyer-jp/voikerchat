import { VercelRequest, VercelResponse } from '@vercel/node';
import { createClient } from '@supabase/supabase-js';
import Anthropic from '@anthropic-ai/sdk';
import { FREE_DAILY_RECAP_LIMIT } from './_constants';

/**
 * 環境変数(chat.ts と同一の名前ゆれ対応)。
 */
const supabaseUrl = process.env.SUPABASE_URL || '';
const supabaseKey =
  process.env.SUPABASE_SERVICE_KEY || process.env.SUPABASE_KEY || '';
const claudeApiKey =
  process.env.ANTHROPIC_API_KEY || process.env.CLAUDE_API_KEY || '';

const VOCAB_SUMMARY_SYSTEM_PROMPT = `You are a Japanese vocabulary extractor for a Filipino learner reviewing a conversation they just practiced.

Given the full conversation, pick up to 8 of the most useful/important Japanese words or short phrases that appeared (prioritize words the learner is likely unfamiliar with over trivial ones). Respond with ONLY a single-line minified JSON array, each item with exactly these keys:
[{"word":"...","reading":"...","meaning_en":"..."}]

- word: the word/phrase as it appeared (kanji if applicable)
- reading: hiragana reading (empty string if the word has no kanji)
- meaning_en: short, simple English meaning

If the conversation has fewer than 8 notable words, return fewer. Output ONLY the JSON array. No markdown, no code fences, no explanation, no extra text.`;

/**
 * POST /api/vocab-summary
 *
 * セッション終了時に「今日の単語」を最大8個抽出する(T-36)。
 * 会話回数(rate_limits)は消費しないが、recapと合算の軽い日次上限
 * (FREE_DAILY_RECAP_LIMIT)をサーバー側で持つ(API直叩き対策、define/hintの
 * 別枠とは独立)。Premiumは無制限。
 *
 * Request body:
 * {
 *   "token": "supabase access token (JWT)",
 *   "conversation": "会話ログ(役割と発話を含むテキスト)",
 *   "sceneId": "1" (optional)
 * }
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
    const { token, conversation, sceneId } = req.body || {};

    if (!token) {
      return res.status(401).json({ error: 'Missing authentication token' });
    }
    if (typeof conversation !== 'string' || !conversation.trim() || conversation.length > 8000) {
      return res.status(400).json({ error: 'Invalid conversation' });
    }

    const { data: userData, error: userErr } = await supabase.auth.getUser(token);
    if (userErr || !userData?.user) {
      return res.status(401).json({ error: 'Invalid or expired token' });
    }
    const userId = userData.user.id;

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

    // recap/vocab-summary合算の軽い日次上限(Premiumは無制限)。define/hintの
    // 枠(metadata.feature in ('define','hint'))とは完全に独立させるため、
    // ここでは 'recap'/'vocab_summary' のみを対象にする。
    if (!isPremium) {
      const startOfDayUtc = new Date();
      startOfDayUtc.setUTCHours(0, 0, 0, 0);
      const { count, error: countError } = await supabase
        .from('usage_logs')
        .select('id', { count: 'exact', head: true })
        .eq('user_id', userId)
        .eq('event', 'message_sent')
        .in('metadata->>feature', ['recap', 'vocab_summary'])
        .gte('created_at', startOfDayUtc.toISOString());

      if (countError) {
        console.error('usage_logs count failed:', countError.code, countError.message);
      } else if ((count ?? 0) >= FREE_DAILY_RECAP_LIMIT) {
        return res.status(429).json({
          error: 'Daily vocab summary limit reached',
        });
      }
    }

    const response = await anthropic.messages.create({
      model: 'claude-haiku-4-5-20251001',
      max_tokens: 500,
      system: VOCAB_SUMMARY_SYSTEM_PROMPT,
      messages: [
        {
          role: 'user',
          content: `Conversation:\n${conversation}`,
        },
      ],
    });

    const content = response.content[0];
    const rawText = content.type === 'text' ? content.text : '';

    // モデルが指示に反してコードフェンスや前後の説明文を付けても落ちないよう、
    // JSON配列本体を抽出してからパースする(堅牢化、2026-07-17)。
    let jsonText = rawText.trim();
    const fence = jsonText.match(/```(?:json)?\s*([\s\S]*?)```/);
    if (fence) jsonText = fence[1].trim();
    if (!jsonText.startsWith('[')) {
      const start = jsonText.indexOf('[');
      const end = jsonText.lastIndexOf(']');
      if (start !== -1 && end > start) jsonText = jsonText.slice(start, end + 1);
    }

    let parsed: Array<{ word?: string; reading?: string; meaning_en?: string }>;
    try {
      parsed = JSON.parse(jsonText);
      if (!Array.isArray(parsed)) throw new Error('not an array');
    } catch (parseErr) {
      console.error('vocab-summary: failed to parse model output:', rawText);
      return res.status(502).json({ error: 'Failed to parse vocab summary response' });
    }

    const words = parsed.slice(0, 8).map((w) => ({
      word: w.word ?? '',
      reading: w.reading ?? '',
      meaning_en: w.meaning_en ?? '',
    }));

    // 使用ログ(失敗しても本処理は止めない)。既存の event 種別のみ使用し、
    // metadata.feature で識別する(usage_logs のスキーマ変更はしない)。
    try {
      const { error: logError } = await supabase.from('usage_logs').insert({
        user_id: userId,
        event: 'message_sent',
        model: 'claude-haiku-4-5-20251001',
        is_premium: isPremium,
        input_tokens: response.usage.input_tokens,
        output_tokens: response.usage.output_tokens,
        metadata: { feature: 'vocab_summary', scene: sceneId ?? null, wordCount: words.length },
      });
      if (logError) {
        console.error('usage_logs insert failed:', logError.code, logError.message);
      }
    } catch (err) {
      console.error('Failed to log vocab_summary usage:', err);
    }

    return res.status(200).json({ words });
  } catch (error: any) {
    console.error('Vocab summary API error:', error);

    const status = error?.status;
    const isOverloaded =
      status === 529 ||
      error?.type === 'overloaded_error' ||
      error?.error?.error?.type === 'overloaded_error';
    if (isOverloaded || status === 503) {
      return res.status(503).json({
        error: 'The vocab summary service is busy right now. Please try again in a moment.',
      });
    }

    return res.status(500).json({
      error: 'Internal server error',
      message: error?.message || 'Unknown error',
    });
  }
}
