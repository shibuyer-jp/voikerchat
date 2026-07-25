-- 2026-07-26: daily_limit 日次リセット漏れバグ(api/chat.ts の
-- checkAndIncrementRateLimit() が used_today のみリセットし daily_limit を
-- 基礎値へ戻していなかった)により、広告視聴ボーナス(+5、上限10)を一度でも
-- 受け取った無料ユーザーの daily_limit が 10 のまま恒久化してしまっている
-- データを、基礎値(5)へ是正する。コード側の修正(PR参照)とは別に、
-- 既存データはこのSQLで手当てが必要。
--
-- 【実行手順】上から順に1ブロックずつ Supabase SQL Editor に貼って実行する。
-- 値の手打ち・置換は一切不要(このファイルのままコピペで完結する)。
-- 実行順: このファイルはコード修正(daily_limit 日次リセット追加)のデプロイ
-- 後に実行すること。デプロイ前に実行すると、翌日以降また同じ状態に戻る
-- (是正しても再発する)ため意味がない。

-- ============================================================
-- ステップ1: 影響範囲のプレビュー(UPDATE前に必ず確認)
-- ============================================================
-- 対象: Premiumではない(is_premium = false)のに daily_limit が基礎値(5)を
-- 超えているユーザー。想定される値は基本的に10(5+広告ボーナス5)のみ。
SELECT count(*) AS affected_row_count
FROM public.rate_limits
WHERE is_premium = false
  AND daily_limit > 5;

-- 内訳を見たい場合はこちらも実行(先頭20件のサンプル)
SELECT user_id, daily_limit, used_today, last_reset_utc
FROM public.rate_limits
WHERE is_premium = false
  AND daily_limit > 5
ORDER BY last_reset_utc DESC
LIMIT 20;

-- ============================================================
-- ステップ2: 是正前の状態をバックアップ(ロールバック用)
-- ============================================================
-- 是正対象行の user_id / daily_limit を退避しておく。同名テーブルが
-- 既にある場合は先に別途 DROP してから実行すること(通常は初回のみ実行)。
CREATE TABLE public._rate_limits_daily_limit_backup_20260726 AS
SELECT user_id, daily_limit, is_premium, now() AS backed_up_at
FROM public.rate_limits
WHERE is_premium = false
  AND daily_limit > 5;

-- ============================================================
-- ステップ3: 是正の実行(Premiumユーザーは対象外)
-- ============================================================
UPDATE public.rate_limits
SET daily_limit = 5
WHERE is_premium = false
  AND daily_limit > 5;

-- ============================================================
-- ステップ4: 是正結果の確認
-- ============================================================
-- 0件になっていれば是正完了。
SELECT count(*) AS remaining_over_base_free_users
FROM public.rate_limits
WHERE is_premium = false
  AND daily_limit > 5;

-- Premiumユーザーの daily_limit が意図せず変わっていないことも確認(50のまま)
SELECT count(*) AS premium_users_not_at_50
FROM public.rate_limits
WHERE is_premium = true
  AND daily_limit <> 50;

-- ============================================================
-- ロールバック(万が一、意図しない結果になった場合のみ実行)
-- ============================================================
-- ステップ2のバックアップからdaily_limitを復元する。
-- UPDATE public.rate_limits AS r
-- SET daily_limit = b.daily_limit
-- FROM public._rate_limits_daily_limit_backup_20260726 AS b
-- WHERE r.user_id = b.user_id;

-- 是正が問題なく確認できたら、バックアップテーブルは削除してよい
-- (残しておいても実害はないが、運用上不要になったテーブルとして掃除する場合)。
-- DROP TABLE IF EXISTS public._rate_limits_daily_limit_backup_20260726;
