#!/bin/bash
# スタジオネクストのツール紹介 自動投稿を Mac から取り外す
#
# ターミナルに次の1行を貼り付けて実行します:
#   bash <(curl -fsSL https://raw.githubusercontent.com/karasui1014/ai-music-news/main/mac/studio-next-uninstall.sh)
#
# おはスタ（朝7:00）の自動投稿や、Mac を毎朝起こす設定には触りません。

set -u

LABEL='com.karasui.studionext'

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"
rm -rf "$HOME/Library/Application Support/studio-next"
echo '✅ 12:00・18:00 の予約と、設定のファイルを消しました（おはスタはそのままです）'
