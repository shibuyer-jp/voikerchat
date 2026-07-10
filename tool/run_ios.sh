#!/bin/bash
# Voikerchat iOS実機起動スクリプト(Mac用)
# 使い方:
#   ./tool/run_ios.sh              # 既定のiPhone実機で起動
#   ./tool/run_ios.sh <device-id>  # 別デバイス指定
# 注意: 実行権限が無い場合は chmod +x tool/run_ios.sh

set -e
DEVICE="${1:-00008140-000938610EB8801C}"  # 既定: Takatoh iPhone

# SUPABASE_PUBLISHABLE_KEY はクライアント配布前提の公開可能キー(秘密鍵ではない)
SUPABASE_URL="https://rfwbwwhqclabhnbsrygw.supabase.co"
SUPABASE_PUBLISHABLE_KEY="sb_publishable_jirMoWsnc0AtQc4c2tUJ6Q_3uc43qHT"

echo "== branch: $(git branch --show-current) / device: $DEVICE =="
flutter run -d "$DEVICE" \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_PUBLISHABLE_KEY="$SUPABASE_PUBLISHABLE_KEY"
