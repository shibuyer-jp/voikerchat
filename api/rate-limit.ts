import { VercelRequest, VercelResponse } from '@vercel/node';
import { createClient } from '@supabase/supabase-js';

/**
 * 環境変数（chat.ts と同方式に統一）
 * - SUPABASE_SERVICE_KEY を優先、無ければ SUPABASE_KEY
 * - JWT 検証は supabase.auth.getUser(token) で行うため
 *   SUPABASE_JWT_SECRET / jsonwebtoken は不要。
 */
const supabaseUrl = process.env.SUPABASE_URL || '';
const supabaseKey =
  process.env.SUPABASE_SERVICE_KEY || process.env.SUPABASE_KEY || '';

/**
 * GET /api/rate-limit?token=<supabase access token>
 *
 * 現在のレート制限ステータスを返す。
 */
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  // 0. 設定チェック（不足は原因不明クラッシュにせず、明示エラーで返す）
  const missing: string[] = [];
  if (!supabaseUrl) missing.push('SUPABASE_URL');
  if (!supabaseKey) missing.push('SUPABASE_SERVICE_KEY (or SUPABASE_KEY)');
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

  try {
    const { token } = req.query;

    // 1. トークン検証（getUser はHS256/非対称鍵いずれの署名でも検証可能）
    if (!token || typeof token !== 'string') {
      return res.status(401).json({ error: 'Missing authentication token' });
    }

    const { data: userData, error: userErr } = await supabase.auth.getUser(token);
    if (userErr || !userData?.user) {
      return res.status(401).json({ error: 'Invalid or expired token' });
    }
    const userId = userData.user.id;

    // 2. Supabase から rate limit 情報取得
    const { data, error } = await supabase
      .from('rate_limits')
      .select('*')
      .eq('user_id', userId)
      .single();

    if (error) {
      // レコードなし → デフォルトを返す
      return res.status(200).json({
        userId,
        isPremium: false,
        usedToday: 0,
        dailyLimit: 5,
        remainingCalls: 5,
        usagePercentage: 0,
        canMakeCall: true,
      });
    }

    // 3. 日付が変わっていれば自動リセット
    const lastReset = new Date(data.last_reset_utc);
    const today = new Date();
    const daysPassed = Math.floor(
      (today.getTime() - lastReset.getTime()) / (1000 * 60 * 60 * 24)
    );

    let usedToday = data.used_today;
    if (daysPassed >= 1) {
      await supabase
        .from('rate_limits')
        .update({
          used_today: 0,
          last_reset_utc: today.toISOString(),
        })
        .eq('user_id', userId);
      usedToday = 0;
    }

    const remainingCalls = Math.max(0, data.daily_limit - usedToday);
    const usagePercentage = (usedToday / data.daily_limit) * 100;

    return res.status(200).json({
      userId,
      isPremium: data.is_premium === true,
      usedToday,
      dailyLimit: data.daily_limit,
      remainingCalls,
      usagePercentage: Math.min(100, usagePercentage),
      canMakeCall: data.is_premium === true || usedToday < data.daily_limit,
    });
  } catch (error: any) {
    console.error('Rate limit API error:', error);
    return res.status(500).json({
      error: 'Internal server error',
      message: error?.message || 'Unknown error',
    });
  }
}
