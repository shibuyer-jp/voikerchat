/**
 * レート制限まわりの定数の唯一の定義元。
 * api/chat.ts / api/revenuecat-webhook.ts / api/ad-reward.ts / api/rate-limit.ts は
 * すべてここから import する(値の手動同期は行わない)。
 */

// 無料/Premium の基礎日次上限
export const FREE_DAILY_LIMIT = 5;
export const PREMIUM_DAILY_LIMIT = 50;

// 広告視聴ボーナス(無料ユーザーのみ・当日限り)
export const AD_BONUS = 5;
export const FREE_DAILY_CAP = 10; // FREE_DAILY_LIMIT + AD_BONUS

// recap(言い直し復習)と vocab-summary(今日の単語)の合算の軽い日次上限。
// 会話回数(rate_limits)とは別枠。両者はセッション終了時(3往復以上)に
// 1回だけまとめて呼ばれる想定のため、define/hintの30より低い値にしている。
// Premiumは無制限。usage_logs(event='message_sent',
// metadata.feature in ('recap','vocab_summary'))の本日合計件数で判定する。
export const FREE_DAILY_RECAP_LIMIT = 10;

export function baseDailyLimit(isPremium: boolean): number {
  return isPremium ? PREMIUM_DAILY_LIMIT : FREE_DAILY_LIMIT;
}
