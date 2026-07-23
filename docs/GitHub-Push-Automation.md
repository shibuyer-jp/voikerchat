# Voikerchat GitHub Push 自動化ガイド

## 概要

このリポジトリを GitHub に push する際の標準手順と、非推奨の旧手順をまとめる。

**2026-07-23 改訂**: PAT を `git remote set-url` で `.git/config` に直接埋め込む方式(旧・方法1/2)は、
push後のスクラブ処理が実装されておらずトークンが残留し続ける実インシデントが発生したため、**使用禁止**とした。
標準は **Git Credential Manager(GCM)経由の素の `git push`** に一本化する。

---

## 標準：Git Credential Manager 経由の `git push`

Windows 版 Git には Git Credential Manager(GCM)が標準同梱されており(`credential.helper = manager`)、
初回のみブラウザでの認証が必要だが、以後は自動的に認証情報が使われる。**`.git/config` にトークンは一切書き込まれない**(Windows Credential Manager に暗号化保存される)。

### 使い方

```bash
git push origin main
```

これだけでよい。初回のみブラウザでのGitHub認証を求められる場合がある。

### セットアップ状態の確認方法

```bash
# credential.helper が manager になっているか確認
git config --get credential.helper

# 認証情報が既にあるか確認（プロンプトなしで応答が返れば設定済み）
git ls-remote origin HEAD
```

`git ls-remote origin HEAD` がエラーなく応答すれば、そのマシンでは追加セットアップ不要で `git push` がそのまま使える。

### GitHub CLI(`gh`)について

`gh auth login` でも認証情報を保存できるが、このリポジトリでは GCM が既に機能している場合、
`gh` を別途 git の credential helper として二重に設定する必要はない。`gh` 自体は Issue/PR操作等の
補助ツールとしてそのまま使ってよい。

---

## ⚠️ 非推奨(使用禁止): PAT 直埋め込み方式

以下の `scripts/push-commits.sh` / `scripts/push-commits.ps1` による方式は、
Google Drive から取得した PAT を `git remote set-url origin https://<PAT>@github.com/...` の形で
**`.git/config` に平文で書き込み、push後にスクラブ(削除)する処理が実装されていない**。
そのためトークンが `.git/config` に残留し続けるリスクがある。**新規に使用しないこと。**

GCM が未セットアップの環境(例: このリポジトリのDesktop機は2026-07-23時点で未確認)でどうしても
一時的な代替が必要な場合のみ、スクリプト側の確認プロンプトに `y` と答えて実行できるが、
**実行後は必ず `git remote set-url origin https://github.com/shibuyer-jp/voikerchat.git` で
リモートURLを埋め込みなしの状態に戻すこと**。恒久対応は GCM のセットアップ(初回ブラウザ認証)。

<details>
<summary>旧手順(参考・非推奨)</summary>

```bash
# Bash
export GITHUB_TOKEN='ghp_...'
bash scripts/push-commits.sh

# PowerShell
$env:GITHUB_TOKEN = 'ghp_...'
powershell -ExecutionPolicy Bypass -File scripts/push-commits.ps1
```

PAT の取得元: Google Drive `00_Project_Credentials/API_Keys/Github_API_Key.txt`

</details>

---

## GitHub Actions による自動 CI/CD

Push 後、自動的に以下が実行される:

- ✅ Flutter analysis & tests(`flutter-ci.yml` / `ci-cd.yml`)
- ✅ Android APK ビルド(debug)
- ✅ iOS TestFlight ビルド(`ios-release.yml`、手動トリガー)

詳細は `.github/workflows/` 配下を参照。push後は `gh run watch` でCIの緑/赤を確認する。

---

**改訂日：** 2026-07-23(PAT直埋め込み方式を非推奨化、GCM方式を標準化)
**リポジトリ：** https://github.com/shibuyer-jp/voikerchat
