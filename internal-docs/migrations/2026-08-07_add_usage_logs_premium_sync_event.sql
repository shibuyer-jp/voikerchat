-- 2026-08-07: usage_logs.event の許容値に 'premium_sync' を追加する。
--
-- 本SQLは Supabase SQL Editor で人間が実行すること(Claude CodeはDBに
-- 直接アクセスできないため)。
--
-- 【破壊的操作について】既存の CHECK 制約を一度 DROP して再作成するが、
-- 許容値を追加するだけで既存値はすべてそのまま許容され続けるため、
-- 既存行への影響はない。列の追加・削除・型変更は行わない。
--
-- 背景(internal-docs/reports/premium_state_mismatch_20260807.md参照):
--   再インストール後、クライアント側(RevenueCat)はApple/Google ID経由で
--   購読を復元してPremiumと判定するが、サーバー側 rate_limits.is_premium は
--   新しい匿名user_idに対して一度も更新されず無料枠のまま取り残される不整合が
--   発覚した。新設する api/premium-sync.ts が、この不整合をクライアント起動時
--   に検知しサーバー側へ再照合をリクエストする。乱用防止のレート制限
--   (1ユーザー1日あたりの上限)を、recap/vocab-summary(api/recap.ts等)と
--   同じ「usage_logs の当日件数カウント」方式で実装するため、新しいevent値
--   'premium_sync' を許容リストへ追加する。
--
-- 【本SQL未実行時の挙動】api/premium-sync.tsのusage_logs書き込みはbest-effort
-- (失敗を握り潰す設計、他のAPIエンドポイントと同方針)のため、本SQLを実行する
-- 前に新ビルドを配信しても機能自体は失敗しない。ただしレート制限が効かず
-- (カウント元の行が一件も記録されないため常に0件)、監査ログも残らない。
-- 実運用に入る前に実行しておくこと。

ALTER TABLE public.usage_logs
  DROP CONSTRAINT IF EXISTS usage_logs_event_check;

ALTER TABLE public.usage_logs
  ADD CONSTRAINT usage_logs_event_check CHECK (event IN (
    'session_start','message_sent','ad_reward','quota_reached',
    'upsell_shown','upsell_clicked','upsell_converted','premium_sync'
  ));

-- 実行後、以下で制約が正しく更新されたことを確認できる:
-- SELECT conname, pg_get_constraintdef(oid)
-- FROM pg_constraint
-- WHERE conrelid = 'public.usage_logs'::regclass AND contype = 'c';
