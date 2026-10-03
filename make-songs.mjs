#!/usr/bin/env node
/**
 * songs.txt を Spotify から作る（1回だけ使う道具）
 *
 * アーティストページの人気曲を先に、足りない分をアルバムの曲で埋めて、
 * 最大20曲を songs.txt に書き出します。
 * Spotify の埋め込みプレーヤーのページ（ログイン不要）から曲を読み取ります。
 *
 * 使い方:  node make-songs.mjs
 */

import { readFile, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = dirname(fileURLToPath(import.meta.url));
const SONGS_PATH = join(ROOT, 'songs.txt');

// 人気曲を先に入れたいので、アーティスト → アルバム の順
const SOURCES = [
  { label: 'アーティストの人気曲', kind: 'artist', id: '6JpxVeZiAqBhNJdsYpY1we' },
  { label: 'アルバム', kind: 'album', id: '3UI9IR83nWvSlWEKy9u9j5' },
];
const MAX_SONGS = 20;
const USER_AGENT =
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15';

// JSON の中から { uri: "spotify:track:…", title / name: "…" } を順番に拾う
function collectTracks(node, out) {
  if (Array.isArray(node)) {
    for (const v of node) collectTracks(v, out);
  } else if (node && typeof node === 'object') {
    const m = typeof node.uri === 'string' && node.uri.match(/^spotify:track:([A-Za-z0-9]{22})$/);
    if (m) out.push({ id: m[1], title: node.title || node.name || '' });
    for (const v of Object.values(node)) collectTracks(v, out);
  }
  return out;
}

async function fetchTracks({ kind, id }) {
  const res = await fetch(`https://open.spotify.com/embed/${kind}/${id}`, {
    headers: { 'User-Agent': USER_AGENT, 'Accept-Language': 'ja' },
    signal: AbortSignal.timeout(20000),
  });
  if (!res.ok) throw new Error(`Spotify が ${res.status} を返しました (${kind}/${id})`);
  const html = await res.text();

  const json = html.match(/<script[^>]*id="__NEXT_DATA__"[^>]*>([\s\S]*?)<\/script>/);
  if (json) {
    const tracks = collectTracks(JSON.parse(json[1]), []);
    if (tracks.length) return tracks;
  }
  // 形が変わっていたときの予備: ページ内の曲IDだけでも拾う
  return [...html.matchAll(/spotify:track:([A-Za-z0-9]{22})/g)].map((m) => ({ id: m[1], title: '' }));
}

async function main() {
  const picked = new Map();
  for (const src of SOURCES) {
    const tracks = await fetchTracks(src);
    console.log(`📀 ${src.label}: ${tracks.length}曲見つかりました`);
    for (const t of tracks) {
      if (picked.size >= MAX_SONGS) break;
      if (!picked.has(t.id)) picked.set(t.id, t.title);
    }
  }
  if (picked.size === 0) throw new Error('曲を1つも見つけられませんでした。');

  const header = (await readFile(SONGS_PATH, 'utf8')).trimEnd();
  const lines = [...picked].map(([id, title]) =>
    title ? `https://open.spotify.com/track/${id}   # ${title}` : `https://open.spotify.com/track/${id}`,
  );
  await writeFile(SONGS_PATH, `${header}\n\n${lines.join('\n')}\n`);

  console.log(`✅ songs.txt に ${picked.size}曲を書きました`);
  for (const l of lines) console.log(`  ${l}`);
}

main().catch((err) => {
  console.error(`❌ ${err.message}`);
  process.exit(1);
});
