import { SupabaseClient } from '@supabase/supabase-js';

/**
 * rate_limits の is_premium / daily_limit を upsert する共通ヘルパー。
 * api/revenuecat-webhook.ts と api/premium-sync.ts の両方から使う
 * (2026-08-07、premium-sync新設に伴い revenuecat-webhook.ts から抽出)。
 * used_today / last_reset_utc は更新しない（レート制限カウントには干渉しない）。
 */
export async function upsertPremiumStatus(
  supabase: SupabaseClient,
  userId: string,
  isPremium: boolean,
  dailyLimit: number,
  logPrefix = 'premium'
): Promise<void> {
  const { data: existing, error: selectError } = await supabase
    .from('rate_limits')
    .select('user_id')
    .eq('user_id', userId)
    .single();

  if (selectError || !existing) {
    if (selectError) {
      console.error(
        `${logPrefix}: rate_limits select failed:`,
        selectError.code,
        selectError.message,
        selectError.details
      );
    }
    const { error: insertError } = await supabase.from('rate_limits').insert({
      user_id: userId,
      used_today: 0,
      daily_limit: dailyLimit,
      is_premium: isPremium,
      last_reset_utc: new Date().toISOString(),
    });
    if (insertError) {
      console.error(
        `${logPrefix}: rate_limits insert failed:`,
        insertError.code,
        insertError.message,
        insertError.details
      );
    }
    return;
  }

  const { error: updateError } = await supabase
    .from('rate_limits')
    .update({ is_premium: isPremium, daily_limit: dailyLimit })
    .eq('user_id', userId);
  if (updateError) {
    console.error(
      `${logPrefix}: rate_limits update failed:`,
      updateError.code,
      updateError.message,
      updateError.details
    );
  }
}
