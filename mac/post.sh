#!/bin/bash
# おはスタ 自動投稿（Mac用）
#
# GitHub の songs.txt から1曲をランダムに選び、
# 「おはスタ✨今日の一曲」＋曲のカード で Substack のノートに投稿します。
# Mac に最初から入っている道具（curl / osascript）だけで動きます。
#
# Substack には公式の投稿APIがないため、ブラウザと同じ非公式の入り口を使います。
# Substack 側の変更で、ある日動かなくなる可能性があります。
#
# 使い方:
#   post.sh          … 投稿する（今日すでに投稿していたら何もしない）
#   post.sh check    … 投稿せず、Substack につながるかだけ確かめる
#   post.sh force    … 今日すでに投稿していても、もう一度投稿する

set -u
export LANG=ja_JP.UTF-8

# ---- 投稿する文言（変えたいときはここを書きかえる） ----
MESSAGE='おはスタ✨今日の一曲'

DIR="$HOME/Library/Application Support/ohasuta"
LOG="$HOME/Library/Logs/ohasuta.log"
SONGS_URL='https://raw.githubusercontent.com/karasui1014/ai-music-news/main/songs.txt'
UA='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15'
MODE="${1:-post}"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG"; }
notify() { osascript -e "display notification \"$1\" with title \"おはスタ自動投稿\"" >/dev/null 2>&1 || true; }
fail() { log "❌ $1"; notify "$1"; exit 1; }

today=$(date +%Y-%m-%d)
if [ "$MODE" = post ] && [ "$(cat "$DIR/last-posted" 2>/dev/null)" = "$today" ]; then
  log "今日はもう投稿済みなので、何もしません。"
  exit 0
fi

SID=$(cat "$DIR/sid" 2>/dev/null || true)
[ -n "$SID" ] || fail '合言葉が保存されていません。設定をやり直してください。'

# スリープから起きた直後はネットがつながっていないことがあるので、最大3分待つ
for _ in $(seq 1 36); do
  curl -s -o /dev/null --max-time 5 https://substack.com && break
  sleep 5
done

# Substack に送る。結果は「本文」と「状態番号」を RES_BODY / RES_CODE に入れる
send() {
  local args=(-sS --max-time 30 -X "$1" "https://substack.com/api/v1$2"
    -H "Cookie: substack.sid=$SID" -H 'Accept: application/json'
    -H 'Origin: https://substack.com' -H 'Referer: https://substack.com/home' -A "$UA"
    -w '\n%{http_code}')
  if [ -n "${3:-}" ]; then args+=(-H 'Content-Type: application/json' --data-binary "$3"); fi
  local res
  res=$(curl "${args[@]}") || fail "Substack につながりませんでした（$2）"
  RES_CODE=$(printf '%s\n' "$res" | tail -n 1)
  RES_BODY=$(printf '%s\n' "$res" | sed '$d')
  if printf '%s' "$RES_BODY" | grep -q 'Just a moment'; then
    fail 'Substack の門番（ロボット確認）に止められました。'
  fi
}

# send して、うまくいかなかったら止める
api() {
  send "$@"
  case "$RES_CODE" in
    2??) ;;
    401|403) fail "Substack の合言葉の期限が切れている可能性があります（$RES_CODE）。入れ直してください。" ;;
    *) fail "Substack が $RES_CODE を返しました（$2）: $(printf '%s' "$RES_BODY" | head -c 200)" ;;
  esac
}

if [ "$MODE" = check ]; then
  send GET /subscriptions
  case "$RES_CODE" in
    2??) log '✅ 合言葉OK。Substack につながりました（投稿はしていません）。' ;;
    401|403) fail "Substack の合言葉が正しくないようです（$RES_CODE）。コピーし直してください。" ;;
    *) log "✅ Substack の門番は通れました（合言葉の確認はできませんでした: $RES_CODE）。" ;;
  esac
  exit 0
fi

# 曲リストを GitHub から取ってくる（取れなかったら前回の分を使う）
if curl -fsS --max-time 20 "$SONGS_URL" -o "$DIR/songs.txt.new"; then
  mv "$DIR/songs.txt.new" "$DIR/songs.txt"
else
  log '⚠️ 曲リストを取れなかったので、前回の分を使います。'
fi
[ -f "$DIR/songs.txt" ] || fail '曲リストがありません。'

ids=$(grep -v '^[[:space:]]*#' "$DIR/songs.txt" \
  | grep -oE '(open\.spotify\.com/(intl-[a-z-]+/)?track/|spotify:track:)[A-Za-z0-9]{22}' \
  | grep -oE '[A-Za-z0-9]{22}$' | sort -u)
count=$(printf '%s\n' "$ids" | grep -c . || true)
[ "$count" -gt 0 ] || fail 'songs.txt に曲のリンクが1つもありません。'

song="https://open.spotify.com/track/$(printf '%s\n' "$ids" | sed -n "$((RANDOM % count + 1))p")"
log "🎵 ${count}曲の中から選びました: $song"

# 1) 曲のリンクを「カード」として登録する
api POST /comment/attachment "{\"url\":\"$song\",\"type\":\"link\"}"
att_id=$(osascript -l JavaScript -e 'function run(a){var o=JSON.parse(a[0]);return o.id===undefined?"":JSON.stringify(o.id)}' "$RES_BODY" 2>/dev/null || true)
[ -n "$att_id" ] || fail "曲のカードを作れませんでした: $(printf '%s' "$RES_BODY" | head -c 200)"

# 2) 文言＋カードでノートを投稿する
note=$(osascript -l JavaScript -e 'function run(a){return JSON.stringify({
  bodyJson:{type:"doc",attrs:{schemaVersion:"v1"},content:[{type:"paragraph",content:[{type:"text",text:a[0]}]}]},
  attachmentIds:[JSON.parse(a[1])],tabId:"for-you",surface:"feed",replyMinimumRole:"everyone"})}' "$MESSAGE" "$att_id")
api POST /comment/feed "$note"

echo "$today" > "$DIR/last-posted"
log '✅ 投稿しました！'
notify '今日の一曲を投稿しました🎵'
