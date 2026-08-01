import { VercelRequest, VercelResponse } from '@vercel/node';
import { createClient, SupabaseClient } from '@supabase/supabase-js';

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
 * GET /api/analytics?token=<supabase access token>
 *
 * ユーザーの学習統計を返す（Premium 限定）。
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

    // 2. Premium ステータス確認
    const { data: rateLimit, error: rateLimitError } = await supabase
      .from('rate_limits')
      .select('is_premium')
      .eq('user_id', userId)
      .single();

    if (rateLimitError) {
      console.error('rate_limits select (is_premium) failed:', rateLimitError.code, rateLimitError.message, rateLimitError.details);
    }
    if (rateLimitError || !rateLimit?.is_premium) {
      return res.status(403).json({
        error: 'Premium required',
        message: 'This feature is only available for Premium subscribers.',
      });
    }

    // 3. 統計データ取得
    const stats = await getAnalyticsStats(supabase, userId);

    return res.status(200).json({
      userId,
      stats,
      generatedAt: new Date().toISOString(),
    });
  } catch (error: any) {
    console.error('Analytics API error:', error);
    return res.status(500).json({
      error: 'Internal server error',
      message: error?.message || 'Unknown error',
    });
  }
}

/**
 * ユーザーの総合分析を取得
 */
async function getAnalyticsStats(
  supabase: SupabaseClient,
  userId: string
): Promise<any> {
  try {
    // 1. 総トークン使用数（usage_logs 新スキーマ: event='message_sent' の output_tokens を集計）
    const { data: tokensData, error: tokensError } = await supabase
      .from('usage_logs')
      .select('input_tokens, output_tokens, created_at')
      .eq('user_id', userId)
      .eq('event', 'message_sent');
    if (tokensError) {
      console.error('usage_logs select (tokens) failed:', tokensError.code, tokensError.message, tokensError.details);
    }

    const totalTokens = (tokensData || []).reduce(
      (sum, log) => sum + (log.output_tokens || 0),
      0
    );
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const tokensToday = (tokensData || [])
      .filter((log) => new Date(log.created_at) >= today)
      .reduce((sum, log) => sum + (log.output_tokens || 0), 0);

    // 2. シーン別進捗
    const { data: sessions, error: sessionsError } = await supabase
      .from('conversation_sessions')
      .select('scene_id, total_messages, total_tokens_used, last_message_at')
      .eq('user_id', userId);
    if (sessionsError) {
      console.error('conversation_sessions select failed:', sessionsError.code, sessionsError.message, sessionsError.details);
    }

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
          (!acc[sceneId].lastActive ||
            new Date(session.last_message_at) > new Date(acc[sceneId].lastActive))
        ) {
          acc[sceneId].lastActive = session.last_message_at;
        }
        return acc;
      },
      {}
    );

    // 3. 学習時間計算（セッション数から推定）
    // 算出式(セッション数×5分)は維持。以前は時間へfloor()していたため
    // 60分未満(11セッションまで)が常に「0h」表示になっていた
    // (2026-08-01実機確認)。分単位の生値を返し、表示側で分/時間を
    // 切り替える。
    const totalSessions = sessions?.length || 0;
    const estimatedLearningMinutes = totalSessions * 5; // 各セッション平均5分と仮定

    // 4. 使用エラー数
    // 新スキーマの usage_logs はエラーイベントを持たない（event はすべて正常系）ため 0 を返す。
    // 将来エラーを可観測にする場合は event 許容値の追加が必要。
    const totalErrors = 0;

    return {
      overview: {
        totalTokens,
        tokensToday,
        estimatedLearningMinutes,
        totalSessions,
        errorCount: totalErrors,
      },
      engagement: {
        // 連続学習日数はクライアント側(StreakService.getOverallCurrentStreak、
        // user_streaks + 端末ローカル日付基準)で算出するようになったため、
        // ここでは返さない。usage_logsの生タイムスタンプをUTC暦日で再集計する
        // 旧ロジックはローカル日付基準のstreak_service.dartと食い違い、
        // 実機で「7/30に会話記録があるのに連続日数0」の原因になっていた
        // (2026-08-01調査)。
        favoriteScene:
          Object.entries(sceneProgress).sort(
            (a: any, b: any) => b[1].messages - a[1].messages
          )[0]?.[0] || null,
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
