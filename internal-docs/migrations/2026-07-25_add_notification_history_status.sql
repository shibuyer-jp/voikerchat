-- 2026-07-25: notification_history に status 列を追加(案B: ローカル通知の
-- 先行INSERT方式)+ クライアントからの本人INSERTポリシーを新設。
--
-- 本SQLは Supabase SQL Editor で人間が実行すること(Claude CodeはDBに
-- 直接アクセスできないため)。
--
-- 【破壊的操作について】本SQLに DROP / 既存データの変更は含まれない。
-- ADD COLUMN・CREATE INDEX・CREATE POLICY のみで、既存の3ポリシー
-- ("Service role can insert notifications" / "Users can update own
-- notifications" / "Users can view own notifications")は一切変更・削除しない。
--
-- 事前確認結果(2026-07-25_verify_notification_history_rls.sql の実行結果より):
--   - 現行カラムに status は無し
--   - RLS有効(relrowsecurity = true)
--   - INSERT は現在 "Service role can insert notifications"(with_check=true、
--     サービスロール限定)のみ。クライアント(匿名認証セッション)からの
--     直接INSERT経路が無いため、案Bの実装にはこれの追加が必須。

-- ============================================================
-- 1. status 列の追加
-- ============================================================
--
-- 背景: ローカル通知(毎日リマインダー/プレミアム勧導)は zonedSchedule で
-- OS側に先行予約するため、実際に発火した瞬間をDartコードが検知できない
-- (バックグラウンド/終了中はコードが動かないため)。そこで、スケジュール
-- した時点で status='scheduled' として先にINSERTし、次回アプリ起動時に
-- received_at(=予定発火時刻) <= now のレコードを 'delivered' に更新する
-- ことで、履歴として自然に確定させる。
-- マイルストーン/機能更新/将来のリモートプッシュ(Phase2)は判定・受信の
-- その場でDartが実行されるため、最初から 'delivered' として直接INSERTする。
--
-- 既存行のデフォルト値: 'delivered' とする。現行のnotification_historyへの
-- INSERT経路は "Service role can insert notifications" のみ(=Phase2の
-- リモート受信を想定した経路)であり、他に書き込み手段が無い以上、既存行が
-- あるとすれば全てリモート受信済み=配信完了しているはずのため。
--
-- CHECK制約: 'scheduled' / 'delivered' の2値に限定する。案Bの設計上
-- この2状態以外は発生しない想定のため、想定外の値の混入を早期に検知する。
ALTER TABLE public.notification_history
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'delivered'
    CHECK (status IN ('scheduled', 'delivered'));

-- 起動時リコンサイル(「予定を過ぎたscheduledをdeliveredへ更新」)の
-- 対象抽出を高速化するための複合インデックス。
CREATE INDEX IF NOT EXISTS idx_notification_history_user_status_received
  ON public.notification_history(user_id, status, received_at);

-- ============================================================
-- 2. クライアントからの本人INSERTポリシーを新設
-- ============================================================
--
-- 案Bはローカル通知のスケジュール/確定処理をアプリ(クライアント)側で
-- 行うため、匿名認証セッションから自分のuser_idでINSERTできる経路が
-- 必要。既存の "Service role can insert notifications" は削除せず残す
-- (Phase2でのリモート書き込み経路を温存するため)。
--
-- 【ポリシー共存について】PostgreSQLのRLSでは、同一コマンド(ここでは
-- INSERT)に対する複数の PERMISSIVE ポリシー(CREATE POLICYのデフォルト
-- 種別。RESTRICTIVEを明示しない限りこちら)は OR で評価される。
-- つまり「Service role側の with_check=true」と「本人側の
-- auth.uid() = user_id」のどちらか一方を満たせば INSERT が許可される。
-- 既存ポリシーの挙動を弱めることはなく、許可される経路が1つ増えるだけ。
-- (なお service_role キーで接続する場合、Postgresの service_role ロールは
-- 通常RLSを全体バイパスするため、既存の "Service role can insert
-- notifications" は実質的に到達しない可能性があるが、削除しない方針に
-- 従いそのまま残す。)
CREATE POLICY "Users can insert own notifications"
  ON public.notification_history
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);
