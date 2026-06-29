import { VercelRequest, VercelResponse } from '@vercel/node';
import { createClient, SupabaseClient } from '@supabase/supabase-js';
import Anthropic from '@anthropic-ai/sdk';

/**
 * 環境変数（名前ゆれ・新旧キーに両対応）
 * - SUPABASE_SERVICE_KEY を優先、無ければ SUPABASE_KEY
 * - ANTHROPIC_API_KEY を優先、無ければ CLAUDE_API_KEY
 * JWT 検証は supabase.auth.getUser(token) で行うため
 * SUPABASE_JWT_SECRET / jsonwebtoken は不要。
 */
const supabaseUrl = process.env.SUPABASE_URL || '';
const supabaseKey =
  process.env.SUPABASE_SERVICE_KEY || process.env.SUPABASE_KEY || '';
const claudeApiKey =
  process.env.ANTHROPIC_API_KEY || process.env.CLAUDE_API_KEY || '';

/**
 * POST /api/chat
 *
 * Server-side rate limiting + Claude Haiku integration
 *
 * Request body:
 * {
 *   "token": "supabase access token (JWT)",
 *   "messages": [{ "role": "user", "content": "..." }],
 *   "sceneId": "scene_123",
 *   "maxTokens": 500
 * }
 */
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  // 0. 設定チェック（不足は原因不明クラッシュにせず、明示エラーで返す）
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

  // クライアントは関数内で生成（モジュール読込時クラッシュを防ぐ）
  const supabase = createClient(supabaseUrl, supabaseKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const anthropic = new Anthropic({ apiKey: claudeApiKey });

  try {
    const { token, messages, sceneId, maxTokens = 500 } = req.body || {};

    // 1. トークン検証（getUser はHS256/非対称鍵いずれの署名でも検証可能）
    if (!token) {
      return res.status(401).json({ error: 'Missing authentication token' });
    }

    const { data: userData, error: userErr } = await supabase.auth.getUser(token);
    if (userErr || !userData?.user) {
      return res.status(401).json({ error: 'Invalid or expired token' });
    }
    const userId = userData.user.id;

    // 2. Premium ステータス取得
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

    // 3. サーバー側レート制限
    if (!isPremium) {
      const canCall = await checkAndIncrementRateLimit(supabase, userId);
      if (!canCall) {
        return res.status(429).json({
          error: 'Daily limit reached',
          message: 'Go Premium to unlock unlimited calls',
        });
      }
    }

    // 4. messages 検証
    if (!Array.isArray(messages) || messages.length === 0) {
      return res.status(400).json({ error: 'Invalid messages format' });
    }

    // 5. Claude Haiku 呼び出し
    const response = await anthropic.messages.create({
      model: 'claude-3-5-haiku-20241022',
      max_tokens: Math.min(maxTokens, 500),
      system: buildSystemPrompt(sceneId),
      messages: messages.map((msg: any) => ({
        role: msg.role as 'user' | 'assistant',
        content: msg.content,
      })),
    });

    // 6. 使用ログ（成功）
    await logUsage(supabase, {
      userId,
      sceneId,
      endpoint: '/api/chat',
      tokensConsumed: response.usage.output_tokens,
      status: 'success',
    });

    // 7. 成功レスポンス
    const content = response.content[0];
    const assistantMessage =
      content.type === 'text' ? content.text : 'Unable to generate response';

    return res.status(200).json({
      success: true,
      content: assistantMessage,
      tokensUsed: response.usage.output_tokens,
      inputTokens: response.usage.input_tokens,
    });
  } catch (error: any) {
    console.error('Chat API error:', error);
    return res.status(500).json({
      error: 'Internal server error',
      message: error?.message || 'Unknown error',
    });
  }
}

/**
 * サーバー側レート制限チェック＆インクリメント
 * 許可なら true、上限到達なら false
 */
async function checkAndIncrementRateLimit(
  supabase: SupabaseClient,
  userId: string
): Promise<boolean> {
  try {
    const { data: rateLimit, error: fetchError } = await supabase
      .from('rate_limits')
      .select('used_today, daily_limit, last_reset_utc')
      .eq('user_id', userId)
      .single();

    if (fetchError || !rateLimit) {
      // レコードなし → デフォルト作成（5回/日）
      await supabase.from('rate_limits').insert({
        user_id: userId,
        used_today: 1,
        daily_limit: 5,
        is_premium: false,
        last_reset_utc: new Date().toISOString(),
      });
      return true;
    }

    const lastReset = new Date(rateLimit.last_reset_utc);
    const today = new Date();
    const daysPassed = Math.floor(
      (today.getTime() - lastReset.getTime()) / (1000 * 60 * 60 * 24)
    );

    if (daysPassed >= 1) {
      await supabase
        .from('rate_limits')
        .update({ used_today: 1, last_reset_utc: today.toISOString() })
        .eq('user_id', userId);
      return true;
    }

    if (rateLimit.used_today >= rateLimit.daily_limit) {
      return false;
    }

    await supabase
      .from('rate_limits')
      .update({ used_today: rateLimit.used_today + 1 })
      .eq('user_id', userId);
    return true;
  } catch (err) {
    console.error('Rate limit check error:', err);
    // 失敗時はフェイルオープン（呼び出しを許可）
    return true;
  }
}

/**
 * シーン別システムプロンプト
 */
function buildSystemPrompt(sceneId: string): string {
  const scenePrompts: { [key: string]: string } = {
    friends: '友達同士の会話をシミュレートしてください。自然で親友のような会話のトーンを使います。',
    restaurant:
      'レストランでのウェイターとお客さんの会話をシミュレートしてください。敬語を使いながらも親切です。',
    shopping:
      '店員と客の会話をシミュレートしてください。商品について質問されて説明します。',
    train: '電車での乗客同士または駅員との会話をシミュレートしてください。',
    hospital:
      '医者と患者の会話をシミュレートしてください。医学用語を使いながらも分かりやすく説明します。',
    introduction: '自己紹介の場面をシミュレートしてください。丁寧で専門的です。',
    cafe: 'カフェでのウェイターと客の会話をシミュレートしてください。',
    freetalk:
      'どのようなトピックの日本語会話でもシミュレートしてください。自然なトーンで。',
    hotblooded:
      '熱血系キャラのトーンで、日本語会話をシミュレートしてください。情熱的で元気です！',
    friendship:
      '友情系キャラのトーンで、日本語会話をシミュレートしてください。温かみのある応答をしてください。',
    emotional:
      '感動系シーンの日本語会話をシミュレートしてください。感情的で心に訴える返答をしてください。',
    school: '学園系シーンの日本語会話をシミュレートしてください。学生らしいトーンで。',
    comedy:
      'ギャグ系シーンの日本語会話をシミュレートしてください。ユーモア溢れた返答をしてください。',
  };

  return (
    scenePrompts[sceneId] ||
    'You are a helpful Japanese language conversation partner. Respond naturally in Japanese.'
  );
}

/**
 * usage_logs への記録（失敗しても本処理は止めない）
 */
async function logUsage(
  supabase: SupabaseClient,
  params: {
    userId: string;
    sceneId?: string;
    endpoint: string;
    tokensConsumed: number;
    status: 'success' | 'error';
    errorMessage?: string;
  }
): Promise<void> {
  try {
    await supabase.from('usage_logs').insert({
      user_id: params.userId,
      scene_id: params.sceneId || null,
      api_endpoint: params.endpoint,
      tokens_consumed: params.tokensConsumed,
      status: params.status,
      error_message: params.errorMessage || null,
      created_at: new Date().toISOString(),
    });
  } catch (err) {
    console.error('Failed to log usage:', err);
  }
}
