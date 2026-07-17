import { VercelRequest, VercelResponse } from '@vercel/node';
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.SUPABASE_URL || '';
const supabaseKey =
  process.env.SUPABASE_SERVICE_KEY || process.env.SUPABASE_KEY || '';

/**
 * POST /api/ad-reward
 *
 * リワード広告視聴後の特典付与(セキュリティ強化、2026-07-17)。
 *
 * 従来 grantAdBonus() はクライアント(Flutter)から Supabase の
 * rate_limits を直接 UPDATE していたが、この経路は usage_logs.ad_reward
 * の記録を伴わず、クライアントが直接書き換え可能な穴だった
 * (docs/migrations/2026-07-17_lock_rate_limits_client_write.sql 参照)。
 * 本エンドポイントは service role key で rate_limits 更新 + usage_logs
 * ad_reward 記録の両方をサーバー側だけで行う。
 *
 * 1日1回の判定: 本日分の usage_logs.ad_reward が既にあれば、
 * daily_limit は変更せず success:true(冪等) を返す。
 *
 * Request body: { "token": "supabase access token (JWT)" }
 */
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const missing: string[] = [];
  if (!supabaseUrl) missing.push('SUPABASE_URL');
  if (!supabaseKey) missing.push('SUPABASE_SERVICE_KEY (or SUPABASE_KEY)');
  if (missing.length > 0) {
    return res.status(500).json({
      error: 'Server misconfiguration',
      message: `Missing environment variable(s): ${missing.join(', ')}`,
    });
  }

  const supabase = createClient(supabaseUrl, supabaseKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  try {
    const { token } = req.body || {};
    if (!token) {
      return res.status(401).json({ error: 'Missing authentication token' });
    }

    const { data: userData, error: userErr } = await supabase.auth.getUser(token);
    if (userErr || !userData?.user) {
      return res.status(401).json({ error: 'Invalid or expired token' });
    }
    const userId = userData.user.id;

    const { data: rateLimit, error: fetchError } = await supabase
      .from('rate_limits')
      .select('daily_limit, is_premium')
      .eq('user_id', userId)
      .single();

    if (fetchError || !rateLimit) {
      console.error('rate_limits select failed:', fetchError?.code, fetchError?.message);
      return res.status(404).json({ error: 'Rate limit record not found' });
    }

    // Premium は既に上限50のためボーナス不要(冪等に成功扱い)。
    if (rateLimit.is_premium) {
      return res.status(200).json({
        success: true,
        dailyLimit: rateLimit.daily_limit,
        alreadyGranted: false,
      });
    }

    // 1日1回の判定: 本日分の ad_reward が既に記録済みか確認(多重付与防止)。
    // rate_limits の日次リセット(last_reset_utc)と同一のUTC日付基準。
    const startOfDayUtc = new Date();
    startOfDayUtc.setUTCHours(0, 0, 0, 0);
    const { count, error: countError } = await supabase
      .from('usage_logs')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', userId)
      .eq('event', 'ad_reward')
      .gte('created_at', startOfDayUtc.toISOString());

    if (countError) {
      console.error('usage_logs ad_reward count failed:', countError.code, countError.message);
    }

    if ((count ?? 0) > 0) {
      return res.status(200).json({
        success: true,
        dailyLimit: rateLimit.daily_limit,
        alreadyGranted: true,
      });
    }

    const newLimit = Math.min(rateLimit.daily_limit + 5, 10);

    const { error: updateError } = await supabase
      .from('rate_limits')
      .update({ daily_limit: newLimit })
      .eq('user_id', userId);
    if (updateError) {
      console.error('rate_limits update failed:', updateError.code, updateError.message);
      return res.status(500).json({ error: 'Failed to grant ad bonus' });
    }

    const { error: logError } = await supabase.from('usage_logs').insert({
      user_id: userId,
      event: 'ad_reward',
      is_premium: false,
      metadata: {},
    });
    if (logError) {
      console.error('usage_logs ad_reward insert failed:', logError.code, logError.message);
    }

    return res.status(200).json({
      success: true,
      dailyLimit: newLimit,
      alreadyGranted: false,
    });
  } catch (error: any) {
    console.error('Ad-reward API error:', error);
    return res.status(500).json({
      error: 'Internal server error',
      message: error?.message || 'Unknown error',
    });
  }
}
