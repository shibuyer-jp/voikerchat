# Voikerchat 引き継ぎ — 2026-06-30（バッジ完了 / AdMob基盤完了）

リポジトリ: `shibuyer-jp/voikerchat`（main直push・Vercel自動デプロイ）
CI: 全チェック緑で本スレ終了。最新コミット `d6812a8`。

## 1. 本スレの達成

### A. CI修復（commit `a54265e`）
- `DiagnosticTestScreenEnhanced` が `Scaffold` を返しておらず「No Material widget found」実行時例外＋フレーキー widget_test の原因だった。両 build 分岐を `Scaffold` で包んで解消。実機クラッシュも同時に修正。

### B. バッジ/ゲーミフィケーション（commits `a7a36e3` + `a304435`）
- `lib/models/badge.dart`: バッジ定義の正本。9種・4条件タイプ（会話数 / 基本シーン / アニメシーン / 連続日数）。
- `lib/services/badge_service.dart`: セッション＋SharedPreferences から実績集計・解除判定・永続化。**一度獲得したら取り消さない**。
- `lib/screens/badges_screen.dart`: グリッドUI（未解除=進捗バー、解除済=獲得日）、新規解除はSnackBar。**無料ユーザーも閲覧可**（統計タブと違いプレミアム非依存）。
- `lib/screens/home_screen.dart`: 「バッジ」タブ追加（4タブ構成）。
- バッジ一覧: 始まりの一歩(1)/おしゃべり(10)/会話マスター(50)/基本制覇(基本8シーン)/アニメの世界へ(1)/アニメマスター(5)/三日坊主卒業(3日)/習慣化(7日)/不屈の継続(30日)。

### C. AdMob 基盤（commit `d6812a8`）
- `pubspec.yaml`: `google_mobile_ads ^8.0.0`（最新を2026-06-30に確認）。
- Android: `minSdk 23`（GMA要件）＋ `AndroidManifest.xml` にアプリIDメタデータ（テスト用）。
- iOS: `Info.plist` に `GADApplicationIdentifier`（テスト用）。
- `main.dart`: `MobileAds.instance.initialize()` を早期実行。**Webは条件付きimportのstub（`lib/stubs/mobile_ads_stub.dart`）でno-op**。
- `lib/services/ad_config.dart`: リワード広告IDを集約。**本番化は `useTestAds=false` ＋ `_prod*` への実ID設定の1か所のみ**。
- `RateLimitService.grantAdBonus(userId)`: 広告報酬で当日上限を +5（最大10）。

## 2. 確定した決定
- バッジ解除状態は SharedPreferences が真実の源。取り消さない。無料ユーザーも閲覧可。
- AdMob: 現状テスト広告ID。実IDへの差し替え点は `AdConfig`（`useTestAds` ＋ `_prod*`）に集約。`minSdk 23`。Webはstubでno-op。
- リワード報酬 = 当日上限 +5（最大10）= `RateLimitService.grantAdBonus`。
- **AdMob登録・実ID設定は次スレで実施**（本スレでは未着手）。

### 使用中のテスト用ID（差し替え対象）
- アプリID: Android `ca-app-pub-3940256099942544~3347511713` / iOS `ca-app-pub-3940256099942544~1458002511`
- リワード広告ユニット: Android `ca-app-pub-3940256099942544/5224354917` / iOS `ca-app-pub-3940256099942544/1712485313`

## 3. 次タスク（優先順）
1. **AdMob ②（表示＋UI配線）**: `RewardedAdService`（load/show、Web安全に。`AdConfig.rewardedUnitId` 使用）。「広告を見て+5」ボタンをレート制限UI（`rate_limit_widget` / チャット上限到達時）に配線 → 視聴完了 → `grantAdBonus` → 残数更新。
2. **AdMob 登録・本番化（手続き：Takatoh側）**: admob.google.com 登録（銀行/税務/住所、審査）→ Android用・iOS用アプリを各1つ作成（アプリID取得）→ 各アプリで「リワード」広告ユニット作成（広告ユニットID取得）→ 実IDを `AdConfig`・`AndroidManifest.xml`・`Info.plist` に反映、`useTestAds=false`。実配信はストア掲載＋`app-ads.txt`公開＋審査が必要。
3. **多言語ARB**（残バックログ）。
4. **T-21 手動ブロッカー**: APNsキー（`AuthKey_26PUZTM353.p8` / Key ID `26PUZTM353` / Team ID `S6XJP274T2`）を Firebase Console にアップロード → トピック `all_users` 宛にテスト送信。
5. 任意: APIベースURLの `--dart-define` 化、`.gitignore` 整理。

## 4. インフラ／運用メモ
- Supabase `rfwbwwhqclabhnbsrygw`（Tokyo）/ Vercel `voikerchat-x621`。
- 本番AI: Claude Haiku `claude-haiku-4-5-20251001`（安定運用継続）。
- CI `flutter-ci.yml`「Analyze & Test」= `dart format`（continue-on-error）＋ `flutter analyze`（致命的）＋ `flutter test`。別ジョブで Android debug ビルド。
- **CIログ取得の注意**: 失敗時の生ログはAzure blob（`productionresultssa6.blob.core.windows.net`、egress許可外）で直接取得不可。analyze詳細は (a) GitHubアノテーションAPI、または (b) 一時ブランチで `flutter analyze` を `::error::` に出力 → アノテーションAPIから取得、で確認できる。
- 旧 `lib/screens/onboarding/diagnostic_test_screen.dart`（基本版）はどこからも未参照の孤立ファイル（残置で問題なし／将来削除可）。
