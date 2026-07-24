-- 2026-07-24: AI生成コンテンツの報告機能(Google Play デベロッパープログラムポリシー必須要件)。
--
-- 背景: Google Play ポリシーにより、AIでコンテンツを生成するアプリは、
-- ユーザーがアプリを離れずに不適切なコンテンツを報告できるアプリ内機能を
-- 備えることが必須。content_reports は AI(assistant)応答に対するユーザー
-- 報告を蓄積する監査ログテーブル。
--
-- 本SQLは Supabase SQL Editor で人間が実行すること(Claude Code はDBに
-- 直接アクセスできないため)。

CREATE TABLE public.content_reports (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES public.user_profiles ON DELETE CASCADE,
  -- 報告後にユーザーが会話をクリア(messages削除)しても報告自体(監査ログ)は
  -- 残す必要があるため、参照先削除時は SET NULL(reported_text が監査用の
  -- スナップショットとして本文を保持し続ける)。
  message_id    UUID REFERENCES public.messages ON DELETE SET NULL,
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
