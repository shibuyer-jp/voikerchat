import { VercelRequest, VercelResponse } from '@vercel/node';
import { createClient } from '@supabase/supabase-js';
import Anthropic from '@anthropic-ai/sdk';

/**
 * 環境変数(chat.ts / vocab-summary.ts と同一の名前ゆれ対応)。
 */
const supabaseUrl = process.env.SUPABASE_URL || '';
const supabaseKey =
  process.env.SUPABASE_SERVICE_KEY || process.env.SUPABASE_KEY || '';
const claudeApiKey =
  process.env.ANTHROPIC_API_KEY || process.env.CLAUDE_API_KEY || '';

const RECAP_SYSTEM_PROMPT = `You are a Japanese language coach reviewing a conversation a Filipino learner just practiced.

Look ONLY at the learner's (user's) utterances. Find up to 3 places where the learner's Japanese was unnatural, grammatically incorrect, or where a clearly better/more natural expression exists. Prioritize the most instructive corrections. Ignore trivial issues (typos in particles that don't change meaning, missing punctuation, romaji usage).

Respond with ONLY a single-line minified JSON array, each item with exactly these keys:
[{"original":"...","improved":"...","tip_en":"..."}]

- original: the learner's sentence (or the relevant part) exactly as they said it
- improved: the natural Japanese version. For every word containing kanji, add its hiragana reading in parentheses like 漢字(かんじ)
- tip_en: one short, encouraging English sentence explaining why the improved version is better

If the learner's Japanese was already natural and correct throughout, return an empty array [].
Output ONLY the JSON array. No markdown, no code fences, no explanation, no extra text.`;

/**
 * POST /api/recap
 *
 * セッション終了時の「言い直し復習」— ユーザー発話から改善点を最大3件抽出する。
 * 競合分析(Speakの "Made for You" 機能)を参考にした個別化復習の簡易版。
 * vocab-summary と同じ呼び出しタイミング(セッション終了時に1回、
 * クライアント側で3往復未満はスキップ)を想定するため、専用の日次上限は設けない。
 * 会話回数(rate_limits)は消費しない。
 *
 * Request body:
 * {
 *   "token": "supabase access token (JWT)",
 *   "conversation": "会話ログ(User:/Assistant: の役割と発話を含むテキスト)",
 *   "sceneId": "1" (optional)
 * }
 *
 * Response: { "corrections": [{ "original", "improved", "tip_en" }] }
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

    const response = await anthropic.messages.create({
      model: 'claude-haiku-4-5-20251001',
      max_tokens: 600,
      system: RECAP_SYSTEM_PROMPT,
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
    // JSON配列本体を抽出してからパースする(vocab-summary と同方式)。
    let jsonText = rawText.trim();
    const fence = jsonText.match(/```(?:json)?\s*([\s\S]*?)```/);
    if (fence) jsonText = fence[1].trim();
    if (!jsonText.startsWith('[')) {
      const start = jsonText.indexOf('[');
      const end = jsonText.lastIndexOf(']');
      if (start !== -1 && end > start) jsonText = jsonText.slice(start, end + 1);
    }

    let parsed: Array<{ original?: string; improved?: string; tip_en?: string }>;
    try {
      parsed = JSON.parse(jsonText);
      if (!Array.isArray(parsed)) throw new Error('not an array');
    } catch (parseErr) {
      console.error('recap: failed to parse model output:', rawText);
      return res.status(502).json({ error: 'Failed to parse recap response' });
    }

    const corrections = parsed
      .slice(0, 3)
      .map((c) => ({
        original: c.original ?? '',
        improved: c.improved ?? '',
        tip_en: c.tip_en ?? '',
      }))
      .filter((c) => c.original && c.improved);

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
        metadata: { feature: 'recap', scene: sceneId ?? null, correctionCount: corrections.length },
      });
      if (logError) {
        console.error('usage_logs insert failed:', logError.code, logError.message);
      }
    } catch (err) {
      console.error('Failed to log recap usage:', err);
    }

    return res.status(200).json({ corrections });
  } catch (error: any) {
    console.error('Recap API error:', error);

    const status = error?.status;
    const isOverloaded =
      status === 529 ||
      error?.type === 'overloaded_error' ||
      error?.error?.error?.type === 'overloaded_error';
    if (isOverloaded || status === 503) {
      return res.status(503).json({
        error: 'The recap service is busy right now. Please try again in a moment.',
      });
    }

    return res.status(500).json({
      error: 'Internal server error',
      message: error?.message || 'Unknown error',
    });
  }
}
