#!/bin/bash
# おはスタ自動投稿を Mac に設定する
#
# ターミナルに次の1行を貼り付けて実行します:
#   bash <(curl -fsSL https://raw.githubusercontent.com/karasui1014/ai-music-news/main/mac/install.sh)
#
# やること:
#   1. 投稿の本体（post.sh）を Mac に置く
#   2. Safari の「Apple EventsからのJavaScriptを許可」をオンにしてもらう
#   3. 毎朝 7:00 に投稿する予約を入れる（launchd）
#   4. スリープ中でも 7:00 に Mac を起こす設定をする（Mac のパスワードが必要）
#      ※ スリープ中に予約の時間が来ると、Mac が起きた瞬間に投稿が始まる仕組み
#      ※ pmset の「毎日の自動起動」は1つしか持てないので、ほかに設定していたら上書きされます
#   5. 予約と同じ形で Safari を動かして、「操作の許可」の確認を出してもらう
#   6. 希望があれば、今日の分をすぐ投稿する

set -eu

BASE='https://raw.githubusercontent.com/karasui1014/ai-music-news/main/mac'
DIR="$HOME/Library/Application Support/ohasuta"
LOG="$HOME/Library/Logs/ohasuta.log"
LABEL='com.karasui.ohasuta'
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

# 予約（launchd）と同じ形で post.sh を動かし、結果が記録に出るまで待って表示する
run_via_launchd() {
  local before new
  before=$(wc -l < "$LOG" | tr -d ' ')
  launchctl kickstart "gui/$(id -u)/$LABEL"
  for _ in $(seq 1 240); do
    sleep 1
    new=$(tail -n +"$((before + 1))" "$LOG" 2>/dev/null || true)
    if printf '%s' "$new" | grep -qE '✅|❌|今日はもう投稿済み'; then
      printf '%s\n' "$new"
      if printf '%s' "$new" | grep -q '❌'; then return 1; fi
      return 0
    fi
  done
  echo '❌ 4分待っても終わりませんでした。画面に確認が出ていないか見てください。'
  return 1
}

echo ''
echo '🎵 おはスタ自動投稿の設定をはじめます'
echo ''

mkdir -p "$DIR" "$HOME/Library/Logs" "$HOME/Library/LaunchAgents"
chmod 700 "$DIR"
touch "$LOG"
# 前のやり方で保存していた合言葉は、もう使わないので消す
rm -f "$DIR/sid"

# 1) 本体を置く
curl -fsSL "$BASE/post.sh" -o "$DIR/post.sh"
chmod 700 "$DIR/post.sh"
echo '✅ 1/5 投稿のプログラムを置きました'

# 2) Safari の設定
echo ''
echo '👉 Safari の設定を1つ変えてください。'
echo '   Safari のメニュー「開発」を開いて、「Apple EventsからのJavaScriptを許可」にチェックを入れます。'
echo '   （「開発」の中に見当たらないときは、「開発」→「デベロッパ設定…」を開くと、その中にあります）'
echo '   （パスワードを聞かれたら、Mac のパスワードを入力してください）'
echo '   あわせて、Safari で substack.com にログインしていることも確かめてください。'
echo ''
echo '   できたら、ここ（ターミナル）をクリックして return キーを押してください。'
# 1行を貼り付けたときの余分な改行などが残っていたら、読み捨てる
while read -rs -t 1 _ < /dev/tty; do :; done
read -r _ < /dev/tty || true
echo '✅ 2/5 Safari の準備ができました'

# 3) 毎朝 7:00 の予約
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
    <string>$DIR/post.sh</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key><integer>7</integer>
    <key>Minute</key><integer>0</integer>
  </dict>
</dict>
</plist>
EOF
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo '✅ 3/5 毎朝 7:00 に投稿する予約を入れました'

# 4) 7:00 に Mac を起こす（投稿中は caffeinate でスリープしないようにしている）
echo ''
if pmset -g sched 2>/dev/null | grep -qiE 'wake.*7:00 ?AM'; then
  echo '   （Mac を起こす設定はもう入っているので、パスワードの入力はいりません）'
else
  echo '👉 スリープ中でも Mac を起こすために、Mac のパスワードを入力して return キーを押してください。'
  echo '   （Mac にログインするときのパスワードです。入力しても画面には何も表示されません）'
  sudo pmset repeat wakeorpoweron MTWRFSU 07:00:00
fi
echo '✅ 4/5 毎朝 7:00 に Mac を起こす設定をしました'

# 5) 予約と同じ形で Safari を動かしてみる（ここで「操作の許可」の確認が出る）
echo ''
echo '👉 これから Safari のウインドウが開いて、すぐ閉じます（投稿はしません）。'
echo '   「Safari を制御しようとしています」のような確認が出たら、「許可」（OK）を押してください。'
touch "$DIR/run-check"
if ! run_via_launchd; then
  echo ''
  echo '❌ Safari を動かせませんでした。上のメッセージを Claude に伝えてください。'
  exit 1
fi
echo '✅ 5/5 Safari を動かせました'

echo ''
echo '🎉 設定がすべて終わりました！'
echo '   毎朝 7:00 に投稿します。夜は充電器につないでおいてください。'
echo ''

# 6) 今日の分をすぐ投稿するか
echo '👉 今日の分を、今すぐ1回投稿しますか？'
echo '   投稿するなら y 、しないなら n を入力して return キーを押してください。'
read -r ANSWER < /dev/tty
if [ "$ANSWER" = y ] || [ "$ANSWER" = Y ]; then
  echo '   Safari が開いて投稿します。終わるまで1分くらい待ってください…'
  run_via_launchd || echo '❌ 投稿できませんでした。上のメッセージを Claude に伝えてください。'
fi
echo ''
