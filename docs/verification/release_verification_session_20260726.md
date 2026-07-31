# リリース前 統合実機検証セッション(2026-07-26)

> **実施時期の方針(2026-07-31 追記)**
>
> STEP1(本番データ是正): **不要と判断。実施しない。**
> 2026-07-31 に本番 rate_limits を確認したところ、
> is_premium=false かつ daily_limit=10 の行は4件のみ。
> 全件が last_reset_utc から46〜165時間経過しており、
> 4b20102(PR #19)以降の実装では次回API呼び出し時に
> 自動的に daily_limit=5 へ回復する。
> さらに4件とも2〜7日放置された開発用アカウントであり、
> クローズドテスト参加者は含まれない。
> docs/migrations/2026-07-26_fix_daily_limit_reset_correction.sql
> は実行しない(テスト期間中の本番DB操作を避けるため。
> ファイル自体は経緯の記録として保持)。
>
> STEP3(daily_limit 動作検証): **実質完了。**
> 2026-07-31、開発者が実機で上限到達→翌日の回復を確認。
> 同日、リセット仕様を実装で特定(last_reset_utc から
> 実時間24時間経過判定、UTC暦日境界ではない。
> chat.ts:207-213, rate-limit.ts:77-85)。cron は存在せず
> API 呼び出し時の遅延リセット。
>
> STEP2 / STEP4 / STEP5 / Phase D / Phase E: **完走後に実施。**
> 実機での破壊的操作(アンインストール、端末日時変更)を伴い、
> テスター61名が稼働中の期間に行うと結果の解釈が困難になるため。
> クローズドテスト完走(2026-08-13見込み)以降とする。

対象PR: #10・#11・#12(通知機能一式)・#13(ストリーク修正)・#17(言語切替時の再スケジュール)・#19(daily_limit日次リセット修正)。

これまで別々に用意していた `docs/verification/notification_verification_20260726.md`(通知/ストリーク系)と
`docs/verification/daily_limit_20260726_all_in_one.sql`(daily_limit是正+動作検証)を、
**1回の実機セッションで完結するよう1本に統合**したものです。以後の実機検証はこのファイルのみを使ってください
(元の2ファイルは経緯の記録として残していますが、参照のみで結構です)。

## ビルド要件(必読)

**本検証には Build 11 以降が必要です。** Build 10(TestFlight配信済み)には STEP 4(Phase B、アプリ内言語切替時の
通知再スケジュール検証)の対象である PR #17 が含まれていません。PR #17 はマージ時刻(2026-07-26 07:53 JST)が
Build 10 のビルド番号更新コミット(2026-07-26 03:17 JST)より後のため、Build 10 には未収録です。Build 11 以降の
TestFlight配信を待ってから本検証セッションを開始してください。

daily_limitの日次リセット修正(PR #19)は`api/*.ts`側(Vercel)の修正であり、**アプリのビルド番号には依存しません**
(サーバー側は常に最新のmainがデプロイされているため、どのビルドのアプリからでもSTEP 1・STEP 3の検証は可能です)。

各STEP/Phaseがどちらの修正に依存するかを整理すると以下の通りです(次回以降、どのビルドで何が検証できるかを
取り違えないための一覧):

| STEP/Phase | 依存する修正 | 必要なアプリビルド |
|---|---|---|
| STEP 1: PART A(daily_limit是正) | サーバー側(PR #19、Vercel。適用済み) | 依存なし(任意のビルドで実施可) |
| STEP 2: Phase A(通知トグル) | アプリ側(PR #10・#11) | Build 8以降(既に反映済み) |
| STEP 3: daily_limit PART B(動作検証) | サーバー側(PR #19、Vercel)。会話送信操作自体は既存機能 | 依存なし(任意のビルドで実施可) |
| STEP 4: Phase B(言語切替・再スケジュール) | アプリ側(PR #17) | **Build 11以降が必須**(Build 10には未収録) |
| STEP 5: Phase C(ストリーク回帰・マイルストーン) | アプリ側(PR #13) | Build 8以降(既に反映済み) |
| Phase D・E(別セクション、再インストール/オフライン復帰) | アプリ側(PR #13の復元ロジック) | Build 8以降(既に反映済み) |

## 最適化の根拠(冒頭にまとめて記載)

- どちらの検証も「実機操作 + Supabase SQL Editor」の往復を伴うため、別々に実施すると再起動・言語切替・
  再インストールが重複します。1本の順序にまとめることで、これらの操作回数を最小化しています。
- **PART A(daily_limitの本番データ是正)は他フェーズの前提条件に影響しません**。全ユーザーを対象とした
  独立したデータ補正(`is_premium = false AND daily_limit > 5` の行のみ)であり、`used_today`・`last_reset_utc`
  や通知/ストリーク関連のテーブルには一切触れないため、**実行順序は他フェーズと無関係(順不同)**です。
  ただし、実機操作を始める前にまとめて片付けたほうが効率的なため、セッション冒頭に配置しています。
- **daily_limitのPART B(動作検証)は、端末の日付ではなくDB側の`last_reset_utc`を操作する仕組み**です
  (サーバー側が「今日」と判定する基準は端末の時計ではなくサーバー自身の時計のため)。Phase C(ストリーク検証)の
  ように端末の時計そのものを操作する必要はありません。この性質上、端末の時計をいじる前(通常の時計のまま)に
  済ませておくのが安全なため、Phase C より前に配置しています。
- **daily_limit PART BがPhase C(ストリーク検証)の前提を壊さないかの確認結果(重要)**:
  会話を1回送信すると、`lib/screens/chat_screen.dart`が毎回無条件に`StreakService.incrementStreak(userId,
  sceneId)`を呼ぶ副作用がある。この関数は`rate_limits.last_reset_utc`を一切参照せず、**端末の実時刻**と
  **`userId`+`sceneId`単位**のローカル(SharedPreferences)な「1日1回」ガードのみで動く、daily_limitとは
  完全に独立した仕組みである。したがって、PART Bが`rate_limits.last_reset_utc`をサーバー側で操作すること
  自体はストリーク判定に一切影響しない。**唯一の実際のリスクは、「メッセージを1回送信する」という操作
  そのものが副作用としてストリークを加算してしまう点**であり、PART BとPhase Cが**同じscene_id**でメッセージを
  送信すると、1日1回の加算枠を奪い合い、Phase Cの期待値(streak=1→2→3)がずれる可能性がある。
  → **対策**: Phase Cは`scene_id=1`を使用し、daily_limit PART B(B1・B2)のメッセージ送信は
  **`scene_id=1`以外のシーン(例: scene_id=2)** で行うことで、ストリークのキー
  (`streak_<userId>_<sceneId>_days`)を完全に分離した(下記STEP 3の該当手順に明記)。これにより、
  実行順序に関わらずPART BとPhase Cは互いに影響しない。
  **なお、この分離によって「二重加算」が起きないことも確認済み**: `user_streaks`テーブルは
  `user_id`+`scene_id`の複合キーで管理されるシーン単位の独立した値であり(`streak_service.dart`の
  `_restoreStreakFromSupabase`/`_syncStreakFromSupabaseIfNewer`はいずれも`user_id`と`scene_id`両方で
  絞り込んだ単一行を前提にしている)、ユーザー単位のグローバル値ではない。したがってscene_id=2側の
  加算がscene_id=1側の値に影響することはなく(全シーン合算の`getAllStreaks()`もコード上どこからも
  呼ばれていない未使用メソッドのため、集計表示への副作用もない)、分離により「取り合い」が
  「二重加算」に変わることもない。
- Phase B(言語切替)はセッション中1回のみ行い、以降のPhase(C以降)はFilipinoのまま進めます(切り戻し不要、
  元の`notification_verification_20260726.md`と同じ方針)。
- Phase D(再インストール)は破壊的操作のため必ず最後、Phase E(オフライン復帰確認)はPhase Dの直後(復元された
  streak値が前提)に行う必要があります。この2つは「日をまたぐ・再インストールが必要」項目として、1セッションで
  完結する本編とは明確に分離し、末尾の別セクションにまとめています。

**実行順序(本編)**: 事前準備 → PART A(daily_limit是正)→ Phase A(通知トグル)→ daily_limit PART B(動作検証・**必須**)→ Phase B(言語切替)→ Phase C(ストリーク回帰)。
本編はここまでで1セッション完結します。Phase D・Eは別途「日をまたぐ・再インストールが必要な項目」を参照してください。

---

## 事前準備(最初に1回だけ)

1. iPhoneとMacをUSB接続する(`xcrun devicectl list devices`で`connected`になっていることを確認可能)
2. Supabase SQL Editorを開く
3. 下記を実行し、**このセッション中使い回す**`user_id`と`scene_id`をセットする(このタブを閉じるまで再設定不要)。
   `user_id`は`auth.users`の一覧から、直近使っているテスト用の匿名ユーザーを選ぶ(通常は一番新しいもの)。

★ここでSQLを実行

```sql
-- ① 自分のuser_idを確認する(直近のものが自分のはず)
SELECT id, created_at FROM auth.users ORDER BY created_at DESC LIMIT 5;
```

```sql
-- ② 上で確認したuser_idを1箇所だけ貼り、scene_idも設定する
--    (このSQL Editorのタブを閉じるまで、以降のクエリで使い回せる)
SET myapp.user_id = 'ここにuser_idを貼る';
SET myapp.scene_id = '1';
```

以降のSQLはすべてこの2つの設定値を`current_setting()`経由で参照するため、**貼り直しは不要**です。

- [ ] 事前準備完了(デバイス接続・SQL Editor・SET完了)

---

## STEP 1: PART A — daily_limitの本番データ是正(全ユーザー対象・順不同だが最初に片付ける)

広告視聴ボーナス(+5、当日限りの想定)を一度でも受け取った無料ユーザーの`daily_limit`が、
日次リセット漏れバグにより10のまま恒久化してしまっているデータを、基礎値(5)へ是正します。
Premiumユーザーは対象外です。

★ここでSQLを実行

```sql
-- A1: 影響範囲のプレビュー(破壊的操作の前に必ず確認)
SELECT count(*) AS affected_row_count
FROM public.rate_limits
WHERE is_premium = false
  AND daily_limit > 5;
```

- **期待結果**: 対象ユーザー数が表示される(想定される値は基本的に10のみ)
- **NG時に疑うべき箇所**: 0件なら「まだ誰も広告ボーナスを受け取っていない」ため正常(即STEP 2へ進んでよい)。極端に多い場合は`is_premium`の判定条件を見直す(Premiumユーザーを誤って含めていないか)。

```sql
-- A2: 是正前の状態をバックアップ(ロールバック用)
CREATE TABLE IF NOT EXISTS public._rate_limits_daily_limit_backup_20260726 AS
SELECT user_id, daily_limit, is_premium, now() AS backed_up_at
FROM public.rate_limits
WHERE is_premium = false
  AND daily_limit > 5;
```

- **期待結果**: A1と同じ件数がINSERTされる
- **NG時に疑うべき箇所**: "already exists"エラーが出た場合、このSQLを既に一度実行済み(同名テーブルが残っている)。前回の是正が完了しているならこのステップと次のA3は再実行不要(A4の確認のみでよい)。

```sql
-- A3: 是正の実行(Premiumユーザーは対象外)
UPDATE public.rate_limits
SET daily_limit = 5
WHERE is_premium = false
  AND daily_limit > 5;
```

- **期待結果**: UPDATE件数がA1のプレビューと一致する

```sql
-- A4: 是正結果の確認
SELECT count(*) AS remaining_over_base_free_users
FROM public.rate_limits
WHERE is_premium = false
  AND daily_limit > 5;

SELECT count(*) AS premium_users_not_at_50
FROM public.rate_limits
WHERE is_premium = true
  AND daily_limit <> 50;
```

- **期待結果**: 1つ目が0件、2つ目も0件(Premiumユーザーが巻き込まれていないこと)
- **NG時に疑うべき箇所**: 1つ目が0件でない場合、A3のUPDATEが失敗している(権限・接続エラー等)。2つ目が0件でない場合、`is_premium`の条件指定を誤ってPremiumユーザーまで書き換えてしまった可能性(最優先で調査・本ファイル末尾のロールバックを検討)。

- [ ] A1〜A4完了(是正0件・Premium巻き込みなしを確認)

---

## STEP 2: Phase A — 通知ON/OFFトグル検証(所要: 数分)

| # | 手順 | 期待結果 |
|---|---|---|
| A2-1 | ★ここでアプリを操作: 設定画面で「通知」をOFFにする | ― |
| A2-2 | ★ここでSQLを実行(下記) | 直前まであった`daily_reminder`の`status='scheduled'`行が削除されている(`delivered`済みの過去行は残っていてよい) |

```sql
SELECT id, payload, status, received_at
FROM notification_history
WHERE user_id = current_setting('myapp.user_id')::uuid
  AND payload = 'daily_reminder'
ORDER BY created_at DESC;
```

| # | 手順 | 期待結果 |
|---|---|---|
| A2-3 | ★ここでアプリを操作: 設定画面で「通知」を再度ONにする | ― |
| A2-4 | ★ここでSQLを実行(上と同じSQLを再実行) | `daily_reminder`の`scheduled`行が新規作成されている |

- [ ] A2-2: OFF後にscheduled行が消えた
- [ ] A2-4: ON後にscheduled行が復活した

**NG時の切り分け**: A2-2で行が消えない場合、`cancelScheduledByPayload`が呼ばれていない(トグルOFFの配線漏れ)。A2-4で行が増えない場合、`scheduleDailyReminders()`が`isNotificationsEnabled()`のガードで止まっている可能性。

---

## STEP 3: daily_limit PART B【必須・省略不可】— 修正コードの動作検証

> api/*.tsにはTypeScript側の自動テストを追加しない判断をしている(`docs/DECISIONS.md` 2026-07-26参照)。
> その判断の前提は「代わりに実地検証(このSTEP)で動作を確認する」ことにあるため、**このSTEPを省略すると
> daily_limitの日次リセットロジックが一切検証されないままリリースされることになり、判断の前提が崩れる**。
> シナリオB1(無料ユーザー)は必須。シナリオB2(Premiumユーザー)のみ、テスト用Premiumアカウントが無い場合に限り省略可。
>
> **使用シーン**: このSTEPのメッセージ送信は`scene_id=1`**以外**(例: scene_id=2)を使うこと。STEP 5(Phase C)は`scene_id=1`を使う。ストリークは`userId`+`sceneId`単位で1日1回しか加算されないため、同じシーンを使うと加算枠を消費し合いPhase Cの期待値がずれる(冒頭「最適化の根拠」参照)。

### B0: 検証用の現状をバックアップ(あとで元に戻すため)

★ここでSQLを実行

```sql
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
```

- **期待結果**: `INSERT 0 1`(1行挿入)
- **NG時に疑うべき箇所**: 0行の場合、対象ユーザーが`rate_limits`にまだ存在しない(一度もアプリで会話していない)。先にアプリで1回会話してレコードを作成してから、この手順からやり直す。

- [ ] B0完了

### シナリオB1【必須】: 無料ユーザーでの日次リセット確認

★ここでSQLを実行

```sql
-- B1-1: バグ発生状態を人工的に再現する
UPDATE public.rate_limits
SET daily_limit = 10,
    used_today = 3,
    last_reset_utc = now() - interval '2 days'
WHERE user_id = current_setting('myapp.user_id')::uuid
  AND is_premium = false;
```

- **期待結果**: `UPDATE 1`
- **NG時に疑うべき箇所**: `UPDATE 0`の場合、対象ユーザーが`is_premium = true`になっている(Premiumテストアカウントを誤って使っている)。B0の結果を確認し、無料ユーザーで実施し直す。

★ここでアプリを操作: 対象ユーザーでログイン中のiPhone/シミュレータで、**`scene_id=1`以外**のシーン(例: scene_id=2)を開き、メッセージを1回送信する(またはボイス発話を1回行う)。`scene_id=1`はSTEP 5(Phase C、ストリーク検証)で使うため、同じシーンを使うとストリークの1日1回加算枠を消費し合ってしまう(冒頭「最適化の根拠」内の「daily_limit PART BがPhase Cの前提を壊さないかの確認結果」参照)。

★ここでSQLを実行

```sql
-- B1-2: 結果を確認する
SELECT daily_limit, used_today, last_reset_utc, is_premium
FROM public.rate_limits
WHERE user_id = current_setting('myapp.user_id')::uuid;
```

- **期待結果**: `daily_limit = 5`、`used_today = 1`、`last_reset_utc`が現在時刻付近に更新されている
- **NG時に疑うべき箇所**:
  - `daily_limit`が`10`のまま → コード修正がデプロイに反映されていない可能性(Vercelの最新デプロイを確認)、または会話送信経路(`api/chat.ts`)とステータス取得経路(`api/rate-limit.ts`)のどちらか一方しか動いていない
  - `used_today`が`2`以上 → 会話を複数回送信してしまった可能性
  - `last_reset_utc`が更新されていない → `daysPassed >= 1`の判定に使う経過日数の計算に問題がある可能性(B1-1で`interval '2 days'`を使っているか再確認)

- [ ] B1完了(daily_limit=5, used_today=1を確認)

### シナリオB2【任意・Premiumテストアカウントがある場合のみ】: Premiumユーザーで50が維持されることの確認

Premiumのテストアカウントがある場合のみ実施。無ければスキップしてよい(STEP 4へ進む)。

```sql
-- B2-0: Premiumテストユーザーのuser_idに切り替える場合はここで再設定する
SET myapp.user_id = 'ここにPremiumテスト用user_idを貼る';
```

上記を実行した場合は、そのユーザー分もB0のバックアップを取り直すこと(B0のSQLをそのまま再実行すればよい)。

★ここでSQLを実行

```sql
-- B2-1: last_reset_utcのみ「2日前」にする(daily_limitは50のまま変更しない)
UPDATE public.rate_limits
SET last_reset_utc = now() - interval '2 days'
WHERE user_id = current_setting('myapp.user_id')::uuid
  AND is_premium = true;
```

- **期待結果**: `UPDATE 1`
- **NG時に疑うべき箇所**: `UPDATE 0`の場合、対象ユーザーが実は`is_premium = false`(Premiumテストアカウントの権限が失効している可能性。RevenueCatのテスト購入状態を確認)。

★ここでアプリを操作: Premiumテストユーザーでログイン中の端末で、**`scene_id=1`以外**のシーン(例: scene_id=2)を開き、メッセージを1回送信する(B1と同じ理由。Premiumテストアカウントは別ユーザーのため通常は`streak_<userId>`単位で既に分離されているが、念のため統一しておく)。

★ここでSQLを実行

```sql
-- B2-2: 結果を確認する
SELECT daily_limit, used_today, last_reset_utc, is_premium
FROM public.rate_limits
WHERE user_id = current_setting('myapp.user_id')::uuid;
```

- **期待結果**: `daily_limit = 50`のまま(変化なし)、`used_today = 1`
- **NG時に疑うべき箇所**: `daily_limit`が`5`に落ちている場合、`baseDailyLimit()`の`isPremium`判定が反転している(`api/_constants.ts`の`baseDailyLimit()`、または`api/chat.ts`/`api/rate-limit.ts`で`isPremium`を渡し忘れている)可能性が高い。最優先で確認すること。

- [ ] B2完了(実施した場合。daily_limit=50維持を確認)

### 検証後: 元の状態に戻す(手打ち不要・バックアップから復元)

B1・B2それぞれで使った`user_id`について(B2を実施した場合は、B2-0で切り替えたuser_idのままでよい)、以下を実行する。

★ここでSQLを実行

```sql
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
```

- **期待結果**: `UPDATE 1`。これで検証前の状態に戻る。

B1・B2両方の検証が終わったら、検証用バックアップテーブルは削除してよい(残しておいても実害はない)。

```sql
-- DROP TABLE IF EXISTS public._rate_limits_verification_backup;
```

- [ ] 検証後、元の状態に復元した

**STEP 3完了後は、Premiumテストユーザーに切り替えた場合、元のテストユーザー(STEP 1の`user_id`)に`myapp.user_id`を戻すこと。**

```sql
-- 必要なら元のテストユーザーに戻す
SET myapp.user_id = '事前準備で設定した元のuser_idを貼る';
```

---

## STEP 4: Phase B — アプリ内言語切替 → 通知の再スケジュール検証(所要: 数分)

**重要**: 手順B4-2は**アプリを再起動せずに**確認すること。再起動を挟むと、リスナーが正しく動作していなくても(起動時の`scheduleDailyReminders()`呼び出しで)辻褄が合ってしまい、誤判定する。

| # | 手順 | 期待結果 |
|---|---|---|
| B4-1 | ★ここでアプリを操作: 設定画面で言語を「Filipino」に切り替える | ― |
| B4-2 | ★ここでSQLを実行(下記)。**切り替えてから3〜5秒待ち、再起動せずに**実行 | `daily_reminder`の新しい`scheduled`行(直近の`created_at`)が**fil表示**(例: タイトルに"Umaga"等)になっている |

```sql
SELECT id, title, body, payload, status, received_at, created_at
FROM notification_history
WHERE user_id = current_setting('myapp.user_id')::uuid
  AND payload = 'daily_reminder'
ORDER BY created_at DESC
LIMIT 6;
```

- [ ] B4-2でfil表示の新しい行が(再起動なしで)確認できた → **リスナーが正しく動作している証拠**
- [ ] B4-2で変化がない → リスナー未発火(要調査。次のB4-4で再起動後にだけ直っていたら「起動時呼び出しで辻褄が合っているだけ」と確定)

| # | 手順 | 期待結果 |
|---|---|---|
| B4-3 | ★ここでアプリを操作: アプリを完全終了 → 再起動する | ― |
| B4-4 | ★ここでSQLを実行(下記の重複チェックSQL) | 0件(`didChangeLocales`経路と今回のリスナーの二重発火で重複INSERTされていないこと) |

```sql
SELECT payload, received_at, COUNT(*)
FROM notification_history
WHERE user_id = current_setting('myapp.user_id')::uuid
  AND payload = 'daily_reminder'
GROUP BY payload, received_at
HAVING COUNT(*) > 1;
```

- [ ] B4-4: 重複0件

| # | 手順 | 期待結果 |
|---|---|---|
| B4-5 | ★ここでアプリを操作: 通知履歴タブ(Mga Abiso)を開く | 言語切替**より前**に受信した過去のレコードは**日本語のまま**表示される(仕様通り。`docs/DECISIONS.md` 2026-07-26参照。「直っていない」ではない) |

- [ ] B4-5: 過去レコードは日本語のまま(想定通り)であることを確認(ここでfilになっていたら逆に想定外)

**この時点でアプリの表示言語はFilipinoのままです。以降のSTEP 5はこのままの言語で進めて構いません(言語をJapaneseに戻す必要はありません)。**

---

## STEP 5: Phase C — ストリーク回帰 + マイルストーン即時履歴書き込み検証(所要: 端末日時操作で1回の滞在時間内に完結)

ストリークは`auth.uid()`ではなく**端末ローカルのSharedPreferences**が主なので、Supabaseの`user_streaks`を直接書き換えてもテストになりません。**端末の日時を手動で進める**方法で実際のインクリメントロジックを通します。

| # | 手順 |
|---|---|
| C1 | ★ここでアプリを操作: 端末の自動日時設定をOFFにする |
| C2 | ★ここでアプリを操作: 現在の日時のまま、`scene_id=1`のシーンで1回会話する(streak=1) |
| C3 | ★ここでアプリを操作: 端末日時を「翌日」に進める |
| C4 | ★ここでアプリを操作: 同じシーンで1回会話する(streak=2) |
| C5 | ★ここでアプリを操作: 端末日時をさらに「翌日」に進める |
| C6 | ★ここでアプリを操作: 同じシーンで1回会話する(streak=3) → **この瞬間、マイルストーン通知が即座に表示されるはず** |

- [ ] C6: 3日達成のマイルストーン通知(トースト/通知)が即時表示された

| # | 手順 | 期待結果 |
|---|---|---|
| C7 | ★ここでSQLを実行(下記) | `milestone`の行が`status='delivered'`で存在する |

```sql
SELECT title, body, payload, status, received_at
FROM notification_history
WHERE user_id = current_setting('myapp.user_id')::uuid
  AND payload = 'milestone'
ORDER BY created_at DESC
LIMIT 5;
```

- [ ] C7: `status='delivered'`のmilestone行を確認

| # | 手順 | 期待結果 |
|---|---|---|
| C8 | ★ここでアプリを操作: 端末の自動日時設定を**元に戻す(ONにする)** | 端末の時計が現在時刻に復帰する |

- [ ] C8: 端末の自動日時設定を元に戻した(この後の通常利用・次回セッションへの悪影響を防ぐため必須)

**本編(STEP 1〜5)はここまでで完結です。** Phase D・Eは日をまたぐ/再インストールが必要なため、下記の別セクションで実施してください。

---

## 本編 全体チェックリスト(サマリ)

- [ ] STEP 1(PART A): 是正0件・Premium巻き込みなしを確認
- [ ] STEP 2(Phase A): 通知トグルOFF/ONでscheduled行が正しく削除/再作成される
- [ ] STEP 3(daily_limit PART B、必須): B1で daily_limit=5・used_today=1、（実施時）B2で daily_limit=50 維持、検証後に元の状態へ復元
- [ ] STEP 4(Phase B): アプリ内言語切替が**再起動なしで**即座に新しい言語の通知をスケジュールする(リスナー動作確認)。再起動後も重複INSERTなし。過去履歴は元の言語のまま(仕様通り)
- [ ] STEP 5(Phase C): ストリーク3日達成でマイルストーン通知が即時表示され、`delivered`で記録される。端末の自動日時設定を元に戻した

何かおかしな挙動があれば、該当のSQL結果・端末ログ(`log collect --device --last 5m`)を添えて共有してください。

---

---

# 日をまたぐ・再インストールが必要な項目(別セッションで実施)

以下は破壊的操作(アプリ再インストール)を伴うため、本編とは別のタイミングで実施してください。
**Phase D → Phase E の順で連続して実施すること**(Phase EはPhase Dで復元されたstreak値が前提のため)。

**注意**: Phase Dはアプリを再インストールするため、STEP 4で設定した言語(Filipino)・STEP 2の通知トグル設定・
その他のローカル設定(ふりがな表示等)が**全てリセットされます**。副次的に、クラウドTTS 1日1回解放フラグ
(`cloud_tts_unlocked_date`、再インストール以外にリセット手段なし)もここで一緒にリセットされます(これ自体の
個別検証手順はありません、副作用として記録するのみ)。

## Phase D: ストリークの端末間整合性(端末変更/再インストール)検証

| # | 手順 | 期待結果 |
|---|---|---|
| D1 | ★ここでSQLを実行(下記) | `user_streaks`の`streak_days`が3(または直近の値)。記録しておく |

```sql
SELECT user_id, scene_id, streak_days, last_updated
FROM user_streaks
WHERE user_id = current_setting('myapp.user_id')::uuid
  AND scene_id = current_setting('myapp.scene_id')
ORDER BY last_updated DESC;
```

| # | 手順 | 期待結果 |
|---|---|---|
| D2 | ★ここでアプリを操作: Voikerchatをアンインストール → TestFlightから再インストール | ― |
| D3 | ★ここでアプリを操作: 再インストール後、同じシーン画面を開く | D1で確認した値(streak=3)が正しく復元されて表示される(=`getCurrentStreak()`がSupabase復元パスに正しく入った証拠) |

- [ ] D3: 再インストール後もstreakが正しく復元された

## Phase E: オフライン復帰時の値整合性検証(Phase Dの直後に連続実施)

Phase Dの直後、streakが復元された状態から行います。

| # | 手順 |
|---|---|
| E1 | ★ここでアプリを操作: 機内モードをONにする(オフライン化) |
| E2 | ★ここでアプリを操作: 同じシーンで1回会話する(streakがローカルでN+1にインクリメントされる。Supabaseへの書き込みは失敗/保留) |
| E3 | ★ここでアプリを操作: 機内モードのまま、該当シーンの画面を出入りする(`getCurrentStreak()`を再度呼ばせる) |

- [ ] E3: ローカル値(N+1)が古いDB値(N)で上書きされず、N+1のまま維持される

| # | 手順 | 期待結果 |
|---|---|---|
| E4 | ★ここでアプリを操作: 機内モードをOFFにしてオンライン復帰。数秒〜数十秒待つ | ― |
| E5 | ★ここでSQLを実行(下記) | `streak_days`がN+1に更新されている(fire-and-forgetの書き込みが遅れて成功する) |

```sql
SELECT streak_days, last_updated
FROM user_streaks
WHERE user_id = current_setting('myapp.user_id')::uuid
  AND scene_id = current_setting('myapp.scene_id');
```

- [ ] E5: オンライン復帰後にDB側もN+1に反映された

## 別セッション項目 チェックリスト(サマリ)

- [ ] D3: アプリ再インストール後もストリークがSupabaseから正しく復元される
- [ ] E3 / E5: オフライン中の新しい値がオンライン復帰後も正しく反映される(古い値に巻き戻らない)
