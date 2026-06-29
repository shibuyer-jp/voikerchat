# Voikerchat 引き継ぎ — 2026-06-30（feat/anon-auth マージ + チャットE2E疎通）

## 1. 前スレで達成した作業（具体的成果）

- **実機スモークテスト完了**：エミュレータ（emulator-5554 / Pixel API34）で
  オンボーディング診断 → Home（下タブ：シーン/統計/通知）→ シーン選択 → チャット まで動作確認。
- **`feat/anon-auth` → `main` マージ完了**（merge commit `acbac98`）。
  内容：シーン選択画面 / アプリ骨格 / Supabase匿名サインイン / GitHub Actions CI /
  Android ビルド設定修正（AGP9オプトアウト, desugaring, compileSdk=36）。
- **チャットがエンドツーエンドで疎通**（AIが日本語で応答することを実機確認）。
  ここに至るまでに以下の連鎖した不具合をすべて解消（下記2）。

## 2. 本日の確定事項（恒久メモ）

### 本番デプロイ構成（重要・再確認不要）
- **voikerchat.com / www.voikerchat.com は Vercel プロジェクト `voikerchat-x621` に接続**。
  （`japanese-learning-app` プロジェクトは無関係。環境変数も別管理）
- GitHub リポジトリ `shibuyer-jp/voikerchat` には Vercel プロジェクトが2つ接続
  （`voikerchat-x621`=本番ドメイン保持、`voikerchat`=サブ）。本番は `voikerchat-x621`。
- `voikerchat-x621` の環境変数（Production/Preview/Development 全環境・設定済み）：
  - `SUPABASE_URL` = `https://rfwbwwhqclabhnbsrygw.supabase.co`
  - `SUPABASE_SERVICE_KEY` = Supabase service_role キー
  - `ANTHROPIC_API_KEY` = Claude APIキー

### Supabase（プロジェクト ID `rfwbwwhqclabhnbsrygw`・旧名 Japanese-learning-app・東京）
- 匿名サインイン有効。
- **本日作成したテーブル（RLS有効・本人行のみ許可ポリシー、authenticated対象）**：
  `messages` / `conversation_sessions` / `user_streaks`。
  （`rate_limits` は既存。`usage_logs` は未作成だがログ用で会話は止まらない＝任意）

### AIモデル（重要）
- 旧 `claude-3-5-haiku-20241022` は **2026-02-19 に Retired** → API失敗の原因だった。
- 現行 **`claude-haiku-4-5-20251001`（Haikuティア・現役）に移行済み**（commit `d4dd772`）。
  ※公式の Haiku 3.5 推奨後継。コスト方針（Haiku継続）と整合。

### api/chat.ts の認証方式（変更）
- 旧：`jwt.verify(token, SUPABASE_JWT_SECRET)`（HS256共有シークレット依存）
- 新：**`supabase.auth.getUser(token)`**（HS256/非対称鍵いずれも検証可・JWT Secret不要）。
  → publishableキー運用と整合。`SUPABASE_JWT_SECRET` は不要になった。
- 環境変数は名前ゆれ吸収：`SUPABASE_SERVICE_KEY || SUPABASE_KEY`、
  `ANTHROPIC_API_KEY || CLAUDE_API_KEY`。不足時は `Missing environment variable(s): ◯◯` を返す。

### main の主要コミット（時系列）
- `f1f249c` CI: Supabase有効APKビルド（dart-define）
- `65162a0` chat: 初期化失敗時の無限スピナー解消
- `2d03dc6` api: package.json 追加（Vercelがserverless依存をインストール）
- `974d30e` api/chat: 環境変数堅牢化 + getUser認証（JWT Secret依存を撤廃）
- `acbac98` merge: feat/anon-auth 本体
- `d4dd772` api/chat: モデルを現役Haiku 4.5へ移行 ← 最新

## 3. 次タスク（優先順）

1. **残バックログの配線**（feat/anon-auth で未配線のもの）：
   プレミアム勧導の配線 → 診断画面 enhanced 切替 → バッジ/ゲーミフィケーション → AdMob → 多言語ARB。
2. **（任意）`usage_logs` テーブル作成**：API使用ログ記録用。未作成でも会話は動くが、
   作ると利用統計/コスト追跡が可能。`messages` 等と同形のRLS付きSQLで追加。
3. **会話履歴の表示確認**：再入室時に過去メッセージが復元されるか（`loadMessageHistory`）。
4. **iOS 側の通り道確認**：今回はAndroidエミュのみ。iOSビルド/匿名サインイン/チャットの疎通。
5. **生成物の .gitignore 整理**（任意）：`.dart_tool/`・`windows/`・`macos/` 等の追跡除外で
   pull差分ノイズ解消（`windows/` はフレッシュclone後 `flutter create .` 必要の件と併せて整理）。
6. **本番ハードニング**：`api/chat.ts` の `baseUrl` は `https://voikerchat.com` 固定。
   将来 staging を分けるなら dart-define 化を検討。

## 4. 開発環境メモ（継続）
- 作業マシン：Laptop（takat）。Flutter 3.44.x。emulator-5554（Pixel/API34）。
  JAVA_HOME=`C:\Program Files\Android\Android Studio\jbr`。パスは常に `%USERPROFILE%`。
- フル機能起動コマンド：
  `flutter run -d emulator-5554 --dart-define=SUPABASE_URL=https://rfwbwwhqclabhnbsrygw.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable key>`
- CI（GitHub Actions）：analyze + test + Android debug APK（Supabase有効）アーティファクト。

## 5. 関連メモリ番号
- #4（識別子 / Apple Team ID S6XJP274T2）
- #5（課金構成：無料5回/日・プレミアム$12.99/月）
- #7（T-21 通知：Phase1完了・Phase2準備済み）
