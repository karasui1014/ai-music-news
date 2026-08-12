#!/bin/bash
# ダブルクリックすると、最新のAI音楽ニュースを集めて data/news.json を更新します。

cd "$(dirname "$0")" || exit 1

echo ""
echo "════════════════════════════════════════"
echo "  AI音楽ニュース  更新"
echo "════════════════════════════════════════"
echo ""

if ! command -v node >/dev/null 2>&1; then
  echo "⚠️  Node.js が見つかりません。"
  echo "   https://nodejs.org/ja からインストールしてから、もう一度実行してください。"
  echo ""
  read -n 1 -s -r -p "何かキーを押すと閉じます..."
  exit 1
fi

node collect.mjs
status=$?

echo ""
if [ $status -eq 0 ]; then
  echo "✅ 更新が終わりました。"
  echo "   「ローカルで確認.command」で表示を確認できます。"
else
  echo "❌ 更新に失敗しました（上のメッセージを確認してください）。"
fi
echo ""
read -n 1 -s -r -p "何かキーを押すと閉じます..."
echo ""
