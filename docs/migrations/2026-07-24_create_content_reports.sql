-- 2026-07-24: AI生成コンテンツの報告機能(Google Play デベロッパープログラムポリシー必須要件)。
--
-- 背景: Google Play ポリシーにより、AIでコンテンツを生成するアプリは、
-- ユーザーがアプリを離れずに不適切なコンテンツを報告できるアプリ内機能を
-- 備えることが必須。content_reports は AI(assistant)応答に対するユーザー
-- 報告を蓄積する監査ログテーブル。
--
-- 本SQLは Supabase SQL Editor で人間が実行すること(Claude Code はDBに
-- 直接アクセスできないため)。

-- user_id は必ず存在する auth.users を直接参照する(public.user_profiles等の
-- カスタムテーブルは環境によって有無・名称が異なるため、Supabase標準の
-- auth.users に対する参照のみを前提にする)。
--
-- message_id は外部キー制約を付けない(単なるUUID列)。content_reports は
-- 監査ログであり、messagesテーブルの実名・存在有無に依存させたくないため。
-- reported_text に本文スナップショットを保持するので、message_id はあくまで
-- 補助的な手がかりとして扱う。
CREATE TABLE public.content_reports (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES auth.users ON DELETE CASCADE,
  message_id    UUID,
  scene_id      TEXT,
  reason        TEXT NOT NULL CHECK (reason IN ('inappropriate', 'incorrect', 'other')),
  detail        TEXT,
  reported_text TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_content_reports_user_id ON public.content_reports(user_id);
CREATE INDEX idx_content_reports_created_at ON public.content_reports(created_at);

ALTER TABLE public.content_reports ENABLE ROW LEVEL SECURITY;

-- insert: 本人の報告のみ許可
CREATE POLICY content_reports_insert_own
  ON public.content_reports
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- select: 自分の報告のみ閲覧可能
CREATE POLICY content_reports_select_own
  ON public.content_reports
  FOR SELECT USING (auth.uid() = user_id);

-- update/delete: ポリシーを作成しない(RLS有効時のデフォルト拒否のまま)。
-- 監査ログの改ざん防止のため、クライアントからの更新・削除経路は存在しない。
-- 運営側のレビュー・対応は service role key 経由(RLSバイパス)で行う想定。
