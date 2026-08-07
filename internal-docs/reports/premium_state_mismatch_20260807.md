# Premium判定の不整合調査(2026-08-07)

## 再現手順

検証環境: iPhone 16 / iOS 26.5.2、TestFlight配信の1.0.0+17→1.0.0+19
[検証日 2026-08-07]

1. 1.0.0+17でPremium定期購入を実施する
2. アプリを端末から削除する(アンインストール)
3. TestFlightから1.0.0+19を新規インストールする(=新しい匿名Supabase
   user_idが発行される)
4. アプリを起動し、ホーム画面・チャット画面を確認する

**期待される結果**: Premium状態が復元され、シーン・上限・広告表示の
すべてが一貫してPremium扱いになる

**実際の結果(同一アプリ内でPremium判定が食い違った)**:
- Premiumシーン(アニメシーン)はロック解除されアクセス可能
- 1日のメッセージ上限は無料枠の「10/10」表示
- 広告視聴の案内が表示される(Premiumなら非表示のはず)

## 発見経緯

上記の再現手順により、実機検証中に偶然発見した。

## 1. シーンロック判定 — RevenueCat(クライアント)のみを参照

`lib/screens/home_screen.dart:37,48-52`が唯一の真実の源:

```dart
late bool _isPremiumUser = widget.isPremiumUser;
...
Future<void> _refreshPremiumStatus() async {
  final isPremium = await RevenueCatService().checkPremiumStatus();
  if (!mounted) return;
  setState(() => _isPremiumUser = isPremium);
}
```

`lib/services/revenuecat_service.dart:112-132`の`checkPremiumStatus()`は
`Purchases.getCustomerInfo()`(RevenueCatクライアントSDK/Apple StoreKit
レシート)のみを参照する。**Supabaseは一切参照しない**。

## 2. 日次上限表示・広告案内 — Supabase `rate_limits.is_premium`のみを参照

**(a) 「10/10」表示**: `lib/widgets/rate_limit_widget.dart:38-41,53` ←
`lib/screens/chat_screen.dart:342-350`(`_loadRateLimit()`) ←
`lib/services/rate_limit_service.dart:19-38`(`rate_limits`テーブルへの
**直接SELECT**。クライアントは`api/rate-limit.ts`を一度も呼んでいない
ことを`lib/`全体のgrepで確認済み)。

**(b) 広告視聴ボタンの表示条件**(今回の症状の直接原因):
`lib/screens/chat_screen.dart:1035-1046`
```dart
showWatchAdButton: _rewardedAdService.isSupported &&
    _rateLimit != null &&
    !_rateLimit!.isPremium &&   // ← Supabase rate_limits.is_premium
    !_cloudTtsUnlockedToday,
```

`chat_screen.dart`はRevenueCat側の`_isPremium`とSupabase側の
`_rateLimit!.isPremium`の**両方**を保持し、機能ごとに参照先が異なる
(アップセルバナー・統計アイコンはRevenueCat側、広告ボタン・
「Go Premium」リンクはSupabase側)。この2つが食い違うと今回のような
矛盾したUIになる。

## 3. 別ソース、かつ一方向にしか同期しない

| 機能 | 参照元 |
|---|---|
| シーンロック | RevenueCat `CustomerInfo`(クライアント) |
| 日次上限表示 | Supabase `rate_limits.daily_limit` |
| 広告視聴ボタン | Supabase `rate_limits.is_premium` |
| メッセージ送信のクォータ強制(実効) | Supabase `rate_limits.is_premium`(`api/chat.ts:81-93`) |
| 統計画面の403ゲート | Supabase `rate_limits.is_premium`(`api/analytics.ts:57-65`) |

`grep -rn "is_premium" lib/`は`lib/models/rate_limit.dart`の
デシリアライズ箇所のみがヒットし、**Flutter側から`is_premium`を
書き込むコードは一切存在しない**。書き込めるのは:
- `api/revenuecat-webhook.ts`(唯一の`true`書き込み元)
- `api/chat.ts:205-211`(行が無い場合に作成。値は直前に読んだ`isPremium`
  = 通常`false`)

の2箇所のみ。つまり一度`is_premium=false`の行が作られると、それを
`true`に戻せるのはwebhookのGRANTイベントだけになる。

## 4. 再インストール時の根本原因チェーン

1. **アプリ削除→再インストールで新しい匿名Supabase user_idが発行される**
   (`lib/main.dart`、匿名認証のみのため。DECISIONS.md 2026-07-29参照)
2. `lib/main.dart:271-277`が`revenueCat.loginWithUserId(userId_new)`を
   呼ぶ → `revenuecat_service.dart:98-109`
   ```dart
   await Purchases.logIn(supabaseUserId);
   await Purchases.restorePurchases();
   ```
   `restorePurchases()`は端末上のApp Store(Android版ならGoogle Play)
   レシートを再検証し、**Apple ID/Googleアカウントに紐づく購読**を
   `user_id_new`へ即座に紐付ける。これは`runApp()`より前に完了するため、
   `HomeScreen`初期表示時点で`checkPremiumStatus()`は`true`を返す
   → **シーンロックが即解除される**(症状1)
3. しかし`api/revenuecat-webhook.ts:18-29`の`GRANT_EVENT_TYPES`
   (`INITIAL_PURCHASE`/`RENEWAL`/`UNCANCELLATION`/`REFUND_REVERSED`/
   `SUBSCRIPTION_EXTENDED`)のいずれも、既存購読を新しい`app_user_id`へ
   再紐付けする`restorePurchases()`/`logIn()`単体では発火しない。
   `TRANSFER`イベントは**明示的にno-op**(`revenuecat-webhook.ts:88-93`
   のコメント参照)。よって`user_id_new`に対する`rate_limits`行は
   一度も作られない
4. 初回メッセージ送信で`api/chat.ts:81-93`が`user_id_new`の`is_premium`
   を検索するが行が無く`false`のまま。`api/chat.ts:200-216`が
   `is_premium: false, daily_limit: 10`で行を新規作成する
5. `rate_limit_service.dart`・`rate_limit_widget.dart`・`chat_screen.dart`
   がこの行をそのまま表示 → **日次上限「10/10」・広告案内が表示される**
   (症状2・3)
6. **自己修復するのは次回の月次`RENEWAL`イベント時のみ**(最大約30日後)。
   Paywall画面の`restorePurchases()`(`paywall_screen.dart:147`)も
   クライアント側の状態しか更新せず、サーバー側は直さない

## 5. Android での再現性

シーンロック判定(`home_screen.dart`)・レート制限判定
(`rate_limit_service.dart`・`chat_screen.dart`)・webhook処理
(`revenuecat-webhook.ts`)のいずれにも`Platform.isIOS`/`Platform.isAndroid`
分岐は存在しない(`revenuecat_service.dart:47-50`のAPIキー選択のみが
唯一のプラットフォーム分岐で、判定ロジック自体には無関係)。
RevenueCatの`restorePurchases()`はAndroidでもGoogle Playアカウントに
紐づくレシートを同様に再検証する仕組みのため、**同一の再インストール
シナリオはAndroidでも構造的に再現する**と判断する(実機未検証)。

## 6. 既存ドキュメントの記載を訂正

以下の記載はクライアント層のみを見た評価であり、サーバー側`rate_limits`
への影響を見落としていたため誤り。本レポートを機に訂正した
(該当ファイル参照):

- `DECISIONS.md`(2026-07-29、RevenueCat Android有効化に関する決定):
  「同一端末の再インストールは`restorePurchases()`がストアアカウントから
  復元するため実害なし」→ **クライアント層(シーンロック)は復元されるが、
  サーバー側`rate_limits.is_premium`は復元されず、次回のRENEWALまで
  最大30日間無料枠のまま取り残される**
- `STATE.md`(バックログ「クロスプラットフォーム課金引き継ぎ」)の同趣旨の記載も同様に訂正

`internal-docs/reports/premium_unlock_investigation_20260805.md`
(PR #53の調査記録)が構築した(a)サーバー即時/(b)クライアントキャッシュの
分類は、**サーバーが先・クライアントが遅れる方向**のみを検証しており、
今回の**クライアントが先・サーバーが永久に取り残される方向**は
検討対象に含まれていなかった。

## 修正内容

方針: webhookのTRANSFER対応(`restorePurchases()`を捕捉できないため
不採用)ではなく、**ログイン後のサーバー側再照合エンドポイント**を新設。

- `api/premium-sync.ts`(新規): クライアントは「同期が必要そうか」の
  判断のみ行い(RevenueCat=Premium かつ Supabase側=false の場合のみ
  リクエスト)、サーバー側は自己申告を一切信用せず**RevenueCat REST API
  (`GET /v1/subscribers/{app_user_id}`)に直接問い合わせて実際に
  activeなentitlementが存在することを検証**してから`rate_limits`を
  更新する。`REVENUECAT_SECRET_KEY`はサーバー環境変数のみで保持し、
  クライアントには一切渡さない
- `api/_premium.ts`(新規): `upsertPremiumStatus()`を
  `revenuecat-webhook.ts`と共有するヘルパーとして抽出
- レート制限: `api/recap.ts`と同方式(`usage_logs`の当日件数カウント)。
  `usage_logs.event`に`'premium_sync'`を追加するマイグレーションが必要
  (`internal-docs/migrations/2026-08-07_add_usage_logs_premium_sync_event.sql`)
- クライアント: `lib/services/premium_sync_service.dart`(新規)+
  `lib/main.dart`の`loginWithUserId()`成功後に`_reconcilePremiumStatus()`
  を追加(fire-and-forget、UI表示をブロックしない)
- プラットフォーム共通の実装(Flutter/api層とも分岐なし)のため、
  iOS/Android両方に同一の修正が効く

## 未確認・要人手対応

- マイグレーションSQL(上記)をSupabase SQL Editorで実行すること
- `REVENUECAT_SECRET_KEY`をVercel環境変数へ追加すること(RevenueCat
  ダッシュボード「API keys → Secret keys」から発行。公開SDKキーとは別物)
- RevenueCat REST APIのエンドポイント(`/v1/subscribers/{id}`)が
  現行でも有効か、RevenueCat公式ドキュメントで実装後に確認すること
  (v2 API への移行が進んでいる可能性)
- Android実機での再現検証は未実施(コード上の構造分析による推定)
