# Premiumシーンロック解除不具合の調査(2026-08-05)

PR #53(fix/premium-scene-unlock-refresh)着手前に実施した調査記録。
Step 2(コード修正)自体はPR #53に実装済み・push済み・**未マージ**。
実機検証(3パターン)を経てからマージ判断する。詳細は
`shibuyer-ops/memory/handoff_20260805_pm.md`参照。

## 現象

実機確認(Xiaomi、ライセンステスター購入) [確認済 2026-08-05]:

| 特典 | 購入直後の反映 |
|---|---|
| 日次上限50 | 即時反映 |
| 広告非表示 | 即時反映 |
| 統計ダッシュボード | 即時反映 |
| アニメシーンのロック解除 | **反映されない**(アプリ再起動が必要) |

ロックされたシーンをタップするとPaywallに遷移し、購入を試みると
「既に購入しています」と表示される(その場では解除されない)。

## Step 1: 原因調査

### 1. シーン選択画面のPremium判定値の取得元とタイミング

`SceneSelectionScreen`(`lib/screens/scene_selection_screen.dart`)は
`isPremiumUser`をコンストラクタ引数として受け取るだけの`StatelessWidget`。
実体は`HomeScreen`が保持する状態。

`lib/screens/home_screen.dart:36-42`
```dart
late bool _isPremiumUser = widget.isPremiumUser;

@override
void initState() {
  super.initState();
  _refreshPremiumStatus();
}
```
`lib/screens/home_screen.dart:46-50`
```dart
Future<void> _refreshPremiumStatus() async {
  final isPremium = await RevenueCatService().checkPremiumStatus();
  if (!mounted) return;
  setState(() => _isPremiumUser = isPremium);
}
```
「都度参照」ではなく「`initState`で一度読み、以降は明示的なコールバック
経由でしか更新されないキャッシュ値」。更新契機は`initState`(起動時1回)と、
`SceneSelectionScreen`に渡す`onPremiumUnlocked`コールバックの2つのみ。

### 2. 日次上限・広告非表示・統計ダッシュボードが即座に反映される理由

これらはいずれも**サーバー側`rate_limits`テーブル(Supabase)の値**、
または**画面を開くたびにサーバーへ問い合わせ直す**設計であり、
RevenueCat SDKのクライアントキャッシュとは別経路。

- **日次上限/広告非表示**: `chat_screen.dart`の`RateLimitWidget`は
  `_rateLimit`(`RateLimitService.getRateLimit()`が`rate_limits`テーブルを
  直接SELECTして得る)を参照する。`_loadRateLimit()`はメッセージ送信のたびに
  再取得される。購入完了はRevenueCatのWebhook(`api/revenuecat-webhook.ts`)
  経由で数秒以内に`rate_limits.is_premium`/`daily_limit`をサーバー側で
  更新するため、次にメッセージを送った瞬間に新しい値を拾う。
- **統計ダッシュボード**: `StatsScreen`(`lib/screens/stats_screen.dart`)は
  クライアント側でPremium判定を一切保持していない。`_loadStats()`が
  `GET /api/analytics?token=...`を呼び、サーバー側(`api/analytics.ts:57-65`、
  `rate_limits.is_premium`参照)で判定した結果(403 = 要Premium)を返す。
  `HomeScreen._tabs`はタブ切替のたびに新しい`StatsScreen()`インスタンスを
  生成する(遅延マウント方式)ため、タブを開くたびに`initState`→`_loadStats()`
  が毎回サーバーへ問い合わせ直し、キャッシュの概念自体が無い。

一方シーンロックは1.の`HomeScreen._isPremiumUser`(RevenueCat SDKの
クライアントキャッシュ)にのみ依存しており、サーバーの`rate_limits`が
更新されても、明示的なコールバックが発火しない限り一切再取得されない。
これが根本原因。

### 3. Paywallへの導線・復帰導線の洗い出し

`PaywallScreen(`の呼び出し箇所は全部で2箇所(`grep`で確認、他に無し):

**(A) `lib/screens/scene_selection_screen.dart:57-60`**(ロック済みシーンタップ)
```dart
Future<void> _openPaywall(BuildContext context) async {
  final unlocked = await Navigator.push<bool>(
    context,
    MaterialPageRoute(builder: (_) => const PaywallScreen()),
  );
  if (unlocked == true) {
    onPremiumUnlocked?.call();
  }
}
```
→ 既に正しく`await`+コールバック連携済み(修正不要)。

**(B) `lib/screens/chat_screen.dart:1238-1247`**(レート制限到達ダイアログ・
段階的アップセルバナー等、チャット画面内の6箇所から呼ばれる共通ハンドラ)
```dart
Future<void> _openPaywall() async {
  final unlocked = await Navigator.push<bool>(
    context,
    MaterialPageRoute(builder: (_) => const PaywallScreen()),
  );
  if (unlocked == true && mounted) {
    setState(() => _isPremium = true);
    _showSuccess(AppLocalizations.of(context).welcomePremium);
  }
}
```
→ `ChatScreen`自身のローカル`_isPremium`しか更新せず、`HomeScreen`/
`SceneSelectionScreen`への還元経路が存在しなかった(修正対象)。

**もう一つの独立した根本原因**: `lib/services/revenuecat_service.dart`の
`purchasePremium()`のエラー分類には、Google Playの`ITEM_ALREADY_OWNED`/
`ProductAlreadyPurchasedError`を判定する分岐が無く、汎用の`unknown_error`
(`retryable: true`)として扱われていた。結果、(A)の正しい経路を通っても
`Navigator.pop(context, true)`が呼ばれず、**既に購入済みのユーザーが
再度ロック済みシーンをタップした場合、正しい経路(A)ですら
`onPremiumUnlocked`が発火しない**(報告の「既に購入しています」表示後も
ロックが解除されないケースの直接原因)。

### 4. PR #52パターン(await化+コールバック再読込)の適用可否

(A)には既に同型のパターンが実装済み。(B)には未適用であり、`ChatScreen`が
呼び出し元へ購入成功を伝える手段が無かった。

## 追加調査: アプリ全体のPremium判定箇所の分類

統計ダッシュボードの即時反映を踏まえ、Premium判定を行う全箇所を
以下に分類した。

### (a) サーバー側 rate_limits を参照 → 即時反映
| 箇所 | 内容 |
|---|---|
| `api/analytics.ts:57-65` | 統計ダッシュボードの403判定 |
| `api/chat.ts`/`api/hint.ts`/`api/define.ts`/`api/recap.ts`/`api/vocab-summary.ts` | 各APIの`rate_limits.is_premium`参照 |
| `lib/services/rate_limit_service.dart`(`RateLimitService.getRateLimit`) | 日次上限表示・広告視聴ボタンの出し分け。`_loadRateLimit()`はメッセージ送信ごとに再取得 |

### (b) RevenueCatクライアントキャッシュを参照 → 遅延しうる
| 箇所 | ローカル変数 | 更新契機 | 症状 |
|---|---|---|---|
| `home_screen.dart:37,46-51` | `_isPremiumUser` | `initState`時、または`onPremiumUnlocked`コールバック | **シーンロック解除(本件バグ)** |
| `chat_screen.dart:107,176,192-194` | `_isPremium` | `initState`時、または自身の`_openPaywall`成功時 | 学習統計ショートカットアイコンの表示切替、高品質ボイス解放表示、段階的アップセルの表示抑制 |

`chat_screen.dart`側は実害が限定的と判断: 同画面内の購入は自分自身の
`_isPremium`を即座に更新するため自己完結している。他画面経由で購入した
場合も、新規に開く`ChatScreen`インスタンスは`initState`で毎回フレッシュに
`checkPremiumStatus()`を実行するため、次に開くチャット画面では正しく
反映される。ズレが残るのは「購入前から開きっぱなしの同一`ChatScreen`
インスタンスに、別画面経由の購入結果を反映する」という稀なケースのみで、
通常の遷移導線では発生しない。**今回まとめて対応が必要なのは
シーンロックのみと判断し、追加対応はしていない。**

### (c) その他(UIのPremiumゲートではない)
| 箇所 | 内容 |
|---|---|
| `main.dart:150,197` | 起動時のプッシュ通知トピック購読同期。ユーザー可視のUI要素ではなく実害なし |
| `lib/models/rate_limit.dart:34,43` | (a)のデータをデシリアライズするモデル定義 |

## Step 2: 実装内容(PR #53、未マージ)

承認済み方針3点をそのまま実装。

1. `revenuecat_service.dart`: `purchasePremium()`に`PlatformException`の
   エラーコード(`PurchasesErrorHelper.getErrorCode`)で
   `PurchasesErrorCode.productAlreadyPurchasedError`を検出する分岐を追加。
   ただしエラー文言だけで判断せず、`Purchases.getCustomerInfo()`で
   実際にentitlementがactiveであることを確認してから`success: true`
   として扱う(`_confirmActiveEntitlement()`新設)。
2. `chat_screen.dart`に`onPremiumUnlocked`コールバックを追加し、
   `scene_selection_screen.dart`(既存の`onPremiumUnlocked`)経由で
   `home_screen.dart`まで貫通させた。
3. (A) `scene_selection_screen.dart`の既存経路は無変更。

## 未検証・要実機確認(マージ判断前に必須)

1. シーン一覧からロック済みシーンをタップ → 購入 → 戻ると開放
2. チャット画面から購入 → シーン一覧に戻ると開放
3. 既に購入済みの状態でロック済みシーンをタップ → 「既に購入しています」
   → その場で開放(**2026-08-05に実機で再現した症状そのもの、最重要**)

検証には購入済み状態のリセットが必要(アプリのデータ消去、または
Google Playでテスト定期購入を解約)。

## [未確認]まとめ
- 上記3パターンの実機検証結果(明日以降実施)
- `_confirmActiveEntitlement()`が実際にRevenueCat側の遅延・キャッシュ
  なしで正しくentitlementを返すか(理論上は`Purchases.getCustomerInfo()`
  がネットワーク問い合わせを行うため妥当なはずだが、実機未検証)
