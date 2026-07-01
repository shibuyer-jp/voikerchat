# CLAUDE.md — Voikerchat 開発ガイド

このファイルはリポジトリ直下（repo root）に置く。Claude Code が毎セッション自動参照する規約。

## リポジトリ / 環境
- Repo: `shibuyer-jp/voikerchat`
- 主開発機: Laptop（`%USERPROFILE%` = `C:\Users\takat`）。パスはハードコードせず必ず `%USERPROFILE%` を使う。
- Flutter 3.44.x / Dart 3.12.x（stable）。
- **fresh clone 直後は必ず `flutter create .` を実行**（`windows/` プラットフォームフォルダは未コミットのため）。
- **clone 後に `lefthook install` を実行**（pre-push フックを有効化するため）。
- **状態管理**: 外部ライブラリなし（Riverpod / Provider / Bloc は未導入）。素の `setState` のみ。
- **lint**: `flutter_lints ^6.0.0`（`analysis_options.yaml` → `include: package:flutter_lints/flutter.yaml`）。カスタム override なし。
- **TS バックエンド**: 同一リポジトリ内の `api/` ディレクトリ（`analytics.ts` / `chat.ts` / `rate-limit.ts`）。Vercel にデプロイ（`vercel.json` あり）。別 CLAUDE.md は不要。

## 絶対ルール: push 前ローカル検証（最重要）
CI が最終ゲートだが、**push 前に必ずローカルで緑を確認する**。目隠し push は禁止。
この順で実行し、すべて成功してからコミット → push。1 つでも赤なら push しない。
1. `flutter pub get`
2. `flutter gen-l10n`（ARB を触った場合）
3. `flutter analyze`
4. `flutter test`

## Git
- identity: `Takatoh Shibuyer` / `takatoh01@gmail.com`
- 1 バッチ = 1 コミット単位。メッセージは簡潔（日本語可）。
- push 後、CI の `Analyze & Test` / `flutter-test` / `Build Android(debug)` が緑になるまで確認。
- push前検証は lefthook(pre-push)で自動実行（analyze/test）。緑でなければpushはブロック。
- push後は `gh run watch` で CI の緑/赤を確認する。

## 実装方針
> 例として流通している DO/DON'T は TS/React 前提のものが多い。以下は Flutter/Dart + Voikerchat 向けに置き換えた版。

### ✅ DO（必ず守ること）
- **ユーザー向けエラーは SnackBar / トーストで表示する**
  → 例外の生文言（stack trace 等）をそのまま出さない。既存の Stage1 トースト本文と整合させる。
- **ネットワーク / DB アクセスは `lib/services/` に集約する**
  → Widget から直接 `http` / Supabase クライアントを叩かない。API base は `https://voikerchat.com` 固定。
- **3 状態以上は enum / sealed class で表現する**
  → `bool isLoading` の乱立を避ける。例: `enum LoadState { idle, loading, success, error }` / `sealed class ChatState`。
- **日時は UTC 基準で保持し、表示時のみローカル整形する**
  → `notification_history_model` の `secondsSinceReceived` / `relativeTimeLabel(l10n, seconds)` パターンに揃える。`DateTime` のタイムゾーン直接演算は避ける。
- **マジックナンバーは定数へ集約する**（`lib/constants/` 等）
  → 例: `FREE_DAILY_LIMIT = 5` / 広告視聴 `+5` / `MAX_DAILY = 10` / `PREMIUM_PRICE_USD = 12.99`。`if (count > 5)` を直書きしない。
- **ユーザー表示文字列は ARB（`AppLocalizations`）へ**
  → ただし学習コンテンツ（診断の問題文・解説）とキャラ名（固有名詞）は日本語 / 原文維持（既存方針）。

### ❌ DON'T（やらないこと）
- **`dynamic` を安易に使わない**（TS の `any` 相当）
  → 型安全が壊れる。不明な型は具体型 or `sealed class` で受け、型で分岐する。
- **`build()` 内で I/O（fetch / DB）を直接呼ばない**（React の「useEffect 内で直接 fetch 禁止」相当）
  → 多重発火・競合・破棄漏れの原因。`initState` / `FutureBuilder` / 状態管理層で行う。
- **可変リストの要素に安定した `Key` を付けずに index 依存にしない**（React の「index を key にしない」相当）
  → 並び替え・削除時のレンダリングバグ源。`ValueKey(<一意ID>)` を使う。
- **1 ファイル ~300 行超を放置しない**
  → レビュー困難。Widget 分割 or ロジックを service / helper へ抽出。
- **シークレットをコードにハードコードしない**（APIキー / APNs キー / PAT 等）
  → `--dart-define` / 環境変数 / Drive 管理経由で参照。※公開 API ベース URL（`voikerchat.com`）のハードコードは既存の意図的仕様なので別扱い。

## i18n / ARB 規約
- ARB: `lib/l10n/`
  - `app_en.arb` … テンプレート（`@key` メタデータ付き）
  - `app_ja.arb` … 値のみ
  - `app_fil.arb` … 値のみ（per-key アノテーション無し）
- `pubspec.yaml: generate: true`。生成物 `lib/l10n/app_localizations*.dart` は `.gitignore` 済み（CI が再生成）。
- **3 言語のキー完全一致**と、プレースホルダ（例 `count:int`）の整合を毎回検証する。
- 表示解決ヘルパー: `lib/l10n/label_helpers.dart`
  （`levelName / levelNameFromToken / relativeTimeLabel / badgeTitle / badgeDesc`）。
  モデル層は l10n 非依存に保ち、ID / enum トークン駆動で UI 側（`BuildContext` のある層）で解決する。
- **fil 訳は Claude の機械下訳 → 本番化前にネイティブレビュー必須**。追加キーはレビュー対象としてメモを残す。
- 原文維持（多言語化しない）:
  - 学習コンテンツ（診断の問題文・解説は日本語維持）
  - キャラ名（`Emi` / `Taro` 等のローマ字。固有名詞）
  - `models/onboarding.dart` の `SceneDefinition.getAllScenes()`（lib/ 内から参照ゼロのデッドコード）

## CI 赤の再発防止（テスト側 l10n 供給）
翻訳を使うウィジェットを描画するテストは、**テスト側でも**
`AppLocalizations.localizationsDelegates` / `supportedLocales` / `locale` を供給すること。
ウィジェット移行の**着手前に、そのウィジェットのテスト有無を必ず確認**する。

## モデル運用
- 本番 AI: Claude Haiku（`claude-haiku-4-5-20251001`）固定。
- 開発時: ARB 移行のような機械的作業は軽量モデル（Sonnet / Haiku）で十分。
  深い設計判断のみ上位モデルに切り替える（`/model` で変更、`/status` で残枠確認）。

## コミュニケーション規約
- 結論ファースト・簡潔・前置き / 謝罪の定型句なし。
- ファイルは常に**完全な内容**で提示（部分スニペット禁止）。
- セッション終了サイン時は引き継ぎ MD を自作:
  ① 前スレ成果 ② 確定した決定 ③ 次タスク（優先順）④ メモリ参照。

## 現在の開発状況（2026-07-01 時点）
> 以下は過去セッションの記憶ベース。実態とズレがあれば修正すること（特にステータス欄）。

### 機能ステータス
| 機能 | 状態 | 備考 |
|------|------|------|
| 認証（Supabase 匿名認証 anon） | ✅ 有効 | プロジェクト `rfwbwwhqclabhnbsrygw`（Tokyo） |
| チャット | ✅ 稼働中 | `messages` / `conversation_sessions` / `user_streaks` / `rate_limits`（RLS 有） |
| 連続日数（ストリーク） | ✅ 実装 | `user_streaks` |
| プッシュ通知 | 🚧 Phase2 進行中 | Phase1 完了（`e235539`）。Phase2 は APNs キー Firebase 登録待ちでブロック |
| 多言語化（ARB i18n） | 🚧 進行中 | 4b 完了（main `742ceeb` / 各 141 キー）。次 4c |
| プレミアム（RevenueCat） | 🚧 配線中 | iOS+Android 構成済。upsell wiring 未 |
| バッジ | 🚧 要確認 | `models/badge.dart` 実装＋ラベル ARB 化済。付与/表示ロジックは要確認 |
| AdMob | 📋 未着手 | 実 ID 差し替えで本番化（i18n 完了後） |
| usage_logs テーブル | 📋 未作成 | 診断強化・従量ログ用 |

### 既知の課題 / オープン項目
- [ ] APNs キー（Key ID `26PUZTM353` / Team ID `S6XJP274T2`）を Firebase Console にアップロード → 通知 Phase2 のブロック解除
- [ ] `analytics.ts` / `rate-limit.ts` を `supabase.auth.getUser` パターンに統一（TS バックエンド層）
- [ ] fil 訳のネイティブレビュー（本番化前）
- [ ] サービス層（`notification_scheduler.dart` / `premium_upsell_service.dart`）の i18n は `BuildContext` 無し層のため設計判断が別途必要

### 直近の作業予定
1. **4c**: `lib/services/scene_service.dart` のシーン `name` / `description`（13 × 2 = 26 文字列）を ID 駆動で多言語化
2. サービス層 i18n（別バッチ・要相談）
3. fil ネイティブレビュー → AdMob 本番化

## lib/ ディレクトリ構成
```
lib/
├── main.dart              # エントリポイント
├── l10n/                  # ARB・生成 AppLocalizations・label_helpers.dart
├── models/                # データモデル（JSON シリアライズ含む）
├── screens/               # 画面 Widget
│   └── onboarding/        # オンボーディング画面群
├── services/              # API・Supabase・通知等のアクセス層
├── stubs/                 # テスト用スタブ
└── widgets/               # 共有 Widget
```
※ `lib/constants/` は CLAUDE.md 本文で言及しているが**未作成**。マジックナンバー集約の際に作成すること。
