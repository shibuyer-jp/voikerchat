import { VercelRequest, VercelResponse } from '@vercel/node';
import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { baseDailyLimit } from './_constants';
import { upsertPremiumStatus } from './_premium';
import { sanitizeLocale, sanitizePlatform } from './_validation';

/**
 * 環境変数(chat.ts と同方式に統一)。
 * REVENUECAT_SECRET_KEY はRevenueCatダッシュボードの「API keys → Secret
 * keys」から発行する、サーバー間連携専用のキー(公開SDKキーとは別物)。
 * クライアントには絶対に渡さない。
 */
const supabaseUrl = process.env.SUPABASE_URL || '';
const supabaseKey =
  process.env.SUPABASE_SERVICE_KEY || process.env.SUPABASE_KEY || '';
const revenueCatSecretKey = process.env.REVENUECAT_SECRET_KEY || '';

// 1ユーザーあたりの1日の呼び出し上限(乱用防止)。想定呼び出し頻度は
// 起動ごとに最大1回のみだが、リトライ等の余裕を持たせる
// (api/recap.ts の FREE_DAILY_RECAP_LIMIT と同じ「usage_logs当日件数」方式)。
const PREMIUM_SYNC_DAILY_LIMIT = 10;

// RevenueCatのentitlement識別子(revenuecat_service.dart / revenuecat-webhook.ts と同一)
const TARGET_ENTITLEMENT_IDS = ['Premium', 'voikerchat_premium'];

/**
 * POST /api/premium-sync
 *
 * クライアント側RevenueCatがPremiumと判定しているのに、サーバー側
 * rate_limits.is_premiumがfalseのまま(再インストール等でwebhookが
 * 発火しなかったケース)を解消するための再照合エンドポイント。
 *
 * 重要: クライアントからの自己申告(「自分はPremiumです」)は一切信用しない。
 * 認証済みuser_idを RevenueCat の app_user_id として REST API に直接問い合わせ、
 * 実際にactiveなentitlementが存在することを検証してから
 * rate_limits.is_premium を更新する。
 *
 * 背景: internal-docs/reports/premium_state_mismatch_20260807.md参照。
 * 再インストール時、新しい匿名user_idに対してRevenueCatの
 * restorePurchases()/logIn()経由の復元はwebhookのGRANT_EVENT_TYPESの
 * いずれも発火させないため(TRANSFERは明示的にno-op)、rate_limits側の
 * Premiumフラグが次回のRENEWALまで最大30日間取り残される不具合の対策。
 *
 * Request body: { "token": "supabase access token (JWT)" }
 * Response: { "isPremium": boolean, "dailyLimit": number, "synced": boolean }
 */
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const missing: string[] = [];
  if (!supabaseUrl) missing.push('SUPABASE_URL');
  if (!supabaseKey) missing.push('SUPABASE_SERVICE_KEY (or SUPABASE_KEY)');
  if (!revenueCatSecretKey) missing.push('REVENUECAT_SECRET_KEY');
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
    const { token, locale, platform } = req.body || {};

    if (!token || typeof token !== 'string') {
      return res.status(401).json({ error: 'Missing authentication token' });
    }

    const { data: userData, error: userErr } = await supabase.auth.getUser(token);
    if (userErr || !userData?.user) {
      return res.status(401).json({ error: 'Invalid or expired token' });
    }
    const userId = userData.user.id;

    // 1. レート制限(recap/vocab-summaryと同方式: usage_logsの当日件数)。
    //    RevenueCat REST APIを叩く前に確認し、乱用時の外部API呼び出しを避ける。
    const startOfDayUtc = new Date();
    startOfDayUtc.setUTCHours(0, 0, 0, 0);
    const { count, error: countError } = await supabase
      .from('usage_logs')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', userId)
      .eq('event', 'premium_sync')
      .gte('created_at', startOfDayUtc.toISOString());

    if (countError) {
      // usage_logs.event の CHECK 制約に 'premium_sync' がまだ追加されていない
      // (internal-docs/migrations/2026-08-07_add_usage_logs_premium_sync_event.sql
      // 未実行)場合もここでエラーになりうるが、レート制限自体は本エンドポイントの
      // 核心機能ではないため、カウント失敗時は制限なしとして処理を継続する。
      console.error('premium-sync: usage_logs count failed:', countError.code, countError.message);
    } else if ((count ?? 0) >= PREMIUM_SYNC_DAILY_LIMIT) {
      return res.status(429).json({ error: 'Daily premium-sync limit reached' });
    }

    // 2. 現在のサーバー側状態を取得(既にPremiumならRevenueCatへ問い合わせる必要なし)。
    const { data: currentRow } = await supabase
      .from('rate_limits')
      .select('is_premium, daily_limit')
      .eq('user_id', userId)
      .single();

    if (currentRow?.is_premium === true) {
      await logSyncAttempt(supabase, userId, 'already_premium', locale, platform);
      return res.status(200).json({
        isPremium: true,
        dailyLimit: currentRow.daily_limit,
        synced: false,
      });
    }

    // 3. RevenueCat REST API へ直接問い合わせて実際のentitlementを検証する。
    //    app_user_id は Purchases.logIn(supabaseUserId) により Supabase の
    //    user_id と一致している前提(lib/main.dart参照)。
    const verifiedIsPremium = await verifyActiveEntitlement(userId);

    if (verifiedIsPremium === null) {
      // RevenueCat API自体への到達に失敗(ネットワーク/5xx等)。
      // クライアントの申告を信用して書き込むことは絶対に行わず、何もしない。
      await logSyncAttempt(supabase, userId, 'revenuecat_unreachable', locale, platform);
      return res.status(502).json({ error: 'Failed to verify entitlement with RevenueCat' });
    }

    if (!verifiedIsPremium) {
      // RevenueCatも「Premiumではない」と回答。クライアント側のキャッシュが
      // 古いだけの可能性が高いため、サーバー側は変更せずクライアントに
      // 正しい状態を伝えて終える。
      await logSyncAttempt(supabase, userId, 'verified_inactive', locale, platform);
      return res.status(200).json({
        isPremium: false,
        dailyLimit: currentRow?.daily_limit ?? baseDailyLimit(false),
        synced: false,
      });
    }

    // 4. 検証済み。rate_limits を更新する。
    const dailyLimit = baseDailyLimit(true);
    await upsertPremiumStatus(supabase, userId, true, dailyLimit, 'premium-sync');
    await logSyncAttempt(supabase, userId, 'granted', locale, platform);

    return res.status(200).json({ isPremium: true, dailyLimit, synced: true });
  } catch (error: any) {
    console.error('premium-sync: internal error', error);
    return res.status(500).json({
      error: 'Internal server error',
      message: error?.message || 'Unknown error',
    });
  }
}

/**
 * RevenueCat REST API (GET /v1/subscribers/{app_user_id}) へ問い合わせ、
 * 対象entitlementが実際にactiveかを検証する。
 * 戻り値: true=active確認 / false=未加入と確認 / null=問い合わせ自体に失敗(判定不能)
 *
 * [未確認] RevenueCatはv2 REST API(/v2/customers/{id})への移行を進めている場合が
 * あるため、本実装後にRevenueCat公式ドキュメントで現行のエンドポイントを確認すること。
 */
async function verifyActiveEntitlement(appUserId: string): Promise<boolean | null> {
  try {
    const response = await fetch(
      `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(appUserId)}`,
      {
        headers: {
          Authorization: `Bearer ${revenueCatSecretKey}`,
          Accept: 'application/json',
        },
      }
    );

    if (response.status === 404) {
      // RevenueCat側にまだ存在しないapp_user_id(未購入等)。
      return false;
    }
    if (!response.ok) {
      console.error('premium-sync: RevenueCat API error', response.status, await response.text());
      return null;
    }

    const data = await response.json();
    const entitlements = data?.subscriber?.entitlements ?? {};
    const now = Date.now();

    for (const id of TARGET_ENTITLEMENT_IDS) {
      const entitlement = entitlements[id];
      if (!entitlement) continue;
      const expiresDate = entitlement.expires_date;
      // expires_date が null = 期限なし(active)。日時指定ありなら未来かどうかで判定。
      if (!expiresDate || new Date(expiresDate).getTime() > now) {
        return true;
      }
    }
    return false;
  } catch (error) {
    console.error('premium-sync: RevenueCat fetch failed', error);
    return null;
  }
}

/**
 * usage_logsへの監査ログ書き込み(best-effort、失敗を握り潰す。他エンドポイントと同方針)。
 */
async function logSyncAttempt(
  supabase: SupabaseClient,
  userId: string,
  result: 'granted' | 'already_premium' | 'verified_inactive' | 'revenuecat_unreachable',
  locale: unknown,
  platform: unknown
): Promise<void> {
  try {
    const { error } = await supabase.from('usage_logs').insert({
      user_id: userId,
      event: 'premium_sync',
      platform: sanitizePlatform(platform),
      locale: sanitizeLocale(locale),
      metadata: { result },
    });
    if (error) {
      console.error('premium-sync: usage_logs insert failed:', error.code, error.message);
    }
  } catch (err) {
    console.error('premium-sync: failed to log sync attempt:', err);
  }
}
