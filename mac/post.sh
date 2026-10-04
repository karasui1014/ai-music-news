#!/bin/bash
# おはスタ 自動投稿（Mac用）
#
# GitHub の songs.txt から1曲をランダムに選び、
# Safari で substack.com を開いて「おはスタ✨今日の一曲」＋曲のカード をノートに投稿します。
# Safari でログインしている状態をそのまま使うので、合言葉（Cookie）のコピーはいりません。
#
# 必要な設定:
#   Safari のメニュー「開発」→「Apple EventsからのJavaScriptを許可」にチェック
#
# Substack には公式の投稿APIがないため、ブラウザと同じ非公式の入り口を使います。
# Substack 側の変更で、ある日動かなくなる可能性があります。
#
# 使い方:
#   post.sh          … 投稿する（今日すでに投稿していたら何もしない）
#   post.sh check    … 投稿せず、Safari を操作できるかだけ確かめる
#   post.sh force    … 今日すでに投稿していても、もう一度投稿する
# 設定のときは、$DIR/run-check があれば check として動く（launchd 経由で確認するため）

set -u
export LANG=ja_JP.UTF-8

# ---- 投稿する文言（変えたいときはここを書きかえる） ----
MESSAGE='おはスタ✨今日の一曲'

DIR="$HOME/Library/Application Support/ohasuta"
LOG="$HOME/Library/Logs/ohasuta.log"
SONGS_URL='https://raw.githubusercontent.com/karasui1014/ai-music-news/main/songs.txt'
MODE="${1:-post}"
if [ -f "$DIR/run-check" ]; then
  rm -f "$DIR/run-check"
  MODE=check
fi

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG"; }
notify() { osascript -e "display notification \"$1\" with title \"おはスタ自動投稿\"" >/dev/null 2>&1 || true; }
fail() { log "❌ $1"; notify "$1"; exit 1; }

# Safari で substack.com を開き、JavaScript を実行して、その結果（文字）を返す。
# JavaScript は window.__ohasuta に結果を入れる。終わるまで最大90秒待つ。
run_in_safari() {
  osascript - "$1" <<'APPLESCRIPT' 2>&1
on run argv
  set js to item 1 of argv
  tell application "Safari"
    make new document with properties {URL:"https://substack.com/home"}
    delay 1
    -- Safari の設定によっては新しいタブとして開くので、開いたタブそのものを覚えておく
    set theTab to current tab of front window
    -- ページの読み込みを待つ（最大60秒）
    set loaded to false
    repeat 60 times
      delay 1
      try
        if (do JavaScript "document.readyState + ' ' + location.host" in theTab) starts with "complete" then
          set loaded to true
          exit repeat
        end if
      on error errMsg
        if errMsg contains "JavaScript" then
          close theTab
          return "NEED_JS_SETTING " & errMsg
        end if
      end try
    end repeat
    if not loaded then
      close theTab
      return "ERROR substack.com を開けませんでした（ネットの状態を確認してください）"
    end if
    delay 2
    -- 本当に substack.com のページか確かめてから動かす（ほかのタブで動かさないため）
    set theHost to (do JavaScript "location.host" in theTab)
    if theHost is not "substack.com" then
      close theTab
      return "ERROR substack.com ではないページが開いていました: " & theHost
    end if
    do JavaScript js in theTab
    set resultText to "running"
    repeat 90 times
      delay 1
      set resultText to (do JavaScript "String(window.__ohasuta)" in theTab)
      if resultText is not "running" then exit repeat
    end repeat
    -- 開いたタブだけを閉じる
    close theTab
    return resultText
  end tell
end run
APPLESCRIPT
}

# Safari から返ってきた結果を見て、うまくいかなかったら止める
check_result() {
  case "$1" in
    OK*) ;;
    NEED_JS_SETTING*) fail 'Safari の「開発」→「Apple EventsからのJavaScriptを許可」にチェックを入れてください。' ;;
    *1743*|*"not allowed"*|*"許可されていません"*) fail 'Safari を操作する許可がありません。システム設定 → プライバシーとセキュリティ → オートメーション で許可してください。' ;;
    *LOGIN*) fail 'Safari で Substack にログインしていないようです。Safari で substack.com にログインしてください。' ;;
    *) fail "うまくいきませんでした: $(printf '%s' "$1" | head -c 300)" ;;
  esac
}

today=$(date +%Y-%m-%d)
if [ "$MODE" = post ] && [ "$(cat "$DIR/last-posted" 2>/dev/null)" = "$today" ]; then
  log "今日はもう投稿済みなので、何もしません。"
  exit 0
fi

# スリープから起きた直後はネットがつながっていないことがあるので、最大3分待つ
for _ in $(seq 1 36); do
  curl -s -o /dev/null --max-time 5 https://substack.com && break
  sleep 5
done

if [ "$MODE" = check ]; then
  res=$(run_in_safari 'window.__ohasuta = "OK"')
  check_result "$res"
  log '✅ Safari を操作できました（投稿はしていません）。'
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

# Safari の中で動かす JavaScript。
# 1) 曲のリンクを「カード」として登録 → 2) 文言＋カードでノートを投稿
# （Mac の古い bash は $( ) の中のヒアドキュメントを読み間違えることがあるので read で受け取る）
read -r -d '' js <<EOF || true
(function () {
  window.__ohasuta = "running";
  var post = function (path, body) {
    return fetch(path, {
      method: "POST", credentials: "include",
      headers: { "Content-Type": "application/json", "Accept": "application/json" },
      body: JSON.stringify(body)
    }).then(function (r) {
      return r.text().then(function (t) {
        if (r.status === 401 || r.status === 403) throw new Error("LOGIN " + r.status);
        if (r.status >= 300) throw new Error(path + " " + r.status + " " + t.slice(0, 200));
        return t ? JSON.parse(t) : {};
      });
    });
  };
  post("/api/v1/comment/attachment", { url: "$song", type: "link" })
    .then(function (att) {
      if (att.id === undefined) throw new Error("曲のカードを作れませんでした " + JSON.stringify(att).slice(0, 200));
      return post("/api/v1/comment/feed", {
        bodyJson: { type: "doc", attrs: { schemaVersion: "v1" },
          content: [{ type: "paragraph", content: [{ type: "text", text: "$MESSAGE" }] }] },
        attachmentIds: [att.id], tabId: "for-you", surface: "feed", replyMinimumRole: "everyone"
      });
    })
    .then(function () { window.__ohasuta = "OK"; })
    .catch(function (e) { window.__ohasuta = "ERROR " + e.message; });
})();
EOF

res=$(run_in_safari "$js")
check_result "$res"

echo "$today" > "$DIR/last-posted"
log '✅ 投稿しました！'
notify '今日の一曲を投稿しました🎵'
