#!/usr/bin/env python3
"""
Studio Next 機能紹介の図解 v2（11枚）を作る。

使い方:  python3 gen2.py   → v2-01.html 〜 v2-11.html ができる

文章の中の「|」は「ここでなら改行してよい」という印。
それ以外の場所では改行しないので、言葉の途中で折り返されない。

ドモAIの絵:
  art/zukai-01.png 〜 art/zukai-11.png を置くと、背景に使う。
  FACE に顔の位置を書くと、その絵から小さい悠ちゃんの顔を切り抜く。
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))

PLANS = {
    'premium': ('plan-premium', 'Studio Premium'),
    'master': ('plan-master', 'Studio Master'),
    'creator': ('plan-creator', 'Studio Creator'),
    'free': ('plan-free', '無料で使える'),
}

# 小さい悠ちゃんの顔を、背景の絵のどこから切り抜くか（絵が届いてから合わせる）
#   番号: (背景の大きさpx, 横の位置px, 縦の位置px)
FACE = {}

CARDS = [
    dict(slug='lyrics-review', emoji='✍️', name='歌詞レビュー', plan='premium', place='「つくる」→ 歌詞レビュー',
         catch='<mark>字余り・|韻・|構成</mark>を|チェックして、|<mark>行ごとの|直し方</mark>を|出してくれる。',
         steps=[('歌詞と条件を入れる', 'ジャンル・|感情・|聴き手も|いっしょに', 'まずは|歌詞を|貼って、|気持ちも|入れてね'),
                ('チェックしてもらう', '「まず|直すなら|ここ」が|わかる', '字余りは|「歌う拍」で|数えるのが|コツだよ'),
                ('行ごとに選ぶ', '「採用」か|「このまま」を|1行ずつ|選べる', '残したい|言葉は、|そのままで|いいんだよ')],
         points=[('🔒', '歌詞は|外に|送られない|（端末の中で|処理）'), ('📋', '直した|歌詞を|そのまま|コピーできる')]),
    dict(slug='mv-idea', emoji='🎬', name='MVアイデア', plan='premium', place='「つくる」→ MVアイデア',
         catch='曲の情報から|<mark>企画案を|3つ</mark>。|選んだ案を|<mark>ショットと|プロンプト</mark>まで|広げてくれる。',
         steps=[('曲の情報を入れる', '曲の|テーマや|聴いてほしい|場面', 'どんな|場面で|聴く曲か、|書いてみてね'),
                ('企画案を選ぶ', '3つの|企画案から|1つを|選ぶ', '冒頭3秒と|サビの|見せ方も|出るよ'),
                ('ショットに広げる', 'ショットごとに|画像・|動画の|プロンプト', 'コピーして、|そのまま|生成に|使えるよ')],
         points=[('🎞', '縦型・|横型どちらも|OK'), ('✅', '制作|チェックリストつき')]),
    dict(slug='ai-producer', emoji='🎛', name='AIプロデューサー', plan='premium', place='「つくる」→ AIプロデューサー',
         catch='曲の狙いと|素材から、|<mark>どこを|どう直すか</mark>を|<mark>優先順位つき</mark>で|出してくれる。',
         steps=[('狙いと素材を入れる', '狙い・|聴き手・|公開先と|歌詞など', '誰に|届けたい|曲か、|教えてね'),
                ('問題がわかる', '「いちばん|大きな|問題」と|直す順番', '全部じゃなくて、|まず|1つで|いいんだよ'),
                ('直し方を見る', 'なぜ・|どうする・|期待できる|変化', '直した|プロンプトも|コピーできるよ')],
         points=[('🎯', '「いま直す」と|「あとで」に|分けてくれる'), ('📝', '歌詞・|構成・|タイトルも|まとめて見る')]),
    dict(slug='prompt-dex', emoji='📚', name='プロンプト工房', plan='premium', place='「つくる」→ プロンプト工房',
         catch='使えるプロンプトを|<mark>探して、|コピーして</mark>、|<mark>★で|貯めて</mark>おける。',
         steps=[('探す', 'キーワードや|ジャンルで|絞り込む', '「lo-fi」|「夜」みたいに|探してね'),
                ('コピーする', 'ボタン1つで|そのまま|使える', 'はじめての|人向けの|印もあるよ'),
                ('★で貯める', 'お気に入りに|入れて、|★だけ表示', 'よく使うのは|★で|まとめておこう')],
         points=[('💡', 'うまくいく点・|つまずく点・|調整のしかたつき'), ('⭐', '自分だけの|棚になる')]),
    dict(slug='storyboard', emoji='🎬', name='絵コンテツール', plan='premium', place='「つくる」→ 外部ツール → 絵コンテツール',
         catch='曲と歌詞から、|MVの|<mark>カット割り・|構成</mark>を|<mark>絵コンテ</mark>に|してくれる。',
         steps=[('曲と歌詞を入れる', '楽曲ファイルと|歌詞を|読み込む', '曲と歌詞、|両方|そろえば|準備OKだよ'),
                ('カット位置を記録', '再生しながら|「スタンプ」を|押す', '切り替えたい|所で|ポンと|押してね'),
                ('絵コンテを生成', 'カット数は|曲から|自動で|計算', '5分の曲なら|150カット|くらいだよ')],
         points=[('🎨', '参考動画で|色やトーンを|反映'), ('📄', 'SRT・|LRCの|歌詞ファイルも|読める')]),
    dict(slug='mastering', emoji='🎚', name='マスタリング自動生成', plan='premium', place='「つくる」→ 外部ツール → マスタリング自動生成ツール',
         catch='音源を入れて|<mark>スタイルを|選ぶだけ</mark>。|<mark>マスタリング設定</mark>を|作ってくれる。',
         steps=[('音源を読み込む', 'ドラッグで|入れるだけ|（2mix推奨）', 'ミックスした|音源を|入れてね'),
                ('スタイルを選ぶ', 'スタイルと|かかり具合を|決める', 'EQの|効き方も|点線で|見えるよ'),
                ('聴きくらべる', '原音と|マスター後を|切り替え', '音量を|そろえて|比べられるよ')],
         points=[('🔒', '端末の中で|処理|（アップロードしない）'), ('🎛', '手動EQで|細かく|調整もできる')]),
    dict(slug='guitar-chord-tab', emoji='🎸', name='ギターコードTAB', plan='premium', place='「つくる」→ 外部ツール → ギターコードTAB',
         catch='ギターの音源から|<mark>コード進行</mark>と|<mark>TAB譜</mark>を|作ってくれる。',
         steps=[('音源と歌詞を入れる', 'ギター音源・|元の曲・|歌詞', '分けた|ギターの|音を|入れてね'),
                ('コードを解析する', 'ボタンを|押すだけ', '弾きやすい|押さえ方で|出してくれるよ'),
                ('まちがいを直す', 'ちがうコードは|クリックで|修正', 'カポを使った|簡単コードにも|できるよ')],
         points=[('💾', '音源・|歌詞・|TABを|端末に保存'), ('⏎', 'Enterキーで|歌詞の|位置合わせ')]),
    dict(slug='subtitle', emoji='💬', name='字幕自動生成ツール', plan='master', place='「つくる」→ 外部ツール → 字幕自動生成ツール',
         catch='歌詞から|<mark>字幕（テロップ）</mark>を|作って、|<mark>タイミングも|自動</mark>で|合わせてくれる。',
         steps=[('音源と歌詞を入れる', '正しい|歌詞を|貼り付ける', '歌詞は|コピペで|OKだよ'),
                ('タイミングを自動生成', '各行の|タイミングを|音源と|照合', '文字は|そのままだから|誤字は|出ないよ'),
                ('動画にする', 'そのまま|完成動画まで', '編集ソフトが|なくても|作れるよ')],
         points=[('✂️', '「/」か|スペースで|好きな所で|改行'), ('🎯', 'ずれた時は|1行目を|手で|合わせられる')]),
    dict(slug='style-prompt', emoji='🎵', name='スタイルプロンプト工房', plan='free', place='「つくる」→ 外部ツール → スタイルプロンプト工房',
         catch='歌詞を入れて|<mark>ポチポチ|選ぶだけ</mark>。|Sunoの|<mark>スタイルプロンプト</mark>を|組み立ててくれる。',
         steps=[('歌詞を入れる', '雰囲気を|提案して|もらえる', '人気レシピから|始めても|速いよ'),
                ('ポチポチ選ぶ', 'ジャンル・|ムード・|ボーカル・|テンポ', '最初に|選んだ|ジャンルが|主役だよ'),
                ('コピーする', 'AIに|伝わりやすい|語順で|完成', 'タグ付き歌詞も|そのまま|使えるよ')],
         points=[('🆓', '無料で|だれでも|使える'), ('🏷️', 'セクションタグも|自動で|つけてくれる')]),
    dict(slug='review', emoji='📝', name='楽曲批評ツール', plan='master', place='「つくる」→ 外部ツール → 楽曲批評ツール',
         catch='できた曲を|<mark>プロデューサー・|評論家・|リスナー</mark>の|<mark>3つの目線</mark>で|批評してくれる。',
         steps=[('曲をアップロード', '曲のファイルと|歌詞（任意）', 'インスト曲なら|歌詞は|なくていいよ'),
                ('条件を選ぶ', 'ジャンル・|応募先の|傾向・|批評の口調', '甘口なら、|良いところ|中心だよ'),
                ('批評をチェック', '客観的な|批評と|改善案', 'コンペに|出す前に|見ておこうね')],
         points=[('🎧', 'MP3・|WAV・|FLACなど|100MBまで'), ('🧭', '3つの視点で|ひとりよがりを|防ぐ')]),
    dict(slug='seedance-prompt', emoji='🎥', name='シーダンス2.5 |プロンプト工房', plan='creator', place='「つくる」→ 外部ツール → シーダンス2.5 プロンプト工房',
         catch='Seedance 2.5用の|プロンプトを|<mark>香盤表</mark>の形で|<mark>組み立てて</mark>|くれる。',
         steps=[('モードを選ぶ', '「かんたん」か|「こだわり」', 'まずは|3つ|埋めるだけで|OKだよ'),
                ('素材と主役を決める', '参考画像と|主役を|そろえる', '画像は|4〜7枚が|ちょうどいいよ'),
                ('1カットずつ作る', '演出を|組み立てて|いく', '慣れたら|フル演出も|同じ画面でね')],
         points=[('💾', '作品を|保存・|JSONで|書き出し'), ('🖼', '素材ゼロでも|始められる')]),
]


def wbr(text):
    return text.replace('|', '<wbr>')


def build(no, c):
    plan_class, plan_label = PLANS[c['plan']]
    plain_name = c['name'].replace('|', ' ')
    name_len = len(c['name'].replace('|', ''))
    h1 = 58 if name_len <= 9 else (50 if name_len <= 12 else 44)

    art = f'art/zukai-{no:02d}.png'
    has_art = os.path.exists(os.path.join(HERE, art))
    vars_ = []
    if has_art:
        vars_.append(f'--art: url({art})')
    if no in FACE:
        size, x, y = FACE[no]
        vars_ += [f'--face: url({art})', f'--face-size: {size}px auto', f'--face-pos: {x}px {y}px']
    style_attr = f' style="{"; ".join(vars_)}; --h1: {h1}px"' if vars_ else f' style="--h1: {h1}px"'
    face_text = '' if no in FACE else '悠'

    steps = ''.join(f'''      <div class="step">
        <div class="num">{i}</div>
        <div class="what"><h3>{wbr(h)}</h3><p>{wbr(d)}</p></div>
        <div class="say"><div class="face">{face_text}</div><p>{wbr(s)}</p></div>
      </div>
''' for i, (h, d, s) in enumerate(c['steps'], 1))
    points = ''.join(f'      <div class="point"><span class="i">{icon}</span><span>{wbr(t)}</span></div>\n' for icon, t in c['points'])
    placeholder = '' if has_art else '<div class="art-placeholder">ここに<br>ドモAIの絵<br>（右に悠ちゃん）</div>'

    return f'''<!doctype html>
<html lang="ja"><head><meta charset="utf-8"><link rel="stylesheet" href="v2.css"></head>
<body class="{plan_class}"{style_attr}>
<div class="art"></div>
{placeholder}
<div class="panel">
  <div class="top">
    <span class="brand">AI音楽部 Studio</span>
    <span class="no">機能紹介 {no:02d} / {len(CARDS)}</span>
    <span class="plan-chip">{plan_label}</span>
  </div>
  <div class="title">
    <div class="emoji">{c['emoji']}</div>
    <h1>{wbr(c['name'])}</h1>
  </div>
  <p class="catch">{wbr(c['catch'])}</p>
  <div class="steps">
{steps}  </div>
  <div class="points">
{points}  </div>
  <div class="foot"><span>{c['place']}</span><span>karasui1014.github.io/studio-next</span></div>
</div>
<div class="hello">今日は<br><span class="nm">「{wbr(c['name'])}」を</span><br>紹介するね！</div>
</body></html>
'''


if __name__ == '__main__':
    for no, c in enumerate(CARDS, 1):
        path = os.path.join(HERE, f'v2-{no:02d}-{c["slug"]}.html')
        open(path, 'w', encoding='utf8').write(build(no, c))
        print(path)
