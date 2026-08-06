-- 2026-08-06: notification_history に DELETE の RLS ポリシーを追加。
--
-- 本SQLは Supabase SQL Editor で人間が実行すること(Claude CodeはDBに
-- 直接アクセスできないため)。
--
-- 【破壊的操作について】本SQLに DROP / 既存データの変更は含まれない。
-- CREATE POLICY のみで、既存の4ポリシー(INSERT×2/SELECT×1/UPDATE×1)は
-- 一切変更・削除しない。
--
-- 背景: 通知履歴のスワイプ削除が実機(iOS)で常に失敗する不具合を調査した
-- 結果、notification_history テーブルに DELETE のRLSポリシーが1件も
-- 存在しないことが判明した(2026-08-06、以下のSQLで確認済み)。
--   select relrowsecurity from pg_class where oid = 'public.notification_history'::regclass;
--   -- => true(RLS有効)
--   select cmd, count(*) from pg_policies
--   where schemaname='public' and tablename='notification_history' group by cmd;
--   -- => INSERT:2, SELECT:1, UPDATE:1(DELETEは0件)
--
-- RLS有効時、あるコマンドに対応するポリシーが1件も無い場合はそのコマンドが
-- デフォルトで全拒否される。PostgRESTの DELETE はこの拒否をエラーとしては
-- 返さず「0行削除」として成功応答するため、原因の発見が遅れた。アプリ側は
-- 削除件数0を「対象が既に存在しなかった」と誤解釈し
-- `Exception('Notification already deleted')`を表示していた
-- (lib/screens/notification_history_screen.dart、別PRで是正)。
--
-- 条件は既存の SELECT ポリシー("Users can view own notifications",
-- auth.uid() = user_id)と揃える。
CREATE POLICY "Users can delete own notifications"
  ON public.notification_history
  FOR DELETE
  USING (auth.uid() = user_id);
