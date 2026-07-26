-- ============================================================
-- daily_limit 日次リセット漏れ 対応 統合SQL(2026-07-26)
-- ============================================================
--
-- 【この1本で完結する内容】
--   PART A: 既存ユーザーのdaily_limit是正(本番データ、全ユーザー対象)
--   PART B: 修正コードの動作検証(専用テストユーザーのみ、実機操作を含む)
--
-- 【前提】PR #19(daily_limit日次リセット修正)がmainにマージ済み・
-- Vercelへデプロイ済みであること(デプロイ前に実行しても翌日また同じ
-- 状態に戻るため無意味)。
--
-- 【実行順序】必ず PART A → PART B の順に、上から1ブロックずつ実行する。
-- PART Bのシナリオでのみ使う「テスト用user_id」を、下記の1箇所に貼れば
-- 以降は貼り直し不要(PART Aは全ユーザー対象のためuser_id指定は不要)。
-- 実機でアプリを操作する必要があるステップには「★ここでアプリを操作」と
-- 明記してあるので、その箇所だけ手を止めてアプリ側の操作を行うこと。

-- PART Bでのみ使用。テスト用(自分の匿名テストアカウント)のuser_idを1回だけ貼る。
-- Premiumユーザーでの確認(シナリオB2)も行う場合は、その直前で再設定する。
SET myapp.user_id = 'ここにテスト用user_idを貼る';


-- ============================================================
-- PART A: 既存ユーザーの daily_limit 是正(本番データ)
-- ============================================================
-- 広告視聴ボーナス(+5、当日限りの想定)を一度でも受け取った無料ユーザーの
-- daily_limit が、日次リセット漏れバグにより 10 のまま恒久化してしまって
-- いるデータを、基礎値(5)へ是正する。Premiumユーザーは対象外。

-- --- A1: 影響範囲のプレビュー(破壊的操作の前に必ず確認) ---
-- 期待結果: 対象ユーザー数が表示される(想定される値は基本的に10のみ)
-- NG時に疑うべき箇所: 0件なら「まだ誰も広告ボーナスを受け取っていない」
-- ため正常(即PART Bへ進んでよい)。極端に多い場合はis_premiumの判定条件を
-- 見直す(Premiumユーザーを誤って含めていないか)。
SELECT count(*) AS affected_row_count
FROM public.rate_limits
WHERE is_premium = false
  AND daily_limit > 5;

-- 内訳を見たい場合(先頭20件のサンプル)
SELECT user_id, daily_limit, used_today, last_reset_utc
FROM public.rate_limits
WHERE is_premium = false
  AND daily_limit > 5
ORDER BY last_reset_utc DESC
LIMIT 20;

-- --- A2: 是正前の状態をバックアップ(ロールバック用) ---
-- 期待結果: A1と同じ件数が INSERT される
-- NG時に疑うべき箇所: "already exists" エラーが出た場合、このSQLを既に
-- 一度実行済み(同名テーブルが残っている)。前回の是正が完了しているなら
-- このステップとA3は再実行不要(A4の確認のみでよい)。
CREATE TABLE IF NOT EXISTS public._rate_limits_daily_limit_backup_20260726 AS
SELECT user_id, daily_limit, is_premium, now() AS backed_up_at
FROM public.rate_limits
WHERE is_premium = false
  AND daily_limit > 5;

-- --- A3: 是正の実行(Premiumユーザーは対象外) ---
-- 期待結果: UPDATE件数がA1のプレビューと一致する
UPDATE public.rate_limits
SET daily_limit = 5
WHERE is_premium = false
  AND daily_limit > 5;

-- --- A4: 是正結果の確認 ---
-- 期待結果: 1つ目が0件、2つ目も0件(Premiumユーザーが巻き込まれていないこと)
-- NG時に疑うべき箇所: 1つ目が0件でない場合、A3のUPDATEが失敗している
-- (権限・接続エラー等)。2つ目が0件でない場合、is_premiumの条件指定を
-- 誤ってPremiumユーザーまで書き換えてしまった可能性(最優先で調査・
-- 末尾のロールバックを検討)。
SELECT count(*) AS remaining_over_base_free_users
FROM public.rate_limits
WHERE is_premium = false
  AND daily_limit > 5;

SELECT count(*) AS premium_users_not_at_50
FROM public.rate_limits
WHERE is_premium = true
  AND daily_limit <> 50;


-- ============================================================
-- PART B: 修正コードの動作検証(専用テストユーザーのみ)
-- ============================================================
-- 日付境界を人工的に再現し、実機でアプリを操作して、daily_limitが
-- 正しく基礎値へリセットされることを確認する。**本番ユーザーのデータには
-- 触れない**(冒頭でSETしたテスト用user_idのみが対象)。

-- --- B0: 検証用の現状をバックアップ(あとで元に戻すため) ---
-- 期待結果: INSERT 0 1(1行挿入)
-- NG時に疑うべき箇所: 0行の場合、対象ユーザーがrate_limitsにまだ存在しない
-- (一度もアプリで会話していない)。先にアプリで1回会話してレコードを
-- 作成してから、この手順からやり直す。
CREATE TABLE IF NOT EXISTS public._rate_limits_verification_backup (
  user_id uuid,
  daily_limit int,
  used_today int,
  last_reset_utc timestamptz,
  is_premium boolean,
  backed_up_at timestamptz DEFAULT now()
);

INSERT INTO public._rate_limits_verification_backup
  (user_id, daily_limit, used_today, last_reset_utc, is_premium)
SELECT user_id, daily_limit, used_today, last_reset_utc, is_premium
FROM public.rate_limits
WHERE user_id = current_setting('myapp.user_id')::uuid;

-- --- シナリオB1: 無料ユーザーでの日次リセット確認 ---

-- B1-1: バグ発生状態を人工的に再現する
-- 期待結果: UPDATE 1
-- NG時に疑うべき箇所: UPDATE 0の場合、対象ユーザーがis_premium=trueに
-- なっている(Premiumテストアカウントを誤って使っている)。B0の結果を
-- 確認し、無料ユーザーで実施し直す。
UPDATE public.rate_limits
SET daily_limit = 10,
    used_today = 3,
    last_reset_utc = now() - interval '2 days'
WHERE user_id = current_setting('myapp.user_id')::uuid
  AND is_premium = false;

-- ★ここでアプリを操作: 対象ユーザーでログイン中のiPhone/シミュレータで、
-- 任意のシーンを開き、メッセージを1回送信する(またはボイス発話を1回行う)。

-- B1-2: 結果を確認する
-- 期待結果: daily_limit=5, used_today=1, last_reset_utcが現在時刻付近に更新
-- NG時に疑うべき箇所:
--   daily_limitが10のまま → コード修正がデプロイに反映されていない可能性
--     (Vercelの最新デプロイを確認)、または会話送信経路(api/chat.ts)と
--     ステータス取得経路(api/rate-limit.ts)のどちらか一方しか動いていない
--   used_todayが2以上 → 会話を複数回送信してしまった可能性
--   last_reset_utcが更新されていない → daysPassed>=1の判定に使う経過日数
--     の計算に問題がある可能性(B1-1で'interval 2 days'を使っているか再確認)
SELECT daily_limit, used_today, last_reset_utc, is_premium
FROM public.rate_limits
WHERE user_id = current_setting('myapp.user_id')::uuid;

-- --- シナリオB2: Premiumユーザーで50が維持されることの確認(可能なら) ---
-- Premiumのテストアカウントがある場合のみ実施。無ければスキップしてよい。

-- B2-0: Premiumテストユーザーのuser_idに切り替える場合はここで再設定する
-- SET myapp.user_id = 'ここにPremiumテスト用user_idを貼る';
-- 上記を実行した場合は、そのユーザー分もB0のバックアップを取り直すこと
-- (B0のSQLをそのまま再実行すればよい)。

-- B2-1: last_reset_utcのみ「2日前」にする(daily_limitは50のまま変更しない)
-- 期待結果: UPDATE 1
-- NG時に疑うべき箇所: UPDATE 0の場合、対象ユーザーが実はis_premium=false
-- (Premiumテストアカウントの権限が失効している可能性。RevenueCatの
-- テスト購入状態を確認)。
UPDATE public.rate_limits
SET last_reset_utc = now() - interval '2 days'
WHERE user_id = current_setting('myapp.user_id')::uuid
  AND is_premium = true;

-- ★ここでアプリを操作: Premiumテストユーザーでログイン中の端末で、
-- 任意のシーンを開き、メッセージを1回送信する。

-- B2-2: 結果を確認する
-- 期待結果: daily_limit=50のまま(変化なし)、used_today=1
-- NG時に疑うべき箇所: daily_limitが5に落ちている場合、baseDailyLimit()の
-- isPremium判定が反転している(api/_constants.tsのbaseDailyLimit()、または
-- api/chat.ts/api/rate-limit.tsでisPremiumを渡し忘れている)可能性が高い。
-- 最優先で確認すること。
SELECT daily_limit, used_today, last_reset_utc, is_premium
FROM public.rate_limits
WHERE user_id = current_setting('myapp.user_id')::uuid;

-- --- 検証後: 元の状態に戻す(手打ち不要・バックアップから復元) ---
-- シナリオB1・B2それぞれで使ったuser_idについて、直前にSETした値のまま
-- 以下を実行する(B2を実施した場合は、B2-0で切り替えたuser_idのままでよい)。
-- 期待結果: UPDATE 1。これで検証前の状態に戻る。
UPDATE public.rate_limits AS r
SET daily_limit = b.daily_limit,
    used_today = b.used_today,
    last_reset_utc = b.last_reset_utc
FROM (
  SELECT DISTINCT ON (user_id) user_id, daily_limit, used_today, last_reset_utc
  FROM public._rate_limits_verification_backup
  WHERE user_id = current_setting('myapp.user_id')::uuid
  ORDER BY user_id, backed_up_at DESC
) AS b
WHERE r.user_id = b.user_id;

-- B1・B2両方の検証が終わったら、検証用バックアップテーブルは削除してよい
-- (残しておいても実害はない)。
-- DROP TABLE IF EXISTS public._rate_limits_verification_backup;


-- ============================================================
-- ロールバック(PART Aの本番是正のみ対象。万一の場合のみ実行)
-- ============================================================
-- PART A(既存データの是正)がもし意図しない結果になった場合、A2で
-- 取ったバックアップからdaily_limitを復元する。
-- UPDATE public.rate_limits AS r
-- SET daily_limit = b.daily_limit
-- FROM public._rate_limits_daily_limit_backup_20260726 AS b
-- WHERE r.user_id = b.user_id;

-- PART Aの是正が問題なく確認できたら、バックアップテーブルは削除してよい。
-- DROP TABLE IF EXISTS public._rate_limits_daily_limit_backup_20260726;
