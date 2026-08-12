import { VercelRequest, VercelResponse } from '@vercel/node';
import { createClient } from '@supabase/supabase-js';
import { timingSafeEqual } from 'crypto';
import { baseDailyLimit } from './_constants';
import { upsertPremiumStatus } from './_premium';

/**
 * 環境変数（chat.ts と同方式に統一）
 * - SUPABASE_SERVICE_KEY を優先、無ければ SUPABASE_KEY
 * - REVENUECAT_WEBHOOK_SECRET: RevenueCat ダッシュボードの
 *   Authorization Header Value と完全一致させる
 */
const supabaseUrl = process.env.SUPABASE_URL || '';
const supabaseKey =
  process.env.SUPABASE_SERVICE_KEY || process.env.SUPABASE_KEY || '';
const webhookSecret = process.env.REVENUECAT_WEBHOOK_SECRET || '';

// Premium 付与エンティティ確認後、is_premium=true / daily_limit=50 にするイベント
const GRANT_EVENT_TYPES = new Set([
  'INITIAL_PURCHASE',
  'RENEWAL',
  'UNCANCELLATION',
  'REFUND_REVERSED',
  'SUBSCRIPTION_EXTENDED',
]);

// is_premium=false / daily_limit=5 に戻すイベント。
// CANCELLATION（自動更新OFF）は契約期間終了まで本来アクセス権が残るため対象外。
// 実際のアクセス喪失は EXPIRATION のみで判定する。
// （2026-06決定。ただし返金は下記 REFUND_CANCEL_REASONS で例外扱いする）
const REVOKE_EVENT_TYPES = new Set(['EXPIRATION']);

// RevenueCat には独立した REFUND イベント種別が無く、返金は CANCELLATION
// イベントの cancel_reason='CUSTOMER_SUPPORT' として届く（RevenueCat公式
// ドキュメント「Event Types and Fields」で確認、2026-08-10）。
// 2026-06決定（CANCELLATIONでは降格しない）は自発的解約（UNSUBSCRIBE）には
// 引き続き正しいが、解約と返金が同一イベント種別に集約されているため、
// 返金ケースに限り例外としてここで降格する。
//
// ホワイトリスト方式: CUSTOMER_SUPPORT と明示的に判定できた場合のみ revoke。
// cancel_reason の他の既知の値（UNSUBSCRIBE / BILLING_ERROR /
// DEVELOPER_INITIATED / PRICE_INCREASE / UNKNOWN）や値が無い場合は
// 保守的に none とし、正当な権利を誤って剥奪しない。
// 特に BILLING_ERROR は猶予期間中の一時的な失敗のため、ここで revoke すると
// 猶予期間中に課金が回復したユーザーの権利を誤って剥奪してしまう。
const REFUND_CANCEL_REASONS = new Set(['CUSTOMER_SUPPORT']);

/**
 * POST /api/revenuecat-webhook
 *
 * RevenueCat からのサブスクリプションイベントを受け取り、
 * rate_limits.is_premium / daily_limit を同期する。
 */
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  // 0. 設定チェック
  const missing: string[] = [];
  if (!supabaseUrl) missing.push('SUPABASE_URL');
  if (!supabaseKey) missing.push('SUPABASE_SERVICE_KEY (or SUPABASE_KEY)');
  if (!webhookSecret) missing.push('REVENUECAT_WEBHOOK_SECRET');
  if (missing.length > 0) {
    return res.status(500).json({
      error: 'Server misconfiguration',
      message: `Missing environment variable(s): ${missing.join(', ')}`,
    });
  }

  // 1. Authorization ヘッダー検証（DBアクセスより前に行う）
  const authHeader = req.headers.authorization;
  if (!isValidAuthHeader(authHeader, webhookSecret)) {
    return res.status(401).json({ error: 'Invalid authorization' });
  }

  // クライアントは関数内で生成（モジュール読込時クラッシュを防ぐ）
  const supabase = createClient(supabaseUrl, supabaseKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  try {
    const event = req.body?.event;
    const appUserId: string | undefined = event?.app_user_id;
    const eventType: string | undefined = event?.type;
    const entitlementIds: string[] = event?.entitlement_ids ?? [];
    const cancelReason: string | undefined = event?.cancel_reason;

    if (!appUserId || !eventType) {
      // 不正/想定外のペイロード。リトライさせても無意味なので 200 で受理して終える。
      console.error('revenuecat-webhook: missing app_user_id or type', event);
      return res.status(200).json({ received: true, ignored: true });
    }

    const isTargetEntitlement =
      entitlementIds.includes('Premium') ||
      entitlementIds.includes('voikerchat_premium');

    const isRefundCancellation =
      eventType === 'CANCELLATION' &&
      !!cancelReason &&
      REFUND_CANCEL_REASONS.has(cancelReason);

    let action: 'grant' | 'revoke' | 'none' = 'none';
    if (isTargetEntitlement && GRANT_EVENT_TYPES.has(eventType)) {
      action = 'grant';
    } else if (isTargetEntitlement && REVOKE_EVENT_TYPES.has(eventType)) {
      action = 'revoke';
    } else if (isTargetEntitlement && isRefundCancellation) {
      action = 'revoke';
    }

    if (action === 'none') {
      // TEST / TRANSFER / BILLING_ISSUE / PRODUCT_CHANGE / SUBSCRIPTION_PAUSED /
      // NON_RENEWING_PURCHASE / CANCELLATION(返金以外) 等はログのみ・DB書き込みなし。
      // CANCELLATION は cancel_reason を後から追跡できるようログへ含める。
      const cancelReasonSuffix =
        eventType === 'CANCELLATION' ? ` cancel_reason=${cancelReason ?? '(missing)'}` : '';
      console.log(
        `revenuecat-webhook: no-op for event type ${eventType} (user ${appUserId})${cancelReasonSuffix}`
      );
      return res.status(200).json({ received: true, action: 'none' });
    }

    if (action === 'revoke' && isRefundCancellation) {
      console.log(
        `revenuecat-webhook: refund detected via CANCELLATION cancel_reason=CUSTOMER_SUPPORT (user ${appUserId}), revoking Premium`
      );
    }

    const isPremium = action === 'grant';
    const dailyLimit = baseDailyLimit(isPremium);

    await upsertPremiumStatus(supabase, appUserId, isPremium, dailyLimit, 'revenuecat-webhook');

    return res.status(200).json({ received: true, action, isPremium, dailyLimit });
  } catch (error: any) {
    console.error('revenuecat-webhook: internal error', error);
    return res.status(500).json({
      error: 'Internal server error',
      message: error?.message || 'Unknown error',
    });
  }
}

/**
 * Authorization ヘッダーをタイミングセーフに検証する
 */
function isValidAuthHeader(
  authHeader: string | string[] | undefined,
  expectedSecret: string
): boolean {
  if (typeof authHeader !== 'string' || authHeader.length === 0) {
    return false;
  }

  const provided = Buffer.from(authHeader) as unknown as Uint8Array;
  const expected = Buffer.from(expectedSecret) as unknown as Uint8Array;

  if (provided.length !== expected.length) {
    // 長さ不一致でも比較コストを揃え、タイミングサイドチャネルを避ける
    timingSafeEqual(expected, expected);
    return false;
  }

  return timingSafeEqual(provided, expected);
}
