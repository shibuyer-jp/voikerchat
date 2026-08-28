-- 2026-08-28: 2026-07-26 の検証作業で作成した一時テーブル2件を本番から削除する。
--
--   public._rate_limits_daily_limit_backup_20260726
--     … migrations/2026-07-26_fix_daily_limit_reset_correction.sql ステップ2で作成。
--        daily_limit 是正 UPDATE のロールバック用スナップショット。
--   public._rate_limits_verification_backup
--     … verification/daily_limit_20260726_all_in_one.sql B0 で作成。
--        日次リセット検証(B1/B2)の原状復帰用スナップショット。
--
-- どちらも接頭辞 `_` = 検証用の一時テーブルであることを示す命名。是正・検証は
-- 完了済みで、これらのバックアップはもう不要(STATE.md バックログ
-- 「本番Supabaseの検証用バックアップテーブル削除 [判定: 2026-08-27]」)。
--
-- ============================================================
-- 実行方法
-- ============================================================
-- 本SQLは Supabase SQL Editor で人間が実行すること
-- (Claude Code は本番DBへ直接アクセスできない)。
-- 対象プロジェクト: ref rfwbwwhqclabhnbsrygw / Tokyo / voikerchat-prod
--
-- 上から順に1ブロックずつ実行し、各ステップの期待結果を確認してから次へ進む。
-- 途中で「中断条件」に当たったら DROP せず、結果を CC / チャット側へ報告すること。
--
-- ============================================================
-- ステップ1: 対象2テーブルの存在と行数を確認する(DROP 前に必ず記録)
-- ============================================================
-- 期待結果: 2行返る(テーブルごとに1行)。row_count を控えて削除記録に残す。
--   - 0行の場合 → 既に削除済み。DROP はスキップし、STATE.md の項目削除だけ行う。
--   - `rate_limits`(本体)や `_` で始まらない名前が混ざって返ることは無いはずだが、
--     万一あれば中断して報告する。
SELECT c.relname AS table_name,
       c.reltuples::bigint AS est_rows,
       (SELECT count(*) FROM public._rate_limits_daily_limit_backup_20260726) AS exact_rows_daily_limit_backup
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname = '_rate_limits_daily_limit_backup_20260726';

SELECT c.relname AS table_name,
       c.reltuples::bigint AS est_rows,
       (SELECT count(*) FROM public._rate_limits_verification_backup) AS exact_rows_verification_backup
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname = '_rate_limits_verification_backup';

-- 参考: 本体 rate_limits の現在の行数(ステップ4で比較するため控える)
SELECT count(*) AS rate_limits_row_count_before FROM public.rate_limits;

-- ============================================================
-- ステップ2: 依存オブジェクトの有無を確認する
-- ============================================================
-- この2テーブルを参照している 外部キー / ビュー / ルール / トリガー / 既定値 等が
-- 無いことを確認する。
-- 期待結果: 0行。1行でも返ったら DROP せず内容を報告すること(中断条件)。
SELECT DISTINCT
       dependent.relname   AS dependent_object,
       dependent.relkind   AS dependent_kind,   -- r=table, v=view, m=matview, ...
       target.relname      AS references_table
FROM pg_depend d
JOIN pg_rewrite r      ON r.oid = d.objid
JOIN pg_class dependent ON dependent.oid = r.ev_class
JOIN pg_class target    ON target.oid = d.refobjid
JOIN pg_namespace tn    ON tn.oid = target.relnamespace
WHERE tn.nspname = 'public'
  AND target.relname IN ('_rate_limits_daily_limit_backup_20260726',
                         '_rate_limits_verification_backup')
  AND dependent.relname <> target.relname;

-- 外部キー(いずれかのテーブルを参照する FK、または これらのテーブルが張る FK)
-- 期待結果: 0行。
SELECT conname, conrelid::regclass AS on_table, confrelid::regclass AS references_table
FROM pg_constraint
WHERE contype = 'f'
  AND (conrelid::regclass::text  IN ('public._rate_limits_daily_limit_backup_20260726',
                                     'public._rate_limits_verification_backup')
    OR confrelid::regclass::text IN ('public._rate_limits_daily_limit_backup_20260726',
                                     'public._rate_limits_verification_backup'));

-- ============================================================
-- ステップ3: 削除する(対象2件のみ。CASCADE は使わない)
-- ============================================================
-- ステップ2 が 0行だったことを確認してから実行する。
-- CASCADE を付けないので、万一依存があればここでエラーになって止まる。それが正しい。
DROP TABLE public._rate_limits_daily_limit_backup_20260726;
DROP TABLE public._rate_limits_verification_backup;

-- ============================================================
-- ステップ4: 削除後の確認
-- ============================================================
-- (a) 2テーブルが存在しないこと。期待結果: 0行。
SELECT c.relname
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname IN ('_rate_limits_daily_limit_backup_20260726',
                    '_rate_limits_verification_backup');

-- (b) 本体 rate_limits が無傷であること。
--     行数がステップ1の rate_limits_row_count_before と一致すること
--     (通常運用の増減は許容。桁が変わる等の異常が無いこと)。
SELECT count(*) AS rate_limits_row_count_after FROM public.rate_limits;

-- (c) 本体 rate_limits のスキーマが変わっていないこと。
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'rate_limits'
ORDER BY ordinal_position;

-- ============================================================
-- 中断条件(いずれかに該当したら DROP せず報告)
-- ============================================================
--  - ステップ1でテーブル名が完全一致で見つからない(似た名前しか無い等)
--  - ステップ2で依存オブジェクトが1件でも返る
--  - ステップ4で rate_limits 本体に想定外の変化がある
--  - ステップ1で既に0行(存在しない) → 削除済みとして扱い、ドキュメント更新のみ行う
