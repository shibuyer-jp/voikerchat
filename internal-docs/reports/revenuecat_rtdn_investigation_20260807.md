# RevenueCat Real-Time Developer Notifications(RTDN)接続の調査(2026-08-07)

バックログ「RevenueCat Android有効化」の残作業(①②③④は完了、RTDN接続のみ
未着手)の調査。接続手順の人間/CC切り分け、未接続時の影響評価、公開前
必須かどうかの判断材料をまとめる。

## 1. RTDNとは何か、どこに位置するか

RTDN(Real-time developer notifications)は、Google Playが定期購入の
状態変化(更新・解約・返金・猶予期間入り等、**アプリの外で起きる
イベント**)をほぼリアルタイムでサーバーへプッシュ通知する仕組み。
Google Cloud Pub/Subのトピックを経由して配信される。

本アプリのデータフローにおける位置づけ:

```
Google Play(定期購入の状態変化)
    │
    │ ① RTDN ← [未接続]
    ▼
RevenueCat(状態を保持・判定)
    │
    │ ② api/revenuecat-webhook.ts ← [接続済み・動作確認済み]
    ▼
rate_limits.is_premium / daily_limit(Supabase)
```

**重要**: ①(Google Play → RevenueCat)と②(RevenueCat → 本アプリの
webhook)は別の統合であり、**②は既に正常に機能している**(RevenueCat
ダッシュボードのWebhook設定・`REVENUECAT_WEBHOOK_SECRET`は設定済み、
`api/revenuecat-webhook.ts`は実装済みで開発者本人の実購入検証でも
動作確認済み、未完了項目14参照)。**未接続なのは①のみ**。つまり
「webhookが壊れている」のではなく、「RevenueCat自身がGoogle Play側の
一部イベントをリアルタイムに知る手段を持っていない」状態である。

## 2. 現在の設定状況(STATE.md記載事項の整理)

- Google Cloudプロジェクト`voikerchat`(Firebaseと同一)で
  **Cloud Pub/Sub APIは既に有効化済み**[本人報告、Claude Code未検証]
- サービスアカウント`revenuecat@voikerchat.iam.gserviceaccount.com`を
  作成済み。ロールは**Pub/Sub編集者+モニタリング閲覧者**
  (`internal-docs/STATE.md`バックログ参照)。「Pub/Sub編集者」ロールは
  トピック・サブスクリプションの作成/管理に十分な権限を含むため、
  RTDN用のPub/Subリソースをこのサービスアカウント経由で用意できる
  想定になっている
- RevenueCat側にPlay StoreアプリはApp ID `appf7acdb482b`で登録済み、
  Google Playサービスアカウント認証も完了済み(Productインポートも
  成功済み)
- 上記を踏まえると、**RTDN接続に必要な基盤(GCPプロジェクト・API有効化・
  サービスアカウント)は既に揃っている**。残っているのはRTDN固有の
  設定(Pub/Subトピックの作成・権限付与・Play Console/RevenueCat両方への
  設定投入)のみと考えられる

## 3. 接続手順(人間/CC切り分け)

**[要確認]** 以下はRevenueCat公式ドキュメント・Google Play公式
ヘルプで一般的に案内されている標準的なRTDN設定フローに基づく整理。
RevenueCatダッシュボードのUIは変更されることがあるため、実施時に
RevenueCat公式ドキュメント(Play Store integration → Real-time
developer notifications)の最新版で手順を再確認すること。

| # | 作業内容 | 担当 | 備考 |
|---|---|---|---|
| 1 | RevenueCatダッシュボードのPlay Store設定画面で、RTDN用のPub/Subトピック名を確認する(RevenueCatが指定するトピック名を使う、または自分でトピックを作成してRevenueCatに伝える2パターンがありうる) | 人間(RevenueCatダッシュボード操作) | 実施時にどちらの方式かをダッシュボードの案内で確認 |
| 2 | Google Cloud Consoleで該当Pub/Subトピックを作成する(未作成の場合) | 人間(GCP Console操作。または`gcloud`コマンドでも可) | 既存サービスアカウントのPub/Sub編集者ロールで作成可能 |
| 3 | Google管理のシステムサービスアカウント`google-play-developer-notifications@system.gserviceaccount.com`に、作成したトピックへの**Pub/Sub発行者(Publisher)**権限を付与する | 人間(GCP Console操作) | Google Play公式ヘルプに記載の固定サービスアカウント名。RevenueCat用に作成した`revenuecat@voikerchat.iam.gserviceaccount.com`とは別物(混同注意) |
| 4 | Play Console → 収益化の設定(Monetization setup)→「リアルタイム デベロッパー通知」欄に、上記トピックのフルパス(`projects/voikerchat/topics/<トピック名>`)を入力して保存 | 人間(Play Console操作) | STATE.mdの運用ルール(トラック設定変更禁止)には該当しない操作(トラック・テスターリスト・国/地域のいずれも変更しないため、クローズドテスト期間中でも実施可) |
| 5 | RevenueCatダッシュボード側でトピック名を入力(方式によっては手順1で既に入力済みで手順4だけ残るケースもある)、接続テストを実行 | 人間(RevenueCatダッシュボード操作) | RevenueCatダッシュボードに「テスト通知を送信」等の確認機能があれば併用する |
| 6 | 実際に何らかの定期購入イベント(可能であれば開発者本人のテスト購読の更新/解約等)を発生させ、RevenueCatダッシュボードの該当サブスクライバーのイベント履歴に反映されることを確認 | 人間(実地確認) | 即時性の実感値を得る目的。必須ではないが推奨 |

**コード側(CC)の作業は無い**。`api/revenuecat-webhook.ts`は既に
RTDN接続の有無によらず動作する実装になっている(RTDN接続後は、より
多くの/より早いイベントが同じエンドポイントに届くようになるだけで、
受信側のロジック変更は不要)。

## 4. 未接続だと何が起きるか(具体的な影響評価)

`api/revenuecat-webhook.ts`の`GRANT_EVENT_TYPES`
(`INITIAL_PURCHASE`/`RENEWAL`/`UNCANCELLATION`/`REFUND_REVERSED`/
`SUBSCRIPTION_EXTENDED`)と`REVOKE_EVENT_TYPES`(`EXPIRATION`)に照らして
イベント種別ごとに整理する。

| イベント | 発生源 | RTDN無しでの影響 |
|---|---|---|
| `INITIAL_PURCHASE`(新規購入) | **アプリ内の購入操作**(クライアントが`Purchases.purchase()`を呼び、RevenueCatサーバーへ直接到達) | **影響なし**。RTDNを経由しないため、接続の有無に関わらずリアルタイムに近い形で届く |
| `RENEWAL`(月次自動更新) | **Google Play側で自動的に発生**(ユーザーはアプリを開かない) | RTDN無しではRevenueCat側の検知が遅延しうる。ただし本イベントの実質的な効果は「既にis_premium=trueのユーザーをtrueのまま維持する」ことであり、**遅延してもユーザー体験への実害は小さい**(遅延中も旧状態のまま=Premiumが継続表示されるだけ) |
| `EXPIRATION`(自動更新なしで契約終了、または猶予期間・保留期間を経て失効) | **Google Play側で自動的に発生** | **RTDN無しでの実害が最も大きいイベント**。検知が遅れるほど、**本来Premiumではなくなったユーザーが実質無料でPremium特典(50回/日・広告非表示・全シーン)を使い続けてしまう**(収益漏れ)。ユーザー体験を損なう方向のバグではなく、事業者側の収益リスク |
| `UNCANCELLATION`/`REFUND_REVERSED`/`SUBSCRIPTION_EXTENDED` | いずれもGoogle Play側で発生する例外的なイベント | 発生頻度が低く、遅延してもリスクは限定的 |
| `CANCELLATION`(自動更新OFFの予約) | Google Play側 | 現状のコードでは`action='none'`(no-op)のため、RTDN接続有無に関わらず本アプリの挙動には影響しない(契約期間終了まではPremiumが正しいという既存の設計判断、DECISIONS.md参照) |

**RTDN無しでのRevenueCat側フォールバック**: RevenueCatはRTDN未接続でも
Google Play Developer APIへの定期ポーリングにより状態を補完する
(RevenueCat公式ドキュメントで言及されている一般的な仕組み)。ただし
**[未確認]** ポーリング間隔・遅延の具体的な時間(RevenueCatの一般的な
案内では最大24時間程度とされることが多いが、本プロジェクトでの実測値
ではない)。本アプリ側で`checkPremiumStatus()`を起動時等に呼んでいる
ことが、この遅延をどこまで縮められるかも**[未確認]**(クライアントの
呼び出しがRevenueCat側の即時再ポーリングをトリガーするかは、RevenueCat
の内部実装次第で本調査では特定できなかった)。

**現時点でのリスク規模**: 2026-08-07時点で確認できているPremiumユーザーは
開発者本人の1件のみ(実測データ、DECISIONS.md 2026-08-05(続)「Premium
ユーザー0人」からの陳腐化を参照)。クローズドテスト中の実被害は
実質ゼロに近い。

## 5. 公開前に必須かどうかの判断材料

**結論: 公開のハードブロッカーではないが、一般公開前に実施することを
推奨する。**

- **必須ではない理由**: (a) 唯一実害の大きい`EXPIRATION`遅延は「本来
  失効したはずのユーザーが一時的にPremiumのまま」という**収益側のリスク**
  であり、ユーザー体験を損なうバグではない。(b) 現在の有料ユーザー数が
  実質1人(開発者本人)のため、遅延が起きても金銭的影響は無視できる規模。
  (c) コード変更を伴わないため、後からいつでも接続できる(手順4はPlay
  Console操作だが、トラック設定変更の運用ルールには抵触しないため
  クローズドテスト期間中でも着手可能)
- **一般公開前に実施すべき理由**: 一般公開後は有料ユーザー数が増える
  想定であり、`EXPIRATION`検知の遅延がユーザー数に比例して収益漏れの
  規模を拡大させる。また、Play Consoleの推奨設定でもあり(定期購入を
  扱うアプリへの標準的なベストプラクティス)、後回しにする積極的な
  理由が無い
- **推奨タイミング**: Androidクローズドテスト完走(見込み2026-08-14前後)
  を待つ必要はない(トラック設定変更に該当しないため)。人手作業のみで
  コード変更を伴わないため、**都合の良いタイミングで随時実施してよい**

## 6. 次のアクション

- `internal-docs/STATE.md`のバックログ「RevenueCat Android有効化」の
  残作業欄に、本レポートへの参照と上記手順表を反映する
- 実施はTakatoh(Play Console/GCP Console/RevenueCatダッシュボードの
  実画面操作が必要なため、CCでは代行不可)
- 実施後、RevenueCatダッシュボードで実際にRTDN経由のイベントが記録
  されることを確認し、本レポートに実施結果を追記すること
