import { VercelRequest, VercelResponse } from '@vercel/node';
import { createClient } from '@supabase/supabase-js';
import Anthropic from '@anthropic-ai/sdk';

/**
 * 環境変数(chat.ts と同一の名前ゆれ対応)。
 */
const supabaseUrl = process.env.SUPABASE_URL || '';
const supabaseKey =
  process.env.SUPABASE_SERVICE_KEY || process.env.SUPABASE_KEY || '';
const claudeApiKey =
  process.env.ANTHROPIC_API_KEY || process.env.CLAUDE_API_KEY || '';

// 辞書機能専用の軽い日次上限(会話回数の rate_limits とは別枠、T-31)。
// Premium は無制限。usage_logs(event='message_sent', metadata.feature='define')の
// 本日件数で判定する(rate_limits のスキーマ変更はしない)。
const FREE_DAILY_DEFINE_LIMIT = 30;

const DEFINE_SYSTEM_PROMPT = `You are a Japanese dictionary assistant helping a Filipino learner understand a word or phrase from a conversation.

Given a Japanese term (possibly inflected/conjugated) and the full sentence it appeared in, respond with ONLY a single-line minified JSON object with exactly these keys:
{"reading":"...","meaning_en":"...","meaning_fil":"...","example_ja":"...","example_en":"..."}

- reading: hiragana reading of the term (empty string if the term has no kanji)
- meaning_en: short, simple English meaning of the term AS USED in the given sentence
- meaning_fil: short, simple Tagalog meaning of the term AS USED in the given sentence
- example_ja: one short, natural Japanese example sentence using the term (different from the given sentence)
- example_en: English translation of example_ja

Output ONLY the JSON object. No markdown, no code fences, no explanation, no extra text.`;

/**
 * POST /api/define
 *
 * AIメッセージ内で選択した語句の意味を調べる(T-31)。
 * 会話回数(rate_limits)は消費しない。
 *
 * Request body:
 * {
 *   "token": "supabase access token (JWT)",
 *   "term": "選択された語句",
 *   "context": "その語句が含まれるメッセージ全文",
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
    const { token, term, context, sceneId } = req.body || {};

    if (!token) {
      return res.status(401).json({ error: 'Missing authentication token' });
    }
    if (typeof term !== 'string' || !term.trim() || term.length > 50) {
      return res.status(400).json({ error: 'Invalid term' });
    }
    if (typeof context !== 'string' || context.length > 2000) {
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

    // 辞書専用の軽い日次上限(Premiumは無制限)
    if (!isPremium) {
      const startOfDayUtc = new Date();
      startOfDayUtc.setUTCHours(0, 0, 0, 0);
      const { count, error: countError } = await supabase
        .from('usage_logs')
        .select('id', { count: 'exact', head: true })
        .eq('user_id', userId)
        .eq('event', 'message_sent')
        .eq('metadata->>feature', 'define')
        .gte('created_at', startOfDayUtc.toISOString());

      if (countError) {
        console.error('usage_logs count failed:', countError.code, countError.message);
      } else if ((count ?? 0) >= FREE_DAILY_DEFINE_LIMIT) {
        return res.status(429).json({
          error: 'Daily dictionary lookup limit reached',
        });
      }
    }

    const response = await anthropic.messages.create({
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

    const content = response.content[0];
    const rawText = content.type === 'text' ? content.text : '';

    let parsed: Record<string, string>;
    try {
      parsed = JSON.parse(rawText.trim());
    } catch (parseErr) {
      console.error('define: failed to parse model output:', rawText);
      return res.status(502).json({ error: 'Failed to parse dictionary response' });
    }

    // 使用ログ(失敗しても本処理は止めない)。既存の event 種別のみ使用し、
    // metadata.feature で辞書機能を識別する(usage_logs のスキーマ変更はしない)。
    try {
      const { error: logError } = await supabase.from('usage_logs').insert({
        user_id: userId,
        event: 'message_sent',
        model: 'claude-haiku-4-5-20251001',
        is_premium: isPremium,
        input_tokens: response.usage.input_tokens,
        output_tokens: response.usage.output_tokens,
        metadata: { feature: 'define', scene: sceneId ?? null, term },
      });
      if (logError) {
        console.error('usage_logs insert failed:', logError.code, logError.message);
      }
    } catch (err) {
      console.error('Failed to log define usage:', err);
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
