#!/bin/bash
# スタジオネクストのツール紹介 自動投稿（Mac用）
#
# 毎日 12:00 と 18:00 に、studio-next/intros.json の12個の紹介から1つを選び、
# Safari で substack.com を開いて「紹介文＋画像＋スタジオネクストへのリンク」をノートに投稿します。
# 12個をランダムな順番で一巡するまで、同じ紹介は出しません（一巡したら、また並べ直します）。
# Safari でログインしている状態をそのまま使うので、合言葉（Cookie）のコピーはいりません。
#
# 必要な設定（おはスタと同じ）:
#   Safari のメニュー「開発」→「Apple EventsからのJavaScriptを許可」にチェック
#
# Substack には公式の投稿APIがないため、ブラウザと同じ非公式の入り口を使います。
# Substack 側の変更で、ある日動かなくなる可能性があります。
#
# 使い方:
#   studio-next.sh          … 投稿する（12:00〜17:59 は「昼」、18:00〜 は「夕方」の分。同じ枠は1日1回だけ）
#   studio-next.sh check    … 投稿せず、Safari を操作できるかだけ確かめる
#   studio-next.sh force    … 時間や回数に関係なく、いま1回投稿する
# 設定のときは、$DIR/run-check や $DIR/run-force があれば、それぞれ check / force として動く（launchd 経由で確認するため）

set -u
export LANG=ja_JP.UTF-8

DIR="$HOME/Library/Application Support/studio-next"
LOG="$HOME/Library/Logs/studio-next.log"
INTROS_URL='https://raw.githubusercontent.com/karasui1014/ai-music-news/main/studio-next/intros.json'
MODE="${1:-post}"
if [ -f "$DIR/run-check" ]; then
  rm -f "$DIR/run-check"
  MODE=check
elif [ -f "$DIR/run-force" ]; then
  rm -f "$DIR/run-force"
  MODE=force
fi

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG"; }
notify() { osascript -e "display notification \"$1\" with title \"スタジオネクスト自動投稿\"" >/dev/null 2>&1 || true; }
fail() { log "❌ $1"; notify "$1"; exit 1; }

# Safari で substack.com を開き、JavaScript を実行して、その結果（文字）を返す。
# JavaScript は window.__snext に結果を入れる。終わるまで最大90秒待つ。
run_in_safari() {
  osascript - "$1" <<'APPLESCRIPT' 2>&1
on run argv
  set js to item 1 of argv
  -- 開くページに目印をつけて、あとで「自分が開いたタブ」を確実に見分けられるようにする
  set marker to "studionext=" & ((random number from 100000 to 999999) as text)
  set targetURL to "https://substack.com/home?" & marker
  -- Safari が閉じていたら先に起動して、前回のウインドウが開き直されるのを待つ
  if not (application "Safari" is running) then
    tell application "Safari" to launch
    delay 10
  end if
  tell application "Safari"
    make new document with properties {URL:targetURL}
    -- 目印がついたタブを、すべてのウインドウから探す（最大20秒）
    set theTab to missing value
    repeat 20 times
      delay 1
      try
        repeat with wi from 1 to (count of windows)
          set winId to id of window wi
          repeat with ti from 1 to (count of tabs of window id winId)
            try
              if (URL of tab ti of window id winId) contains marker then
                set theTab to tab ti of window id winId
              end if
            end try
          end repeat
        end repeat
      end try
      if theTab is not missing value then exit repeat
    end repeat
    if theTab is missing value then
      return "ERROR Substack を開いたタブが見つかりませんでした"
    end if
    -- ページの読み込みを待つ（最大60秒）
    set loaded to false
    repeat 60 times
      delay 1
      try
        if (do JavaScript "document.readyState" in theTab) is "complete" then
          set loaded to true
          exit repeat
        end if
      on error errMsg
        if errMsg contains "JavaScript" then
          my closeIfSubstack(theTab)
          return "NEED_JS_SETTING " & errMsg
        end if
      end try
    end repeat
    if not loaded then
      my closeIfSubstack(theTab)
      return "ERROR substack.com を開けませんでした（ネットの状態を確認してください）"
    end if
    delay 2
    -- 本当に substack.com のページか確かめてから動かす（違ったら何もせず、タブも閉じない）
    set theHost to (do JavaScript "location.host" in theTab)
    if theHost is not "substack.com" then
      return "ERROR substack.com ではないページが開いていました: " & theHost
    end if
    do JavaScript js in theTab
    set resultText to "running"
    repeat 90 times
      delay 1
      set resultText to (do JavaScript "String(window.__snext)" in theTab)
      if resultText is not "running" then exit repeat
    end repeat
    my closeIfSubstack(theTab)
    return resultText
  end tell
end run

-- 自分が開いた substack.com のタブだけを閉じる（ほかのタブは絶対に閉じない）
on closeIfSubstack(theTab)
  tell application "Safari"
    try
      if (URL of theTab) starts with "https://substack.com/" then close theTab
    end try
  end tell
end closeIfSubstack
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

mkdir -p "$DIR"
today=$(date +%Y-%m-%d)
hour=$((10#$(date +%H)))

# どの枠（昼／夕方）の投稿かを決める
slot=manual
slot_ja=手動
if [ "$MODE" = post ]; then
  if [ "$hour" -ge 18 ]; then
    slot=evening
  elif [ "$hour" -ge 12 ]; then
    slot=noon
  else
    # 夜中や朝に Mac が起きて、前の日の予約が遅れて動いたときは投稿しない
    log "投稿の時間（12時〜）ではないので、何もしません。"
    exit 0
  fi
  if [ "$slot" = noon ]; then slot_ja=昼; else slot_ja=夕方; fi
  if [ "$(cat "$DIR/last-$slot" 2>/dev/null)" = "$today" ]; then
    log "今日の${slot_ja}の分はもう投稿済みなので、何もしません。"
    exit 0
  fi
fi

# スリープから起きた直後はネットがつながっていないことがあるので、最大3分待つ
for _ in $(seq 1 36); do
  curl -s -o /dev/null --max-time 5 https://substack.com && break
  sleep 5
done

if [ "$MODE" = check ]; then
  res=$(run_in_safari 'window.__snext = "OK"')
  check_result "$res"
  log '✅ Safari を操作できました（投稿はしていません）。'
  exit 0
fi

# 紹介のリストを GitHub から取ってくる（取れなかったら前回の分を使う）
if curl -fsS --max-time 20 "$INTROS_URL" -o "$DIR/intros.json.new"; then
  mv "$DIR/intros.json.new" "$DIR/intros.json"
else
  rm -f "$DIR/intros.json.new"
  log '⚠️ 紹介のリストを取れなかったので、前回の分を使います。'
fi
[ -f "$DIR/intros.json" ] || fail '紹介のリストがありません。'

all_ids=$(grep -oE '"id"[[:space:]]*:[[:space:]]*"[0-9A-Za-z_-]+"' "$DIR/intros.json" \
  | sed -E 's/.*"([0-9A-Za-z_-]+)"$/\1/')
[ -n "$all_ids" ] || fail 'intros.json に紹介が1つもありません。'

# 順番待ちの列（queue）から、今もリストにある紹介だけを残す
QUEUE="$DIR/queue"
touch "$QUEUE"
printf '%s\n' "$all_ids" > "$DIR/all-ids"
grep -xF -f "$DIR/all-ids" "$QUEUE" > "$QUEUE.tmp" || true
mv "$QUEUE.tmp" "$QUEUE"

# 列が空になったら、全部をランダムに並べ直す（前回と同じ紹介が続かないようにする）
if [ ! -s "$QUEUE" ]; then
  last=$(cat "$DIR/last-id" 2>/dev/null || true)
  printf '%s\n' "$all_ids" | awk 'BEGIN { srand() } { print rand() "\t" $0 }' | sort -n | cut -f2 > "$QUEUE"
  if [ -n "$last" ] && [ "$(head -n 1 "$QUEUE")" = "$last" ] && [ "$(wc -l < "$QUEUE" | tr -d ' ')" -gt 1 ]; then
    { tail -n +2 "$QUEUE"; echo "$last"; } > "$QUEUE.tmp" && mv "$QUEUE.tmp" "$QUEUE"
  fi
  log "🔀 紹介の順番を並べ直しました: $(tr '\n' ' ' < "$QUEUE")"
fi

id=$(head -n 1 "$QUEUE")
# 変数の直後に全角文字が来るときは必ず ${ } で囲む。
# Mac の古い bash（3.2）は「$id（」の「（」の一部まで変数名として読んでしまい、
# set -u のせいで「unbound variable」で黙って止まる（2026-10-11 に実際に起きた）
log "🧰 今回の紹介: ${id}（${slot_ja}）"

# Safari の中で動かす JavaScript。
# 1) 紹介文と画像を GitHub から読む → 2) 画像を Substack に上げる → 3) 紹介文＋画像＋リンクでノートを投稿
#    画像だけうまくいかなかったときは、スタジオネクストのリンクのカードを付けて投稿する
# （Mac の古い bash は $( ) の中のヒアドキュメントを読み間違えることがあるので read で受け取る）
read -r -d '' js <<EOF || true
(function () {
  window.__snext = "running";
  var BASE = "https://raw.githubusercontent.com/karasui1014/ai-music-news/main/studio-next/";
  var SITE = "https://karasui1014.github.io/studio-next/";
  var ID = "$id";
  var note = "";
  var item = null;
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
  var toDataURL = function (blob) {
    return new Promise(function (resolve, reject) {
      var fr = new FileReader();
      fr.onload = function () { resolve(fr.result); };
      fr.onerror = function () { reject(new Error("画像を読めませんでした")); };
      fr.readAsDataURL(blob);
    });
  };
  var paragraph = function (line) {
    if (line === "") return { type: "paragraph" };
    var text = { type: "text", text: line };
    if (line === SITE) text.marks = [{ type: "link", attrs: { href: SITE } }];
    return { type: "paragraph", content: [text] };
  };
  fetch(BASE + "intros.json?t=" + Date.now())
    .then(function (r) { if (!r.ok) throw new Error("intros.json " + r.status); return r.json(); })
    .then(function (list) {
      for (var i = 0; i < list.length; i++) if (list[i].id === ID) item = list[i];
      if (!item) throw new Error("紹介 " + ID + " が見つかりませんでした");
      return fetch(BASE + item.image)
        .then(function (r) { if (!r.ok) throw new Error("画像 " + r.status); return r.blob(); })
        .then(toDataURL)
        .then(function (dataUrl) { return post("/api/v1/image", { image: dataUrl }); })
        .then(function (img) {
          if (!img.url) throw new Error("画像のURLがもらえませんでした");
          return post("/api/v1/comment/attachment", { url: img.url, type: "image" });
        })
        .then(function (att) {
          if (att.id === undefined) throw new Error("画像のカードを作れませんでした");
          return att.id;
        })
        .catch(function (e) {
          if (String(e.message).indexOf("LOGIN") === 0) throw e;
          note = " (画像なしでリンクのカードを付けました: " + String(e.message).slice(0, 120) + ")";
          return post("/api/v1/comment/attachment", { url: SITE, type: "link" })
            .then(function (att) { return att.id; })
            .catch(function () { return null; });
        });
    })
    .then(function (attId) {
      var lines = item.lines.concat(["", "▼ スタジオネクストはこちら", SITE]);
      var body = {
        bodyJson: { type: "doc", attrs: { schemaVersion: "v1" }, content: lines.map(paragraph) },
        tabId: "for-you", surface: "feed", replyMinimumRole: "everyone"
      };
      if (attId !== null && attId !== undefined) body.attachmentIds = [attId];
      return post("/api/v1/comment/feed", body);
    })
    .then(function () { window.__snext = "OK" + note; })
    .catch(function (e) { window.__snext = "ERROR " + e.message; });
})();
EOF

res=$(run_in_safari "$js")
check_result "$res"

# 投稿できたら、列の先頭を消して記録する
tail -n +2 "$QUEUE" > "$QUEUE.tmp" && mv "$QUEUE.tmp" "$QUEUE"
echo "$id" > "$DIR/last-id"
[ "$slot" = manual ] || echo "$today" > "$DIR/last-$slot"
case "$res" in
  "OK ("*) log "⚠️ ${res#OK }" ;;
esac
log "✅ 投稿しました！（紹介 ${id}）"
notify "ツール紹介を投稿しました🧰"
