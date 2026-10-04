#!/bin/bash
# おはスタ自動投稿を Mac に設定する
#
# ターミナルに次の1行を貼り付けて実行します:
#   bash <(curl -fsSL https://raw.githubusercontent.com/karasui1014/ai-music-news/main/mac/install.sh)
#
# やること:
#   1. 投稿の本体（post.sh）を Mac に置く
#   2. Substack の合言葉を Mac の中に保存する（自分だけが読める設定）
#   3. Substack につながるか確かめる（投稿はしない）
#   4. 毎朝 7:00 に投稿する予約を入れる
#   5. スリープ中でも 7:00 に Mac を起こす設定をする（Mac のパスワードが必要）
#      ※ スリープ中に予約の時間が来ると、Mac が起きた瞬間に投稿が始まる仕組み
#      ※ pmset の「毎日の自動起動」は1つしか持てないので、ほかに設定していたら上書きされます

set -eu

BASE='https://raw.githubusercontent.com/karasui1014/ai-music-news/main/mac'
DIR="$HOME/Library/Application Support/ohasuta"
LABEL='com.karasui.ohasuta'
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

echo ''
echo '🎵 おはスタ自動投稿の設定をはじめます'
echo ''

mkdir -p "$DIR" "$HOME/Library/Logs" "$HOME/Library/LaunchAgents"
chmod 700 "$DIR"

# 1) 本体を置く
curl -fsSL "$BASE/post.sh" -o "$DIR/post.sh"
chmod 700 "$DIR/post.sh"
echo '✅ 1/5 投稿のプログラムを置きました'

# 2) 合言葉を保存する
# 1行を貼り付けたときの余分な改行などが残っていたら、読み捨てる
while read -rs -t 1 _ < /dev/tty; do :; done

echo ''
echo '👉 Substack の合言葉（substack.sid の値）を貼り付けて、return キーを押してください。'
echo '   ※ 貼り付けても画面には何も表示されません。そのまま return を押せば大丈夫です。'
SID=''
while [ -z "$SID" ]; do
  read -rs RAW < /dev/tty || true
  # 表の1行ぶん（名前・ドメインなど）が一緒にコピーされていても、合言葉の部分（s%3A…）だけを取り出す
  SID=$(printf '%s' "$RAW" | grep -oE 's(%3A|:)[^[:space:];]+' | head -n 1 || true)
  RAW=$(printf '%s' "$RAW" | tr -d '[:space:]')
  if [ -z "$RAW" ]; then
    echo '   （まだ何も入っていません。合言葉を貼り付けて return キーを押してください）'
  elif [ -z "$SID" ]; then
    # 合言葉ではないもの（画面の文字など）が貼り付けられた。全部は見せず、最初の4文字だけ見せる
    echo ''
    echo "   ❌ 合言葉ではないものが貼り付けられたようです（「$(printf '%s' "$RAW" | cut -c1-4)」で始まる ${#RAW}文字）。"
    echo '      合言葉は「s%3A」で始まる、80〜90文字くらいの文字です。'
    echo '      Safari で「値」をダブルクリックして、値が青く選ばれた状態になってから'
    echo '      Command + A → Command + C でコピーし、ここに貼り付けて return キーを押してください。'
  fi
done
echo ''
# 全部は表示せず、文字数と最初の4文字だけ見せる（コピーがうまくいったかの目安）
echo "   受け取った合言葉: ${#SID}文字（「$(printf '%s' "$SID" | cut -c1-4)」で始まる）"
(umask 077; printf '%s' "$SID" > "$DIR/sid")
echo '✅ 2/5 合言葉を保存しました'

# 3) つながるか確かめる
echo ''
if ! "$DIR/post.sh" check; then
  echo ''
  echo '❌ Substack につながりませんでした。上のメッセージを Claude に伝えてください。'
  exit 1
fi
echo '✅ 3/5 Substack につながりました'

# 4) 毎朝 7:00 の予約
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
echo '✅ 4/5 毎朝 7:00 に投稿する予約を入れました'

# 5) 7:00 に Mac を起こす（投稿中は caffeinate でスリープしないようにしている）
echo ''
if pmset -g sched 2>/dev/null | grep -qiE 'wake.*7:00 ?AM'; then
  echo '   （Mac を起こす設定はもう入っているので、パスワードの入力はいりません）'
else
  echo '👉 スリープ中でも Mac を起こすために、Mac のパスワードを入力して return キーを押してください。'
  echo '   （Mac にログインするときのパスワードです。入力しても画面には何も表示されません）'
  sudo pmset repeat wakeorpoweron MTWRFSU 07:00:00
fi
echo '✅ 5/5 毎朝 7:00 に Mac を起こす設定をしました'

echo ''
echo '🎉 設定がすべて終わりました！'
echo '   毎朝 7:00 に投稿します。夜は充電器につないでおいてください。'
echo ''

# 今日の分をすぐ投稿するか
echo '👉 今日の分を、今すぐ1回投稿しますか？'
echo '   投稿するなら y 、しないなら n を入力して return キーを押してください。'
read -r ANSWER < /dev/tty
if [ "$ANSWER" = y ] || [ "$ANSWER" = Y ]; then
  "$DIR/post.sh" || echo '❌ 投稿できませんでした。上のメッセージを Claude に伝えてください。'
fi
echo ''
