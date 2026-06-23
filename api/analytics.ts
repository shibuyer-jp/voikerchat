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
 * GET /api/analytics
 * 
 * Get user learning analytics (Premium only)
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

    // Premium ステータス確認
    const { data: rateLimit, error: rateLimitError } = await supabase
      .from('rate_limits')
      .select('is_premium')
      .eq('user_id', userId)
      .single();

    if (rateLimitError || !rateLimit?.is_premium) {
      return res.status(403).json({
        error: 'Premium required',
        message: 'This feature is only available for Premium subscribers.',
      });
    }

    // 統計データ取得
    const stats = await getAnalyticsStats(userId);

    return res.status(200).json({
      userId,
      stats,
      generatedAt: new Date().toISOString(),
    });
  } catch (error: any) {
    console.error('Analytics API error:', error);
    return res.status(500).json({
      error: 'Internal server error',
      message: error.message || 'Unknown error',
    });
  }
}

/**
 * Get comprehensive analytics for user
 */
async function getAnalyticsStats(userId: string): Promise<any> {
  try {
    // 1. 総トークン使用数
    const { data: tokensData } = await supabase
      .from('usage_logs')
      .select('tokens_consumed, created_at')
      .eq('user_id', userId)
      .eq('status', 'success');

    const totalTokens = (tokensData || []).reduce((sum, log) => sum + (log.tokens_consumed || 0), 0);
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const tokensToday = (tokensData || [])
      .filter((log) => new Date(log.created_at) >= today)
      .reduce((sum, log) => sum + (log.tokens_consumed || 0), 0);

    // 2. シーン別進捗
    const { data: sessions } = await supabase
      .from('conversation_sessions')
      .select('scene_id, total_messages, total_tokens_used, last_message_at')
      .eq('user_id', userId);

    const sceneProgress = (sessions || []).reduce(
      (acc: any, session: any) => {
        const sceneId = session.scene_id || 'unknown';
        if (!acc[sceneId]) {
          acc[sceneId] = {
            messages: 0,
            tokens: 0,
            lastActive: null,
          };
        }
        acc[sceneId].messages += session.total_messages || 0;
        acc[sceneId].tokens += session.total_tokens_used || 0;
        if (
          session.last_message_at &&
          (!acc[sceneId].lastActive || new Date(session.last_message_at) > new Date(acc[sceneId].lastActive))
        ) {
          acc[sceneId].lastActive = session.last_message_at;
        }
        return acc;
      },
      {}
    );

    // 3. 学習時間計算（セッション数から推定）
    const totalSessions = sessions?.length || 0;
    const estimatedMinutes = totalSessions * 5; // 各セッション平均5分と仮定
    const estimatedHours = Math.floor(estimatedMinutes / 60);

    // 4. 使用エラー数
    const { data: errorLogs } = await supabase
      .from('usage_logs')
      .select('id')
      .eq('user_id', userId)
      .eq('status', 'error');

    const totalErrors = errorLogs?.length || 0;

    // 5. 連続学習日数（簡易版）
    const { data: dateActivity } = await supabase
      .from('usage_logs')
      .select('created_at')
      .eq('user_id', userId)
      .eq('status', 'success')
      .order('created_at', { ascending: false });

    let consecutiveDays = 0;
    if (dateActivity && dateActivity.length > 0) {
      const dates = new Set<string>();
      dateActivity.forEach((log) => {
        const date = new Date(log.created_at).toISOString().split('T')[0];
        dates.add(date);
      });

      // Convert to sorted array
      const sortedDates = Array.from(dates).sort().reverse();
      const today = new Date().toISOString().split('T')[0];

      if (sortedDates[0] === today || sortedDates[0] === getYesterdayDate()) {
        let current = new Date(sortedDates[0]);
        for (const dateStr of sortedDates) {
          const date = new Date(dateStr);
          const diff = Math.floor((current.getTime() - date.getTime()) / (1000 * 60 * 60 * 24));
          if (diff === 0 || diff === 1) {
            consecutiveDays++;
            current = date;
          } else {
            break;
          }
        }
      }
    }

    return {
      overview: {
        totalTokens,
        tokensToday,
        estimatedLearningHours: estimatedHours,
        totalSessions,
        errorCount: totalErrors,
      },
      engagement: {
        consecutiveLearningDays: consecutiveDays,
        favoriteScene: Object.entries(sceneProgress)
          .sort((a: any, b: any) => b[1].messages - a[1].messages)[0]?.[0] || null,
      },
      sceneProgress,
      timestamps: {
        generated: new Date().toISOString(),
      },
    };
  } catch (err) {
    console.error('Error getting analytics stats:', err);
    throw err;
  }
}

/**
 * Helper function to get yesterday's date string
 */
function getYesterdayDate(): string {
  const yesterday = new Date();
  yesterday.setDate(yesterday.getDate() - 1);
  return yesterday.toISOString().split('T')[0];
}
