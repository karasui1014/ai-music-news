#!/usr/bin/env python3
"""
Studio Next 機能紹介の図解（12枚）を作る。

使い方:  python3 gen.py   → 01〜12 の .html ができる（画像にするのは別の手順）

キャラの絵:
  いまは chara-sheet.png（キャラシート）を仮に切り抜いて使っている。
  ドモAIで作った絵が届いたら、chara/ フォルダに
    big-01.png 〜 big-12.png（大きい悠ちゃん・背景は白）
    face-a.png 〜 face-c.png（小さい悠ちゃん・背景は白）
  を置けば、自動でそちらに切り替わる。
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
STYLE = open(os.path.join(HERE, 'guide-style.txt'), encoding='utf8').read()

PLANS = {
    'premium': ('plan-premium', 'Studio Premium'),
    'master': ('plan-master', 'Studio Master'),
    'creator': ('plan-creator', 'Studio Creator'),
    'free': ('plan-free', '無料で使える'),
}

# 1枚ずつの中身。say はステップごとの小さい悠ちゃんのひとこと（やさしい先輩）
CARDS = [
    dict(slug='lyrics-review', emoji='✍️', name='歌詞レビュー', plan='premium', place='「つくる」→ 歌詞レビュー',
         catch='<mark>字余り・韻・構成</mark>をチェックして、<mark>行ごとに直し方</mark>を出してくれる。',
         steps=[('入れる', '歌詞・ジャンル・<br>感情・聴き手', 'まずは歌詞を貼って、気持ちも入れてね'),
                ('チェック', '「まず直すなら<br>ここ」がわかる', '字余りは「歌う拍」で数えるのがコツだよ'),
                ('えらぶ', '行ごとに「採用」か<br>「このまま」', '残したい言葉は、そのままでいいんだよ')],
         points=[('🔒', '歌詞は外に送られない<br>（端末の中で処理）'), ('📋', '直した歌詞を<br>そのままコピーできる')]),
    dict(slug='mv-idea', emoji='🎬', name='MVアイデア', plan='premium', place='「つくる」→ MVアイデア',
         catch='曲の情報から<mark>企画案を3つ</mark>。選んだ案を<mark>ショットとプロンプト</mark>まで広げてくれる。',
         steps=[('入れる', '曲のテーマや<br>聴いてほしい場面', 'どんな場面で聴く曲か、書いてみてね'),
                ('えらぶ', '3つの企画案から<br>好きな案を1つ', '冒頭3秒とサビの見せ方も出るよ'),
                ('ひろげる', 'ショットごとに<br>画像・動画プロンプト', 'コピーして、そのまま生成に使えるよ')],
         points=[('🎞', '縦型・横型どちらもOK<br>（秒数つきショットリスト）'), ('✅', '制作チェックリストつきで<br>迷わず進められる')]),
    dict(slug='ai-producer', emoji='🎛', name='AIプロデューサー', plan='premium', place='「つくる」→ AIプロデューサー',
         catch='曲の狙いと素材から、<mark>どこをどう直すか</mark>を<mark>優先順位つき</mark>で出してくれる。',
         steps=[('入れる', '狙い・聴き手・公開先<br>＋歌詞やプロンプト', '誰に届けたい曲か、教えてね'),
                ('わかる', '「いちばん大きな問題」<br>と直す順番', '全部じゃなくて、まず1つでいいんだよ'),
                ('直す', 'なぜ・どうする・<br>期待できる変化', '直したプロンプトもコピーできるよ')],
         points=[('🎯', '「いま直す」と「あとで」<br>に分けてくれる'), ('📝', '歌詞・プロンプト・構成・<br>タイトルをまとめて見る')]),
    dict(slug='prompt-dex', emoji='📚', name='プロンプト工房', plan='premium', place='「つくる」→ プロンプト工房',
         catch='使えるプロンプトを<mark>探して、コピーして</mark>、<mark>★で貯めて</mark>おける。',
         steps=[('さがす', 'キーワードや<br>ジャンルで絞り込み', '「lo-fi」「夜」みたいに探してね'),
                ('コピー', 'ボタン1つで<br>そのまま使える', 'はじめての人向けの印もあるよ'),
                ('ためる', '★をつけて<br>お気に入りに', 'よく使うのは★でまとめておこう')],
         points=[('💡', 'うまくいく点・つまずく点・<br>調整のしかたつき'), ('⭐', '★だけ表示で<br>自分だけの棚になる')]),
    dict(slug='storyboard', emoji='🎬', name='絵コンテツール', plan='premium', place='「つくる」→ 外部ツール → 絵コンテツール',
         catch='曲と歌詞から、MVの<mark>カット割り・構成</mark>を<mark>絵コンテ</mark>にしてくれる。',
         steps=[('読み込む', '楽曲ファイルと<br>歌詞を入れる', '曲と歌詞、両方そろえば準備OKだよ'),
                ('しるす', '再生しながら<br>「スタンプ」でカット位置', '切り替えたい所でポンと押してね'),
                ('生成する', 'カット数は<br>曲から自動で計算', '5分の曲なら150カットくらいだよ')],
         points=[('🎨', '参考動画を入れると<br>色やトーンを反映'), ('📄', 'SRT・LRCの<br>歌詞ファイルも読める')]),
    dict(slug='mastering', emoji='🎚', name='マスタリング自動生成', plan='premium', place='「つくる」→ 外部ツール → マスタリング自動生成ツール',
         catch='音源を入れて<mark>スタイルを選ぶだけ</mark>。<mark>マスタリング設定</mark>を作ってくれる。',
         steps=[('読み込む', '音源をドラッグ<br>（2mix推奨）', 'ミックスした音源を入れてね'),
                ('えらぶ', 'スタイルと<br>かかり具合', 'EQの効き方も点線で見えるよ'),
                ('聴きくらべ', '原音 ⇄ マスター後<br>を切り替え', '音量をそろえて比べられるよ')],
         points=[('🔒', '端末の中で処理<br>（アップロードしない）'), ('🎛', '手動EQ（±12dB）で<br>細かく調整もできる')]),
    dict(slug='guitar-chord-tab', emoji='🎸', name='ギターコードTAB', plan='premium', place='「つくる」→ 外部ツール → ギターコードTAB',
         catch='ギターの音源から<mark>コード進行</mark>と<mark>TAB譜</mark>を作ってくれる。',
         steps=[('入れる', 'ギター音源・<br>元の曲・歌詞', '分けたギターの音を入れてね'),
                ('解析する', '「コードを解析する」<br>を押すだけ', '弾きやすい押さえ方で出してくれるよ'),
                ('なおす', 'ちがうコードは<br>クリックで修正', 'カポを使った簡単コードにもできるよ')],
         points=[('💾', '音源・歌詞・コードTABを<br>端末に保存できる'), ('⏎', 'Enterキーで<br>歌詞の位置合わせ')]),
    dict(slug='subtitle', emoji='💬', name='字幕自動生成ツール', plan='master', place='「つくる」→ 外部ツール → 字幕自動生成ツール',
         catch='歌詞から<mark>字幕（テロップ）</mark>を作って、<mark>タイミングも自動</mark>で合わせてくれる。',
         steps=[('入れる', '音源と<br>正しい歌詞', '歌詞はコピペでOKだよ'),
                ('自動生成', '各行のタイミングを<br>音源と照合', '文字はそのままだから誤字は出ないよ'),
                ('完成', 'そのまま<br>動画にできる', '編集ソフトがなくても作れるよ')],
         points=[('✂️', '「/」かスペースで<br>好きな所で改行'), ('🎯', 'ずれた時は<br>1行目を手で合わせられる')]),
    dict(slug='style-prompt', emoji='🎵', name='スタイルプロンプト工房', plan='free', place='「つくる」→ 外部ツール → スタイルプロンプト工房',
         catch='歌詞を入れて<mark>ポチポチ選ぶだけ</mark>。Sunoの<mark>スタイルプロンプト</mark>を組み立ててくれる。',
         steps=[('入れる', '歌詞を入れて<br>雰囲気を提案してもらう', '人気レシピから始めても速いよ'),
                ('えらぶ', 'ジャンル・ムード・<br>ボーカル・テンポ', '最初に選んだジャンルが主役だよ'),
                ('コピー', 'AIに伝わりやすい<br>語順で完成', 'タグ付き歌詞もそのまま使えるよ')],
         points=[('🆓', '無料で<br>だれでも使える'), ('🏷️', 'セクションタグも<br>自動でつけてくれる')]),
    dict(slug='review', emoji='📝', name='楽曲批評ツール', plan='master', place='「つくる」→ 外部ツール → 楽曲批評ツール',
         catch='できた曲を<mark>プロデューサー・評論家・リスナー</mark>の<mark>3つの目線</mark>で批評してくれる。',
         steps=[('アップロード', '曲のファイルと<br>歌詞（任意）', 'インスト曲なら歌詞はなくていいよ'),
                ('えらぶ', 'ジャンル・応募先の<br>傾向と批評の口調', '甘口なら、良いところ中心だよ'),
                ('チェック', '客観的な批評と<br>改善案', 'コンペに出す前に見ておこうね')],
         points=[('🎧', 'MP3・WAV・FLACなど<br>100MBまで'), ('🧭', '3つの視点で<br>ひとりよがりを防ぐ')]),
    dict(slug='seedance-batch', emoji='🎞', name='Seedance Batch Studio', plan='creator', place='「つくる」→ 外部ツール → Seedance Batch Studio',
         catch='動画の素材を<mark>まとめて</mark>、<mark>いっぺんに生成</mark>できる。',
         steps=[('用意する', '作りたい素材を<br>まとめて準備', '1本ずつ待たなくていいよ'),
                ('まとめて生成', 'バッチで<br>いっぺんに作る', 'そのあいだに別の作業ができるよ'),
                ('えらぶ', 'できた素材から<br>使うものを選ぶ', 'MVの素材集めがラクになるよ')],
         points=[('🎞', 'MVや動画の<br>素材集めに'), ('⏱', '1本ずつ待つ手間を<br>へらせる')]),
    dict(slug='seedance-prompt', emoji='🎥', name='シーダンス2.5 プロンプト工房', plan='creator', place='「つくる」→ 外部ツール → シーダンス2.5 プロンプト工房',
         catch='Seedance 2.5用のプロンプトを<mark>香盤表</mark>の形で<mark>組み立てて</mark>くれる。',
         steps=[('えらぶ', '「かんたん」か<br>「こだわり」', 'まずは3つ埋めるだけでOKだよ'),
                ('そろえる', '参考画像と<br>主役を決める', '画像は4〜7枚がちょうどいいよ'),
                ('つくりこむ', '1カットずつ<br>演出を組み立てる', '慣れたらフル演出も同じ画面でね')],
         points=[('💾', '作品を保存・<br>JSONで書き出しできる'), ('🖼', '素材ゼロでも<br>始められる')]),
]


def chara_css(no):
    """ドモAIの絵があればそれを、なければキャラシートの仮の絵を使う"""
    big = f'chara/big-{no:02d}.png'
    css = ''
    if os.path.exists(os.path.join(HERE, big)):
        css += f'.guide .big {{ background: url({big}) no-repeat center bottom / contain; -webkit-mask-image: none; }}\n'
    for k, face in zip(('f1', 'f2', 'f3'), ('face-a', 'face-b', 'face-c')):
        path = f'chara/{face}.png'
        if os.path.exists(os.path.join(HERE, path)):
            css += f'.face.{k} {{ background: #fff url({path}) no-repeat center / cover; }}\n'
    return css


def build(no, c):
    plan_class, plan_label = PLANS[c['plan']]
    name = c['name']
    title_size = 68 if len(name) <= 8 else (56 if len(name) <= 12 else 46)
    steps = ''
    for i, (h, desc, say) in enumerate(c['steps'], 1):
        if i > 1:
            steps += '        <div class="arrow">▶</div>\n'
        steps += f'''        <div class="step">
          <span class="n">STEP {i}</span>
          <h3>{h}</h3>
          <p class="desc">{desc}</p>
          <div class="say"><div class="face f{i}"></div><p>{say}</p></div>
        </div>
'''
    points = ''.join(f'        <div class="point"><span class="i">{icon}</span>{text}</div>\n' for icon, text in c['points'])
    hello_name = name if len(name) <= 10 else name.replace(' ', '<br>', 1)
    return f'''<!doctype html>
<html lang="ja"><head><meta charset="utf-8"><link rel="stylesheet" href="base.css">
{STYLE}
<style>
  h1 {{ font-size: {title_size}px; }}
{chara_css(no)}</style></head>
<body class="{plan_class}">
<div class="blob a"></div><div class="blob b"></div>
<div class="page">
  <div class="top">
    <span class="brand">AI音楽部 Studio</span>
    <span class="no">機能紹介 {no:02d} / {len(CARDS)}</span>
    <span class="plan-chip">{plan_label}</span>
  </div>

  <div class="main">
    <div class="left">
      <div class="title">
        <div class="emoji">{c['emoji']}</div>
        <h1>{name}</h1>
      </div>
      <p class="catch">{c['catch']}</p>

      <div class="steps">
{steps}      </div>

      <div class="points">
{points}      </div>
    </div>

    <div class="guide">
      <div class="hello">今日は<br>「{hello_name}」を<br>紹介するね！</div>
      <div class="big"></div>
    </div>
  </div>

  <div class="foot">
    <span>{c['place']}</span>
    <span>karasui1014.github.io/studio-next</span>
  </div>
</div>
</body></html>
'''


if __name__ == '__main__':
    for no, c in enumerate(CARDS, 1):
        path = os.path.join(HERE, f'{no:02d}-{c["slug"]}.html')
        open(path, 'w', encoding='utf8').write(build(no, c))
        print(path)
