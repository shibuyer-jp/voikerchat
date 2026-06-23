# Voikerchat GitHub Push 自動化ガイド

## 概要

このドキュメントでは、commit 19fc020（T-13 Supabase メッセージ履歴実装）を GitHub にプッシュするための複数の方法を説明します。

**目標：** 全自動で `ghp_...` PAT を Google Drive から取得し、GitHub に push する

---

## 方法 1：Windows PowerShell（推奨）

### 前提条件
- Windows 10/11
- PowerShell 5.0 以上
- Git がインストール済み
- 本リポジトリがクローン済み

### 実行手順

#### A. 環境変数で PAT を設定（最も自動化された方法）

```powershell
# 1. PowerShell を開く（Windows + R → powershell.exe）

# 2. Google Drive から PAT を取得
#    場所: https://drive.google.com
#    パス: 00_Project_Credentials/API_Keys/Github_API_Key.txt
#    （ファイルを開いて ghp_... をコピー）

# 3. 環境変数を設定
$env:GITHUB_TOKEN = 'ghp_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'

# 4. Push スクリプトを実行
cd "$env:USERPROFILE\Documents\Voikerchat"
powershell -ExecutionPolicy Bypass -File scripts/push-commits.ps1
```

#### B. 対話的に PAT を入力（セキュア）

```powershell
# 1. PowerShell を開く

# 2. Push スクリプトを実行
cd "$env:USERPROFILE\Documents\Voikerchat"
powershell -ExecutionPolicy Bypass -File scripts/push-commits.ps1

# 3. プロンプトで PAT を入力
#    Enter GitHub PAT: [非表示で入力]
```

### 実行結果例

```
==========================================
Voikerchat GitHub Auto-Push
==========================================

[INFO] Project directory: C:\Users\User01\Documents\Voikerchat
[INFO] Retrieving GitHub PAT...
[OK] PAT received (ghp_XXXXXXX...)
[INFO] Updating git remote URL...
[OK] Remote URL updated
[INFO] Testing GitHub connectivity...
[OK] GitHub connection verified

[INFO] Current branch: main
[INFO] Commits to push: 1
[INFO] Pushing commits to GitHub...
[OK] Push successful!

[INFO] Verifying push...
[OK] All commits successfully pushed

Latest commits:
19fc020 feat: T-13 Supabase message history - add models, service, and chat screen
efbc3ba fix: rename DiagnosticLevel to UserDiagnosticLevel to avoid Flutter naming conflict
7ab47c8 feat: implement Onboarding UI (diagnostic test & level result screens)

==========================================
✓ Voikerchat Push Complete
==========================================

Repository: https://github.com/shibuyer-jp/voikerchat
Branch: main
```

---

## 方法 2：Bash/Shell（Linux/macOS）

```bash
# 1. リポジトリディレクトリへ移動
cd ~/voikerchat

# 2. Google Drive から PAT を取得
#    場所: https://drive.google.com
#    パス: 00_Project_Credentials/API_Keys/Github_API_Key.txt

# 3. 環境変数を設定
export GITHUB_TOKEN='ghp_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'

# 4. Push スクリプトを実行
bash scripts/push-commits.sh
```

---

## 方法 3：GitHub CLI（最も簡潔）

GitHub CLI をインストール済みの場合：

```bash
# 1. GitHub にログイン
gh auth login

# 2. Push を実行
git push origin main

# GitHub CLI が自動的に認証を処理します
```

---

## 方法 4：Git Credential Manager

Windows/macOS/Linux で認証情報を安全に管理：

```bash
# 1. Git Credential Manager をインストール
#    https://github.com/git-ecosystem/git-credential-manager

# 2. 初回実行時に認証ダイアログが表示されます
git push origin main

# 以降、認証情報がキャッシュされます
```

---

## PAT 取得方法の詳細

### Google Drive から直接取得

1. **Google Drive にアクセス**
   - https://drive.google.com

2. **フォルダを辿る**
   ```
   マイドライブ
   └─ Shibuyer_Management (または 0AJPURde9GjEYUk9PVA)
      └─ 00_Project_Credentials
         └─ API_Keys
            └─ Github_API_Key.txt
   ```

3. **ファイルを開く**
   - ダブルクリック → Google ドキュメントで開く

4. **PAT をコピー**
   - ファイル内容：`ghp_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX`
   - 全文を選択・コピー

### GitHub から新規発行（代替案）

1. https://github.com/settings/tokens を開く

2. **Personal access tokens (classic)** → **Generate new token (classic)**

3. **設定**
   - Scopes: `repo` を選択
   - Expiration: No expiration（或いは 90 days）

4. **Generate token** → トークンをコピー

5. **Google Drive に保存**（今後の参照用）

---

## トラブルシューティング

### エラー：`Invalid PAT format`

**原因：** PAT が `ghp_` で始まっていない、または形式が不正

**対応：**
1. PAT を再度確認（全文をコピーしたか）
2. 改行や空白が含まれていないか確認
3. Google Drive のファイルをテキストエディタで開き直す

### エラー：`GitHub connection failed`

**原因：** PAT が正しくない、または権限不足

**対応：**
1. PAT を再度 Google Drive から取得
2. GitHub でトークンが有効か確認（Settings → Tokens）
3. 別の PAT を発行して試す

### エラー：`No commits to push`

**原因：** すでに最新の状態

**対応：** 正常です。以下を確認してください：
```bash
git log --oneline -3
# 19fc020 が表示されていれば OK
```

### エラー：`Permission denied`

**原因：** PAT に権限がない

**対応：**
1. GitHub Settings → Developer settings → Personal access tokens
2. トークンをクリック → **Regenerate token**
3. **Scopes:** `repo` を確認

---

## 完全自動化（上級）

### 毎日自動でリモートをチェック

**Windows タスクスケジューラで定期実行：**

```powershell
# push-auto.ps1
$PAT = $env:GITHUB_TOKEN  # 環境変数から取得
cd C:\Users\User01\Documents\Voikerchat
powershell -ExecutionPolicy Bypass -File scripts/push-commits.ps1
```

**タスクスケジューラの設定：**
1. `Win + X` → `タスク スケジューラ`
2. **タスクの作成**
3. **トリガー：** 毎日 9:00 AM
4. **アクション：** PowerShell スクリプト実行
5. **条件：** ネットワーク接続時のみ

---

## GitHub Actions による自動 CI/CD

Push 後、自動的に以下が実行されます：

- ✅ Flutter analysis & tests
- ✅ Windows ビルド
- ✅ Android APK ビルド
- ✅ iOS ビルド
- ✅ Web の Vercel デプロイ
- ✅ GitHub Release 作成

詳細は `.github/workflows/ci-cd.yml` を参照

---

## セキュリティに関する注意

⚠️ **PAT の扱い**

- PAT は secrets のように扱う（他人と共有しない）
- PowerShell コマンド履歴には記録されない（`Read-Host -AsSecureString` 使用）
- `.env` ファイルには保存しない
- Git リポジトリにコミットしない

✓ **推奨される方法**

1. **Google Drive に保存**（このプロジェクトの仕様）
2. **環境変数で使用**（セッションスコープ）
3. **Git Credential Manager**（OS-level 暗号化）

---

## 次のステップ

✅ commit 19fc020 を push 後：

1. **GitHub リポジトリを確認**
   ```
   https://github.com/shibuyer-jp/voikerchat/commits/main
   ```

2. **Actions を確認**
   ```
   https://github.com/shibuyer-jp/voikerchat/actions
   ```
   - CI/CD パイプラインが自動実行されます

3. **T-14 開始**
   - iOS/Android ビルド調整

---

## Quick Reference

| 方法 | コマンド | 難易度 |
|-----|--------|--------|
| PowerShell | `pwsh scripts/push-commits.ps1` | ⭐ 簡単 |
| Bash | `bash scripts/push-commits.sh` | ⭐ 簡単 |
| GitHub CLI | `gh auth login && git push` | ⭐ 最簡単 |
| Credential Manager | `git push origin main` | ⭐⭐ 初期セットアップ後は簡単 |
| Manual | `git push https://[PAT]@github.com/...` | ⭐⭐⭐ 複雑 |

---

**作成日：** 2026-06-23  
**対象コミット：** 19fc020 (T-13 Supabase メッセージ履歴)  
**リポジトリ：** https://github.com/shibuyer-jp/voikerchat
