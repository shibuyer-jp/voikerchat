import { VercelRequest, VercelResponse } from '@vercel/node';
import { createClient } from '@supabase/supabase-js';
import Anthropic from '@anthropic-ai/sdk';
import { sanitizeLocale, sanitizePlatform } from './_validation';

/**
 * 環境変数(chat.ts と同一の名前ゆれ対応)。
 */
const supabaseUrl = process.env.SUPABASE_URL || '';
const supabaseKey =
  process.env.SUPABASE_SERVICE_KEY || process.env.SUPABASE_KEY || '';
const claudeApiKey =
  process.env.ANTHROPIC_API_KEY || process.env.CLAUDE_API_KEY || '';

// 辞書(T-31)と合算の軽い日次上限。カウント自体は api/define.ts 側で
// metadata.feature in ('define','hint') として判定するため、ここでは
// 上限値の重複定義を避け、同じ値のみ持つ(判定ロジックはdefine.tsに集約)。
const FREE_DAILY_DEFINE_HINT_LIMIT = 30;

const HINT_SYSTEM_PROMPT = `You are a Japanese conversation coach helping a Filipino learner figure out what to say next in an ongoing roleplay conversation.

Given the recent conversation context, suggest ONE short, natural Japanese sentence the learner could say next, matching their apparent level. Respond with ONLY a single-line minified JSON object with exactly these keys:
{"example_ja":"...","example_en":"..."}

- example_ja: one short, natural Japanese sentence appropriate as the learner's next line
- example_en: English translation of example_ja

Output ONLY the JSON object. No markdown, no code fences, no explanation, no extra text.`;

/**
 * POST /api/hint
 *
 * 会話の続き方に迷った時のヒント(次に言えそうな例文+英訳)を1つ返す(T-36)。
 * 会話回数(rate_limits)は消費しない。T-31の辞書機能と合算の軽い日次上限を
 * usage_logs(event='message_sent', metadata.feature in ('define','hint'))で判定。
 *
 * Request body:
 * {
 *   "token": "supabase access token (JWT)",
 *   "context": "直近の会話(役割と発話を含む短いテキスト)",
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
    const { token, context, sceneId, locale, platform } = req.body || {};

    if (!token) {
      return res.status(401).json({ error: 'Missing authentication token' });
    }
    if (typeof context !== 'string' || !context.trim() || context.length > 3000) {
      return res.status(400).json({ error: 'Invalid context' });
    }

    const { data: userData, error: userErr } = await supabase.auth.getUser(token);
    if (userErr || !userData?.user) {
      return res.status(401).json({ error: 'Invalid or expired token' });
    }
    const userId = userData.user.id;

    // Premium ステータス取得(会話と同じ判定元)
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

    // 辞書(T-31)と合算の軽い日次上限(Premiumは無制限)
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
          error: 'Daily hint/lookup limit reached',
        });
      }
    }

    const response = await anthropic.messages.create({
      model: 'claude-haiku-4-5-20251001',
      max_tokens: 150,
      system: HINT_SYSTEM_PROMPT,
      messages: [
        {
          role: 'user',
          content: `Recent conversation:\n${context}`,
        },
      ],
    });

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

    let parsed: Record<string, string>;
    try {
      parsed = JSON.parse(jsonText);
    } catch (parseErr) {
      console.error('hint: failed to parse model output:', rawText);
      return res.status(502).json({ error: 'Failed to parse hint response' });
    }

    // 使用ログ(失敗しても本処理は止めない)。既存の event 種別のみ使用し、
    // metadata.feature で識別する(usage_logs のスキーマ変更はしない)。
    // 命名注意: オンボーディングの recordHintUsage とは別物(仕様書指摘通り)。
    try {
      const { error: logError } = await supabase.from('usage_logs').insert({
        user_id: userId,
        event: 'message_sent',
        model: 'claude-haiku-4-5-20251001',
        is_premium: isPremium,
        input_tokens: response.usage.input_tokens,
        output_tokens: response.usage.output_tokens,
        platform: sanitizePlatform(platform),
        locale: sanitizeLocale(locale),
        metadata: { feature: 'hint', scene: sceneId ?? null },
      });
      if (logError) {
        console.error('usage_logs insert failed:', logError.code, logError.message);
      }
    } catch (err) {
      console.error('Failed to log hint usage:', err);
    }

    return res.status(200).json({
      example_ja: parsed.example_ja ?? '',
      example_en: parsed.example_en ?? '',
    });
  } catch (error: any) {
    console.error('Hint API error:', error);

    const status = error?.status;
    const isOverloaded =
      status === 529 ||
      error?.type === 'overloaded_error' ||
      error?.error?.error?.type === 'overloaded_error';
    if (isOverloaded || status === 503) {
      return res.status(503).json({
        error: 'The hint service is busy right now. Please try again in a moment.',
      });
    }

    return res.status(500).json({
      error: 'Internal server error',
      message: error?.message || 'Unknown error',
    });
  }
}
