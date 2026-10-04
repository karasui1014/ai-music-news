#!/bin/bash
# おはスタ自動投稿を Mac から取り外す
#
# ターミナルに次の1行を貼り付けて実行します:
#   bash <(curl -fsSL https://raw.githubusercontent.com/karasui1014/ai-music-news/main/mac/uninstall.sh)

set -u

LABEL='com.karasui.ohasuta'

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"
rm -rf "$HOME/Library/Application Support/ohasuta"
echo '✅ 毎朝の予約と、保存していた合言葉を消しました'

echo '👉 Mac を毎朝起こす設定も消すので、Mac のパスワードを入力して return キーを押してください。'
sudo pmset repeat cancel
echo '✅ 取り外しが終わりました'
