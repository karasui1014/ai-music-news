#!/usr/bin/env node
/**
 * おはスタ 自動投稿
 *
 * songs.txt に並べた Spotify の曲から1曲をランダムに選び、
 * 「おはスタ✨今日の一曲」＋曲のカード で Substack のノートに投稿します。
 *
 * Substack には公式の投稿用APIがないため、ブラウザと同じ非公式の入り口を使います。
 * Substack 側の変更で、ある日動かなくなる可能性があります。
 *
 * 必要な環境変数:
 *   SUBSTACK_SID  … Substack にログインしたときの Cookie「substack.sid」の値
 *   DRY_RUN       … "true" なら投稿せず、選んだ曲を表示するだけ
 *
 * 使い方:  node substack-note.mjs
 */

import { readFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = dirname(fileURLToPath(import.meta.url));
const SONGS_PATH = join(ROOT, 'songs.txt');

// ---- 投稿する文言（変えたいときはここを書きかえる） ----
const MESSAGE = 'おはスタ✨今日の一曲';

const API = 'https://substack.com/api/v1';
const FETCH_TIMEOUT_MS = 20000;
const USER_AGENT =
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15';

const DRY_RUN = process.env.DRY_RUN === 'true';

// songs.txt から Spotify の曲リンクだけを取り出す
async function loadSongs() {
  const text = await readFile(SONGS_PATH, 'utf8');
  const songs = new Set();
  for (const raw of text.split('\n')) {
    const line = raw.trim();
    if (!line || line.startsWith('#')) continue;
    const m =
      line.match(/open\.spotify\.com\/(?:intl-[a-z-]+\/)?track\/([A-Za-z0-9]{22})/) ||
      line.match(/spotify:track:([A-Za-z0-9]{22})/);
    if (!m) {
      console.warn(`⚠️ 曲のリンクではないので飛ばしました: ${line}`);
      continue;
    }
    songs.add(`https://open.spotify.com/track/${m[1]}`);
  }
  return [...songs];
}

// 「substack.sid=」付きで貼られても、値だけを取り出す
function cookieValue(raw) {
  return raw.trim().replace(/^substack\.sid=/, '').replace(/;.*$/, '');
}

async function api(path, body, sid) {
  const res = await fetch(`${API}${path}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Accept: 'application/json',
      Cookie: `substack.sid=${sid}`,
      Origin: 'https://substack.com',
      Referer: 'https://substack.com/home',
      'User-Agent': USER_AGENT,
    },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(FETCH_TIMEOUT_MS),
  });
  const text = await res.text();
  if (!res.ok) {
    const hint =
      res.status === 401 || res.status === 403
        ? '\n→ Substack の合言葉（SUBSTACK_SID）の期限が切れている可能性があります。README の手順で入れ直してください。'
        : '';
    throw new Error(`Substack が ${res.status} を返しました (${path}): ${text.slice(0, 300)}${hint}`);
  }
  return text ? JSON.parse(text) : {};
}

function noteBody(text) {
  return {
    type: 'doc',
    attrs: { schemaVersion: 'v1' },
    content: [{ type: 'paragraph', content: [{ type: 'text', text }] }],
  };
}

async function main() {
  const songs = await loadSongs();
  if (songs.length === 0) {
    throw new Error('songs.txt に曲のリンクが1つもありません。Spotify の曲リンクを貼ってください。');
  }

  const song = songs[Math.floor(Math.random() * songs.length)];
  console.log(`🎵 ${songs.length}曲の中から選びました: ${song}`);
  console.log(`📝 投稿する文言: ${MESSAGE}`);

  if (DRY_RUN) {
    console.log('🧪 テストモードなので、投稿はしませんでした。');
    return;
  }

  const sid = cookieValue(process.env.SUBSTACK_SID || '');
  if (!sid) {
    throw new Error('SUBSTACK_SID が登録されていません。README の手順で GitHub の Secrets に登録してください。');
  }

  // 1) 曲のリンクを「カード」として登録する
  const attachment = await api('/comment/attachment', { url: song, type: 'link' }, sid);
  if (!attachment.id) {
    throw new Error(`曲のカードを作れませんでした: ${JSON.stringify(attachment).slice(0, 300)}`);
  }

  // 2) 文言＋カードでノートを投稿する
  const note = await api(
    '/comment/feed',
    {
      bodyJson: noteBody(MESSAGE),
      attachmentIds: [attachment.id],
      tabId: 'for-you',
      surface: 'feed',
      replyMinimumRole: 'everyone',
    },
    sid,
  );
  console.log(`✅ 投稿しました！ (ノートID: ${note.id ?? '不明'})`);
}

main().catch((err) => {
  console.error(`❌ ${err.message}`);
  process.exit(1);
});
