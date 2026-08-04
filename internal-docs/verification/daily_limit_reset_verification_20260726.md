# daily_limit 日次リセット 実地検証(2026-07-26)

> ## 【実行禁止】このファイルは記録用です。実行しないでください。
> 実行するのは `internal-docs/verification/daily_limit_20260726_all_in_one.sql`
> (または統合版 `internal-docs/verification/release_verification_session_20260726.md`)
> のみです。このファイルに含まれるSQLを重ねて実行すると、UPDATEが
> 二重に走ります。

対象: `api/chat.ts` の `checkAndIncrementRateLimit()` および `api/rate-limit.ts` の日次リセット処理(PR参照)。
日付境界を跨いだ際に `daily_limit` が基礎値(無料5/Premium50)へ正しく戻ることを、実機でのアプリ操作を交えて検証する。

## 実行順序について

- 本検証は**専用のテストユーザー(自分の匿名テストアカウント)**に対してのみ実施すること。実際に影響を受けた既存ユーザーの是正には `internal-docs/migrations/2026-07-26_fix_daily_limit_reset_correction.sql` を使う(別ファイル・別対象)。
- 本検証はコード修正のデプロイ**後**に実施すること(デプロイ前だと修正が効かず、意図的に「まだ直っていない」結果になる)。
- 本検証で使うバックアップテーブル名(`_rate_limits_verification_backup`)は、補正SQL側のバックアップテーブル(`_rate_limits_daily_limit_backup_20260726`)と別名のため、**どちらを先に実行しても競合しない**。ただし分かりやすさのため「補正SQL(既存データの是正)→ 本検証(新規動作の確認)」の順で実施することを推奨する。

## 事前準備(最初に1回だけ・値の置換はここ1箇所のみ)

```sql
-- 検証に使うテストユーザーのuser_idを1箇所だけ貼る(以降すべてこの設定値を使い回す)
SET myapp.user_id = 'ここにテスト用user_idを貼る';
```

以降のSQLはすべて `current_setting('myapp.user_id')::uuid` 経由で参照するため、貼り直し不要。

---

## ステップ0: 現状をバックアップする(あとで元に戻すため)

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
- **NG時に疑うべき箇所**: 0行の場合、対象ユーザーが `rate_limits` にまだ存在しない(一度もアプリで会話していない)。先にアプリで1回会話してレコードを作成してから、この手順からやり直す。

---

## シナリオA: 無料ユーザーでの日次リセット確認

### A1. バグ発生状態を人工的に再現する

```sql
UPDATE public.rate_limits
SET daily_limit = 10,
    used_today = 3,
    last_reset_utc = now() - interval '2 days'
WHERE user_id = current_setting('myapp.user_id')::uuid
  AND is_premium = false;
```

- **期待結果**: `UPDATE 1`
- **NG時に疑うべき箇所**: `UPDATE 0` の場合、対象ユーザーが `is_premium = true` になっている(Premiumテストアカウントを誤って使っている)。ステップ0の結果を確認し、無料ユーザーで実施し直す。

### A2. アプリで会話を1回送信する

対象ユーザーでログイン中のiPhone/シミュレータで、任意のシーンを開き、メッセージを1回送信する(またはボイス発話を1回行う)。

### A3. 結果を確認する

```sql
SELECT daily_limit, used_today, last_reset_utc, is_premium
FROM public.rate_limits
WHERE user_id = current_setting('myapp.user_id')::uuid;
```

- **期待結果**: `daily_limit = 5`、`used_today = 1`、`last_reset_utc` が現在時刻付近に更新されている
- **NG時に疑うべき箇所**:
  - `daily_limit` が `10` のまま → コード修正がデプロイに反映されていない可能性(Vercelの最新デプロイを確認)、または `api/chat.ts` と `api/rate-limit.ts` のどちらか一方しか修正されていない(会話送信は `api/chat.ts` 経由、アプリ起動時のステータス表示取得は `api/rate-limit.ts` 経由なので、どちらのエンドポイントが先に呼ばれたかで切り分ける)
  - `used_today` が `2` 以上 → 会話を複数回送信してしまった可能性、または手順を最初からやり直す必要がある
  - `last_reset_utc` が更新されていない → `daysPassed >= 1` の判定に使っている経過日数の計算に問題がある可能性(A1で `interval '2 days'` を使っているか再確認。1日未満だと `daysPassed` が0のままリセットされない)

---

## シナリオB: Premiumユーザーで50が維持されることの確認(可能なら)

Premiumのテストアカウントがある場合のみ実施。無ければスキップしてよい。

### B1. Premiumユーザーのuser_idに切り替える

```sql
-- Premiumテストユーザーのuser_idに変更する場合はここで再設定する
SET myapp.user_id = 'ここにPremiumテスト用user_idを貼る';
```

### B2. 現状をバックアップする(ステップ0と同じSQLを再実行)

```sql
INSERT INTO public._rate_limits_verification_backup
  (user_id, daily_limit, used_today, last_reset_utc, is_premium)
SELECT user_id, daily_limit, used_today, last_reset_utc, is_premium
FROM public.rate_limits
WHERE user_id = current_setting('myapp.user_id')::uuid;
```

### B3. last_reset_utc のみ「2日前」にする(daily_limitは50のまま変更しない)

```sql
UPDATE public.rate_limits
SET last_reset_utc = now() - interval '2 days'
WHERE user_id = current_setting('myapp.user_id')::uuid
  AND is_premium = true;
```

- **期待結果**: `UPDATE 1`
- **NG時に疑うべき箇所**: `UPDATE 0` の場合、対象ユーザーが実は `is_premium = false`(Premiumテストアカウントの権限が失効している可能性。RevenueCatのテスト購入状態を確認)。

### B4. アプリで会話を1回送信し、結果を確認する

```sql
SELECT daily_limit, used_today, last_reset_utc, is_premium
FROM public.rate_limits
WHERE user_id = current_setting('myapp.user_id')::uuid;
```

- **期待結果**: `daily_limit = 50` のまま(変化なし)、`used_today = 1`
- **NG時に疑うべき箇所**: `daily_limit` が `5` に落ちている場合、`baseDailyLimit(isPremium)` の `isPremium` 判定が反転している(`api/_constants.ts` の `baseDailyLimit()`、または `api/chat.ts` で `isPremium` を渡し忘れている)可能性が高い。最優先で確認すること。

---

## 検証後: 元の状態に戻す(手打ち不要・バックアップから復元)

シナリオA・Bで使った `myapp.user_id` それぞれについて、以下を実行する(直前にSETした値のままでOK)。

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

全シナリオの検証が終わったら、バックアップテーブルは削除してよい(残しておいても実害はない)。

```sql
DROP TABLE IF EXISTS public._rate_limits_verification_backup;
```

---

## チェックリスト(サマリ)

- [ ] A3: 無料ユーザーで `daily_limit` が `10` → `5` にリセットされ、`used_today = 1` になった
- [ ] B4(実施した場合): Premiumユーザーで `daily_limit = 50` が維持された
- [ ] 検証後、バックアップから元の状態に復元した
