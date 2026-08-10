# RevenueCat Real-Time Developer Notifications(RTDN)接続の調査(2026-08-07)

> **[2026-08-10追記] 実施完了・手順の訂正**: 本レポート作成から3日後の2026-08-10、
> 実際にRTDN接続を実施した。下記「3. 接続手順」は**当初の想定と実態が異なって
> いた**ため、実施結果を踏まえて訂正版へ書き換えた(黙って書き換えず、当初の
> 想定内容は文末の「3-旧. 当初の想定手順(誤り、記録用)」に残す)。実施結果の
> サマリーは「6. 次のアクション」参照。

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
    │ ① RTDN ← [2026-08-10 接続完了]
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
動作確認済み、未完了項目14参照)。①も2026-08-10に接続完了した。

## 2. 現在の設定状況(2026-08-10更新)

- Google Cloudプロジェクト`voikerchat`(Firebaseと同一)で
  **Cloud Pub/Sub APIは有効化済み**
- サービスアカウント`revenuecat@voikerchat.iam.gserviceaccount.com`の
  ロールは**Pub/Sub管理者(roles/pubsub.admin)/Pub/Sub編集者/
  モニタリング閲覧者**の3つ(2026-08-10、RTDN接続の過程でPub/Sub管理者を
  追加付与。詳細は3節参照)
- RevenueCat側にPlay StoreアプリはApp ID `appf7acdb482b`で登録済み、
  Google Playサービスアカウント認証も完了済み(Productインポートも
  成功済み)
- Pub/Subトピック`projects/voikerchat/topics/Play-Store-Notifications`が
  RevenueCat側の「Connect to Google」操作により作成され、Play Console
  側の設定と接続済み

## 3. 接続手順(実施結果、2026-08-10)

> **[訂正]** 下記は2026-08-10に実際にRTDN接続を実施した結果を反映した
> 手順である。2026-08-07時点の当初の想定(本レポート初版)は、必要な
> IAMロール・Pub/Subトピック作成の主体・発行者権限付与の主体の3点で
> 実態と異なっていた。当初の想定内容は本レポート末尾「3-旧」に記録として
> 残す。

| # | 作業内容 | 実際の担当 | 実施結果・注意点 |
|---|---|---|---|
| 1 | RevenueCatダッシュボード → Play Store設定画面で「Connect to Google」を実行 | 人間(RevenueCatダッシュボード操作) | RevenueCatが**Pub/Subトピックを自動作成**した(人間がGCP Consoleで手動作成する必要は無かった) |
| 2 | Google管理のシステムサービスアカウント`google-play-developer-notifications@system.gserviceaccount.com`への発行者(Publisher)権限付与 | **RevenueCatが自動実行**(人間の作業は不要だった) | 当初「人間がGCP Consoleで手動付与」を想定していたが、実際はRevenueCatの「Connect to Google」操作に含まれていた |
| 3 | サービスアカウント`revenuecat@voikerchat.iam.gserviceaccount.com`のIAMロールに**Pub/Sub管理者(roles/pubsub.admin)**を追加 | 人間(GCP Console操作) | **当初の想定と異なり必須だった**。既存の「Pub/Sub編集者」ではトピックのIAMポリシー変更権限が無く、「Your Google service account credentials do not have permission to create a Google Cloud Pub/Sub topic.」というエラーで手順1が失敗した。エラー解消後に手順1をやり直して成功した |
| 4 | Play Console → 収益化のセットアップ → リアルタイム デベロッパー通知 →「リアルタイムの通知を有効にする」ON、トピック名`projects/voikerchat/topics/Play-Store-Notifications`(フルパス)を入力、通知の内容で「定期購入、取り消し済みの購入、すべての1回限りのアイテム」を選択して保存 | 人間(Play Console操作) | STATE.mdの運用ルール(トラック設定変更禁止)には該当しない操作のため、クローズドテスト期間中に実施した |
| 5 | RevenueCatダッシュボードでステータス確認 | 人間 | 「Connected to Google」(緑チェック)を確認。Last received: 2026-08-10 4:04 a.m. UTC(Play Consoleからのテスト通知を受信) |

**運用上の落とし穴**: GCPのIAMロール検索で「Pub/Sub Lite 管理者」が
「Pub/Sub 管理者」より先に候補表示され、誤って選択しやすい。これは
別サービス(Pub/Sub Lite)のロールであり、本件には無効。正しいのは
「Pub/Sub 管理者」= `roles/pubsub.admin`。

**所要時間の実測**: 約20分(権限エラーの解決を含む)。

**コード側(CC)の作業は無かった**。`api/revenuecat-webhook.ts`はRTDN
接続の有無によらず動作する実装のままで変更不要だった(RTDN接続後は、
より多くの/より早いイベントが同じエンドポイントに届くようになるだけ)。

### 3-旧. 当初の想定手順(2026-08-07、誤り・記録用)

> 以下は本レポート初版の記載。実態と異なっていた3点に**[誤り]**を付記して
> そのまま残す。

| # | 作業内容 | 担当 | 備考 |
|---|---|---|---|
| 1 | RevenueCatダッシュボードのPlay Store設定画面で、RTDN用のPub/Subトピック名を確認する(RevenueCatが指定するトピック名を使う、または自分でトピックを作成してRevenueCatに伝える2パターンがありうる) | 人間(RevenueCatダッシュボード操作) | 実施時にどちらの方式かをダッシュボードの案内で確認 |
| 2 | Google Cloud Consoleで該当Pub/Subトピックを作成する(未作成の場合) | **[誤り]** 人間(GCP Console操作。または`gcloud`コマンドでも可)と想定していたが、実際はRevenueCatの「Connect to Google」操作が自動作成した | 既存サービスアカウントのPub/Sub編集者ロールで作成可能、としていたが誤り(**[誤り]** Pub/Sub編集者では不足、Pub/Sub管理者が必要だった) |
| 3 | Google管理のシステムサービスアカウント`google-play-developer-notifications@system.gserviceaccount.com`に、作成したトピックへの**Pub/Sub発行者(Publisher)**権限を付与する | **[誤り]** 人間(GCP Console操作)と想定していたが、実際はRevenueCatが自動実行した | Google Play公式ヘルプに記載の固定サービスアカウント名。RevenueCat用に作成した`revenuecat@voikerchat.iam.gserviceaccount.com`とは別物(混同注意) |
| 4 | Play Console → 収益化の設定(Monetization setup)→「リアルタイム デベロッパー通知」欄に、上記トピックのフルパス(`projects/voikerchat/topics/<トピック名>`)を入力して保存 | 人間(Play Console操作) | STATE.mdの運用ルール(トラック設定変更禁止)には該当しない操作(トラック・テスターリスト・国/地域のいずれも変更しないため、クローズドテスト期間中でも実施可) |
| 5 | RevenueCatダッシュボード側でトピック名を入力(方式によっては手順1で既に入力済みで手順4だけ残るケースもある)、接続テストを実行 | 人間(RevenueCatダッシュボード操作) | RevenueCatダッシュボードに「テスト通知を送信」等の確認機能があれば併用する |
| 6 | 実際に何らかの定期購入イベント(可能であれば開発者本人のテスト購読の更新/解約等)を発生させ、RevenueCatダッシュボードの該当サブスクライバーのイベント履歴に反映されることを確認 | 人間(実地確認) | 即時性の実感値を得る目的。必須ではないが推奨 |

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
| `CANCELLATION`(自動更新OFFの予約、または返金) | Google Play側 | **[2026-08-10追記]** 自発的解約(`cancel_reason=UNSUBSCRIBE`)は契約期間終了までPremiumが正しいという既存の設計判断(DECISIONS.md 2026-06)どおりでよいが、返金(`cancel_reason=CUSTOMER_SUPPORT`)は別問題として発覚した。詳細は`internal-docs/DECISIONS.md` 2026-08-10(続4)、修正PR参照 |

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

**結論(2026-08-07時点): 公開のハードブロッカーではないが、一般公開前に
実施することを推奨する。**(2026-08-10に実施完了、下記6節参照)

- **必須ではないと判断していた理由**: (a) 唯一実害の大きい`EXPIRATION`遅延は
  「本来失効したはずのユーザーが一時的にPremiumのまま」という**収益側の
  リスク**であり、ユーザー体験を損なうバグではない。(b) 現在の有料
  ユーザー数が実質1人(開発者本人)のため、遅延が起きても金銭的影響は
  無視できる規模。(c) コード変更を伴わないため、後からいつでも接続
  できる
- **一般公開前に実施すべき理由**: 一般公開後は有料ユーザー数が増える
  想定であり、`EXPIRATION`検知の遅延がユーザー数に比例して収益漏れの
  規模を拡大させる。また、Play Consoleの推奨設定でもあり(定期購入を
  扱うアプリへの標準的なベストプラクティス)、後回しにする積極的な
  理由が無い

## 6. 次のアクション

- ~~`internal-docs/STATE.md`のバックログ「RevenueCat Android有効化」の
  残作業欄に、本レポートへの参照と上記手順表を反映する~~ → **完了
  (2026-08-10)**
- ~~実施はTakatoh(Play Console/GCP Console/RevenueCatダッシュボードの
  実画面操作が必要なため、CCでは代行不可)~~ → **完了**

### 実施結果(2026-08-10)

- Topic ID: `projects/voikerchat/topics/Play-Store-Notifications`
- ステータス: 「Connected to Google」(緑チェック)[確認済 2026-08-10、
  RevenueCatダッシュボード実画面]
- Last received: 2026-08-10 4:04 a.m. UTC(Play Consoleからのテスト通知を受信)
- 所要時間: 約20分(Pub/Sub管理者ロール追加によるエラー解消を含む)
- 副産物として、コードレビューで返金時のPremium剥奪バグ(`CANCELLATION`
  イベントが`cancel_reason`を判定せず一律no-opになっていた不具合)を
  発見した。修正PRは作成済み・未マージ(Build 22での反映を想定)。
  詳細は`internal-docs/DECISIONS.md` 2026-08-10(続4)参照
- **未解決の別件**: RevenueCat上に2026-08-06のライセンステスト購読の
  記録が見当たらない(Active/Expired subscribersともに0人)。原因は
  [未確認]。詳細はSTATE.mdバックログ「RevenueCat Android有効化」参照
