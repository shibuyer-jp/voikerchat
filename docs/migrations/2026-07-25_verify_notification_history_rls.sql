-- 2026-07-25: notification_history の現行RLSポリシー確認用クエリ。
--
-- 背景: notification_history テーブルは docs/migrations/ 導入前(T-21, 6/23頃)に
-- Supabase側で直接作成されており、本リポジトリに作成時のCREATE TABLE/RLS SQLが
-- 残っていない。Claude CodeはDBに直接アクセスできないため、通知履歴書き込み機能
-- (PR-3, 案B+C)の実装前に、以下をSupabase SQL Editorで実行し、結果を貼り戻して
-- ほしい。

-- 1. テーブル定義(列一覧)の確認
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'notification_history'
ORDER BY ordinal_position;

-- 2. RLSが有効かどうか
SELECT relrowsecurity, relforcerowsecurity
FROM pg_class
WHERE oid = 'public.notification_history'::regclass;

-- 3. 現行ポリシー一覧(insert/select が auth.uid() = user_id で
--    絞られているか。content_reports と同じ形になっているかを確認したい)
SELECT policyname, cmd, qual, with_check
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'notification_history';
