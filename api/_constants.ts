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

export function baseDailyLimit(isPremium: boolean): number {
  return isPremium ? PREMIUM_DAILY_LIMIT : FREE_DAILY_LIMIT;
}
