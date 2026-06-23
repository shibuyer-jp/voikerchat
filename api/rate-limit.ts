import { VercelRequest, VercelResponse } from '@vercel/node';
import { createClient } from '@supabase/supabase-js';
import * as jwt from 'jsonwebtoken';

const supabaseUrl = process.env.SUPABASE_URL || '';
const supabaseKey = process.env.SUPABASE_KEY || '';
const jwtSecret = process.env.SUPABASE_JWT_SECRET || '';

const supabase = createClient(supabaseUrl, supabaseKey);

interface AuthPayload {
  sub: string;
  iat: number;
  exp: number;
}

/**
 * GET /api/rate-limit
 * 
 * Get current rate limit status
 * Query params: ?token=jwt_token
 */
export default async function handler(req: VercelRequest, res: VercelResponse) {
  // Only GET allowed
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const { token } = req.query;

    // JWT 検証
    if (!token || typeof token !== 'string') {
      return res.status(401).json({ error: 'Missing authentication token' });
    }

    let userId: string;
    try {
      const payload = jwt.verify(token, jwtSecret) as AuthPayload;
      userId = payload.sub;
    } catch (err) {
      return res.status(401).json({ error: 'Invalid or expired token' });
    }

    // Supabase から rate limit 情報取得
    const { data, error } = await supabase
      .from('rate_limits')
      .select('*')
      .eq('user_id', userId)
      .single();

    if (error) {
      // No record: return default
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

    // Check if day has passed (auto-reset)
    const lastReset = new Date(data.last_reset_utc);
    const today = new Date();
    const daysPassed = Math.floor(
      (today.getTime() - lastReset.getTime()) / (1000 * 60 * 60 * 24)
    );

    let usedToday = data.used_today;
    if (daysPassed >= 1) {
      // Reset counter
      await supabase
        .from('rate_limits')
        .update({
          used_today: 0,
          last_reset_utc: today.toISOString(),
        })
        .eq('user_id', userId);
      usedToday = 0;
    }

    const remainingCalls = Math.max(
      0,
      data.daily_limit - usedToday
    );
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
      message: error.message || 'Unknown error',
    });
  }
}
