#!/bin/bash
# ダブルクリックすると、このMacの中だけでページを開いて表示を確認できます。
# （ブラウザの決まりで、ファイルを直接開くとニュースが読み込めないため簡易サーバーを使います）

cd "$(dirname "$0")" || exit 1

PORT=8765

echo ""
echo "════════════════════════════════════════"
echo "  AI音楽ニュース  ローカル確認"
echo "════════════════════════════════════════"
echo ""
echo "  http://localhost:${PORT} を開きます。"
echo "  終わるときは、この画面で Control + C を押してください。"
echo ""

( sleep 1 && open "http://localhost:${PORT}" ) &

python3 -m http.server "${PORT}" --bind 127.0.0.1
