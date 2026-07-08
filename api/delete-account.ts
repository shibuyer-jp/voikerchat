import { VercelRequest, VercelResponse } from '@vercel/node';
import { createClient } from '@supabase/supabase-js';

/**
 * 環境変数（chat.ts / rate-limit.ts と同方式に統一）
 * - SUPABASE_SERVICE_KEY を優先、無ければ SUPABASE_KEY
 * - JWT 検証は supabase.auth.getUser(token) で行う。
 *
 * 注意: auth.admin.deleteUser は service_role キーが必須。
 * SUPABASE_KEY（anon）しか無い環境では認証ユーザー削除に失敗する。
 */
const supabaseUrl = process.env.SUPABASE_URL || '';
const supabaseKey =
  process.env.SUPABASE_SERVICE_KEY || process.env.SUPABASE_KEY || '';

/**
 * ユーザーデータを保持するテーブル（すべて user_id で所有者を判別）。
 * 認証ユーザー削除の前に明示削除する（FK に ON DELETE CASCADE が無い
 * テーブルでも孤児行を残さないため）。存在しないテーブルはログのみで継続。
 */
const USER_DATA_TABLES = [
  'messages',
  'conversation_sessions',
  'user_streaks',
  'rate_limits',
  'usage_logs',
  'notification_history',
];

/** POST body / Authorization ヘッダ / query のいずれからでもトークンを受け取る。 */
function extractToken(req: VercelRequest): string | null {
  const body = (req.body ?? {}) as Record<string, unknown>;
  if (typeof body.token === 'string' && body.token) return body.token;

  const auth = req.headers['authorization'];
  if (typeof auth === 'string' && auth.startsWith('Bearer ')) {
    return auth.slice('Bearer '.length);
  }

  const q = req.query.token;
  if (typeof q === 'string' && q) return q;

  return null;
}

/**
 * POST /api/delete-account
 * body: { token: <supabase access token> }
 *
 * 認証ユーザー本人のアカウントと全学習データを完全削除する（不可逆）。
 */
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  // 0. 設定チェック（不足は明示エラーで返す）
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
    // 1. トークン検証 → 本人の user_id を確定（他人のアカウントは削除できない）
    const token = extractToken(req);
    if (!token) {
      return res.status(401).json({ error: 'Missing authentication token' });
    }

    const { data: userData, error: userErr } = await supabase.auth.getUser(token);
    if (userErr || !userData?.user) {
      return res.status(401).json({ error: 'Invalid or expired token' });
    }
    const userId = userData.user.id;

    // 2. 学習データを明示削除（ベストエフォート。存在しない表はログのみで継続）
    for (const table of USER_DATA_TABLES) {
      const { error } = await supabase.from(table).delete().eq('user_id', userId);
      if (error) {
        console.error(
          `delete-account: failed to clear ${table}:`,
          error.code,
          error.message,
          error.details
        );
        // テーブル不在（42P01 / PGRST205）等は無視して継続。
        // 認証ユーザー削除まで到達することを優先する。
      }
    }

    // 3. 認証ユーザー本体を削除（service_role 必須・authoritative）
    const { error: delErr } = await supabase.auth.admin.deleteUser(userId);
    if (delErr) {
      console.error(
        'delete-account: auth.admin.deleteUser failed:',
        delErr.name,
        delErr.message
      );
      return res.status(500).json({
        error: 'Failed to delete account',
        message: delErr.message,
      });
    }

    return res.status(200).json({ ok: true, deletedUserId: userId });
  } catch (error: any) {
    console.error('Delete account API error:', error);
    return res.status(500).json({
      error: 'Internal server error',
      message: error?.message || 'Unknown error',
    });
  }
}
