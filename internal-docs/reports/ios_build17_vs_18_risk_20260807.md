# iOS Build 17 vs main(Build 18相当) 公開リスク評価(2026-08-07)

## 依頼背景

未完了項目13(iOSの公開タイミング判断)で「Androidの完走を待って同時公開する」方針は
決定済み(`DECISIONS.md` 2026-08-07(続)参照)だが、それとは別に「審査済みの
Build 17(`1.0.0+17`)をそのまま公開する」か「main(`1.0.0+18`相当)で再提出する」かは
未検討だった。iOS 2回目リジェクト対応でBuild 17を審査提出したcommitは`0c790cf`
(2026-08-03 11:19 JST、「chore: bump version to 1.0.0+17 for iOS resubmission」)。
Build 17は2026-08-06に審査承認済み・未公開。本書は`0c790cf..HEAD`の`lib/`・`api/`差分を
コードベースで調査し、Build 17をそのまま一般公開した場合のiOS固有リスクを評価する。

**調査方法**: 静的コード読解のみ(実機検証は実施していない)。結論は
「コード上、何が確認できて何が確認できないか」を切り分けて記載する。

## 調査結果サマリ

`0c790cf..HEAD`で変更された`lib/`ファイルは34件、`api/`ファイルは9件(`git diff
0c790cf..HEAD --stat`)。このうち、依頼のあった3件の不具合修正(PR #59・PR #53・PR #40)は
**いずれもBuild 17のコミットには一切含まれていない**ことを`git merge-base
--is-ancestor`で確認した。

| 対象PR | 内容 | Build17(`0c790cf`)に含まれるか |
|---|---|---|
| PR #59 | オフライン起動タイムアウト(main.dart) | ❌ 含まれない |
| PR #53 | プレミアムシーンロック解除(revenuecat_service.dart/chat_screen.dart) | ❌ 含まれない |
| PR #40 | AI同意画面オーバーフロー対策(ai_data_consent_screen.dart) | ❌ 含まれない |

つまり「Androidで修正済みの不具合がiOSでも有効か未検証」という以前に、**Build 17には
これら3件の修正コード自体が存在しない**。以下、それぞれの実際の挙動をコードから追跡する。

---

## 1. main.dart 起動シーケンス — オフライン時にどこで停止するか

### Build 17(`0c790cf`)時点のコード構造

`main()`は完全に逐次(sequential)実行で、並列化・タイムアウトのいずれも無い。
関係する外部呼び出しをコード順に列挙する(すべて`await`されており、いずれも
タイムアウト設定なし):

1. `LocalNotificationService().initialize()` — ローカル処理主体(通知権限ダイアログ含む)。ネットワーク依存は薄い
2. `NotificationScheduler().initialize()` / `.scheduleDailyReminders()` — ローカルスケジューリング
3. `RemoteNotificationService().initialize()` → 内部で`_refreshFCMToken()`が`_fcm.getToken()`を呼ぶ。**タイムアウト無し**(`_kFcmCallTimeout`はHEADで新設された定数で、Build 17には存在しない)
4. `remoteNotificationService.subscribeToDefaultTopics()` → `_fcm.subscribeToTopic()`を複数回呼ぶ。**タイムアウト無し**。トピック購読はFCMサーバーとの実際の通信を要するため、オフライン時に最も詰まりやすい箇所の一つ
5. 上記3〜4は1つの`try/catch`で囲まれているが、**`await`が例外を投げずに単に応答が返らない(ハングする)場合、catchには到達しない**。タイムアウトが無い限り、この`try`ブロックの内部で永久に停止しうる
6. `revenueCatService.initialize()` → 内部で`Purchases.configure()`を呼ぶ。**タイムアウト無し**(`_kRevenueCatCallTimeout`もHEADで新設)
7. `revenueCatService.checkPremiumStatus()` → `Purchases.getCustomerInfo()`。**タイムアウト無し**
8. `Supabase.initialize()` → **タイムアウト無し**
9. `auth.signInAnonymously()`(キャッシュ済みセッションが無い場合)→ **タイムアウト無し**。明確にネットワーク呼び出し
10. (Supabase初期化成功時のみ)`revenueCatService.loginWithUserId(userId)` → RevenueCat側との通信。**タイムアウト無し**
11. すべて完了後に初めて`runApp(const VoikerchatApp())`

HEAD(PR #59)で追加された`_kInitTimeout`(8秒)・`_kFcmCallTimeout`(8秒)・
`_kRevenueCatCallTimeout`(8秒)という3つの定数は、`0c790cf..HEAD`の差分で**新規追加**
されたものであり、Build 17のコードにはこれらのタイムアウトが一つも存在しない
(`git diff 0c790cf..HEAD -- lib/main.dart lib/services/remote_notification_service.dart
lib/services/revenuecat_service.dart`で確認)。

### 結論(この項目)

オフライン時、上記1〜10のうち最初にネットワークI/Oを試みた箇所で無期限に停止する。
どの呼び出しが実際に最初にハングするか(FCMトークン取得は端末ローカルでも解決できる
実装がある場合があり、SDKバージョン依存)は静的読解だけでは断定できないが、
**4番(FCMトピック購読)・6〜7番(RevenueCat)・9番(Supabase匿名サインイン)の
いずれもタイムアウトが無く、これらは実装上ほぼ確実にネットワーク往復を要する**。
したがって「機内モードで起動すると白画面のまま進まない」という、PR #59が修正した
不具合と同一の症状が、Build 17でも確実に再現する。これは推測ではなく、
PR #59で追加されたタイムアウト機構がBuild 17に一切存在しないという事実からの
論理的帰結である。

---

## 2. revenuecat_service.dart / chat_screen.dart — StoreKit経由でも同じコードパスを通るか

### PR #53が追加したコードの中身

`purchasePremium()`のcatchブロックに、以下の分岐が追加されている(HEAD、Build 17には無し):

```dart
if (e is PlatformException &&
    PurchasesErrorHelper.getErrorCode(e) ==
        PurchasesErrorCode.productAlreadyPurchasedError) {
  final alreadyActive = await _confirmActiveEntitlement();
  if (alreadyActive) {
    return {'success': true, 'message': 'Welcome to Voikerchat Premium!'};
  }
}
```

`PurchasesErrorCode`は`purchases_flutter`(RevenueCat SDK)が提供する**プラットフォーム
非依存の統一エラーコード enum**であり、コード上に`Platform.isAndroid`/`Platform.isIOS`
のような分岐は存在しない(`git diff 0c790cf..HEAD -- lib/ | grep "Platform\.is"`で
lib/配下全体を検索したが1件もヒットしなかった)。`chat_screen.dart`側の
`widget.onPremiumUnlocked?.call()`によるシーン選択画面への状態伝播も同様に
プラットフォーム分岐の無い純粋なDartコールバックである。

### コードから確認できること/できないこと

**確認できること**: 修正コード自体はAndroid固有の実装ではなく、RevenueCat SDKの
共通抽象レイヤー(`PurchasesErrorCode`)を使っている。したがって「コードの構造上」は
iOS(StoreKit経由)でも同じ分岐に到達する設計になっている。

**確認できないこと**: 以下はコード読解だけでは判断できず、実機/Sandbox検証が必要:
- iOSのStoreKit購入フローが、Androidの`ITEM_ALREADY_OWNED`と同じ状況で実際に
  `PurchasesErrorCode.productAlreadyPurchasedError`を送出するか(RevenueCat SDK内部の
  プラットフォーム別実装に依存し、リポジトリ内のコードからは見えない)
- iOSのentitlement反映タイミング(StoreKitのトランザクション確定・レシート検証は
  Google Play Billingと非同期の性質が異なる可能性がある)が、`_confirmActiveEntitlement()`
  の即時呼び出しで正しく`active`を返すかどうか
- そもそもBuild 17は**このコード自体を含んでいない**ため、iOSで一度も動作した実績がない

### 結論(この項目)

「Androidで検証できたのはAndroidの経路のみ」という未完了項目12の指摘は妥当。
加えて、Build 17はこの修正コードを一切含まないため、Build 17をそのまま公開すると
未完了項目9で発見・修正した「プレミアムシーンのロック解除バグ」の**原因コードが
iOS側にそのまま残る**(Androidで発生したのと同じ再現条件が揃えば、iOSでも同じ
バグが起きうる)。「iOSでも直っているか未検証」ではなく「iOSは直っていないコードの
ままである」という、より確度の高いリスクとして扱うべき。

---

## 3. ai_data_consent_screen.dart — iPad Air 11-inchでのオーバーフロー

### Build 17時点のレイアウト

```dart
child: Padding(
  padding: const EdgeInsets.all(24),
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [ /* アイコン・本文・リンク・同意/非同意ボタン */ ],
  ),
),
```

`SingleChildScrollView`によるラップ・`bottomNavigationBar`への固定フッター分離は
**Build 17に存在しない**(PR #40はBuild 17の後にマージ)。つまりBuild 17は、
STATE.mdの「技術的負債」節に記録されている**修正前の状態そのもの**である。

### 高さの見積もり

`test/screens/ai_data_consent_screen_test.dart`(HEAD)のオーバーフロー再現テストは
`physicalSize = Size(360, 640)`(360×640論理ピクセル、devicePixelRatio 1.0)という
**小型スマートフォン相当**の画面サイズを前提にしている。これに対しiPad Air
11-inch(M3)は論理解像度が縦向きでおよそ820×1180pt(公称値、Apple公表の
ポイント解像度に基づく概算)であり、テストが再現している640ptよりも**縦方向に
約1.8倍以上の余白がある**。

本文(アイコン48px+タイトル+説明文+2つのリンクボタン+同意/非同意の2ボタン)の
総高さは、フォントスケール1.0倍であれば640pt以内に収まる設計であることが上記
テストで確認されている。したがって同じコンテンツをiPad Air 11-inch(縦向き、
標準フォントスケール)で表示した場合、**オーバーフローする可能性は低い**。

さらに、Build 17はこの画面を含んだ状態で2026-08-06に実際にiPad Air 11-inch M3
実機を使ったApple審査に合格している(2回目リジェクトの理由はマイク権限ダイアログの
Cancelボタンとデータ開示不足であり、レイアウト起因のリジェクトではなかった。
`DECISIONS.md` 2026-08-03参照)。これは「審査時の標準的な条件下ではオーバーフローが
発生しなかった」ことの状況証拠になる。

### 結論(この項目)

iPad Air 11-inchでの標準的な条件下でのオーバーフローリスクは**低い**と判断する。
ただし、Dynamic Type(iOS側のアクセシビリティ大文字設定)を最大まで上げた場合の
挙動はコード上確認できず、Android側でPR #40のきっかけとなった「フォントサイズ最大」
条件と同種のリスクは残る。この点はSTATE.mdに既存の「技術的負債」記載
(「iPad Air 11-inch(iOS)での確認はまだ実施していない」)の範囲内であり、
本調査で新たに悪化した評価ではない。

---

## 4. サーバー側(api/)変更との互換性 — 無料枠5→10(commit `64ef08b`)

### クライアント側の値の解決順序

`lib/models/rate_limit.dart`(Build 17時点から変更なし):

```dart
dailyLimit: json['daily_limit'] as int? ?? RateLimitConstants.freeDailyLimit,
```

サーバーAPI(`api/chat.ts`・`api/rate-limit.ts`)のレスポンス、または
Supabase `rate_limits`テーブルの行を直接読む場合のいずれも、`daily_limit`列は
**既存ユーザーであれば必ず値を持つ**(NULL不可のスキーマ)。よって`??`の右辺
(`RateLimitConstants.freeDailyLimit`、Build 17では`5`、HEADでは`10`)が使われるのは、
サーバー側に該当ユーザーのレコードが**まだ存在しない**特殊なケースに限られる。

このケースが実際に発生するのは`lib/services/rate_limit_service.dart`の
`getRateLimit()`が`rate_limits`テーブルへの`.select().single()`が失敗した場合の
catchフォールバックのみ(初回起動でまだ一度も`api/chat.ts`を呼んでいない新規ユーザー)。

### 結論(この項目)

**通常利用のユーザーには問題が起きない**: 既存ユーザー・一度でもチャットを送信した
ユーザーは、サーバー(現在`FREE_DAILY_LIMIT=10`)から返る`daily_limit`をそのまま
表示に使うため、Build 17のクライアントであっても「残り10回」等の表示は正しく行われる。
`api/chat.ts`・`api/define.ts`等のサーバー側変更(cache tokenのログ記録追加、
furigana精度改善、define.tsの`mode: 'sentence'`新設等)もいずれも**追加的
(additive)な変更**であり、Build 17クライアントが送らないフィールド・呼ばないモードは
単に使われないだけで、既存のリクエスト/レスポンス形状を壊す変更は無い
(`git diff 0c790cf..HEAD -- api/chat.ts api/define.ts`で確認)。

**軽微な既知の齟齬**: ごく短時間だけ存在する「初回起動でまだ一度もAPIを呼んでいない
新規ユーザーが、何らかの理由でSupabaseへの直接SELECTに失敗した」場合のみ、Build 17の
ローカル定数(`freeDailyLimit=5`)がフォールバックとして使われ、実際の10と食い違って
一瞬「残り5回」と表示されうる。ただしこれは初回のAPI呼び出し(初回メッセージ送信)で
即座に正しい値へ上書きされる、表示上の一過性の問題であり、機能停止や誤動作には
つながらない。

---

## 総合評価と見立て

| 項目 | Build 17をそのまま公開した場合のリスク |
|---|---|
| オフライン起動時の白画面 | 🔴 **高**。修正コードが一切無く、症状は確実に再現する |
| プレミアムシーンのロック解除バグ | 🔴 **高**。修正コードが一切無く、iOSでStoreKit購入時に同一条件が揃えば再現しうる。「未検証」ではなく「未修正のまま」 |
| AI同意画面のオーバーフロー(iPad) | 🟡 **低**。iPad Air 11-inch標準条件では審査通過実績がありオーバーフローの可能性は低いが、大文字アクセシビリティ設定は未検証のまま(既知の残課題と同水準) |
| 無料枠5→10とのサーバー互換性 | 🟢 **なし**。サーバー値を正として表示するため実害はない。新規ユーザーの一瞬の表示不整合のみ |

**見立て: +18(現在のmain相当)で再提出すべき**。

根拠は「Androidで直した不具合がiOSで動くか未検証だから慎重に」という消極的な理由
ではなく、**Build 17には対象3件の修正コードそのものが存在しない**という、より
明確な事実に基づく。特にオフライン白画面(App Store Guideline 2.1 Performance抵触の
懸念がSTATE.mdに既に記録されている)とプレミアムシーンロック解除バグ(実際の
課金者に直接影響する不具合)の2件は、いずれも「公開後に実ユーザーが確実に踏みうる」
既知の不具合であり、既に修正コードがmainに存在するにもかかわらずBuild 17で
あえて未修正のまま公開する合理的理由が見当たらない。

再提出のコストは、未完了項目13で既に整理されている通り「Androidの完走を待つ場合、
どのみち審査期間(通常7日以内)がボトルネックになる」ため、Build 17ではなく
mainベースの新ビルドで再提出しても、審査回数が1回増える(約7日以内)以外の
追加コストは無い。iOS Sandbox課金検証(未完了項目12、公開前必須)を行うのであれば、
検証対象は「これから公開するビルド」であるべきで、その意味でもmainベースの
新ビルドでの検証・提出が筋が通っている。

## 未確認・要実機検証事項(本調査の限界)

- iOS StoreKitが`ITEM_ALREADY_OWNED`相当の状況で実際に`productAlreadyPurchasedError`を
  返すか(RevenueCat SDK内部実装、コードからは不可視)
- Dynamic Type最大設定でのai_data_consent_screen.dartのレイアウト(iPad実機)
- FCMトークン取得(`_refreshFCMToken`)がオフライン時に即座に失敗するのか、
  内部で無期限に待つのかは、Firebase SDKの挙動次第でありコード読解だけでは断定不可
- いずれも未完了項目12(iOS Sandbox課金検証)・項目13(iOS公開)の実機検証で
  確認されるべき事項であり、本書はその前段の判断材料に位置づける
