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

## 状態管理の絶対ルール(このファイルの範囲)
- **このCLAUDE.mdには「不変の指針」のみを書く。プロジェクトの現在状態・課題・作業予定は書かない**
- 現在状態は `internal-docs/STATE.md` を参照。**セッション開始時に必ず読み、セッション終了時に必ず更新してコミットする**(更新漏れ=次セッションの不具合原因)
- 設計・仕様の決定は `internal-docs/DECISIONS.md` に1行追記(追記専用・削除禁止。「いつ・何を・なぜ」)
- Git identity: `shibuyer-jp` / `262262561+shibuyer-jp@users.noreply.github.com`(Vercel連携リポジトリで他のメールを使うとデプロイがブロックされる)

## モデル運用(2026-07-07以降)
- 実装・定型作業: Sonnet / Claude Code(1タスク=1セッション、計画ループ禁止、質問は1つまで)
- 設計判断・障害切り分けのみ: Opus(温存運用)
- 本番AI: Claude Haiku(`claude-haiku-4-5-20251001`)固定

## lib/ ディレクトリ構成
```
lib/
├── main.dart              # エントリポイント
├── l10n/                  # ARB・生成AppLocalizations・label_helpers.dart
├── models/                # データモデル
├── screens/               # 画面Widget(onboarding/含む)
├── services/              # API・Supabase・通知等のアクセス層
├── stubs/                 # テスト用スタブ
└── widgets/               # 共有Widget
```

## Phase A 品質ゲート(2026-07-16〜)
リリース前改善タスクを自走する場合は、まず `internal-docs/tasks/RUNBOOK.md` と `internal-docs/tasks/PROGRESS.md` を読むこと。タスク仕様は `internal-docs/tasks/T-3x_*.md`、全体計画は `internal-docs/Release-Master-Plan-v2.0.md`。

## Claude(チャット) と CC(Claude Code) の分担ルール(2026-08-07)

**背景**: チャット側のClaudeがリポジトリをcloneしてドキュメント編集・PRマージまで行うと、
本来CCが安く実行できる作業をチャットの使用量で消費してしまう。役割を明示的に分ける。

### CC(Claude Code)が担当する

- リポジトリの操作全般: clone / branch / commit / push / PR作成 / PRマージ / ブランチ整理
- ファイルの読み書き: コード実装、`internal-docs/` 配下のドキュメント作成・更新
- `STATE.md` / `DECISIONS.md` の更新とコミット(状態記録は原則CCが書く)
- `gh` CLI を使った PR・Issue の操作
- テスト実行、`flutter analyze` / `flutter test`、ビルド番号の更新
- SQLファイルの作成(実行はユーザー)

### Claude(チャット)が担当する

- 意思決定の支援: 選択肢の整理、トレードオフの提示、優先順位づけ
- 前提の検証と矛盾の指摘(記録と実態のズレ、古い情報の検出)
- CCへ渡す指示文(プロンプト)の作成
- スクリーンショット・エラーメッセージ・審査通知など、ユーザーが提示した情報の解釈
- 調査・設計の壁打ち、文章のドラフト(ストア掲載文・申請回答案など)

### 判断に迷ったときの原則

**「リポジトリに書き込む作業か?」で分ける。** 書き込むならCC、考えるだけならチャット。

**チャット側が例外的にリポジトリを触ってよい場合**: CCが動かせない環境にいる、
または往復のほうが明らかに高コストな極小の作業。その場合も理由を明示すること。

### 引き継ぎの形式

チャット側で方針が固まったら、**CCへそのまま貼れる指示文**を出力して終わる。
指示文には「対象ファイル」「変更内容」「判断理由」「検証方法」を含めること。
