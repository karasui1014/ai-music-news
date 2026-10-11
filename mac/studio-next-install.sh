#!/bin/bash
# スタジオネクストのツール紹介 自動投稿を Mac に設定する
#
# ターミナルに次の1行を貼り付けて実行します:
#   bash <(curl -fsSL https://raw.githubusercontent.com/karasui1014/ai-music-news/main/mac/studio-next-install.sh)
#
# やること:
#   1. 投稿の本体（studio-next.sh）を Mac に置く
#   2. 毎日 12:00 と 18:00 に投稿する予約を入れる（launchd）
#   3. 予約と同じ形で Safari を動かして、うまく操作できるか確かめる（投稿はしない）
#   4. 希望があれば、今すぐ1回投稿してみる
#
# Safari の準備（「Apple EventsからのJavaScriptを許可」と Substack へのログイン）は、おはスタと同じです。
# おはスタの設定が済んでいれば、追加でやることはありません。
# ※ Mac を自動で起こす設定は、おはスタの朝7:00 だけです。12:00・18:00 にスリープしていたら、
#    次に Mac を開いたときに（その日の12時以降なら）投稿されます。

set -eu

BASE='https://raw.githubusercontent.com/karasui1014/ai-music-news/main/mac'
DIR="$HOME/Library/Application Support/studio-next"
LOG="$HOME/Library/Logs/studio-next.log"
LABEL='com.karasui.studionext'
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

# 予約（launchd）と同じ形で studio-next.sh を動かし、結果が記録に出るまで待って表示する
run_via_launchd() {
  local before new
  before=$(wc -l < "$LOG" | tr -d ' ')
  launchctl kickstart "gui/$(id -u)/$LABEL"
  for _ in $(seq 1 240); do
    sleep 1
    new=$(tail -n +"$((before + 1))" "$LOG" 2>/dev/null || true)
    if printf '%s' "$new" | grep -qE '✅|❌|何もしません'; then
      printf '%s\n' "$new"
      if printf '%s' "$new" | grep -q '❌'; then return 1; fi
      return 0
    fi
  done
  echo '❌ 4分待っても終わりませんでした。画面に確認が出ていないか見てください。'
  return 1
}

echo ''
echo '🧰 スタジオネクストのツール紹介 自動投稿の設定をはじめます'
echo ''

mkdir -p "$DIR" "$HOME/Library/Logs" "$HOME/Library/LaunchAgents"
chmod 700 "$DIR"
touch "$LOG"

# 1) 本体を置く
curl -fsSL "$BASE/studio-next.sh" -o "$DIR/studio-next.sh"
chmod 700 "$DIR/studio-next.sh"
echo '✅ 1/3 投稿のプログラムを置きました'

# 2) 毎日 12:00 と 18:00 の予約
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/caffeinate</string>
    <string>-i</string>
    <string>/bin/bash</string>
    <string>$DIR/studio-next.sh</string>
  </array>
  <key>StartCalendarInterval</key>
  <array>
    <dict>
      <key>Hour</key><integer>12</integer>
      <key>Minute</key><integer>0</integer>
    </dict>
    <dict>
      <key>Hour</key><integer>18</integer>
      <key>Minute</key><integer>0</integer>
    </dict>
  </array>
</dict>
</plist>
EOF
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo '✅ 2/3 毎日 12:00 と 18:00 に投稿する予約を入れました'

# 3) 予約と同じ形で Safari を動かしてみる
echo ''
echo '👉 これから Safari のウインドウが開いて、すぐ閉じます（投稿はしません）。'
echo '   「Safari を制御しようとしています」のような確認が出たら、「許可」（OK）を押してください。'
touch "$DIR/run-check"
if ! run_via_launchd; then
  echo ''
  echo '❌ Safari を動かせませんでした。上のメッセージを Claude に伝えてください。'
  exit 1
fi
echo '✅ 3/3 Safari を動かせました'

echo ''
echo '🎉 設定がすべて終わりました！'
echo '   毎日 12:00 と 18:00 に、ツール紹介を1つずつ投稿します。'
echo ''

# 4) 今すぐ1回投稿してみるか
echo '👉 ためしに、今すぐ1回投稿してみますか？'
echo '   投稿するなら y 、しないなら n を入力して return キーを押してください。'
read -r ANSWER < /dev/tty
if [ "$ANSWER" = y ] || [ "$ANSWER" = Y ]; then
  echo '   Safari が開いて投稿します。終わるまで1分くらい待ってください…'
  touch "$DIR/run-force"
  run_via_launchd || echo '❌ 投稿できませんでした。上のメッセージを Claude に伝えてください。'
fi
echo ''
