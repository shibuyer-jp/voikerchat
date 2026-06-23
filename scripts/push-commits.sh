#!/bin/bash

###############################################################################
# Voikerchat GitHub Push Script
# 
# Usage:
#   ./scripts/push-commits.sh              # Interactive (prompts for PAT)
#   ./scripts/push-commits.sh YOUR_PAT     # Non-interactive (pass PAT as arg)
#   GITHUB_TOKEN=YOUR_PAT ./scripts/push-commits.sh  # Via env variable
#
# This script automatically:
# 1. Extracts GitHub PAT from environment or prompts user
# 2. Updates git remote URL with authenticated HTTPS
# 3. Pushes all commits to main branch
# 4. Verifies push success
#
###############################################################################

set -e

PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
cd "$PROJECT_DIR"

echo "=========================================="
echo "Voikerchat GitHub Push Automation"
echo "=========================================="
echo ""

# Step 1: Get GitHub PAT
echo "[Step 1] GitHub PAT 取得"

PAT="${1:-${GITHUB_TOKEN:-}}"

if [ -z "$PAT" ]; then
    echo "GitHub PAT が見つかりません。"
    echo ""
    echo "PAT 取得手順："
    echo "  1. https://github.com/settings/tokens を開く"
    echo "  2. 'Personal access tokens (classic)' から 'Generate new token (classic)' をクリック"
    echo "  3. 権限: 'repo' を選択"
    echo "  4. Token を生成・コピー"
    echo ""
    read -sp "GitHub PAT を入力してください: " PAT
    echo ""
fi

# Validate PAT format
if ! [[ "$PAT" =~ ^ghp_[a-zA-Z0-9_]{36,}$ ]]; then
    echo "❌ エラー: PAT フォーマットが不正です（ghp_... で始まる必要があります）"
    exit 1
fi

echo "✓ PAT を受け取りました"
echo ""

# Step 2: Update git remote URL with authenticated HTTPS
echo "[Step 2] Git Remote URL を更新"

REPO_URL="https://${PAT}@github.com/shibuyer-jp/voikerchat.git"

git remote set-url origin "$REPO_URL"
echo "✓ Remote URL を更新: origin → ${REPO_URL:0:30}...${REPO_URL: -10}"
echo ""

# Step 3: Verify connectivity
echo "[Step 3] GitHub 接続確認"

if ! git ls-remote origin > /dev/null 2>&1; then
    echo "❌ エラー: GitHub 接続失敗"
    echo "   PAT が正しいか確認してください"
    exit 1
fi

echo "✓ GitHub 接続成功"
echo ""

# Step 4: Push commits
echo "[Step 4] コミットを GitHub に Push"

BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "現在のブランチ: $BRANCH"

# Show commits to push
COMMIT_COUNT=$(git rev-list --count origin/$BRANCH..$BRANCH 2>/dev/null || echo "0")
if [ "$COMMIT_COUNT" -eq "0" ]; then
    echo "⚠️  Push 対象のコミットがありません（すでに同期済み）"
    exit 0
fi

echo "Push 対象: $COMMIT_COUNT コミット"
echo ""

# Execute push
if git push origin $BRANCH; then
    echo ""
    echo "✓ Push 成功！"
    echo ""
    echo "[Push 完了]"
    echo "リポジトリ: https://github.com/shibuyer-jp/voikerchat"
    echo "ブランチ: $BRANCH"
else
    echo "❌ Push 失敗"
    exit 1
fi

# Step 5: Verify push
echo ""
echo "[Step 5] Push 確認"

PUSHED_COMMITS=$(git rev-list --count origin/$BRANCH..$BRANCH 2>/dev/null || echo "0")
if [ "$PUSHED_COMMITS" -eq "0" ]; then
    echo "✓ すべてのコミットが push されました"
    
    # Show latest commits
    echo ""
    echo "最新のコミット:"
    git log --oneline -3
else
    echo "⚠️  未 push のコミット: $PUSHED_COMMITS"
fi

echo ""
echo "=========================================="
echo "✓ Voikerchat Push 完了"
echo "=========================================="
