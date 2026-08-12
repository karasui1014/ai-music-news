'use strict';

/**
 * AI音楽ニュース — 画面側の処理
 *
 * ■ セキュリティの方針
 *   取り込む記事は外部サイトが書いた文字列です。そのままHTMLとして扱うと
 *   悪意のあるスクリプトが動く危険（XSS）があるため、このファイルでは
 *     - innerHTML を一切使わない（必ず textContent と createElement）
 *     - リンクは http / https のURLだけを許可する
 *     - 外部リンクには rel="noopener noreferrer" を付ける
 *   を徹底しています。
 */

(function () {
  var DATA_URL = 'data/news.json';
  var LS_READ = 'ainews.read';
  var LS_SAVED = 'ainews.saved';
  var LS_THEME = 'ainews.theme';
  var MAX_REMEMBERED = 1000;
  var RANKING_MAX = 10;   // 注目ニュースはここまで。データ側が増えても超えて出さない

  var state = {
    items: [],
    ranking: [],
    sources: [],
    xLinks: [],
    generatedAt: null,
    filter: 'all',
    query: '',
    read: new Set(),
    saved: new Set()
  };

  var el = {
    list: document.getElementById('list'),
    status: document.getElementById('status'),
    chips: document.getElementById('chips'),
    updatedAt: document.getElementById('updatedAt'),
    search: document.getElementById('search'),
    searchBar: document.getElementById('searchBar'),
    searchToggle: document.getElementById('searchToggle'),
    searchClear: document.getElementById('searchClear'),
    themeToggle: document.getElementById('themeToggle'),
    xPanel: document.getElementById('xPanel'),
    xLinks: document.getElementById('xLinks'),
    sourcePanel: document.getElementById('sourcePanel'),
    sources: document.getElementById('sources'),
    sourceCount: document.getElementById('sourceCount')
  };

  // ========================================================
  // 保存まわり（localStorage）
  // 保存するのは記事IDと表示設定だけで、個人情報は一切扱いません。
  // ========================================================

  function loadSet(key) {
    try {
      var raw = JSON.parse(localStorage.getItem(key) || '[]');
      return new Set(Array.isArray(raw) ? raw.filter(function (v) {
        return typeof v === 'string' && v.length <= 64;
      }) : []);
    } catch (e) {
      return new Set();
    }
  }

  function saveSet(key, set) {
    try {
      var arr = Array.from(set);
      if (arr.length > MAX_REMEMBERED) arr = arr.slice(-MAX_REMEMBERED);
      localStorage.setItem(key, JSON.stringify(arr));
    } catch (e) {
      /* 保存できなくても表示は続ける */
    }
  }

  // ========================================================
  // 表示テーマ
  // ========================================================

  function applyTheme(theme) {
    if (theme === 'light' || theme === 'dark') {
      document.documentElement.setAttribute('data-theme', theme);
    } else {
      document.documentElement.removeAttribute('data-theme');
    }
    var meta = document.querySelector('meta[name="theme-color"]');
    if (meta) meta.setAttribute('content', currentIsLight() ? '#f4f6fb' : '#0b0f1a');
  }

  function currentIsLight() {
    var attr = document.documentElement.getAttribute('data-theme');
    if (attr) return attr === 'light';
    return window.matchMedia('(prefers-color-scheme: light)').matches;
  }

  function initTheme() {
    var saved = null;
    try { saved = localStorage.getItem(LS_THEME); } catch (e) { /* noop */ }
    applyTheme(saved);

    el.themeToggle.addEventListener('click', function () {
      var next = currentIsLight() ? 'dark' : 'light';
      applyTheme(next);
      try { localStorage.setItem(LS_THEME, next); } catch (e) { /* noop */ }
    });
  }

  // ========================================================
  // 小さな道具
  // ========================================================

  /** http / https 以外のURLは弾く（javascript: などを防ぐ） */
  function safeUrl(url) {
    if (typeof url !== 'string') return null;
    try {
      var u = new URL(url, window.location.href);
      return (u.protocol === 'http:' || u.protocol === 'https:') ? u.href : null;
    } catch (e) {
      return null;
    }
  }

  function elem(tag, className, text) {
    var node = document.createElement(tag);
    if (className) node.className = className;
    if (text != null) node.textContent = String(text);
    return node;
  }

  function svgIcon(pathD) {
    var NS = 'http://www.w3.org/2000/svg';
    var svg = document.createElementNS(NS, 'svg');
    svg.setAttribute('viewBox', '0 0 24 24');
    svg.setAttribute('aria-hidden', 'true');
    var path = document.createElementNS(NS, 'path');
    path.setAttribute('d', pathD);
    svg.appendChild(path);
    return svg;
  }

  /** 「3時間前」のような相対時刻 */
  function relativeTime(iso) {
    if (!iso) return '';
    var t = Date.parse(iso);
    if (isNaN(t)) return '';
    var diff = Date.now() - t;
    var min = Math.floor(diff / 60000);
    if (min < 1) return 'たった今';
    if (min < 60) return min + '分前';
    var hour = Math.floor(min / 60);
    if (hour < 24) return hour + '時間前';
    var day = Math.floor(hour / 24);
    if (day < 7) return day + '日前';
    var d = new Date(t);
    return (d.getMonth() + 1) + '月' + d.getDate() + '日';
  }

  function isNew(iso) {
    var t = Date.parse(iso || '');
    return !isNaN(t) && Date.now() - t < 24 * 60 * 60 * 1000;
  }

  function formatUpdated(iso) {
    var t = Date.parse(iso || '');
    if (isNaN(t)) return '更新時刻ふめい';
    var d = new Date(t);
    var pad = function (n) { return n < 10 ? '0' + n : String(n); };
    return '更新 ' + (d.getMonth() + 1) + '/' + d.getDate() + ' ' +
      pad(d.getHours()) + ':' + pad(d.getMinutes());
  }

  var CATEGORY_LABEL = {
    jp: '日本語',
    global: '海外',
    official: '公式',
    youtube: '動画'
  };

  // ========================================================
  // 絞り込み
  // ========================================================

  function matchesFilter(item) {
    if (state.filter === 'all') return true;
    if (state.filter === 'saved') return state.saved.has(item.id);
    return item.category === state.filter;
  }

  function matchesQuery(item) {
    if (!state.query) return true;
    // 原文でも日本語訳でも引っかかるようにする
    var hay = [
      item.title, item.titleJa, item.summary, item.summaryJa, item.source
    ].filter(Boolean).join(' ').toLowerCase();
    return state.query.split(/\s+/).every(function (word) {
      return !word || hay.indexOf(word) !== -1;
    });
  }

  function visibleItems() {
    return state.items.filter(function (item) {
      return matchesFilter(item) && matchesQuery(item);
    });
  }

  // ========================================================
  // 描画
  // ========================================================

  function buildCard(item) {
    var href = safeUrl(item.url);
    if (!href) return null;

    var card = elem('article', 'card');
    if (state.read.has(item.id)) card.classList.add('is-read');

    var link = elem('a', 'card__link');
    link.href = href;
    link.target = '_blank';
    // noopener/noreferrer: リンク先から元ページを操作されるのを防ぐ
    link.rel = 'noopener noreferrer external';
    link.referrerPolicy = 'no-referrer';

    var top = elem('div', 'card__top');

    var cat = CATEGORY_LABEL[item.category] ? item.category : 'global';
    top.appendChild(elem('span', 'tag tag--' + cat, CATEGORY_LABEL[cat]));

    var srcText = item.source || '';
    if (item.via) srcText += ' · ' + item.via;
    top.appendChild(elem('span', 'card__src', srcText));

    if (isNew(item.published)) {
      var dot = elem('span', 'card__new');
      dot.setAttribute('aria-label', '新着');
      top.appendChild(dot);
    }

    var time = elem('time', 'card__time', relativeTime(item.published));
    if (item.published) time.dateTime = item.published;
    top.appendChild(time);

    link.appendChild(top);

    // 日本語訳があればそれを主役にし、原文は下に小さく添える
    var hasJa = !!item.titleJa;
    link.appendChild(elem('h2', 'card__title', hasJa ? item.titleJa : item.title));
    if (hasJa) link.appendChild(elem('p', 'card__orig', item.title));

    var body = hasJa ? (item.summaryJa || '') : (item.summary || '');
    if (body) link.appendChild(elem('p', 'card__summary', body));

    link.addEventListener('click', function () {
      if (state.read.has(item.id)) return;
      state.read.add(item.id);
      saveSet(LS_READ, state.read);
      card.classList.add('is-read');
    });

    var save = elem('button', 'card__save');
    save.type = 'button';
    var isSaved = state.saved.has(item.id);
    save.setAttribute('aria-pressed', isSaved ? 'true' : 'false');
    save.setAttribute('aria-label', isSaved ? 'あとで読むから外す' : 'あとで読むに入れる');
    save.appendChild(svgIcon('M6 3.6h12v16.8l-6-4.2-6 4.2z'));
    save.addEventListener('click', function (ev) {
      ev.preventDefault();
      ev.stopPropagation();
      var nowSaved = !state.saved.has(item.id);
      if (nowSaved) state.saved.add(item.id); else state.saved.delete(item.id);
      saveSet(LS_SAVED, state.saved);
      save.setAttribute('aria-pressed', nowSaved ? 'true' : 'false');
      save.setAttribute('aria-label', nowSaved ? 'あとで読むから外す' : 'あとで読むに入れる');
      renderChips();
      if (state.filter === 'saved' && !nowSaved) renderList();
    });

    card.appendChild(link);
    card.appendChild(save);
    return card;
  }

  /**
   * 注目ランキング。
   * 「すべて」を絞り込みなしで見ているときだけ、リストの先頭に出す。
   * 絞り込み中に出すと、その条件と関係ない記事が混ざって分かりにくいため。
   */
  function renderRanking() {
    if (state.filter !== 'all' || state.query) return null;

    var ranked = state.ranking
      .map(function (id) {
        return state.items.find(function (it) { return it.id === id; });
      })
      .filter(Boolean)
      .slice(0, RANKING_MAX);
    if (ranked.length < 3) return null;

    var box = elem('section', 'rank');
    var head = elem('div', 'rank__head');
    head.appendChild(elem('h2', 'rank__title', '注目ニュース'));
    head.appendChild(elem('span', 'rank__note', 'いま読むならこの' + ranked.length + '本'));
    box.appendChild(head);

    var list = elem('ol', 'rank__list');
    ranked.forEach(function (item, i) {
      var href = safeUrl(item.url);
      if (!href) return;

      var li = elem('li', 'rank__item');
      if (state.read.has(item.id)) li.classList.add('is-read');

      var a = elem('a', 'rank__link');
      a.href = href;
      a.target = '_blank';
      a.rel = 'noopener noreferrer external';
      a.referrerPolicy = 'no-referrer';

      a.appendChild(elem('span', 'rank__no rank__no--' + (i + 1), String(i + 1)));

      var body = elem('div', 'rank__body');
      body.appendChild(elem('p', 'rank__text', item.titleJa || item.title));

      var meta = elem('div', 'rank__meta');
      meta.appendChild(elem('span', null, item.source || ''));
      if (item.coverage > 1) {
        meta.appendChild(elem('span', 'rank__hot', item.coverage + '媒体が報道'));
      }
      meta.appendChild(elem('span', 'rank__time', relativeTime(item.published)));
      body.appendChild(meta);

      a.appendChild(body);
      a.addEventListener('click', function () {
        if (state.read.has(item.id)) return;
        state.read.add(item.id);
        saveSet(LS_READ, state.read);
        li.classList.add('is-read');
      });

      li.appendChild(a);
      list.appendChild(li);
    });

    box.appendChild(list);
    return box;
  }

  function renderList() {
    var items = visibleItems();
    el.list.textContent = '';

    if (!items.length) {
      el.status.hidden = false;
      el.status.className = 'status';
      el.status.textContent = state.query
        ? '「' + state.query + '」に合う記事はありませんでした。'
        : (state.filter === 'saved'
          ? 'あとで読むに入れた記事はまだありません。カードの右上のしおりマークで保存できます。'
          : 'この条件の記事はまだありません。');
      return;
    }

    el.status.hidden = true;
    var frag = document.createDocumentFragment();

    var ranking = renderRanking();
    if (ranking) {
      // 「すべて」を絞り込みなしで見ているときは、注目の10本だけを見せる。
      // その下に全件（100件超）を積み上げると「どれを読めばいいか分からない」に
      // 逆戻りしてしまうため。カテゴリを選ぶか検索すれば個別の記事には辿り着ける。
      frag.appendChild(ranking);
      var more = elem('p', 'rank__more',
        'ほかの記事は、上のカテゴリを選ぶか検索すると見られます。');
      frag.appendChild(more);
      el.list.appendChild(frag);
      return;
    }

    items.forEach(function (item) {
      var card = buildCard(item);
      if (card) frag.appendChild(card);
    });
    el.list.appendChild(frag);
  }

  function countFor(filter) {
    var saved = state.filter, q = state.query;
    state.filter = filter;
    var n = state.items.filter(function (item) {
      return matchesFilter(item) && matchesQuery(item);
    }).length;
    state.filter = saved;
    state.query = q;
    return n;
  }

  function renderChips() {
    var defs = [{ key: 'all', label: 'すべて' }];
    ['jp', 'global', 'official', 'youtube'].forEach(function (key) {
      if (state.items.some(function (i) { return i.category === key; })) {
        defs.push({ key: key, label: CATEGORY_LABEL[key] });
      }
    });
    defs.push({ key: 'saved', label: 'あとで読む' });

    el.chips.textContent = '';
    defs.forEach(function (def) {
      var chip = elem('button', 'chip');
      chip.type = 'button';
      chip.setAttribute('aria-pressed', state.filter === def.key ? 'true' : 'false');
      chip.appendChild(elem('span', null, def.label));
      chip.appendChild(elem('span', 'chip__n', countFor(def.key)));
      chip.addEventListener('click', function () {
        state.filter = def.key;
        renderChips();
        renderList();
        window.scrollTo({ top: 0, behavior: 'smooth' });
      });
      el.chips.appendChild(chip);
    });
  }

  function renderXLinks() {
    if (!state.xLinks.length) return;
    el.xLinks.textContent = '';
    state.xLinks.forEach(function (link) {
      var href = safeUrl(link.url);
      if (!href || !link.name) return;
      var a = elem('a', 'xlink', String(link.name));
      a.href = href;
      a.target = '_blank';
      a.rel = 'noopener noreferrer external';
      a.referrerPolicy = 'no-referrer';
      el.xLinks.appendChild(a);
    });
    el.xPanel.hidden = false;
  }

  function renderSources() {
    if (!state.sources.length) return;
    el.sources.textContent = '';
    var ok = 0;
    state.sources.forEach(function (s) {
      if (s.ok) ok++;
      var row = elem('div', 'source');
      row.appendChild(elem('span', 'source__dot' + (s.ok ? '' : ' source__dot--ng')));
      row.appendChild(elem('span', 'source__name', s.name || s.id));
      row.appendChild(elem('span', 'source__n', s.ok ? s.matched + '件' : (s.error || '取得失敗')));
      el.sources.appendChild(row);
    });
    el.sourceCount.textContent = '（' + ok + '/' + state.sources.length + ' 稼働中）';
    el.sourcePanel.hidden = false;
  }

  // ========================================================
  // データ読み込み
  // ========================================================

  function sanitizeItem(raw) {
    if (!raw || typeof raw !== 'object') return null;
    var url = safeUrl(raw.url);
    var title = typeof raw.title === 'string' ? raw.title.trim() : '';
    if (!url || !title) return null;
    return {
      id: typeof raw.id === 'string' ? raw.id.slice(0, 64) : url,
      title: title.slice(0, 300),
      url: url,
      summary: typeof raw.summary === 'string' ? raw.summary.slice(0, 400) : '',
      titleJa: typeof raw.titleJa === 'string' ? raw.titleJa.slice(0, 300) : null,
      summaryJa: typeof raw.summaryJa === 'string' ? raw.summaryJa.slice(0, 400) : null,
      published: typeof raw.published === 'string' ? raw.published : null,
      source: typeof raw.source === 'string' ? raw.source.slice(0, 60) : '',
      via: typeof raw.via === 'string' ? raw.via.slice(0, 30) : null,
      category: typeof raw.category === 'string' ? raw.category : 'global',
      coverage: Number(raw.coverage) > 1 ? Math.min(Number(raw.coverage), 99) : 1
    };
  }

  function load() {
    return fetch(DATA_URL, { cache: 'no-cache' })
      .then(function (res) {
        if (!res.ok) throw new Error('HTTP ' + res.status);
        return res.json();
      })
      .then(function (data) {
        state.items = (Array.isArray(data.items) ? data.items : [])
          .map(sanitizeItem)
          .filter(Boolean);
        state.ranking = Array.isArray(data.ranking) ? data.ranking : [];
        state.sources = Array.isArray(data.sources) ? data.sources : [];
        state.xLinks = Array.isArray(data.xLinks) ? data.xLinks : [];
        state.generatedAt = data.generatedAt || null;

        el.updatedAt.textContent =
          formatUpdated(state.generatedAt) + '　記事' + state.items.length + '件';

        renderChips();
        renderList();
        renderXLinks();
        renderSources();
      })
      .catch(function (err) {
        el.status.hidden = false;
        el.status.className = 'status status--error';
        el.status.textContent =
          'ニュースを読み込めませんでした（' + err.message + '）。しばらくしてから開き直してみてください。';
        el.updatedAt.textContent = '読み込みエラー';
      });
  }

  // ========================================================
  // 起動
  // ========================================================

  function initSearch() {
    el.searchToggle.addEventListener('click', function () {
      var open = el.searchBar.hidden;
      el.searchBar.hidden = !open;
      el.searchToggle.setAttribute('aria-expanded', open ? 'true' : 'false');
      el.searchToggle.setAttribute('aria-label', open ? '検索を閉じる' : '検索を開く');
      if (open) {
        el.search.focus();
      } else if (state.query) {
        state.query = '';
        el.search.value = '';
        el.searchClear.hidden = true;
        renderChips();
        renderList();
      }
    });

    var timer = null;
    el.search.addEventListener('input', function () {
      el.searchClear.hidden = !el.search.value;
      clearTimeout(timer);
      timer = setTimeout(function () {
        state.query = el.search.value.trim().toLowerCase();
        renderChips();
        renderList();
      }, 120);
    });

    el.searchClear.addEventListener('click', function () {
      el.search.value = '';
      el.searchClear.hidden = true;
      state.query = '';
      renderChips();
      renderList();
      el.search.focus();
    });
  }

  function initServiceWorker() {
    if (!('serviceWorker' in navigator)) return;
    // localhost では登録しない。開発中にキャッシュで古い画面が出るのを防ぐため。
    if (location.protocol !== 'https:') return;
    window.addEventListener('load', function () {
      navigator.serviceWorker.register('sw.js').catch(function () { /* 失敗しても通常表示 */ });
    });
  }

  state.read = loadSet(LS_READ);
  state.saved = loadSet(LS_SAVED);

  initTheme();
  initSearch();
  initServiceWorker();
  load();

  // アプリに戻ってきたときに最新データを取り直す
  document.addEventListener('visibilitychange', function () {
    if (document.visibilityState === 'visible') load();
  });
})();
