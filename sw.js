/**
 * オフラインでも読めるようにするための Service Worker。
 *
 * 安全のため、扱うのは自分のサイト（同じオリジン）へのGETリクエストだけです。
 * 外部サイトへの通信には一切割り込みません。
 */

var CACHE = 'ainews-v3';
var SHELL = [
  './',
  'index.html',
  'style.css?v=3',
  'app.js?v=3',
  'manifest.webmanifest',
  'assets/favicon.svg',
  'assets/icon-192.png',
  'assets/icon-512.png'
];

self.addEventListener('install', function (event) {
  event.waitUntil(
    caches.open(CACHE)
      .then(function (cache) {
        // cache:'reload' を付けないと、ブラウザが持っている古いファイルを
        // そのまま保存してしまい、更新しても画面が変わらなくなる。
        return Promise.all(SHELL.map(function (url) {
          return fetch(new Request(url, { cache: 'reload' }))
            .then(function (res) { return res.ok ? cache.put(url, res) : null; })
            .catch(function () { return null; });
        }));
      })
      .then(function () { return self.skipWaiting(); })
  );
});

self.addEventListener('activate', function (event) {
  event.waitUntil(
    caches.keys()
      .then(function (keys) {
        return Promise.all(keys.map(function (key) {
          return key === CACHE ? null : caches.delete(key);
        }));
      })
      .then(function () { return self.clients.claim(); })
  );
});

self.addEventListener('fetch', function (event) {
  var req = event.request;
  if (req.method !== 'GET') return;

  var url = new URL(req.url);
  if (url.origin !== self.location.origin) return;

  // ニュース本体は「まずネット、だめならキャッシュ」
  if (url.pathname.endsWith('/data/news.json')) {
    event.respondWith(
      fetch(req)
        .then(function (res) {
          if (res && res.ok) {
            var copy = res.clone();
            caches.open(CACHE).then(function (c) { c.put(req, copy); });
          }
          return res;
        })
        .catch(function () {
          return caches.match(req).then(function (hit) {
            return hit || Response.error();
          });
        })
    );
    return;
  }

  // それ以外（HTML・CSS・JS・画像）は
  // 「キャッシュをすぐ返しつつ、裏で最新を取り直して次回に備える」方式。
  // こうしておくと、ページを更新したときにキャッシュ名を変え忘れても
  // 次に開いたときには自動的に新しいものになります。
  event.respondWith(
    caches.match(req).then(function (hit) {
      var network = fetch(req)
        .then(function (res) {
          if (res && res.ok && res.type === 'basic') {
            var copy = res.clone();
            caches.open(CACHE).then(function (c) { c.put(req, copy); });
          }
          return res;
        })
        .catch(function () { return hit; });

      return hit || network;
    })
  );
});
