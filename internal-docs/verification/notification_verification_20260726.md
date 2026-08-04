# 通知機能 実機検証キット(2026-07-26)

> **後継ドキュメントあり**: `internal-docs/verification/release_verification_session_20260726.md` に、本ドキュメントの内容と
> daily_limitの動作検証を1本化した統合セッションを用意しています。今後の実機検証は統合版を使用してください
> (このファイルは経緯の記録として残していますが、内容は統合版に含まれています)。

対象: PR #10・#11・#12(通知機能一式)・#13(ストリーク修正)・#17(言語切替時の再スケジュール)。
この1枚で実機検証が完結するようにまとめてあります。手順は**アプリの再起動・言語切替・機内モード切替の回数が最小になる順**に並んでいます。上から順に進めてください。

## 事前準備(最初に1回だけ)

1. iPhoneとMacをUSB接続する(`xcrun devicectl list devices`で`connected`になっていることを確認可能)
2. Supabase SQL Editorを開く
3. 下記を実行し、**このセッション中使い回す**`user_id`と`scene_id`をセットする(このタブを閉じるまで再設定不要です)。`user_id`は`auth.users`の一覧から、直近使っているテスト用の匿名ユーザーを選んでください(通常は一番新しいもの)。

```sql
-- ① 自分のuser_idを確認する(直近のものが自分のはず)
SELECT id, created_at FROM auth.users ORDER BY created_at DESC LIMIT 5;
```

```sql
-- ② 上で確認したuser_idを1箇所だけ貼り、scene_idも設定する
--    (このSQL Editorのタブを閉じるまで、以降のクエリで使い回せます)
SET myapp.user_id = 'ここにuser_idを貼る';
SET myapp.scene_id = '1';
```

以降のSQLは全てこの2つの設定値を`current_setting()`経由で参照するので、**貼り直しは不要**です。

---

## Phase A: 通知ON/OFFトグル検証(所要: 数分・1日で完結)

| # | 手順 | 期待結果 |
|---|---|---|
| A1 | 設定画面で「通知」をOFFにする | ― |
| A2 | 下記SQLを実行 | 直前まであった`daily_reminder`の`status='scheduled'`行が削除されている(`delivered`済みの過去行は残っていてよい) |

```sql
SELECT id, payload, status, received_at
FROM notification_history
WHERE user_id = current_setting('myapp.user_id')::uuid
  AND payload = 'daily_reminder'
ORDER BY created_at DESC;
```

| # | 手順 | 期待結果 |
|---|---|---|
| A3 | 設定画面で「通知」を再度ONにする | ― |
| A4 | 上と同じSQLを再実行 | `daily_reminder`の`scheduled`行が新規作成されている |

- [ ] A2: OFF後にscheduled行が消えた
- [ ] A4: ON後にscheduled行が復活した

**NG時の切り分け**: A2で行が消えない場合、`cancelScheduledByPayload`が呼ばれていない(トグルOFFの配線漏れ)。A4で行が増えない場合、`scheduleDailyReminders()`が`isNotificationsEnabled()`のガードで止まっている可能性。

---

## Phase B: アプリ内言語切替 → 通知の再スケジュール検証(所要: 数分・1日で完結)

**重要**: 手順B2は**アプリを再起動せずに**確認してください。再起動を挟むと、リスナーが正しく動作していなくても(起動時の`scheduleDailyReminders()`呼び出しで)辻褄が合ってしまい、誤判定します。

| # | 手順 | 期待結果 |
|---|---|---|
| B1 | 設定画面で言語を「Filipino」に切り替える | ― |
| B2 | **切り替えてから3〜5秒待ち、再起動せずに**下記SQLを実行 | `daily_reminder`の新しい`scheduled`行(直近の`created_at`)が**fil表示**(例: タイトルに"Umaga"等)になっている |

```sql
SELECT id, title, body, payload, status, received_at, created_at
FROM notification_history
WHERE user_id = current_setting('myapp.user_id')::uuid
  AND payload = 'daily_reminder'
ORDER BY created_at DESC
LIMIT 6;
```

- [ ] B2でfil表示の新しい行が(再起動なしで)確認できた → **リスナーが正しく動作している証拠**
- [ ] B2で変化がない → リスナー未発火(要調査。次のB4で再起動後にだけ直っていたら「起動時呼び出しで辻褄が合っているだけ」と確定)

| # | 手順 | 期待結果 |
|---|---|---|
| B3 | アプリを完全終了 → 再起動する | ― |
| B4 | 下記の重複チェックSQLを実行 | 0件(`didChangeLocales`経路と今回のリスナーの二重発火で重複INSERTされていないこと) |

```sql
SELECT payload, received_at, COUNT(*)
FROM notification_history
WHERE user_id = current_setting('myapp.user_id')::uuid
  AND payload = 'daily_reminder'
GROUP BY payload, received_at
HAVING COUNT(*) > 1;
```

- [ ] B4: 重複0件

| # | 手順 | 期待結果 |
|---|---|---|
| B5 | 通知履歴タブ(Mga Abiso)を開く | 言語切替**より前**に受信した過去のレコードは**日本語のまま**表示される(仕様通り。DECISIONS.md 2026-07-26参照。「直っていない」ではない) |

- [ ] B5: 過去レコードは日本語のまま(想定通り)であることを確認(ここでfilになっていたら逆に想定外)

**この時点でアプリの表示言語はFilipinoのままです。以降のPhase C・Dはこのままの言語で進めて構いません(言語をJapaneseに戻す必要はありません)。**

---

## Phase C: ストリーク回帰 + マイルストーン即時履歴書き込み検証(所要: 端末日時操作で1回の滞在時間内に完結)

ストリークは`auth.uid()`ではなく**端末ローカルのSharedPreferences**が主なので、Supabaseの`user_streaks`を直接書き換えてもテストになりません。**端末の日時を手動で進める**方法で実際のインクリメントロジックを通します。

| # | 手順 |
|---|---|
| C1 | 端末の自動日時設定をOFFにする |
| C2 | 現在の日時のまま、`scene_id=1`のシーンで1回会話する(streak=1) |
| C3 | 端末日時を「翌日」に進める |
| C4 | 同じシーンで1回会話する(streak=2) |
| C5 | 端末日時をさらに「翌日」に進める |
| C6 | 同じシーンで1回会話する(streak=3) → **この瞬間、マイルストーン通知が即座に表示されるはず** |

- [ ] C6: 3日達成のマイルストーン通知(トースト/通知)が即時表示された

| # | 手順 | 期待結果 |
|---|---|---|
| C7 | 下記SQLを実行 | `milestone`の行が`status='delivered'`で存在する |

```sql
SELECT title, body, payload, status, received_at
FROM notification_history
WHERE user_id = current_setting('myapp.user_id')::uuid
  AND payload = 'milestone'
ORDER BY created_at DESC
LIMIT 5;
```

- [ ] C7: `status='delivered'`のmilestone行を確認

---

## Phase D: ストリークの端末間整合性(端末変更/再インストール)検証(所要: 数分・破壊的操作のため最後に実施)

**注意**: この手順はアプリを再インストールするため、Phase Bで設定した言語(Filipino)・Phase Aの通知トグル設定・その他のローカル設定(ふりがな表示等)が**全てリセットされます**。この検証を最後に回しているのはそのためです。副次的に、クラウドTTS 1日1回解放フラグ(`cloud_tts_unlocked_date`、再インストール以外にリセット手段なし)もここで一緒にリセットされます。

| # | 手順 | 期待結果 |
|---|---|---|
| D1 | Phase Cでstreak=3まで進めた状態で、下記SQLを実行し記録しておく | `user_streaks`の`streak_days`が3(または直近の値) |

```sql
SELECT user_id, scene_id, streak_days, last_updated
FROM user_streaks
WHERE user_id = current_setting('myapp.user_id')::uuid
  AND scene_id = current_setting('myapp.scene_id')
ORDER BY last_updated DESC;
```

| # | 手順 | 期待結果 |
|---|---|---|
| D2 | Voikerchatをアンインストール → TestFlightから再インストール | ― |
| D3 | 再インストール後、同じシーン画面を開く | D1で確認した値(streak=3)が正しく復元されて表示される(=`getCurrentStreak()`がSupabase復元パスに正しく入った証拠) |

- [ ] D3: 再インストール後もstreakが正しく復元された

---

## Phase E: オフライン復帰時の値整合性検証(所要: 数分・任意・Dの直後に実施)

Phase Dの直後、streakが復元された状態から行います。

| # | 手順 |
|---|---|
| E1 | 機内モードをONにする(オフライン化) |
| E2 | 同じシーンで1回会話する(streakがローカルでN+1にインクリメントされる。Supabaseへの書き込みは失敗/保留) |
| E3 | 機内モードのまま、該当シーンの画面を出入りする(`getCurrentStreak()`を再度呼ばせる) |

- [ ] E3: ローカル値(N+1)が古いDB値(N)で上書きされず、N+1のまま維持される

| # | 手順 | 期待結果 |
|---|---|---|
| E4 | 機内モードをOFFにしてオンライン復帰。数秒〜数十秒待つ | ― |
| E5 | 下記SQLで確認 | `streak_days`がN+1に更新されている(fire-and-forgetの書き込みが遅れて成功する) |

```sql
SELECT streak_days, last_updated
FROM user_streaks
WHERE user_id = current_setting('myapp.user_id')::uuid
  AND scene_id = current_setting('myapp.scene_id');
```

- [ ] E5: オンライン復帰後にDB側もN+1に反映された

---

## 全体チェックリスト(サマリ)

- [ ] A2 / A4: 通知トグルOFF/ONでscheduled行が正しく削除/再作成される
- [ ] B2: アプリ内言語切替が**再起動なしで**即座に新しい言語の通知をスケジュールする(リスナー動作確認)
- [ ] B4: 言語切替後の再起動でも重複INSERTが発生しない
- [ ] B5: 言語切替より前の過去履歴は元の言語のまま(仕様通り)
- [ ] C6 / C7: ストリーク3日達成でマイルストーン通知が即時表示され、`delivered`で記録される
- [ ] D3: アプリ再インストール後もストリークがSupabaseから正しく復元される
- [ ] E3 / E5: オフライン中の新しい値がオンライン復帰後も正しく反映される(古い値に巻き戻らない)

何かおかしな挙動があれば、該当のSQL結果・端末ログ(`log collect --device --last 5m`)を添えて共有してください。
