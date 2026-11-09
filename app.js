// Tempo: a music player with a free streaming catalog (Audius), SoundCloud links, your own files,
// and optional accounts that sync liked songs and playlists across devices.
import { readTags, parseName, MIME, extOf, isAudio } from './tags.js';
import * as au from './audius.js';
import * as sync from './sync.js';
import * as sc from './soundcloud.js';
import * as yt from './youtube.js';

/* ================= helpers ================= */
const $ = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => [...r.querySelectorAll(s)];
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const enc = encodeURIComponent;
const fmt = (s) => {
  if (!isFinite(s) || s < 0) s = 0;
  s = Math.floor(s);
  const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), ss = String(s % 60).padStart(2, '0');
  return h ? `${h}:${String(m).padStart(2, '0')}:${ss}` : `${m}:${ss}`;
};
const fmtLong = (s) => {
  if (s < 60) return `${Math.round(s)} sec`;
  const h = Math.floor(s / 3600), m = Math.round((s % 3600) / 60);
  return h ? `${h} hr ${m} min` : `${m} min`;
};
const compact = (n) => (n >= 1e6 ? (n / 1e6).toFixed(1).replace(/\.0$/, '') + 'M' : n >= 1e3 ? (n / 1e3).toFixed(1).replace(/\.0$/, '') + 'K' : String(n || 0));
const hash = (str) => { let h = 2166136261; for (let i = 0; i < str.length; i++) { h ^= str.charCodeAt(i); h = Math.imul(h, 16777619); } return (h >>> 0).toString(36); };
const hue = (str) => parseInt(hash(str || 'x'), 36) % 360;
const plural = (n, w) => `${n} ${w}${n === 1 ? '' : 's'}`;
const isMobile = () => matchMedia('(max-width:760px)').matches;
const shuffleArr = (a) => { for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; } return a; };
const byText = (k) => (a, b) => (a[k] || '').localeCompare(b[k] || '', undefined, { sensitivity: 'base', numeric: true });
const lsGet = (k, d) => { try { const v = localStorage.getItem(k); return v == null ? d : JSON.parse(v); } catch { return d; } };
const lsSet = (k, v) => { try { localStorage.setItem(k, JSON.stringify(v)); } catch {} };

/* ================= icons ================= */
const ICON = {
  play: 'M8 5.14v13.72a1 1 0 0 0 1.5.86l11-6.86a1 1 0 0 0 0-1.72l-11-6.86A1 1 0 0 0 8 5.14z',
  pause: 'M6 4.5h4v15H6zM14 4.5h4v15h-4z',
  next: 'M5 6.3v11.4a1 1 0 0 0 1.55.83L15 13.1V18h2.5V6H15v4.9L6.55 5.47A1 1 0 0 0 5 6.3z',
  prev: 'M19 6.3v11.4a1 1 0 0 1-1.55.83L9 13.1V18H6.5V6H9v4.9l8.45-5.43A1 1 0 0 1 19 6.3z',
  more: 'M5 10a2 2 0 1 0 0 4 2 2 0 0 0 0-4zm7 0a2 2 0 1 0 0 4 2 2 0 0 0 0-4zm7 0a2 2 0 1 0 0 4 2 2 0 0 0 0-4z',
  heartFill: 'M20.8 4.6a5.5 5.5 0 0 0-7.8 0L12 5.7l-1-1.1a5.5 5.5 0 0 0-7.8 7.8l1 1.1L12 21l7.8-7.5 1-1.1a5.5 5.5 0 0 0 0-7.8z',
  heart: 'M20.8 4.6a5.5 5.5 0 0 0-7.8 0L12 5.7l-1-1.1a5.5 5.5 0 0 0-7.8 7.8l1 1.1L12 21l7.8-7.5 1-1.1a5.5 5.5 0 0 0 0-7.8z',
  shuffle: 'M16 3h5v5M4 20 21 3M21 16v5h-5M15 15l6 6M4 4l5 5',
  repeat: 'M17 2l4 4-4 4M3 11V10a4 4 0 0 1 4-4h14M7 22l-4-4 4-4M21 13v1a4 4 0 0 1-4 4H3',
  repeatOne: 'M17 2l4 4-4 4M3 11V10a4 4 0 0 1 4-4h14M7 22l-4-4 4-4M21 13v1a4 4 0 0 1-4 4H3M11 10.5l1.5-1V15',
  search: 'M11 4a7 7 0 1 0 0 14 7 7 0 0 0 0-14zM21 21l-5-5',
  home: 'M3 10.5 12 3l9 7.5V20a1 1 0 0 1-1 1h-5v-6h-6v6H4a1 1 0 0 1-1-1z',
  library: 'M4 4v16M9 4v16M14 4.5l6 15.5',
  plus: 'M12 5v14M5 12h14',
  queue: 'M3 6h14M3 12h14M3 18h8M15 15v6l5-3z',
  volume: 'M11 5 6 9H2v6h4l5 4zM15.5 8.5a5 5 0 0 1 0 7M19 5a10 10 0 0 1 0 14',
  mute: 'M11 5 6 9H2v6h4l5 4zM23 9l-6 6M17 9l6 6',
  down: 'M6 9l6 6 6-6',
  back: 'M15 18l-6-6 6-6',
  upload: 'M12 16V4M7 9l5-5 5 5M4 20h16',
  download: 'M12 4v12M7 11l5 5 5-5M4 20h16',
  trash: 'M3 6h18M8 6V4h8v2M19 6l-1 14H6L5 6',
  folder: 'M3 6a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z',
  edit: 'M12 20h9M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4z',
  x: 'M6 6l12 12M18 6 6 18',
  album: 'M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zM12 10a2 2 0 1 0 0 4 2 2 0 0 0 0-4z',
  user: 'M20 21a8 8 0 0 0-16 0M12 3a4 4 0 1 0 0 8 4 4 0 0 0 0-8z',
  playNext: 'M3 6h11M3 12h11M3 18h7M17 10v8M13 14h8',
  share: 'M4 12v7a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-7M12 3v12M8 7l4-4 4 4',
  link: 'M10 14a5 5 0 0 0 7 0l3-3a5 5 0 0 0-7-7l-1 1M14 10a5 5 0 0 0-7 0l-3 3a5 5 0 0 0 7 7l1-1',
  cloud: 'M17.5 19H7a5 5 0 1 1 .9-9.9A6 6 0 0 1 19.5 11 4 4 0 0 1 17.5 19z',
  check: 'M5 12l5 5 9-10',
};
const FILLED = new Set(['play', 'pause', 'next', 'prev', 'more', 'heartFill']);
const icon = (n, cls = '') =>
  `<svg class="ic ${cls}" viewBox="0 0 24 24" aria-hidden="true" ${FILLED.has(n) ? 'fill="currentColor"' : 'fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"'}><path d="${ICON[n]}"/></svg>`;
const fillIcons = (root = document) => $$('i[data-icon]', root).forEach((el) => { el.innerHTML = icon(el.dataset.icon); });

/* ================= storage (IndexedDB) ================= */
let dbp;
function db() {
  return (dbp ??= new Promise((res, rej) => {
    const r = indexedDB.open('tempo', 1);
    r.onupgradeneeded = () => {
      const d = r.result;
      d.createObjectStore('tracks', { keyPath: 'id' });
      d.createObjectStore('files');
      d.createObjectStore('covers');
      d.createObjectStore('playlists', { keyPath: 'id' });
    };
    r.onsuccess = () => res(r.result);
    r.onerror = () => rej(r.error);
  }));
}
async function tx(store, mode, fn) {
  const d = await db();
  return new Promise((res, rej) => {
    const t = d.transaction(store, mode);
    const out = fn(t.objectStore(store));
    t.oncomplete = () => res(out && 'result' in out ? out.result : undefined);
    t.onerror = () => rej(t.error);
    t.onabort = () => rej(t.error);
  });
}
const idb = {
  all: (st) => tx(st, 'readonly', (s) => s.getAll()),
  keys: (st) => tx(st, 'readonly', (s) => s.getAllKeys()),
  get: (st, k) => tx(st, 'readonly', (s) => s.get(k)),
  put: (st, v, k) => tx(st, 'readwrite', (s) => (k === undefined ? s.put(v) : s.put(v, k))),
  putMany: (st, vs) => tx(st, 'readwrite', (s) => { vs.forEach((v) => s.put(v)); }),
  del: (st, k) => tx(st, 'readwrite', (s) => s.delete(k)),
};
// Only store the fields we need (drops in-memory flags).
const saveTrack = (t) => idb.put('tracks', { ...t, _saved: undefined });

/* ================= state ================= */
// S.tracks holds every song we know about: your files, plus catalog songs you've
// played, liked or added to a playlist. Catalog songs you've only browsed stay in memory.
const S = {
  tracks: new Map(),
  playlists: new Map(),
  queue: [], qi: -1, order: null,
  shuffle: false, repeat: 'off', // off | all | one
  from: { label: 'Home', href: '#/home' },
  recent: [],
  recs: new Set(), // songs smart shuffle added to the queue
};
let likes = {};    // track id -> +time liked / -time unliked (used to merge across devices)
let scDeleted = {}; // removed SoundCloud song id -> time removed
let plTomb = {};   // deleted playlist id -> time deleted
const coverKeys = new Set();
const coverURL = new Map();
let lists = {}, froms = {};
const isRemote = (t) => t?.source === 'audius';
const isSC = (t) => t?.source === 'soundcloud';
const isYT = (t) => t?.source === 'youtube';
// Streamed catalog songs: only kept on the device once you play, like or add them somewhere.
const isStream = (t) => isRemote(t) || isYT(t);
const isFile = (t) => !!t && !isRemote(t) && !isSC(t) && !isYT(t);
const urlArt = (t) => isRemote(t) || isSC(t) || isYT(t);
const albumKey = (t) => (isRemote(t) ? 'au:' + t.rid : isSC(t) || isYT(t) ? t.id : `${t.albumArtist || t.artist}\u001f${t.album}`);
const sourceURL = (t) => t.permalink || (isYT(t) ? (t.vid ? 'https://www.youtube.com/watch?v=' + t.vid : 'https://www.youtube.com/results?search_query=' + enc(`${t.artist} ${t.title}`)) : '');
const current = () => S.tracks.get(S.queue[S.qi]);

function ingest(list) {
  return list.map((t) => {
    const have = S.tracks.get(t.id);
    if (have) { Object.assign(have, { art150: t.art150, art480: t.art480, art1000: t.art1000, playCount: t.playCount, title: t.title, artist: t.artist }); return have; }
    S.tracks.set(t.id, t);
    return t;
  });
}
// Keep catalog songs on this device once they're part of your queue, likes or playlists.
async function keep(ids) {
  const out = [];
  for (const id of ids) { const t = S.tracks.get(id); if (isStream(t) && !t._saved) { t._saved = true; if (!t.addedAt) t.addedAt = Date.now(); out.push({ ...t, _saved: undefined }); } }
  if (out.length) await idb.putMany('tracks', out).catch(() => {});
}

function persist() {
  lsSet('tempo:state', {
    queue: S.queue, qi: S.qi, order: S.order, shuffle: S.shuffle, repeat: S.repeat, from: S.from,
    recent: S.recent, recs: [...S.recs], time: loadedId ? P.time() : pendingSeek, vol: audio.volume, muted: audio.muted,
  });
}
function restore() {
  const st = lsGet('tempo:state', null);
  if (!st) return;
  const ok = (id) => S.tracks.has(id);
  S.shuffle = st.shuffle === 'smart' ? 'smart' : !!st.shuffle;
  S.recs = new Set((st.recs || []).filter(ok)); S.repeat = ['off', 'all', 'one'].includes(st.repeat) ? st.repeat : 'off';
  S.recent = (st.recent || []).filter(ok);
  if (st.from) S.from = st.from;
  const cur = st.queue?.[st.qi];
  S.queue = (st.queue || []).filter(ok);
  S.order = st.order ? st.order.filter(ok) : null;
  S.qi = ok(cur) ? Math.max(0, S.queue.indexOf(cur)) : (S.queue.length ? 0 : -1);
  if (ok(cur)) pendingSeek = st.time || 0;
  if (typeof st.vol === 'number') audio.volume = st.vol;
  audio.muted = !!st.muted;
}

/* ================= artwork ================= */
async function ensureCover(k) {
  if (!coverKeys.has(k)) return null;
  if (coverURL.has(k)) return coverURL.get(k);
  const b = await idb.get('covers', k);
  if (!b) { coverKeys.delete(k); return null; }
  const u = URL.createObjectURL(b);
  coverURL.set(k, u);
  return u;
}
const coverFor = async (t, big) => (urlArt(t) ? (big ? t.art1000 || t.art480 : t.art480) || null : ensureCover(albumKey(t)));
async function hydrateCovers(root = document) {
  for (const el of $$('[data-cover]', root)) {
    const k = el.dataset.cover;
    if (el.dataset.done === k) continue;
    const u = await ensureCover(k);
    el.dataset.done = k;
    if (u) { el.style.backgroundImage = `url("${u}")`; el.classList.add('has-img'); }
  }
}
function art(key, label, cls = 'sm', url = '') {
  const letter = esc((label || '?').trim().charAt(0).toUpperCase());
  if (url) return `<div class="art ${cls}" style="--h:${hue(key)}"><span>${letter}</span><img src="${esc(url)}" alt="" loading="lazy" onerror="this.remove()"></div>`;
  return `<div class="art ${cls}" data-cover="${esc(key)}" style="--h:${hue(key)}"><span>${letter}</span></div>`;
}
const trackArt = (t, cls) => (urlArt(t)
  ? art(albumKey(t), t.title, cls, /xs|sm/.test(cls) ? t.art150 || t.art480 : t.art480)
  : art(albumKey(t), t.album !== 'Unknown Album' ? t.album : t.title, cls));
async function setArt(el, t) {
  el.style.setProperty('--h', hue(albumKey(t)));
  const big = el.classList.contains('xl');
  const u = await coverFor(t, big);
  if (current() !== t) return;
  el.innerHTML = `<span>${esc((urlArt(t) || t.album === 'Unknown Album' ? t.title : t.album).charAt(0).toUpperCase())}</span>` + (u ? `<img src="${esc(u)}" alt="" onerror="this.remove()">` : '');
}

/* ================= grouping ================= */
// "Your library" = your own files + catalog songs you've liked.
const libTracks = () => [...S.tracks.values()].filter((t) => !isStream(t) || t.liked || t.inLib);
const localTracks = () => [...S.tracks.values()].filter(isFile);
function getAlbums() {
  const m = new Map();
  for (const t of localTracks()) {
    const k = albumKey(t);
    let a = m.get(k);
    if (!a) { a = { key: k, name: t.album, artist: t.albumArtist || t.artist, year: 0, tracks: [], addedAt: 0 }; m.set(k, a); }
    a.tracks.push(t);
    a.addedAt = Math.max(a.addedAt, t.addedAt);
    if (!a.year && t.year) a.year = t.year;
  }
  for (const a of m.values()) a.tracks.sort((x, y) => (x.disc - y.disc) || (x.track - y.track) || byText('title')(x, y));
  return [...m.values()];
}
function getArtists() {
  const m = new Map();
  for (const t of libTracks()) {
    const k = isRemote(t) ? 'au:' + t.artistId : t.artist;
    let a = m.get(k);
    if (!a) { a = { key: k, name: t.artist, remoteId: isRemote(t) ? t.artistId : '', tracks: [], first: t }; m.set(k, a); }
    a.tracks.push(t);
    if (isFile(a.first) && !coverKeys.has(albumKey(a.first)) && (coverKeys.has(albumKey(t)) || isSC(t))) a.first = t;
  }
  return [...m.values()].sort(byText('name'));
}
const likedTracks = () => [...S.tracks.values()].filter((t) => t.liked).sort((a, b) => (b.likedAt || 0) - (a.likedAt || 0));
const plTracks = (pl) => pl.ids.map((id) => S.tracks.get(id)).filter(Boolean);
const totalDur = (ts) => ts.reduce((s, t) => s + (t.duration || 0), 0);
const artistHref = (t) => (isRemote(t) ? `#/a/${enc(t.artistId)}` : isYT(t) ? `#/search/${enc(t.artist.split(',')[0])}` : `#/artist/${enc(t.artist)}`);

/* ================= templates ================= */
function row(t, i, ctx, o = {}) {
  const albumCol = isRemote(t) ? `<span>${esc(t.genre || 'Single')}</span>` : isSC(t) ? '<span>SoundCloud</span>' : isYT(t) ? `<span>${t.from ? esc(t.from) + ' → ' : ''}YouTube</span>` : `<a href="#/album/${enc(albumKey(t))}" data-act="go">${esc(t.album)}</a>`;
  return `<div class="row" data-act="play" data-ctx="${esc(ctx)}" data-i="${i}" data-id="${esc(t.id)}">
    <span class="idx"><span class="n">${o.album ? (t.track || i + 1) : i + 1}</span><span class="eq"><i></i><i></i><i></i></span></span>
    <div class="lead">${o.album ? '' : trackArt(t, 'xs')}<div class="meta"><div class="ttl">${esc(t.title)}</div><div class="sub">${S.recs.has(t.id) && (ctx === 'queue' || ctx.startsWith('pl:')) ? '<span class="rec">✦ Recommended</span> ' : ''}<a href="${artistHref(t)}" data-act="go">${esc(t.artist)}</a></div></div></div>
    <div class="col-alb">${albumCol}</div>
    <button class="ib like ${t.liked ? 'on' : ''}" data-act="like" data-id="${esc(t.id)}" aria-label="${t.liked ? 'Remove from Liked Songs' : 'Save to Liked Songs'}">${icon(t.liked ? 'heartFill' : 'heart')}</button>
    <span class="dur">${t.duration ? fmt(t.duration) : '–'}</span>
    <button class="ib more" data-act="more" data-id="${esc(t.id)}" data-ctx="${esc(ctx)}" data-i="${i}" aria-label="More options">${icon('more')}</button>
  </div>`;
}
function trackList(tracks, ctx, o = {}) {
  lists[ctx] = tracks.map((t) => t.id);
  if (o.from) froms[ctx] = o.from;
  if (!tracks.length) return `<p class="empty-sm">${o.empty || 'No songs here yet.'}</p>`;
  const head = o.noHead ? '' : `<div class="thead d-only"><span>#</span><span>Title</span><span class="col-alb">${o.album ? '' : 'Album'}</span><span></span><span style="text-align:right">Time</span><span></span></div>`;
  return `<div class="tracks ${o.album ? 'is-album' : ''}">${head}${tracks.map((t, i) => row(t, i, ctx, o)).join('')}</div>`;
}
const albumCard = (a) => `<div class="card" data-act="nav" data-href="#/album/${enc(a.key)}">
  <div class="cart">${art(a.key, a.name, 'md')}<button class="fab cplay" data-act="playAlbum" data-key="${esc(a.key)}" aria-label="Play ${esc(a.name)}">${icon('play')}</button></div>
  <div class="ttl">${esc(a.name)}</div><div class="sub">${a.year ? a.year + ' · ' : ''}${esc(a.artist)}</div></div>`;
const artistCard = (a) => {
  const href = a.remoteId ? `#/a/${enc(a.remoteId)}` : `#/artist/${enc(a.name)}`;
  const pic = a.pic || (a.first && urlArt(a.first) ? a.first.art480 : '');
  return `<div class="card" data-act="nav" data-href="${href}">
  ${a.first && isFile(a.first) ? art(albumKey(a.first), a.name, 'md round') : art('ar' + a.name, a.name, 'md round', pic)}
  <div class="ttl">${esc(a.name)}</div><div class="sub">${a.followers != null ? compact(a.followers) + ' followers' : plural(a.tracks.length, 'song')}</div></div>`;
};
const remotePlCard = (p) => `<div class="card" data-act="nav" data-href="#/p/${enc(p.id)}">
  <div class="cart">${art('rp' + p.id, p.name, 'md', p.art)}<button class="fab cplay" data-act="playRemotePl" data-id="${esc(p.id)}" aria-label="Play ${esc(p.name)}">${icon('play')}</button></div>
  <div class="ttl">${esc(p.name)}</div><div class="sub">${esc(p.by)}</div></div>`;
const plCover = (p, cls) => { const t = plTracks(p)[0]; return t ? trackArt(t, cls) : art('pl' + p.id, p.name, cls); };
const plCard = (p) => `<div class="card" data-act="nav" data-href="#/playlist/${p.id}">${plCover(p, 'md')}
  <div class="ttl">${esc(p.name)}</div><div class="sub">Playlist · ${plural(plTracks(p).length, 'song')}</div></div>`;
const likedCard = () => `<div class="card" data-act="nav" data-href="#/liked"><div class="art md liked">${icon('heartFill')}</div>
  <div class="ttl">Liked Songs</div><div class="sub">${plural(likedTracks().length, 'song')}</div></div>`;
const backBtn = () => `<button class="ib backbtn" data-act="back" aria-label="Back">${icon('back')}</button>`;
const playActions = (ctx, extra = '') => `<div class="actions">
  <button class="fab" data-act="playAll" data-ctx="${esc(ctx)}" aria-label="Play">${icon('play')}</button>
  <button class="ib big" data-act="shuffleAll" data-ctx="${esc(ctx)}" aria-label="Shuffle play">${icon('shuffle')}</button>${extra}</div>`;
const loading = (n = 5) => `<div class="skel">${'<div class="sk-row"><i></i><b></b></div>'.repeat(n)}</div>`;
const shelfLoading = () => `<div class="shelf">${'<div class="card"><div class="art md sk"></div><div class="sk-line"></div></div>'.repeat(6)}</div>`;
const asyncBox = (kind, arg = '', ph = loading()) => `<div data-async="${kind}" data-arg="${esc(arg)}">${ph}</div>`;
const offlineMsg = () => `<p class="empty-sm">Couldn't reach the music catalog${navigator.onLine ? '' : ' (you are offline)'}. <button class="linkbtn" data-act="retry">Try again</button></p>`;

/* ================= views ================= */
function installBanner() {
  if (isStandalone() || lsGet('tempo:hideInstall', false)) return '';
  if (isIOS()) return `<div class="banner">${icon('share')}<p>Get the app: tap <b>Share</b> then <b>Add to Home Screen</b>.</p><button class="ib" data-act="hideInstall" aria-label="Dismiss">${icon('x')}</button></div>`;
  if (installEvt) return `<div class="banner">${icon('download')}<p>Install Tempo as an app on this device.</p><button class="btn primary" data-act="install">Install</button><button class="ib" data-act="hideInstall" aria-label="Dismiss">${icon('x')}</button></div>`;
  return '';
}
function vHome() {
  const hr = new Date().getHours();
  const greet = hr < 5 ? 'Good night' : hr < 12 ? 'Good morning' : hr < 18 ? 'Good afternoon' : 'Good evening';
  const albums = getAlbums().sort((a, b) => b.addedAt - a.addedAt);
  const recent = S.recent.map((id) => S.tracks.get(id)).filter(Boolean);
  const seen = new Set(); const quickItems = [];
  for (const t of recent) {
    const k = isFile(t) ? albumKey(t) : 'a:' + (t.artistId || t.artist);
    if (seen.has(k)) continue; seen.add(k);
    quickItems.push(isFile(t)
      ? `<div class="q" data-act="nav" data-href="#/album/${enc(albumKey(t))}">${trackArt(t, '')}<span class="l">${esc(t.album)}</span></div>`
      : `<div class="q" data-act="nav" data-href="${artistHref(t)}">${trackArt(t, '')}<span class="l">${esc(t.artist)}</span></div>`);
    if (quickItems.length >= 4) break;
  }
  const pls = [...S.playlists.values()].sort((a, b) => b.updatedAt - a.updatedAt).slice(0, 2);
  const quick = [
    `<div class="q" data-act="nav" data-href="#/liked"><div class="art liked">${icon('heartFill')}</div><span class="l">Liked Songs</span></div>`,
    ...pls.map((p) => `<div class="q" data-act="nav" data-href="#/playlist/${p.id}">${plCover(p, '')}<span class="l">${esc(p.name)}</span></div>`),
    ...quickItems,
  ].slice(0, 6);
  const user = sync.currentUser();
  return `<div class="view" style="--h:${hue(current() ? albumKey(current()) : 'home')}"><div class="hero-grad"></div>
    ${installBanner()}
    <div class="view-head"><h1>${greet}</h1><a class="ib m-only acct" href="#/account" aria-label="Account">${user ? `<span class="avatar">${esc(user.email[0].toUpperCase())}</span>` : icon('user')}</a></div>
    <div class="quick">${quick.join('')}</div>
    <div class="dj-card" data-act="dj" role="button" tabindex="0">
      <div class="dj-orb"><span></span></div>
      <div class="dj-text"><b>${DJ_NAME}</b><p>Your personal DJ. Plays what you love, mixes in new finds and talks you through it.</p></div>
      <button class="fab" data-act="dj" aria-label="Start ${DJ_NAME}">${icon('play')}</button>
    </div>
    ${recent.length ? `<section class="sec"><div class="sec-head"><h2>Recently played</h2></div>${trackList(recent.slice(0, 6), 'recent', { from: { label: 'Recently played', href: '#/home' }, noHead: true })}</section>` : ''}
    <section class="sec"><div class="sec-head"><h2>Trending this week</h2><a href="#/genre/">Show all</a></div>${asyncBox('trending')}</section>
    <section class="sec"><div class="sec-head"><h2>Popular playlists</h2></div>${asyncBox('trendingPl', '', shelfLoading())}</section>
    <section class="sec"><div class="sec-head"><h2>Explore genres</h2></div>${genreGrid(au.GENRES.slice(0, 8))}</section>
    ${albums.length ? `<section class="sec"><div class="sec-head"><h2>Your albums</h2><a href="#/library/albums">Show all</a></div><div class="shelf">${albums.slice(0, 12).map(albumCard).join('')}</div></section>`
      : `<section class="sec"><div class="banner big">${icon('upload')}<p><b>Got your own music files?</b><br>Add MP3, M4A, FLAC or WAV files and they'll play offline right next to the catalog.</p><button class="btn" data-act="import">Add files</button></div></section>`}
    <p class="credit">Catalog streaming from <a href="https://audius.co" target="_blank" rel="noopener">Audius</a>, where artists share their music for free.</p>
  </div>`;
}
const genreGrid = (gs) => `<div class="genres">${gs.map((g) => `<a class="genre" style="--h:${hue(g)}" href="#/genre/${enc(g)}">${esc(g)}</a>`).join('')}</div>`;
function vGenre(g) {
  return `<div class="view" style="--h:${hue(g || 'top')}"><div class="hero-grad"></div>${backBtn()}
    <div class="view-head"><h1>${esc(g || 'Top songs this week')}</h1></div>
    ${asyncBox('genre', g, loading(10))}
    ${g ? '' : `<section class="sec"><div class="sec-head"><h2>Genres</h2></div>${genreGrid(au.GENRES)}</section>`}</div>`;
}
let searchQ = '';
function vSearch() {
  return `<div class="view">
    <div class="view-head"><h1>Search</h1></div>
    <label class="searchbox">${icon('search')}<input id="q" type="search" placeholder="Search songs, artists, or paste a SoundCloud link" value="${esc(searchQ)}" autocomplete="off" enterkeyhint="search"></label>
    <div id="results">${searchResults()}</div>
  </div>`;
}
function searchResults() {
  const q = searchQ.trim().toLowerCase();
  const link = searchQ.trim();
  if (/open\.spotify\.com\//.test(link) || yt.isPlaylistLink(link) || (sc.isLink(link) && sc.isCollectionLink(link)))
    return `<div class="banner big">${icon('download')}<p><b>That's a playlist link.</b><br>Import it to rebuild it as a playlist in Tempo.</p><button class="btn primary" data-act="importPl" data-link="${esc(link)}">Import playlist</button></div>`;
  if (sc.isLink(link)) return `<div class="banner big">${icon('link')}<p><b>That's a SoundCloud link.</b><br>Add the song to your library to play it here.</p><button class="btn primary" data-act="addSC" data-link="${esc(link)}">Add song</button></div>`;
  if (yt.isLink(link) && yt.videoId(link)) return `<div class="banner big">${icon('link')}<p><b>That's a YouTube link.</b><br>Add the song to your library to play it here.</p><button class="btn primary" data-act="addYT" data-link="${esc(link)}">Add song</button></div>`;
  if (!q) return `<div class="banner">${icon('link')}<p>Paste a Spotify, YouTube, YouTube Music or SoundCloud link here to add a song or import a whole playlist.</p></div><section class="sec"><h2>Browse all</h2>${genreGrid(au.GENRES)}</section>`;
  const words = q.split(/\s+/);
  const hit = (s) => words.every((w) => s.includes(w));
  const songs = libTracks().filter((t) => hit(`${t.title} ${t.artist} ${t.album} ${t.genre}`.toLowerCase())).sort(byText('title'));
  const albums = getAlbums().filter((a) => hit(`${a.name} ${a.artist}`.toLowerCase()));
  return `${songs.length ? `<section class="sec"><div class="sec-head"><h2>In your library</h2></div>${trackList(songs.slice(0, 8), 'searchLib', { from: { label: `Search: ${searchQ}`, href: '#/search' }, noHead: true })}</section>` : ''}
    ${albums.length ? `<section class="sec"><div class="sec-head"><h2>Your albums</h2></div><div class="shelf">${albums.map(albumCard).join('')}</div></section>` : ''}
    <div id="ytResults">${ytSearchState === searchQ.trim() ? '' : ytSearchOn ? `<div class="banner">${icon('search')}<p>Not finding it? Search all of YouTube for “${esc(searchQ.trim())}”.</p><button class="btn" data-act="ytSearch">Search YouTube</button></div>` : ''}</div>
    ${asyncBox('search', searchQ.trim(), `<section class="sec"><h2>Songs</h2>${loading(6)}</section>`)}`;
}
function vLibrary(tab) {
  const tabs = [['playlists', 'Playlists'], ['songs', 'Songs'], ['albums', 'Albums'], ['artists', 'Artists']];
  let body = '';
  if (tab === 'albums') body = `<div class="grid" style="margin-top:18px">${getAlbums().sort(byText('name')).map(albumCard).join('') || '<p class="empty-sm">Albums from music files you add show up here.</p>'}</div>`;
  else if (tab === 'artists') body = `<div class="grid" style="margin-top:18px">${getArtists().map(artistCard).join('') || '<p class="empty-sm">Like songs or add music files and their artists show up here.</p>'}</div>`;
  else if (tab === 'songs') {
    const sort = lsGet('tempo:sort', 'added');
    const ts = libTracks();
    if (sort === 'title') ts.sort(byText('title'));
    else if (sort === 'artist') ts.sort((a, b) => byText('artist')(a, b) || byText('album')(a, b) || (a.track - b.track));
    else ts.sort((a, b) => (b.likedAt || b.addedAt) - (a.likedAt || a.addedAt));
    body = `<div class="toolbar"><span class="muted">${plural(ts.length, 'song')}${ts.length ? ' · ' + fmtLong(totalDur(ts)) : ''}</span>
      <select class="sort" id="sort" aria-label="Sort songs">${[['added', 'Recently added'], ['title', 'Title'], ['artist', 'Artist']].map(([v, l]) => `<option value="${v}" ${v === sort ? 'selected' : ''}>${l}</option>`).join('')}</select></div>
      ${ts.length ? playActions('songs') : ''}
      ${trackList(ts, 'songs', { from: { label: 'Your Library', href: '#/library/songs' }, empty: 'Songs you like and music files you add show up here.' })}`;
  } else {
    body = `<div class="grid" style="margin-top:18px">${likedCard()}${[...S.playlists.values()].sort((a, b) => b.updatedAt - a.updatedAt).map(plCard).join('')}
      <div class="card new" data-act="newPlaylist"><div class="art md">${icon('plus')}</div><div class="ttl">New playlist</div><div class="sub">Build your own mix</div></div></div>`;
  }
  return `<div class="view">
    <div class="view-head"><h1>Your Library</h1><div class="head-btns"><button class="btn" data-act="importPl">${icon('download')}Import playlist</button><button class="btn" data-act="addSC">${icon('link')}SoundCloud link</button><button class="btn" data-act="import">${icon('plus')}Add files</button></div></div>
    <div class="chips">${tabs.map(([k, l]) => `<a class="chip ${k === tab ? 'on' : ''}" href="#/library/${k}">${l}</a>`).join('')}</div>
    ${body}</div>`;
}
function vAlbum(key) {
  const a = getAlbums().find((x) => x.key === key);
  if (!a) return vMissing('album');
  return `<div class="view" style="--h:${hue(a.key)}"><div class="hero-grad"></div>${backBtn()}
    <div class="dhead">${art(a.key, a.name, 'lg')}<div class="info"><small>Album</small><h1>${esc(a.name)}</h1>
      <div class="by"><a href="#/artist/${enc(a.artist)}">${esc(a.artist)}</a>${a.year ? ` · ${a.year}` : ''} · ${plural(a.tracks.length, 'song')}, ${fmtLong(totalDur(a.tracks))}</div></div></div>
    ${playActions('album')}
    ${trackList(a.tracks, 'album', { album: true, from: { label: a.name, href: `#/album/${enc(a.key)}` } })}</div>`;
}
function vArtist(name) {
  const tracks = libTracks().filter((t) => !isRemote(t) && !isYT(t) && t.artist === name);
  if (!tracks.length) return vMissing('artist');
  const albums = getAlbums().filter((al) => al.tracks.some((t) => t.artist === name) || al.artist === name).sort((x, y) => (y.year || 0) - (x.year || 0));
  const popular = [...tracks].sort((x, y) => (y.plays || 0) - (x.plays || 0) || byText('title')(x, y)).slice(0, 5);
  const all = [...tracks].sort((x, y) => byText('album')(x, y) || (x.disc - y.disc) || (x.track - y.track));
  const from = { label: name, href: `#/artist/${enc(name)}` };
  lists.artistAll = all.map((t) => t.id); froms.artistAll = from;
  const k = albumKey(tracks.find((t) => coverKeys.has(albumKey(t))) || tracks[0]);
  const scPic = tracks.find(urlArt)?.art480 || '';
  return `<div class="view" style="--h:${hue(k)}"><div class="hero-grad"></div>${backBtn()}
    <div class="dhead">${art(k, name, 'lg round', coverKeys.has(k) ? '' : scPic)}<div class="info"><small>Artist</small><h1>${esc(name)}</h1>
      <div class="by">${plural(tracks.length, 'song')} · ${plural(albums.length, 'album')}</div></div></div>
    ${playActions('artistAll')}
    <section class="sec" style="margin-top:8px"><div class="sec-head"><h2>Popular</h2></div>${trackList(popular, 'artistTop', { from, noHead: true })}</section>
    <section class="sec"><div class="sec-head"><h2>Albums</h2></div><div class="shelf">${albums.map(albumCard).join('')}</div></section>
    <section class="sec"><div class="sec-head"><h2>All songs</h2></div>${trackList(all, 'artistAll', { from })}</section></div>`;
}
const vRemoteArtist = (id) => `<div class="view">${backBtn()}${asyncBox('artist', id, `<div class="dhead"><div class="art lg round sk"></div></div>${loading(8)}`)}</div>`;
const vRemotePlaylist = (id) => `<div class="view">${backBtn()}${asyncBox('playlist', id, `<div class="dhead"><div class="art lg sk"></div></div>${loading(8)}`)}</div>`;
function vPlaylist(id) {
  const p = S.playlists.get(id);
  if (!p) return vMissing('playlist');
  const ts = plTracks(p);
  const key = ts[0] ? albumKey(ts[0]) : 'pl' + p.id;
  return `<div class="view" style="--h:${hue(key)}"><div class="hero-grad"></div>${backBtn()}
    <div class="dhead">${plCover(p, 'lg')}<div class="info"><small>Playlist${p.from ? ' · imported from ' + esc(p.from) : ''}</small><h1>${esc(p.name)}</h1>
      <div class="by">${plural(ts.length, 'song')}${ts.length ? `, ${fmtLong(totalDur(ts))}` : ''}</div></div></div>
    ${ts.length ? playActions('pl:' + p.id, `<button class="ib big" data-act="plRename" data-pl="${p.id}" aria-label="Rename">${icon('edit')}</button><button class="ib big" data-act="plDelete" data-pl="${p.id}" aria-label="Delete playlist">${icon('trash')}</button>`)
      : `<div class="actions"><button class="btn" data-act="plRename" data-pl="${p.id}">${icon('edit')}Rename</button><button class="btn" data-act="plDelete" data-pl="${p.id}">${icon('trash')}Delete</button></div>`}
    ${trackList(ts, 'pl:' + p.id, { from: { label: p.name, href: `#/playlist/${p.id}` }, empty: 'This playlist is empty. Find songs in Search, tap ⋯ and choose “Add to playlist”.' })}</div>`;
}
function vLiked() {
  const ts = likedTracks();
  return `<div class="view" style="--h:330"><div class="hero-grad"></div>${backBtn()}
    <div class="dhead"><div class="art lg liked">${icon('heartFill')}</div><div class="info"><small>Playlist</small><h1>Liked Songs</h1><div class="by">${plural(ts.length, 'song')}</div></div></div>
    ${ts.length ? playActions('liked') : ''}
    ${trackList(ts, 'liked', { from: { label: 'Liked Songs', href: '#/liked' }, empty: 'Songs you like will show up here. Tap the ♡ on any song.' })}</div>`;
}
function vQueue() {
  const cur = current();
  const rows = S.queue.map((id, i) => [S.tracks.get(id), i]).filter(([t, i]) => t && i > S.qi);
  return `<div class="view">${backBtn()}<div class="view-head"><h1>Queue</h1>${rows.length ? `<button class="btn" data-act="clearQueue">Clear queue</button>` : ''}</div>
    ${cur ? `<section class="sec" style="margin-top:0"><div class="sec-head"><h2>Now playing</h2></div><div class="tracks">${row(cur, S.qi, 'queue')}</div></section>` : '<p class="empty-sm">Nothing is playing.</p>'}
    ${rows.length ? `<section class="sec"><div class="sec-head"><h2>Next up</h2><span class="muted">${plural(rows.length, 'song')}</span></div><div class="tracks">${rows.map(([t, i]) => row(t, i, 'queue')).join('')}</div></section>` : cur ? '<p class="empty-sm">Nothing queued after this song.</p>' : ''}</div>`;
}
let authMsg = '';
function vAccount() {
  const user = sync.currentUser();
  const localCount = localTracks().length;
  let body;
  if (!sync.enabled) {
    body = `<div class="panel"><h2>Accounts aren't switched on yet</h2>
      <p class="muted">Accounts let you sign in on any phone or computer and keep your Liked Songs and playlists in sync.
      Whoever runs this copy of Tempo can turn them on with a free Supabase project. The steps are in the README.</p>
      <p class="muted">Until then, everything is saved on this device.</p></div>`;
  } else if (!user) {
    body = `<form class="panel auth" id="authForm" autocomplete="on">
      <h2>Sign in to sync</h2>
      <p class="muted">Keep your Liked Songs and playlists on every device.</p>
      <label>Email<input name="email" type="email" required autocomplete="email" inputmode="email"></label>
      <label>Password<input name="password" type="password" required minlength="6" autocomplete="current-password"></label>
      ${authMsg ? `<p class="authmsg">${esc(authMsg)}</p>` : ''}
      <div class="auth-btns"><button class="btn primary" value="signin">Sign in</button><button class="btn" value="signup">Create account</button></div>
      <button type="button" class="linkbtn" data-act="forgot">Forgot password?</button>
    </form>`;
  } else {
    const status = syncState === 'error' ? 'Sync problem: tap Sync now' : syncState === 'syncing' ? 'Syncing…'
      : lastSync ? `${icon('check')} Synced at ${new Date(lastSync).toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' })}` : 'Not synced yet';
    body = `<div class="panel"><div class="who"><span class="avatar big">${esc(user.email[0].toUpperCase())}</span><div><b>${esc(user.email)}</b>
      <div class="muted status">${status}</div></div></div>
      <p class="muted">Your Liked Songs and playlists sync to every device you sign in on. Music files you add stay on the device you added them on.</p>
      <div class="auth-btns"><button class="btn" data-act="syncNow">${icon('cloud')}Sync now</button><button class="btn ghost" data-act="signOut">Sign out</button></div></div>`;
  }
  return `<div class="view">${backBtn()}<div class="view-head"><h1>Account</h1></div>${body}
    <div class="panel"><h2>Music services</h2>
      <div class="svc"><div><b>Import playlists</b><p class="muted">Bring in playlists from Spotify, YouTube, YouTube Music or SoundCloud.</p></div><button class="btn" data-act="importPl">${icon('download')}Import</button></div>
      <div class="svc"><div><b>SoundCloud</b><p class="muted">${lsGet('tempo:scProfile', '') ? `Linked: ${esc(lsGet('tempo:scProfile', '').replace(/^https?:\/\/(www\.)?/, ''))}` : 'Link your profile to bring in your uploads. You can also import any SoundCloud playlist.'}</p></div><button class="btn" data-act="linkSC">${icon('link')}${lsGet('tempo:scProfile', '') ? 'Refresh' : 'Link'}</button></div>
      <div class="svc"><div><b>YouTube</b><p class="muted">${ytSearchOn ? `${icon('check')} Search is on. Imported Spotify songs play from YouTube.` : yt.hasServer() ? 'Search is off. Add a free YouTube API key to this deployment to search YouTube and play imported Spotify songs (README, step 3).' : 'Search needs the online version of Tempo plus a free YouTube API key (README, step 3). You can still paste YouTube links.'}</p></div></div>
      <div class="svc"><div><b>${DJ_NAME}'s voice</b><p class="muted">The DJ talks between songs using your device's built-in voice.</p></div><button class="btn" data-act="djVoice">${DJ.voice ? 'Turn off' : 'Turn on'}</button></div>
    </div>
    <div class="panel"><h2>On this device</h2><p class="muted">${plural(localCount, 'music file')} · ${plural(likedTracks().length, 'liked song')} · ${plural(S.playlists.size, 'playlist')}<br><span id="storageLine"></span></p>
      <div class="auth-btns"><button class="btn" data-act="import">${icon('upload')}Add music files</button>${installEvt ? `<button class="btn" data-act="install">${icon('download')}Install app</button>` : ''}</div></div>
    <p class="credit">Catalog streaming from <a href="https://audius.co" target="_blank" rel="noopener">Audius</a>.</p></div>`;
}
const vMissing = (w) => `<div class="view">${backBtn()}<p class="empty-sm">This ${w} isn't in your library anymore.</p></div>`;

/* ================= async sections (catalog) ================= */
let renderSeq = 0;
const ASYNC = {
  async trending() {
    const ts = ingest(await au.trending());
    return trackList(ts.slice(0, 10), 'trending', { from: { label: 'Trending this week', href: '#/genre/' }, noHead: true });
  },
  async trendingPl() {
    const ps = await au.trendingPlaylists();
    return `<div class="shelf">${ps.map(remotePlCard).join('')}</div>`;
  },
  async genre(el, g) {
    const ts = ingest(await au.trending(g));
    return (ts.length ? playActions('genre') : '') + trackList(ts.slice(0, 50), 'genre', { from: { label: g || 'Top songs', href: `#/genre/${enc(g)}` }, empty: 'Nothing trending in this genre right now.' });
  },
  async search(el, q) {
    const [songs, artists, pls] = await Promise.all([au.searchTracks(q), au.searchArtists(q).catch(() => []), au.searchPlaylists(q).catch(() => [])]);
    const ts = ingest(songs);
    if (!ts.length && !artists.length && !pls.length) return $('#results .row') ? '' : `<p class="empty-sm">No results for “${esc(q)}”. Try different words.</p>`;
    return `${ts.length ? `<section class="sec"><div class="sec-head"><h2>Songs</h2></div>${trackList(ts.slice(0, 20), 'search', { from: { label: `Search: ${q}`, href: '#/search' }, noHead: true })}</section>` : ''}
      ${artists.length ? `<section class="sec"><div class="sec-head"><h2>Artists</h2></div><div class="shelf">${artists.map((a) => artistCard({ ...a, remoteId: a.id })).join('')}</div></section>` : ''}
      ${pls.length ? `<section class="sec"><div class="sec-head"><h2>Playlists</h2></div><div class="shelf">${pls.map(remotePlCard).join('')}</div></section>` : ''}`;
  },
  async artist(el, id) {
    const [a, list] = await Promise.all([au.artist(id), au.artistTracks(id)]);
    const ts = ingest(list);
    const from = { label: a.name, href: `#/a/${enc(id)}` };
    el.closest('.view').style.setProperty('--h', hue(a.name));
    return `<div class="hero-grad"></div><div class="dhead">${art('ar' + a.name, a.name, 'lg round', a.pic)}<div class="info"><small>Artist${a.verified ? ' · Verified' : ''}</small><h1>${esc(a.name)}</h1>
      <div class="by">${compact(a.followers)} followers · ${plural(a.tracks, 'song')}</div></div></div>
      ${ts.length ? playActions('artist') : ''}
      <section class="sec" style="margin-top:8px"><div class="sec-head"><h2>Popular</h2></div>${trackList(ts, 'artist', { from, noHead: true, empty: 'This artist has no songs that can be streamed.' })}</section>
      ${a.bio ? `<section class="sec"><div class="sec-head"><h2>About</h2></div><p class="muted bio">${esc(a.bio)}</p></section>` : ''}`;
  },
  async playlist(el, id) {
    const p = await au.playlist(id);
    const ts = ingest(p.tracks);
    el.closest('.view').style.setProperty('--h', hue(p.name));
    return `<div class="hero-grad"></div><div class="dhead">${art('rp' + p.id, p.name, 'lg', p.art)}<div class="info"><small>${p.isAlbum ? 'Album' : 'Playlist'}</small><h1>${esc(p.name)}</h1>
      <div class="by">${esc(p.by)} · ${plural(ts.length, 'song')}${ts.length ? ', ' + fmtLong(totalDur(ts)) : ''}</div></div></div>
      ${ts.length ? playActions('rpl', `<button class="ib big" data-act="savePl" data-id="${esc(p.id)}" aria-label="Save a copy to your library">${icon('plus')}</button>`) : ''}
      ${trackList(ts, 'rpl', { from: { label: p.name, href: `#/p/${enc(id)}` }, empty: 'No playable songs in this playlist.' })}`;
  },
};
function runAsync(root) {
  const seq = renderSeq;
  for (const el of $$('[data-async]', root)) {
    const kind = el.dataset.async, arg = el.dataset.arg;
    ASYNC[kind](el, arg).then((html) => {
      if (seq !== renderSeq || !el.isConnected) return;
      el.innerHTML = html;
      hydrateCovers(el); markPlaying();
    }).catch((e) => {
      console.warn(kind, e);
      if (seq === renderSeq && el.isConnected) el.innerHTML = offlineMsg();
    });
  }
}

/* ================= router ================= */
function route() {
  const h = location.hash.replace(/^#\/?/, '') || 'home';
  const i = h.indexOf('/');
  return i < 0 ? { name: h, arg: '' } : { name: h.slice(0, i), arg: decodeURIComponent(h.slice(i + 1)) };
}
const main = $('#main');
function render(keepScroll = false) {
  const top = main.scrollTop;
  const { name, arg } = route();
  if (keepScroll && name === 'search' && $('#q') && $('#results') && !arg) { updateSearch(); return; }
  renderSeq++;
  lists = {}; froms = {};
  let html;
  switch (name) {
    case 'search': if (arg) searchQ = arg; html = vSearch(); break;
    case 'library': html = vLibrary(arg || 'playlists'); break;
    case 'album': html = vAlbum(arg); break;
    case 'artist': html = vArtist(arg); break;
    case 'playlist': html = vPlaylist(arg); break;
    case 'liked': html = vLiked(); break;
    case 'queue': html = vQueue(); break;
    case 'genre': html = vGenre(arg); break;
    case 'a': html = vRemoteArtist(arg); break;
    case 'p': html = vRemotePlaylist(arg); break;
    case 'account': html = vAccount(); break;
    default: html = vHome();
  }
  $('#view').innerHTML = html;
  main.scrollTop = keepScroll ? top : 0;
  const nav = ['home', 'search', 'account'].includes(name) ? name : ['queue', 'genre', 'a', 'p'].includes(name) ? '' : 'library';
  $$('[data-nav]').forEach((a) => a.classList.toggle('on', a.dataset.nav === nav));
  $$('#sidePl a').forEach((a) => a.classList.toggle('on', a.getAttribute('href') === location.hash));
  hydrateCovers($('#view'));
  runAsync($('#view'));
  markPlaying();
  if (name === 'account') updateStorage();
}
let searchTimer;
function updateSearch() {
  renderSeq++;
  lists = {}; froms = {};
  $('#results').innerHTML = searchResults();
  hydrateCovers($('#results')); markPlaying();
  clearTimeout(searchTimer);
  const seq = renderSeq;
  searchTimer = setTimeout(() => { if (seq === renderSeq) runAsync($('#results')); }, 350);
}
function renderSidebar() {
  const pls = [...S.playlists.values()].sort((a, b) => b.updatedAt - a.updatedAt);
  $('#sidePl').innerHTML = `<a href="#/liked"><div class="art xs liked">${icon('heartFill')}</div><div class="meta"><div class="ttl">Liked Songs</div><div class="sub">${plural(likedTracks().length, 'song')}</div></div></a>` +
    pls.map((p) => `<a href="#/playlist/${p.id}">${plCover(p, 'xs')}<div class="meta"><div class="ttl">${esc(p.name)}</div><div class="sub">Playlist</div></div></a>`).join('');
  hydrateCovers($('#sidePl'));
  $$('#sidePl a').forEach((a) => a.classList.toggle('on', a.getAttribute('href') === location.hash));
  const user = sync.currentUser();
  $('#acctBtn').innerHTML = user ? `<span class="avatar">${esc(user.email[0].toUpperCase())}</span><span class="acct-l">${esc(user.email)}</span>` : `${icon('user')}<span class="acct-l">${sync.enabled ? 'Sign in' : 'Account'}</span>`;
}
async function updateStorage() {
  try {
    const e = await navigator.storage?.estimate?.();
    if (!e) return;
    const gb = (n) => (n > 1e9 ? (n / 1e9).toFixed(1) + ' GB' : Math.max(1, Math.round(n / 1e6)) + ' MB');
    if ($('#storageLine')) $('#storageLine').textContent = `${gb(e.usage || 0)} of storage used`;
  } catch {}
}
const refresh = () => { render(true); renderSidebar(); };

/* ================= playback ================= */
const audio = $('#audio');
let curURL = null, loadedId = null, pendingSeek = 0, loadToken = 0, errCount = 0, unlocked = false, silent = false;
let pre = { id: null, url: null };
// Three players: the <audio> element (your files + Audius), SoundCloud's embedded
// player and YouTube's embedded player. P always talks to whichever one is active.
let engine = 'audio';
const emb = { paused: true, time: 0, dur: 0 };
const ENG = {
  audio: { paused: () => audio.paused, time: () => audio.currentTime, dur: () => audio.duration, seek: (t) => { audio.currentTime = t; }, play: () => audio.play().catch(() => {}), pause: () => audio.pause(), volume: () => {} },
  sc: { paused: () => emb.paused, time: () => emb.time, dur: () => emb.dur, seek: (t) => { emb.time = t; sc.seek(t); updateTime(); }, play: () => sc.play(), pause: () => { sc.pause(); emb.paused = true; updatePlayUI(); }, volume: (v) => sc.volume(v) },
  yt: { paused: () => emb.paused, time: () => emb.time, dur: () => emb.dur, seek: (t) => { emb.time = t; yt.seek(t); updateTime(); }, play: () => yt.play(), pause: () => { yt.pause(); emb.paused = true; updatePlayUI(); }, volume: (v) => yt.volume(v) },
};
const P = {
  paused: () => ENG[engine].paused(), time: () => ENG[engine].time(), dur: () => ENG[engine].dur(),
  seek: (t) => ENG[engine].seek(t), play: () => ENG[engine].play(), pause: () => ENG[engine].pause(),
};
const setVolumeAll = () => { const v = audio.muted ? 0 : audio.volume; ENG.sc.volume(v); ENG.yt.volume(v); };
let lastEmbSave = 0;
const embEvents = {
  play: () => { emb.paused = false; errCount = 0; updatePlayUI(); },
  pause: () => { emb.paused = true; updatePlayUI(); },
  finish: () => { emb.paused = true; next(true); },
  progress: (t, d) => { emb.time = t; if (d) emb.dur = d; updateTime(); if (Date.now() - lastEmbSave > 4000) { lastEmbSave = Date.now(); persist(); } },
  error: (code) => {
    const t = current();
    // YouTube: the owner blocked embedding or removed it. For matched songs, try the next-best video.
    if (engine === 'yt' && isYT(t) && t.q && [100, 101, 150].includes(code) && (t.bad?.length || 0) < 3) {
      t.bad = [...(t.bad || []), t.vid]; t.vid = ''; load(t.id); return;
    }
    toast(engine === 'yt' ? `YouTube won't play “${t?.title}” here` : "SoundCloud couldn't play this song");
    if (++errCount < 3 && S.queue.length > 1) setTimeout(() => next(true), 900);
  },
};
function switchEngine(kind) {
  if (engine !== kind) {
    if (engine === 'audio') { audio.pause(); revoke(curURL); curURL = null; audio.removeAttribute('src'); }
    else if (engine === 'sc') sc.pause();
    else if (engine === 'yt') yt.stop();
    engine = kind;
  }
  const box = $('#embedBox');
  box.hidden = kind === 'audio';
  box.dataset.kind = kind;
  $('#embedLabel').textContent = kind === 'yt' ? 'Playing from YouTube' : 'Playing from SoundCloud';
  $('#scFrame').hidden = kind !== 'sc'; $('#ytFrame').hidden = kind !== 'yt';
  document.body.dataset.engine = kind;
}

function silentURL() {
  const n = 800, b = new ArrayBuffer(44 + n), v = new DataView(b);
  const w = (o, s) => { for (let i = 0; i < s.length; i++) v.setUint8(o + i, s.charCodeAt(i)); };
  w(0, 'RIFF'); v.setUint32(4, 36 + n, true); w(8, 'WAVE'); w(12, 'fmt '); v.setUint32(16, 16, true);
  v.setUint16(20, 1, true); v.setUint16(22, 1, true); v.setUint32(24, 8000, true); v.setUint32(28, 8000, true);
  v.setUint16(32, 1, true); v.setUint16(34, 8, true); w(36, 'data'); v.setUint32(40, n, true);
  for (let i = 0; i < n; i++) v.setUint8(44 + i, 128);
  return URL.createObjectURL(new Blob([b], { type: 'audio/wav' }));
}
// iOS only lets audio start from a tap. Song files load asynchronously, so the
// audio element is "unlocked" synchronously on the first tap with a tiny silent clip.
function unlock() {
  if (unlocked || loadedId) return;
  unlocked = true; silent = true;
  audio.src = silentURL();
  audio.play().catch(() => {});
}
const revoke = (u) => { if (u && u.startsWith('blob:')) URL.revokeObjectURL(u); };

async function load(id, autoplay = true, seek = 0) {
  const tok = ++loadToken;
  const t = S.tracks.get(id);
  if (!t) return;
  if (autoplay && DJ.on && DJ.lines.has(id)) { await djSpeak(id); if (tok !== loadToken) return; }
  if (isSC(t)) return loadEmbed('sc', t, tok, autoplay, seek);
  if (isYT(t)) return loadEmbed('yt', t, tok, autoplay, seek);
  let url;
  if (isRemote(t)) url = au.streamURL(t.rid);
  else if (pre.id === id) { url = pre.url; pre = { id: null, url: null }; }
  else {
    const blob = await idb.get('files', id);
    if (tok !== loadToken) return;
    if (!blob) { toast(`“${t.title}” isn't on this device`); if (autoplay && S.queue.length > 1 && ++errCount < 5) next(true); return; }
    url = URL.createObjectURL(blob);
  }
  return loadAudio(t, url, tok, autoplay, seek);
}
async function loadAudio(t, url, tok, autoplay, seek) {
  switchEngine('audio');
  if (curURL !== url) revoke(curURL);
  curURL = url; loadedId = t.id; silent = false; pendingSeek = 0;
  audio.src = url;
  if (seek > 0) audio.addEventListener('loadedmetadata', () => { audio.currentTime = Math.min(seek, (audio.duration || seek + 1) - 0.5); }, { once: true });
  updateTrackUI();
  if (autoplay) {
    try { await audio.play(); } catch (e) { if (e.name === 'NotAllowedError') toast('Tap play to start'); }
    if (tok !== loadToken) return;
    countPlay(t);
  }
  persist();
  prefetchNext();
}
function countPlay(t) {
  t.plays = (t.plays || 0) + 1; t.lastPlayed = Date.now();
  if (!isStream(t) || t._saved) saveTrack(t);
  S.recent = [t.id, ...S.recent.filter((x) => x !== t.id)].slice(0, 50);
  if (DJ.on && S.qi >= S.queue.length - 2) djExtend();
}
// Songs imported from Spotify etc. only have a title + artist. Find the matching YouTube video.
async function resolveYT(t) {
  if (t.vid) return t.vid;
  if (!(await yt.searchEnabled())) return null;
  const results = (await yt.search(`${t.artist.split(',')[0]} ${t.title}`)).filter((r) => !(t.bad || []).includes(r.vid));
  const m = yt.bestMatch(results, t.title, t.artist, t.duration);
  if (!m || yt.quality(m, t.title, t.artist) < 0.5) return null;
  Object.assign(t, { vid: m.vid, permalink: 'https://www.youtube.com/watch?v=' + m.vid });
  if (!t.art480) Object.assign(t, { art150: m.art, art480: m.art, art1000: m.art });
  if (!t.duration) t.duration = m.duration;
  if (t._saved || t.liked) { saveTrack(t); changed(); }
  return t.vid;
}
// Without YouTube search, try to find the same song on Audius instead.
async function audiusMatch(t) {
  if (t.alt) return t.alt;
  const res = await au.searchTracks(`${t.artist.split(',')[0]} ${t.title}`).catch(() => []);
  const scored = res.map((r) => ({ r, q: yt.quality(r, t.title, t.artist) })).sort((x, y) => y.q - x.q);
  if (!scored.length || scored[0].q < 0.75) return null;
  t.alt = scored[0].r.rid;
  return t.alt;
}
async function loadEmbed(kind, t, tok, autoplay, seek) {
  let vid = null;
  if (kind === 'yt') {
    updateTrackUI(t);
    try { vid = await resolveYT(t); } catch (e) { console.warn('YouTube lookup failed', e); }
    if (tok !== loadToken) return;
    if (!vid) {
      const alt = await audiusMatch(t);
      if (tok !== loadToken) return;
      if (alt) return loadAudio(t, au.streamURL(alt), tok, autoplay, seek);
      toast((await yt.searchEnabled()) ? `Couldn't find “${t.title}” on YouTube` : `Can't play “${t.title}” yet. Turn on YouTube search to play imported songs (see Account)`, 4000);
      if (autoplay && S.queue.length > 1 && ++errCount < 5) setTimeout(() => next(true), 700);
      return;
    }
  }
  switchEngine(kind);
  loadedId = t.id; silent = false; pendingSeek = 0;
  // stays "paused" until the player confirms it started (the PLAY event)
  Object.assign(emb, { paused: true, time: seek || 0, dur: t.duration || 0 });
  updateTrackUI();
  try {
    const d = kind === 'sc' ? await sc.load($('#scFrame'), embEvents, t.url, autoplay) : await yt.load($('#ytFrame'), embEvents, vid, autoplay, seek);
    if (tok !== loadToken) return;
    setVolumeAll();
    if (d && Math.abs((t.duration || 0) - d) > 1) { t.duration = d; if (!isStream(t) || t._saved) saveTrack(t); }
    emb.dur = d || t.duration;
    if (kind === 'sc' && seek > 0) P.seek(seek);
    updateTime();
  } catch (e) { toast(e.message || "Couldn't load the player"); return; }
  if (autoplay) countPlay(t);
  persist();
}
function nextIndex() {
  if (S.repeat === 'one') return S.qi;
  if (S.qi < S.queue.length - 1) return S.qi + 1;
  return S.repeat === 'all' ? 0 : -1;
}
async function prefetchNext() {
  const ni = nextIndex();
  const id = ni >= 0 ? S.queue[ni] : null;
  const t = S.tracks.get(id);
  if (!isFile(t) || id === loadedId || pre.id === id) return;
  const blob = await idb.get('files', id);
  if (!blob) return;
  revoke(pre.url);
  pre = { id, url: URL.createObjectURL(blob) };
}
function playList(ids, i = 0, from) {
  if (!ids?.length) return;
  i = Math.max(0, Math.min(i, ids.length - 1));
  if (from) S.from = from;
  if (DJ.on && from?.label !== DJ_NAME) stopDJ();
  S.recs.clear();
  keep(ids);
  if (S.shuffle) {
    S.order = ids.slice();
    S.queue = [ids[i], ...shuffleArr(ids.filter((_, j) => j !== i))]; S.qi = 0;
  } else { S.queue = ids.slice(); S.order = null; S.qi = i; }
  load(S.queue[S.qi]);
  if (S.shuffle === 'smart') smartFill();
}
function shufflePlay(ids, from) {
  if (!ids?.length) return;
  if (!S.shuffle) { S.shuffle = lsGet('tempo:smartDefault', false) ? 'smart' : true; updateModesUI(); }
  playList(ids, Math.floor(Math.random() * ids.length), from);
}
function togglePlay() {
  if (!S.queue.length) {
    const ids = lists.trending || lists.recent || libTracks().map((t) => t.id);
    if (ids.length) playList(ids, 0, { label: 'Home', href: '#/home' });
    else toast('Pick a song to play');
    return;
  }
  if (!loadedId) { load(S.queue[S.qi], true, pendingSeek); return; }
  if (P.paused()) P.play(); else P.pause();
}
function next(auto = false) {
  if (!S.queue.length) return;
  if (auto && S.repeat === 'one') { P.seek(0); P.play(); return; }
  if (S.qi < S.queue.length - 1) S.qi++;
  else if (S.repeat !== 'off') S.qi = 0;
  else { S.qi = 0; load(S.queue[0], false); return; } // end of the queue: stop on the first song
  load(S.queue[S.qi]);
}
function prev() {
  if (!S.queue.length) return;
  if (P.time() > 3 || (S.qi === 0 && S.repeat === 'off')) { P.seek(0); return; }
  S.qi = S.qi > 0 ? S.qi - 1 : S.queue.length - 1;
  load(S.queue[S.qi]);
}
function toggleShuffle() {
  const was = S.shuffle;
  S.shuffle = !was ? true : was === true ? 'smart' : false;
  if (S.queue.length) {
    const cur = S.queue[S.qi];
    if (S.shuffle === true) {
      S.order = S.queue.slice();
      S.queue = [cur, ...shuffleArr(S.queue.filter((_, j) => j !== S.qi))]; S.qi = 0;
    } else if (!S.shuffle) {
      dropRecs();
      if (S.order) { S.queue = S.order.filter((id) => S.tracks.has(id)); S.order = null; S.qi = Math.max(0, S.queue.indexOf(cur)); }
    }
  }
  toast(S.shuffle === 'smart' ? 'Smart shuffle on: mixing in songs picked for you' : S.shuffle ? 'Shuffle on' : 'Shuffle off');
  updateModesUI(); persist(); prefetchNext();
  if (S.shuffle === 'smart') smartFill();
  if (route().name === 'queue') render(true);
}
function cycleRepeat() {
  S.repeat = { off: 'all', all: 'one', one: 'off' }[S.repeat];
  toast({ off: 'Repeat off', all: 'Repeating your queue', one: 'Repeating this song' }[S.repeat]);
  updateModesUI(); persist(); prefetchNext();
}
function playNext(id) {
  if (!S.queue.length) { playList([id], 0); return; }
  keep([id]);
  S.queue.splice(S.qi + 1, 0, id);
  if (S.order) { const p = S.order.indexOf(S.queue[S.qi]); S.order.splice(p + 1, 0, id); }
  toast('Playing next'); persist(); prefetchNext();
}
function addToQueue(id) {
  if (!S.queue.length) { playList([id], 0); return; }
  keep([id]);
  S.queue.push(id); S.order?.push(id);
  toast('Added to queue'); persist(); prefetchNext();
}
function removeFromQueue(i) {
  if (i === S.qi) return;
  const [id] = S.queue.splice(i, 1);
  if (i < S.qi) S.qi--;
  if (S.order) { const p = S.order.indexOf(id); if (p >= 0) S.order.splice(p, 1); }
  persist(); prefetchNext();
}

/* ---------- audio events ---------- */
audio.addEventListener('play', () => { if (!silent) { unlocked = true; updatePlayUI(); } });
audio.addEventListener('pause', updatePlayUI);
audio.addEventListener('playing', () => { errCount = 0; updatePlayUI(); });
audio.addEventListener('ended', () => { if (!silent && engine === 'audio') next(true); });
audio.addEventListener('loadedmetadata', () => {
  if (silent) return;
  const t = S.tracks.get(loadedId);
  if (t && isFinite(audio.duration) && Math.abs((t.duration || 0) - audio.duration) > 1) {
    t.duration = audio.duration;
    if (!isStream(t) || t._saved) saveTrack(t);
  }
  updateTime();
});
audio.addEventListener('error', () => {
  if (silent || !loadedId || engine !== 'audio' || !audio.getAttribute('src')) return;
  const t = S.tracks.get(loadedId);
  toast(isRemote(t) ? `Couldn't stream “${t?.title}”${navigator.onLine ? '' : ' (offline)'}` : `Can't play “${t?.title}” on this device`);
  if (++errCount < 3 && S.queue.length > 1) setTimeout(() => next(true), 900);
});
let lastSave = 0;
audio.addEventListener('timeupdate', () => {
  if (silent || engine !== 'audio') return;
  updateTime();
  const now = Date.now();
  if (now - lastSave > 4000) { lastSave = now; persist(); }
});

/* ---------- player UI ---------- */
let seeking = false;
function updateTime() {
  const d = loadedId && isFinite(P.dur()) && P.dur() > 0 ? P.dur() : current()?.duration;
  const c = loadedId ? P.time() : pendingSeek;
  const p = d ? Math.min(100, (c / d) * 100) : 0;
  if (!seeking) {
    $$('.seek').forEach((el) => { el.value = Math.round(p * 10); el.style.setProperty('--p', p + '%'); });
    $$('[data-t=cur]').forEach((el) => { el.textContent = fmt(c); });
  }
  $$('[data-t=dur]').forEach((el) => { el.textContent = fmt(d); });
  $('#mProg').style.width = p + '%';
  if ('mediaSession' in navigator && engine === 'audio' && loadedId && isFinite(audio.duration) && audio.duration > 0) {
    try { navigator.mediaSession.setPositionState({ duration: audio.duration, position: Math.min(audio.currentTime, audio.duration), playbackRate: audio.playbackRate || 1 }); } catch {}
  }
}
function updatePlayUI() {
  const playing = !P.paused() && !silent;
  document.body.classList.toggle('is-playing', playing);
  $$('[data-act=toggle]').forEach((b) => { b.innerHTML = icon(playing ? 'pause' : 'play'); b.setAttribute('aria-label', playing ? 'Pause' : 'Play'); });
  if ('mediaSession' in navigator) navigator.mediaSession.playbackState = loadedId ? (playing ? 'playing' : 'paused') : 'none';
}
function updateModesUI() {
  $$('[data-act=shuffle]').forEach((b) => { b.classList.toggle('on', !!S.shuffle); b.classList.toggle('smart', S.shuffle === 'smart'); b.setAttribute('aria-label', S.shuffle === 'smart' ? 'Smart shuffle (on)' : S.shuffle ? 'Shuffle (on)' : 'Shuffle'); });
  $$('[data-act=repeat]').forEach((b) => { b.classList.toggle('on', S.repeat !== 'off'); b.innerHTML = icon(S.repeat === 'one' ? 'repeatOne' : 'repeat'); });
}
function updateLikeUI() {
  const t = current();
  ['#pLike', '#npLike'].forEach((s) => { const b = $(s); b.classList.toggle('on', !!t?.liked); b.innerHTML = icon(t?.liked ? 'heartFill' : 'heart'); });
}
async function updateTrackUI() {
  const t = current();
  $('#player').classList.toggle('is-empty', !t);
  if (!t) { document.title = 'Tempo'; return; }
  const k = albumKey(t);
  $('#pTitle').textContent = t.title;
  $('#pArtist').textContent = t.artist;
  $('#npTitle').textContent = t.title;
  $('#npArtist').textContent = t.artist;
  $('#npArtist').href = artistHref(t);
  $('#npFrom').textContent = S.from?.label || 'Your Library';
  $('#npFrom').href = S.from?.href || '#/home';
  $('#npSource').hidden = isFile(t);
  $('#npSource').href = sourceURL(t) || 'https://audius.co';
  $('#npSource').textContent = isSC(t) ? 'Listen on SoundCloud ↗' : isYT(t) ? 'Watch on YouTube ↗' : 'Listen on Audius ↗';
  $('#npDJ').hidden = !DJ.on; $('#djPill').hidden = !DJ.on;
  $('#npRec').hidden = !S.recs.has(t.id);
  $('#player').style.setProperty('--h', hue(k));
  setArt($('#pArt'), t); setArt($('#npArt'), t);
  const bg = $('#npBg');
  bg.style.setProperty('--h', hue(k));
  updateLikeUI(); updateTime(); updatePlayUI(); markPlaying();
  document.title = `${t.title} · ${t.artist}`;
  const u = await coverFor(t, true);
  if (current() !== t) return;
  bg.classList.toggle('has-img', !!u);
  bg.style.backgroundImage = u ? `url("${u}")` : '';
  if ('mediaSession' in navigator) {
    let artwork = [{ src: new URL('icon-512.png', location.href).href, sizes: '512x512', type: 'image/png' }];
    if (u) artwork = urlArt(t)
      ? [{ src: t.art480, sizes: '480x480', type: 'image/jpeg' }, ...(t.art1000 ? [{ src: t.art1000, sizes: '1000x1000', type: 'image/jpeg' }] : [])]
      : [{ src: u, sizes: '512x512', type: (await idb.get('covers', k))?.type || 'image/jpeg' }];
    navigator.mediaSession.metadata = new MediaMetadata({ title: t.title, artist: t.artist, album: t.album || '', artwork });
  }
}
function markPlaying() {
  const id = loadedId || S.queue[S.qi];
  $$('.row').forEach((r) => r.classList.toggle('playing', r.dataset.id === id && (r.dataset.ctx !== 'queue' || +r.dataset.i === S.qi)));
}
function setupMediaSession() {
  if (!('mediaSession' in navigator)) return;
  const ms = navigator.mediaSession;
  const h = (a, f) => { try { ms.setActionHandler(a, f); } catch {} };
  h('play', () => togglePlay());
  h('pause', () => P.pause());
  h('previoustrack', prev);
  h('nexttrack', () => next());
  h('seekto', (d) => { if (d.seekTime != null) P.seek(d.seekTime); });
  h('seekbackward', (d) => { P.seek(Math.max(0, P.time() - (d.seekOffset || 10))); });
  h('seekforward', (d) => { P.seek(Math.min(P.dur() || 0, P.time() + (d.seekOffset || 10))); });
}

/* ================= likes & playlists ================= */
async function toggleLike(id) {
  const t = S.tracks.get(id); if (!t) return;
  t.liked = !t.liked; t.likedAt = t.liked ? Date.now() : 0;
  likes[id] = t.liked ? t.likedAt : -Date.now();
  lsSet('tempo:likes', likes);
  if (isStream(t)) { t._saved = true; if (!t.addedAt) t.addedAt = Date.now(); }
  await saveTrack(t);
  $$(`.like[data-id="${CSS.escape(id)}"]`).forEach((b) => { b.classList.toggle('on', t.liked); b.innerHTML = icon(t.liked ? 'heartFill' : 'heart'); });
  updateLikeUI();
  toast(t.liked ? 'Added to Liked Songs' : 'Removed from Liked Songs');
  renderSidebar(); changed();
  if (['liked', 'library'].includes(route().name)) render(true);
}
async function savePlaylist(p) {
  p.updatedAt = Date.now();
  S.playlists.set(p.id, p);
  delete plTomb[p.id]; lsSet('tempo:plTomb', plTomb);
  await idb.put('playlists', p);
  changed();
}
async function newPlaylist(withIds = [], name) {
  name ??= await ask({ title: 'New playlist', placeholder: 'My playlist', value: `My Playlist #${S.playlists.size + 1}`, ok: 'Create' });
  if (!name) return null;
  await keep(withIds);
  const p = { id: hash(name + Date.now() + Math.random()), name, ids: withIds.slice(), createdAt: Date.now() };
  await savePlaylist(p);
  renderSidebar();
  if (withIds.length === 1) toast(`Added to ${name}`); else location.hash = `#/playlist/${p.id}`;
  return p;
}
async function addToPlaylist(id) {
  const pls = [...S.playlists.values()].sort((a, b) => b.updatedAt - a.updatedAt);
  const choice = await pick('Add to playlist', [{ value: '__new', label: 'New playlist', html: `<div class="art xs" style="background:var(--surface)">${icon('plus')}</div>` },
    ...pls.map((p) => ({ value: p.id, label: p.name, sub: plural(p.ids.length, 'song'), html: plCover(p, 'xs') }))]);
  if (!choice) return;
  if (choice === '__new') { await newPlaylist([id]); return; }
  const p = S.playlists.get(choice);
  if (p.ids.includes(id) && !(await confirmBox('Already added', `This song is already in “${p.name}”. Add it again?`, 'Add anyway'))) return;
  await keep([id]);
  p.ids.push(id);
  await savePlaylist(p);
  toast(`Added to ${p.name}`);
  refresh();
}
async function removeFromPlaylist(plId, i) {
  const p = S.playlists.get(plId); if (!p) return;
  p.ids.splice(i, 1);
  await savePlaylist(p);
  toast(`Removed from ${p.name}`);
  refresh();
}
async function deletePlaylist(p) {
  S.playlists.delete(p.id);
  plTomb[p.id] = Date.now(); lsSet('tempo:plTomb', plTomb);
  await idb.del('playlists', p.id);
  changed();
}
async function deleteTrack(id) {
  const t = S.tracks.get(id); if (!t || isStream(t)) return;
  if (!(await confirmBox(isSC(t) ? 'Remove from library?' : 'Delete from this device?', `“${t.title}” will be removed from your library and your playlists.`, isSC(t) ? 'Remove' : 'Delete'))) return;
  const wasCurrent = S.queue[S.qi] === id;
  S.tracks.delete(id);
  await idb.del('tracks', id); await idb.del('files', id);
  for (const p of S.playlists.values()) if (p.ids.includes(id)) { p.ids = p.ids.filter((x) => x !== id); await savePlaylist(p); }
  const curId = S.queue[S.qi];
  const before = S.queue.slice(0, S.qi).filter((x) => x === id).length;
  S.queue = S.queue.filter((x) => x !== id);
  S.order = S.order?.filter((x) => x !== id) || null;
  S.recent = S.recent.filter((x) => x !== id);
  if (wasCurrent) {
    P.pause(); loadedId = null; switchEngine('audio');
    S.qi = Math.min(S.qi - before, S.queue.length - 1);
    if (S.qi >= 0) load(S.queue[S.qi], false); else { S.qi = -1; updateTrackUI(); updatePlayUI(); }
  } else S.qi = S.queue.indexOf(curId);
  if (isSC(t)) { scDeleted[id] = Date.now(); lsSet('tempo:scDel', scDeleted); changed(); }
  const k = albumKey(t);
  if (isFile(t) && !localTracks().some((x) => albumKey(x) === k)) {
    await idb.del('covers', k); coverKeys.delete(k);
    if (coverURL.has(k)) { URL.revokeObjectURL(coverURL.get(k)); coverURL.delete(k); }
  }
  if (pre.id === id) { revoke(pre.url); pre = { id: null, url: null }; }
  persist(); toast(isSC(t) ? 'Removed' : 'Deleted'); refresh();
}

/* ================= SoundCloud links ================= */
async function addSoundCloud(link) {
  link ??= await ask({ title: 'Add a SoundCloud song', placeholder: 'https://soundcloud.com/artist/song', ok: 'Add', type: 'url' });
  if (!link) return;
  if (!sc.isLink(link)) { toast("That doesn't look like a SoundCloud link"); return; }
  const tst = toast('Looking up the song…', 0);
  try {
    const info = await sc.lookup(link);
    if (info.isSet) { tst.set('Playlist links aren\'t supported yet. Paste a link to a single song'); setTimeout(tst.close, 3500); return; }
    const id = 'sc:' + hash(info.url);
    let t = S.tracks.get(id);
    if (!t) {
      t = { id, source: 'soundcloud', url: info.url, permalink: info.permalink, title: info.title, artist: info.artist, artistUrl: info.artistUrl,
        album: '', albumArtist: '', genre: '', duration: 0, track: 0, disc: 0, year: 0, art150: info.art150, art480: info.art480, art1000: info.art1000,
        addedAt: Date.now(), liked: likes[id] > 0, likedAt: likes[id] > 0 ? likes[id] : 0, plays: 0 };
      S.tracks.set(id, t);
      delete scDeleted[id]; lsSet('tempo:scDel', scDeleted);
      await saveTrack(t);
      changed();
    }
    tst.close();
    toast(`Added “${t.title}”`);
    if (route().name === 'search') { searchQ = ''; if ($('#q')) $('#q').value = ''; }
    refresh();
    unlock();
    playList([id], 0, { label: 'SoundCloud', href: '#/library/songs' });
  } catch (e) { tst.set(e.message || "Couldn't add that link"); setTimeout(tst.close, 3500); }
}

/* ================= YouTube songs & playlist import ================= */
let ytSearchOn = false, ytSearchState = '';
// "Artist - Song (Official Video)" on channel X -> { title: 'Song', artist: 'Artist' }
function cleanYT(title, channel) {
  let t = String(title).replace(/\s*[([](?:official\s*)?(?:music\s*|lyrics?\s*|lyric\s*)?(?:video|audio|visuali[sz]er)?(?:\s*\(?(?:hd|hq|4k)(?:\s*remaster(?:ed)?)?\)?)?[)\]]/gi, (m) => (/official|video|audio|lyric|visuali|hd|hq|4k/i.test(m) ? '' : m)).trim();
  let artist = channel || 'YouTube';
  const m = t.match(/^(.+?)\s+[-–—]\s+(.+)$/);
  if (m) { artist = m[1].trim(); t = m[2].trim(); }
  return { title: t || title, artist };
}
function ytTrack({ vid, title, artist, art = '', duration = 0, q = false, from = '' }) {
  const id = vid ? 'yt:' + vid : 'ytq:' + hash(`${artist}|${title}`.toLowerCase());
  const have = S.tracks.get(id);
  if (have) return have;
  const t = {
    id, source: 'youtube', vid: vid || '', q: !!q, from, title, artist, album: '', albumArtist: '', genre: '', duration, track: 0, disc: 0, year: 0,
    art150: art, art480: art, art1000: art, permalink: vid ? 'https://www.youtube.com/watch?v=' + vid : '',
    addedAt: Date.now(), liked: likes[id] > 0, likedAt: likes[id] > 0 ? likes[id] : 0, plays: 0,
  };
  S.tracks.set(id, t);
  return t;
}
const ytResultTrack = (r) => { const c = cleanYT(r.title, r.channel); return ytTrack({ vid: r.vid, title: r.topic ? r.title : c.title, artist: r.topic ? r.channel : c.artist, art: r.art, duration: r.duration }); };
function scTrack(x) {
  const id = 'sc:' + hash(x.url);
  let t = S.tracks.get(id);
  if (!t) {
    t = { id, source: 'soundcloud', url: x.url, permalink: x.permalink, title: x.title, artist: x.artist, artistUrl: x.artistUrl || '', album: '', albumArtist: '', genre: x.genre || '',
      duration: x.duration || 0, track: 0, disc: 0, year: 0, art150: x.art150, art480: x.art480, art1000: x.art1000, addedAt: Date.now(), liked: likes[id] > 0, likedAt: likes[id] > 0 ? likes[id] : 0, plays: 0 };
    S.tracks.set(id, t);
    delete scDeleted[id];
  }
  return t;
}
async function runYouTubeSearch() {
  const q = searchQ.trim();
  const box = $('#ytResults');
  if (!q || !box) return;
  ytSearchState = q;
  box.innerHTML = `<section class="sec"><h2>From YouTube</h2>${loading(5)}</section>`;
  try {
    const ts = (await yt.search(q)).map(ytResultTrack);
    if (searchQ.trim() !== q || !box.isConnected) return;
    box.innerHTML = `<section class="sec"><div class="sec-head"><h2>From YouTube</h2></div>${trackList(ts, 'ytsearch', { from: { label: `YouTube: ${q}`, href: '#/search/' + enc(q) }, noHead: true, empty: 'Nothing found on YouTube.' })}</section>`;
    markPlaying();
  } catch (e) { box.innerHTML = `<p class="empty-sm">${esc(e.message)}</p>`; }
}
function clearSearchBox() { if (route().name === 'search') { searchQ = ''; if ($('#q')) $('#q').value = ''; } }
async function addYouTube(link) {
  const vid = yt.videoId(link || '');
  if (!vid) { toast("That doesn't look like a YouTube video link"); return; }
  const tst = toast('Looking up the video…', 0);
  let info;
  try { info = await yt.info(vid); } catch { info = { vid, title: 'YouTube video', channel: 'YouTube', art: `https://i.ytimg.com/vi/${vid}/hqdefault.jpg` }; }
  const c = cleanYT(info.title, info.channel);
  const t = ytTrack({ vid, title: c.title, artist: c.artist, art: info.art });
  t.inLib = true;
  await keep([t.id]); await saveTrack(t); changed();
  tst.close(); toast(`Added “${t.title}”`);
  clearSearchBox(); refresh(); unlock();
  playList([t.id], 0, { label: 'YouTube', href: '#/library/songs' });
}
// Import a Spotify / YouTube / YouTube Music / SoundCloud playlist (or profile) as a Tempo playlist.
async function importPlaylist(link) {
  link ??= await ask({ title: 'Import a playlist', placeholder: 'Spotify, YouTube, YouTube Music or SoundCloud link', ok: 'Import', type: 'url' });
  if (!link) return null;
  link = link.trim();
  const tst = toast('Reading the playlist…', 0);
  try {
    let name, tracks, from;
    if (sc.isLink(link)) {
      const r = await sc.listSounds(link);
      if (!r.sounds.length) throw new Error('No playable songs found at that SoundCloud link');
      tracks = r.sounds.map(scTrack);
      lsSet('tempo:scDel', scDeleted);
      await idb.putMany('tracks', tracks.map((t) => ({ ...t, _saved: undefined })));
      const set = link.match(/\/sets\/([^/?#]+)/);
      name = set ? set[1].replace(/-/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase()) : `${r.owner || 'SoundCloud'} on SoundCloud`;
      from = 'SoundCloud';
    } else if (/open\.spotify\.com\//.test(link) || yt.isLink(link)) {
      await yt.searchEnabled();
      if (!yt.hasServer()) throw new Error('Importing from Spotify and YouTube works in the online version of Tempo (it needs its small server).');
      const d = await yt.importPlaylist(link);
      if (!d.tracks?.length) throw new Error('That playlist is empty');
      from = d.from; name = d.name;
      tracks = d.tracks.map((x) => {
        if (x.vid) { const c = cleanYT(x.title, x.artist); return ytTrack({ vid: x.vid, title: c.title, artist: c.artist, art: x.art, from }); }
        return ytTrack({ title: x.title, artist: x.artist, duration: x.duration, q: true, from });
      });
    } else throw new Error('Paste a Spotify, YouTube, YouTube Music or SoundCloud link');
    const ids = [...new Set(tracks.map((t) => t.id))];
    await keep(ids);
    let p = [...S.playlists.values()].find((x) => x.src === link);
    if (p) { p.ids = ids; p.name = name; await savePlaylist(p); location.hash = `#/playlist/${p.id}`; }
    else { p = await newPlaylist(ids, name); if (!p) return null; p.src = link; p.from = from; await savePlaylist(p); if (ids.length === 1) location.hash = `#/playlist/${p.id}`; }
    clearSearchBox(); refresh();
    tst.set(`Imported “${name}”: ${plural(ids.length, 'song')}`); setTimeout(tst.close, 3500);
    if (from === 'Spotify' && !ytSearchOn) setTimeout(() => toast('Tip: turn on YouTube search (see Account) so every imported song can play', 5000), 3600);
    return p;
  } catch (e) {
    tst.set(e.message || "Couldn't import that playlist"); setTimeout(tst.close, 4500);
    return null;
  }
}
async function linkSoundCloud() {
  const link = await ask({ title: 'Link your SoundCloud', placeholder: 'https://soundcloud.com/your-name', ok: 'Link', type: 'url', value: lsGet('tempo:scProfile', '') });
  if (!link) return;
  if (!sc.isLink(link)) { toast("That doesn't look like a SoundCloud profile link"); return; }
  lsSet('tempo:scProfile', link.trim());
  await importPlaylist(link.trim());
}

/* ================= recommendations, smart shuffle & DJ ================= */
const normG = (g) => String(g || '').toLowerCase().replace(/[^a-z]/g, '');
const matchGenre = (g) => { const n = normG(g); return n ? au.GENRES.find((x) => { const m = normG(x); return m && (n.includes(m) || m.includes(n)); }) || '' : ''; };
const countTop = (arr) => { const m = new Map(); arr.forEach((x) => m.set(x, (m.get(x) || 0) + 1)); return [...m.entries()].sort((a, b) => b[1] - a[1]).map(([k]) => k); };
function taste() {
  const score = (t) => (t.liked ? 5 : 0) + Math.min(t.plays || 0, 10) + (S.recent.includes(t.id) ? 2 : 0);
  const fav = [...S.tracks.values()].filter((t) => score(t) > 0).sort((a, b) => score(b) - score(a));
  return { fav, genres: countTop(fav.map((t) => matchGenre(t.genre)).filter(Boolean)), artists: countTop(fav.map((t) => t.artist)) };
}
// Songs similar to `seeds`: trending in their genres, more from their artists, and (if on) YouTube.
async function recommend(seeds, n = 8, exclude = new Set()) {
  const genres = countTop(seeds.map((t) => matchGenre(t.genre)).filter(Boolean));
  const auArtists = countTop(seeds.filter(isRemote).map((t) => t.artistId));
  const others = countTop(seeds.filter((t) => !isRemote(t)).map((t) => t.artist.split(',')[0].trim()));
  const jobs = [];
  for (const g of genres.slice(0, 2)) jobs.push(au.trending(g));
  for (const a of auArtists.slice(0, 2)) jobs.push(au.artistTracks(a));
  if (ytSearchOn && others.length) jobs.push(yt.search(`${others.slice(0, 2).join(', ')} similar songs`).then((rs) => rs.map(ytResultTrack)));
  if (!jobs.length) jobs.push(au.trending());
  const pools = (await Promise.all(jobs.map((j) => j.catch(() => [])))).map((l) => shuffleArr(ingest(l).slice(0, 25)));
  const seen = new Set([...exclude, ...seeds.map((t) => t.id)]);
  const seenNames = new Set(seeds.map((t) => `${t.artist}|${t.title}`.toLowerCase()));
  const out = [];
  for (let i = 0; out.length < n && i < 25; i++) {
    for (const pool of pools) {
      const t = pool[i];
      const key = t && `${t.artist}|${t.title}`.toLowerCase();
      if (!t || seen.has(t.id) || seenNames.has(key)) continue;
      seen.add(t.id); seenNames.add(key); out.push(t);
      if (out.length >= n) break;
    }
  }
  return out;
}
async function smartFill() {
  if (S.shuffle !== 'smart' || !S.queue.length) return;
  const seeds = S.queue.filter((id) => !S.recs.has(id)).map((id) => S.tracks.get(id)).filter(Boolean).slice(0, 40);
  const base = S.queue.slice(S.qi + 1).filter((id) => !S.recs.has(id));
  const recs = await recommend(seeds, Math.max(3, Math.min(15, Math.ceil(base.length / 3))), new Set(S.queue));
  if (S.shuffle !== 'smart' || !recs.length) return;
  await keep(recs.map((t) => t.id));
  const fresh = S.queue.slice(S.qi + 1).filter((id) => !S.recs.has(id));
  const out = []; let r = 0;
  fresh.forEach((id, i) => { out.push(id); if ((i + 1) % 3 === 0 && r < recs.length) { out.push(recs[r].id); S.recs.add(recs[r++].id); } });
  while (r < recs.length && out.length < 6) { out.push(recs[r].id); S.recs.add(recs[r++].id); }
  S.queue = S.queue.slice(0, S.qi + 1).concat(out);
  persist(); prefetchNext();
  if (route().name === 'queue') render(true);
}
function dropRecs() {
  if (!S.recs.size) return;
  const cur = S.queue[S.qi];
  S.queue = S.queue.filter((id, i) => i === S.qi || !S.recs.has(id));
  S.qi = Math.max(0, S.queue.indexOf(cur));
  S.recs.clear();
}

const DJ_NAME = 'DJ Tempo';
const DJ = { on: false, lines: new Map(), voice: lsGet('tempo:djVoice', true), seg: 0, busy: false };
function pickVoice() {
  const vs = window.speechSynthesis?.getVoices?.() || [];
  return vs.find((v) => /^en/i.test(v.lang) && /natural|neural|premium|enhanced|google us|samantha|daniel|aria|guy/i.test(v.name)) || vs.find((v) => /^en/i.test(v.lang));
}
function djSpeak(id) {
  const line = DJ.lines.get(id);
  DJ.lines.delete(id);
  if (!line) return Promise.resolve();
  const cap = $('#djCaption'); cap.textContent = line; cap.hidden = false;
  clearTimeout(djSpeak.t); djSpeak.t = setTimeout(() => { cap.hidden = true; }, 9000);
  if (!DJ.voice || !('speechSynthesis' in window)) return Promise.resolve();
  return new Promise((res) => {
    let done = false;
    const fin = () => { if (!done) { done = true; res(); } };
    const u = new SpeechSynthesisUtterance(line);
    const v = pickVoice(); if (v) u.voice = v;
    u.rate = 1.04; u.onend = fin; u.onerror = fin;
    setTimeout(fin, Math.min(15000, 2500 + line.length * 70));
    P.pause();
    speechSynthesis.cancel(); speechSynthesis.speak(u);
  });
}
function greeting() { const h = new Date().getHours(); return h < 5 ? 'Up late, huh' : h < 12 ? 'Good morning' : h < 18 ? 'Good afternoon' : 'Good evening'; }
async function djSegment(first = false, only = '') {
  const tp = taste();
  const used = new Set(S.queue);
  const kinds = only ? [only] : ['favorites', 'fresh', 'genre', 'throwback'];
  const hello = first ? `Hey, it's ${DJ_NAME}. ${greeting()}. ` : '';
  for (let tries = 0; tries < kinds.length; tries++) {
    const kind = kinds[(DJ.seg++) % kinds.length];
    let ts = [], line = '';
    if (kind === 'favorites') {
      ts = shuffleArr(tp.fav.filter((t) => !used.has(t.id)).slice(0, 15)).slice(0, 4);
      if (ts.length >= 2) line = `${hello}Let's start with some songs you keep coming back to. Here's ${ts[0].title} by ${ts[0].artist}.`;
    } else if (kind === 'fresh') {
      ts = await recommend(tp.fav.slice(0, 20), 4, used);
      if (ts.length) line = `${hello}Time for something new. I think ${ts[0].artist} fits your vibe. This is ${ts[0].title}.`;
    } else if (kind === 'genre') {
      const g = tp.genres[DJ.seg % Math.max(1, Math.min(3, tp.genres.length))] || au.GENRES[Math.floor(Math.random() * 12)];
      ts = shuffleArr(ingest(await au.trending(g).catch(() => [])).filter((t) => !used.has(t.id)).slice(0, 15)).slice(0, 4);
      if (ts.length) line = tp.genres.includes(g) ? `${hello}You've been in a ${g} mood lately, so here's what's hot in ${g} this week.` : `${hello}Let's dig into some ${g}. Starting with ${ts[0].artist}.`;
    } else if (kind === 'throwback') {
      const old = tp.fav.filter((t) => !used.has(t.id) && t.lastPlayed && Date.now() - t.lastPlayed > 2 * 864e5);
      ts = shuffleArr(old).slice(0, 3);
      if (ts.length >= 2) line = `${hello}Let's rewind a little. Remember this one? ${ts[0].title}.`;
    }
    if (line && ts.length) { DJ.lines.set(ts[0].id, line); return ts.map((t) => t.id); }
  }
  const ts = ingest(await au.trending()).filter((t) => !used.has(t.id)).slice(0, 5);
  if (ts.length) DJ.lines.set(ts[0].id, `${hello}Here's what everyone's playing this week, starting with ${ts[0].artist}.`);
  return ts.map((t) => t.id);
}
async function startDJ() {
  if (DJ.busy) return;
  DJ.busy = true;
  const tst = toast(`${DJ_NAME} is picking your songs…`, 0);
  try {
    DJ.lines.clear(); DJ.seg = 0;
    const ids = await djSegment(true);
    if (!ids.length) throw new Error("Couldn't reach the music catalog. Try again in a moment");
    if (S.shuffle) { S.shuffle = false; S.recs.clear(); updateModesUI(); }
    DJ.on = true;
    playList(ids, 0, { label: DJ_NAME, href: '#/home' });
  } catch (e) { toast(e.message); } finally { DJ.busy = false; tst.close(); }
}
async function djExtend() {
  if (DJ.busy || !DJ.on) return;
  DJ.busy = true;
  try { const ids = await djSegment(); if (DJ.on && ids.length) { await keep(ids); S.queue.push(...ids); persist(); prefetchNext(); } }
  finally { DJ.busy = false; }
}
async function djSwitch() {
  if (!DJ.on) return startDJ();
  if (DJ.busy) return;
  DJ.busy = true;
  try {
    const ids = await djSegment(false, ['fresh', 'genre'][Math.floor(Math.random() * 2)]);
    if (!ids.length) return;
    DJ.lines.set(ids[0], "Alright, let's switch it up. " + (DJ.lines.get(ids[0]) || ''));
    await keep(ids);
    S.queue = S.queue.slice(0, S.qi + 1).concat(ids);
    next();
  } finally { DJ.busy = false; }
}
function stopDJ() {
  DJ.on = false; DJ.lines.clear();
  try { speechSynthesis.cancel(); } catch {}
  $('#djCaption').hidden = true; $('#npDJ').hidden = true; $('#djPill').hidden = true;
}

/* ================= accounts & sync ================= */
let syncState = 'idle', lastSync = lsGet('tempo:lastSync', 0), pushTimer = null, pulling = null;
const stripTrack = (t) => ({ inLib: t.inLib, id: t.id, source: t.source, rid: t.rid, vid: t.vid, q: t.q, from: t.from, url: t.url, permalink: t.permalink, artistUrl: t.artistUrl, title: t.title, artist: t.artist, artistId: t.artistId, album: '', albumArtist: '', genre: t.genre, duration: t.duration, track: 0, disc: 0, year: t.year || 0, art150: t.art150, art480: t.art480, art1000: t.art1000, permalink: t.permalink });
function snapshot() {
  const pls = {};
  for (const [id, ts] of Object.entries(plTomb)) pls[id] = { id, deleted: true, updatedAt: ts };
  for (const p of S.playlists.values()) pls[p.id] = p;
  const needed = new Set([...[...S.tracks.values()].filter((t) => t.inLib).map((t) => t.id), ...likedTracks().map((t) => t.id), ...[...S.playlists.values()].flatMap((p) => p.ids)]);
  const tracks = [...needed].map((id) => S.tracks.get(id)).filter(isStream).map(stripTrack);
  for (const t of S.tracks.values()) if (isSC(t)) tracks.push({ ...stripTrack(t), addedAt: t.addedAt });
  return { v: 1, likes, playlists: pls, tracks, scDeleted, at: Date.now() };
}
async function applyRemote(r) {
  if (!r) return;
  const toSave = [];
  for (const [id, ts] of Object.entries(r.scDeleted || {})) {
    if (ts <= (scDeleted[id] || 0)) continue;
    scDeleted[id] = ts;
    const t = S.tracks.get(id);
    if (isSC(t) && t.addedAt < ts) { S.tracks.delete(id); await idb.del('tracks', id); }
  }
  lsSet('tempo:scDel', scDeleted);
  for (const t of r.tracks || []) {
    if (isSC(t) && (scDeleted[t.id] || 0) >= (t.addedAt || 0)) continue;
    if (!S.tracks.has(t.id)) { const nt = { ...t, liked: false, plays: 0, addedAt: t.addedAt || Date.now(), _saved: true }; S.tracks.set(t.id, nt); toSave.push(nt); }
  }
  for (const [id, ts] of Object.entries(r.likes || {})) if (Math.abs(ts) > Math.abs(likes[id] || 0)) likes[id] = ts;
  for (const t of S.tracks.values()) {
    const ts = likes[t.id];
    if (ts === undefined) continue;
    const liked = ts > 0;
    if (t.liked !== liked || (liked && t.likedAt !== ts)) { t.liked = liked; t.likedAt = liked ? ts : 0; if (!isStream(t) || t._saved) toSave.push(t); }
  }
  lsSet('tempo:likes', likes);
  if (toSave.length) await idb.putMany('tracks', [...new Set(toSave)].map((t) => ({ ...t, _saved: undefined })));
  for (const rp of Object.values(r.playlists || {})) {
    const local = S.playlists.get(rp.id);
    const localAt = local?.updatedAt ?? plTomb[rp.id] ?? -1;
    if (rp.updatedAt <= localAt) continue;
    if (rp.deleted) { S.playlists.delete(rp.id); plTomb[rp.id] = rp.updatedAt; await idb.del('playlists', rp.id); }
    else { S.playlists.set(rp.id, rp); delete plTomb[rp.id]; await idb.put('playlists', rp); }
  }
  lsSet('tempo:plTomb', plTomb);
}
function setSyncState(s) {
  syncState = s;
  if (s === 'ok') { lastSync = Date.now(); lsSet('tempo:lastSync', lastSync); }
  if (route().name === 'account') render(true);
}
async function syncNow() {
  if (!sync.currentUser()) return;
  if (pulling) return pulling;
  pulling = (async () => {
    setSyncState('syncing');
    try {
      await applyRemote(await sync.pull());
      await sync.push(snapshot());
      setSyncState('ok');
      refresh();
    } catch (e) {
      console.warn('sync failed', e);
      setSyncState('error');
    } finally { pulling = null; }
  })();
  return pulling;
}
// Called after any change to likes or playlists.
function changed() {
  if (!sync.currentUser()) return;
  clearTimeout(pushTimer);
  pushTimer = setTimeout(async () => {
    try { await sync.push(snapshot()); setSyncState('ok'); } catch (e) { console.warn('push failed', e); setSyncState('error'); }
  }, 1500);
}
async function onAuthForm(form, mode) {
  const email = form.email.value.trim(), password = form.password.value;
  if (!email || password.length < 6) { authMsg = 'Enter your email and a password of at least 6 characters.'; render(true); return; }
  authMsg = mode === 'signup' ? 'Creating your account…' : 'Signing in…';
  render(true);
  try {
    if (mode === 'signup') {
      const needsConfirm = await sync.signUp(email, password);
      authMsg = needsConfirm ? `Almost done: open the link we emailed to ${email}, then sign in here.` : '';
    } else { await sync.signIn(email, password); authMsg = ''; }
  } catch (e) {
    authMsg = /invalid login/i.test(e.message) ? 'Wrong email or password.' : e.message || 'Something went wrong.';
  }
  render(true);
}

/* ================= import (your own files) ================= */
function probeDuration(blob) {
  return new Promise((res) => {
    const a = new Audio(); const u = URL.createObjectURL(blob);
    let done = false;
    const end = (d) => { if (done) return; done = true; URL.revokeObjectURL(u); a.removeAttribute('src'); res(isFinite(d) ? d : 0); };
    a.preload = 'metadata';
    a.onloadedmetadata = () => end(a.duration);
    a.onerror = () => end(0);
    setTimeout(() => end(0), 6000);
    a.src = u;
  });
}
let importing = false;
async function importFiles(fileList) {
  const files = [...fileList].filter(isAudio);
  if (!files.length) { toast('No audio files found there'); return; }
  if (importing) { toast('Already adding songs. Hang on'); return; }
  importing = true;
  try { await navigator.storage?.persist?.(); } catch {}
  let added = 0, skipped = 0, failed = 0;
  const tst = toast(`Adding 0 of ${files.length}…`, 0);
  for (const [i, f] of files.entries()) {
    tst.set(`Adding ${i + 1} of ${files.length}…`);
    const id = hash(`${f.name}|${f.size}|${f.lastModified}`);
    if (S.tracks.has(id)) { skipped++; continue; }
    try {
      const tags = await readTags(f);
      const fn = parseName(f.name);
      const type = f.type || MIME[extOf(f.name)] || 'audio/mpeg';
      const t = {
        id, source: 'file', title: tags.title || fn.title, artist: tags.artist || fn.artist || 'Unknown Artist',
        album: tags.album || 'Unknown Album', albumArtist: tags.albumArtist || '',
        track: tags.track || 0, disc: tags.disc || 0, year: tags.year || 0, genre: tags.genre || '',
        duration: 0, size: f.size, type, file: f.name, addedAt: Date.now() + i, liked: likes[id] > 0, likedAt: likes[id] > 0 ? likes[id] : 0, plays: 0,
      };
      const blob = new Blob([await f.arrayBuffer()], { type });
      const k = albumKey(t);
      if (tags.picture && tags.picture.size > 200 && !coverKeys.has(k)) { await idb.put('covers', tags.picture, k); coverKeys.add(k); }
      t.duration = await probeDuration(blob);
      await idb.put('files', blob, id);
      await idb.put('tracks', t);
      S.tracks.set(id, t);
      added++;
      if (added === 1 || added % 10 === 0) refresh();
    } catch (e) {
      console.error('Import failed for', f.name, e);
      failed++;
      if (e?.name === 'QuotaExceededError') { toast('This device is out of space for more songs'); break; }
    }
  }
  importing = false;
  tst.set([added && `Added ${plural(added, 'song')}`, skipped && `${skipped} already added`, failed && `${failed} failed`].filter(Boolean).join(' · ') || 'Nothing added');
  setTimeout(() => tst.close(), 3500);
  refresh();
}
async function filesFromDrop(dt) {
  const entries = [...(dt.items || [])].map((it) => it.webkitGetAsEntry?.()).filter(Boolean);
  if (!entries.length) return [...dt.files];
  const out = [];
  const walk = async (e) => {
    if (e.isFile) out.push(await new Promise((r, j) => e.file(r, j)));
    else if (e.isDirectory) {
      const rd = e.createReader(); let batch;
      do { batch = await new Promise((r, j) => rd.readEntries(r, j)); for (const c of batch) await walk(c); } while (batch.length);
    }
  };
  for (const e of entries) { try { await walk(e); } catch (err) { console.warn(err); } }
  return out;
}

/* ================= UI bits: toast, dialog, menu ================= */
function toast(msg, ms = 2200) {
  const el = document.createElement('div');
  el.className = 'toast'; el.textContent = msg;
  const box = $('#toasts');
  while (box.children.length > 2) box.firstChild.remove();
  box.appendChild(el);
  const api = { set: (m) => { el.textContent = m; }, close: () => el.remove() };
  if (ms) setTimeout(api.close, ms);
  return api;
}
const dlg = $('#dlg');
dlg.addEventListener('click', (e) => { if (e.target === dlg) dlg.close('cancel'); });
function openDialog(html, onClose) {
  return new Promise((res) => {
    dlg.innerHTML = html; dlg.returnValue = '';
    dlg.onclose = () => res(onClose(dlg.returnValue));
    dlg.showModal();
  });
}
function ask({ title, value = '', placeholder = '', ok = 'Save', type = 'text' }) {
  const p = openDialog(`<form method="dialog"><h3>${esc(title)}</h3><input name="v" type="${type}" value="${esc(value)}" placeholder="${esc(placeholder)}" maxlength="100" required autocomplete="off">
    <div class="dlg-btns"><button class="btn ghost" value="cancel" formnovalidate>Cancel</button><button class="btn primary" value="ok">${esc(ok)}</button></div></form>`,
  (rv) => (rv === 'ok' ? $('input', dlg).value.trim() || null : null));
  const inp = $('input', dlg); inp.focus(); inp.select();
  return p;
}
function confirmBox(title, msg, ok = 'Delete') {
  return openDialog(`<form method="dialog"><h3>${esc(title)}</h3><p>${esc(msg)}</p><div class="dlg-btns"><button class="btn ghost" value="cancel">Cancel</button><button class="btn ${ok === 'Delete' ? 'danger' : 'primary'}" value="ok">${esc(ok)}</button></div></form>`, (rv) => rv === 'ok');
}
function pick(title, items) {
  const p = openDialog(`<form method="dialog"><h3>${esc(title)}</h3><div class="pick">${items.map((it) => `<button value="${esc(it.value)}">${it.html || ''}<div class="meta"><div class="ttl">${esc(it.label)}</div>${it.sub ? `<div class="sub">${esc(it.sub)}</div>` : ''}</div></button>`).join('')}</div>
    <div class="dlg-btns"><button class="btn ghost" value="">Cancel</button></div></form>`, (rv) => rv || null);
  hydrateCovers(dlg);
  return p;
}
const menu = $('#menu'), scrim = $('#scrim');
function openMenu(btn) {
  const id = btn.dataset.id, ctx = btn.dataset.ctx || '', i = btn.dataset.i;
  const t = S.tracks.get(id); if (!t) return;
  const items = [
    ['qnext', 'playNext', 'Play next'], ['qadd', 'queue', 'Add to queue'], ['addpl', 'plus', 'Add to playlist'],
    ['like', t.liked ? 'heartFill' : 'heart', t.liked ? 'Remove from Liked Songs' : 'Save to Liked Songs'],
  ];
  if (isFile(t)) items.push(['goAlbum', 'album', 'Go to album']);
  items.push(['goArtist', 'user', 'Go to artist']);
  if (ctx.startsWith('pl:')) items.push(['rmpl', 'x', 'Remove from this playlist']);
  if (ctx === 'queue' && +i !== S.qi) items.push(['qremove', 'x', 'Remove from queue']);
  if (isRemote(t)) items.push(['openSource', 'link', 'Open on Audius']);
  else if (isYT(t)) items.push(['openSource', 'link', 'Open on YouTube']);
  else if (isSC(t)) items.push(['openSource', 'link', 'Open on SoundCloud'], ['del', 'trash', 'Remove from library', 'danger']);
  else items.push(['del', 'trash', 'Delete from this device', 'danger']);
  menu.innerHTML = `<div class="mh">${trackArt(t, 'xs')}<div class="meta"><div class="ttl">${esc(t.title)}</div><div class="sub">${esc(t.artist)}</div></div></div>` +
    items.map(([a, ic, l, c]) => `<button data-act="${a}" data-id="${esc(id)}" data-ctx="${esc(ctx)}" data-i="${i}" class="${c || ''}">${icon(ic)}${esc(l)}</button>`).join('');
  menu.hidden = false;
  hydrateCovers(menu);
  if (isMobile()) { scrim.hidden = false; return; }
  const r = btn.getBoundingClientRect(), mw = menu.offsetWidth, mh = menu.offsetHeight;
  let x = r.right - mw, y = r.bottom + 4;
  if (y + mh > innerHeight - 8) y = Math.max(8, r.top - mh - 4);
  menu.style.left = Math.max(8, x) + 'px'; menu.style.top = y + 'px';
}
function closeMenu() { menu.hidden = true; scrim.hidden = true; }

/* ================= actions (event delegation) ================= */
const ctxList = (ctx) => (ctx?.startsWith('pl:') ? plTracks(S.playlists.get(ctx.slice(3)) || { ids: [] }).map((t) => t.id) : lists[ctx]) || [];
const ctxFrom = (ctx) => froms[ctx] || (ctx === 'queue' ? S.from : { label: 'Your Library', href: '#/library' });
const A = {
  go() {},
  nav: (el) => { location.hash = el.dataset.href; },
  back: () => { if (history.length > 1) history.back(); else location.hash = '#/home'; },
  retry: () => render(true),
  play(el) {
    const { ctx, i } = el.dataset;
    if (ctx === 'queue') { S.qi = +i; load(S.queue[S.qi]); return; }
    const from = ctxFrom(ctx);
    if ((loadedId || S.queue[S.qi]) === el.dataset.id && S.from?.href === from.href && S.from?.label === from.label) { togglePlay(); return; }
    playList(ctxList(ctx), +i, from);
  },
  playAll: (el) => { const ids = ctxList(el.dataset.ctx); if (S.shuffle) { S.shuffle = false; S.recs.clear(); updateModesUI(); } playList(ids, 0, ctxFrom(el.dataset.ctx)); },
  shuffleAll: (el) => shufflePlay(ctxList(el.dataset.ctx), ctxFrom(el.dataset.ctx)),
  playAlbum: (el) => { const a = getAlbums().find((x) => x.key === el.dataset.key); if (a) playList(a.tracks.map((t) => t.id), 0, { label: a.name, href: `#/album/${enc(a.key)}` }); },
  async playRemotePl(el) {
    try { const p = await au.playlist(el.dataset.id); const ts = ingest(p.tracks); if (!ts.length) return toast('No playable songs in this playlist'); playList(ts.map((t) => t.id), 0, { label: p.name, href: `#/p/${enc(p.id)}` }); }
    catch { toast("Couldn't load that playlist"); }
  },
  async savePl(el) {
    try { const p = await au.playlist(el.dataset.id); const ts = ingest(p.tracks); await newPlaylist(ts.map((t) => t.id), p.name); toast(`Saved “${p.name}” to your library`); }
    catch { toast("Couldn't save that playlist"); }
  },
  toggle: togglePlay,
  next: () => next(),
  prev,
  shuffle: toggleShuffle,
  repeat: cycleRepeat,
  like: (el) => toggleLike(el.dataset.id),
  likeCur: (el, e) => { e.stopPropagation(); const t = current(); if (t) toggleLike(t.id); },
  more: (el) => openMenu(el),
  qnext: (el) => playNext(el.dataset.id),
  qadd: (el) => addToQueue(el.dataset.id),
  qremove: (el) => { removeFromQueue(+el.dataset.i); render(true); },
  clearQueue: () => { S.queue = S.queue.slice(0, S.qi + 1); S.order = null; persist(); render(true); toast('Queue cleared'); },
  addpl: (el) => addToPlaylist(el.dataset.id),
  rmpl: (el) => removeFromPlaylist(el.dataset.ctx.slice(3), +el.dataset.i),
  goAlbum: (el) => { location.hash = `#/album/${enc(albumKey(S.tracks.get(el.dataset.id)))}`; },
  goArtist: (el) => { location.hash = artistHref(S.tracks.get(el.dataset.id)); },
  openSource: (el) => { const t = S.tracks.get(el.dataset.id); const u = t && sourceURL(t); if (u) open(u, '_blank', 'noopener'); },
  del: (el) => deleteTrack(el.dataset.id),
  newPlaylist: () => newPlaylist(),
  async plRename(el) {
    const p = S.playlists.get(el.dataset.pl);
    const name = await ask({ title: 'Rename playlist', value: p.name });
    if (!name) return;
    p.name = name; await savePlaylist(p); refresh();
  },
  async plDelete(el) {
    const p = S.playlists.get(el.dataset.pl);
    if (!(await confirmBox('Delete playlist?', `“${p.name}” will be deleted. The songs stay in your library.`))) return;
    await deletePlaylist(p);
    location.hash = '#/library/playlists'; renderSidebar(); toast('Playlist deleted');
  },
  import: () => $('#fileIn').click(),
  addSC: (el) => addSoundCloud(el.dataset.link),
  embMin: () => { if (engine === 'sc') $('#embedBox').classList.toggle('min'); },
  importPl: (el) => importPlaylist(el.dataset.link),
  linkSC: () => linkSoundCloud(),
  ytSearch: () => runYouTubeSearch(),
  addYT: (el) => addYouTube(el.dataset.link),
  dj: () => startDJ(),
  djSwitch: () => djSwitch(),
  djVoice: () => { DJ.voice = !DJ.voice; lsSet('tempo:djVoice', DJ.voice); if (!DJ.voice) speechSynthesis?.cancel(); toast(DJ.voice ? 'DJ voice on' : 'DJ voice off'); render(true); },
  djStop: () => { stopDJ(); toast('DJ off'); },
  importDir: () => $('#dirIn').click(),
  openNP: () => { if (!current()) return; $('#np').hidden = false; },
  closeNP: () => { $('#np').hidden = true; },
  queue: () => { $('#np').hidden = true; location.hash = '#/queue'; },
  mute: () => { audio.muted = !audio.muted; updateVolUI(); setVolumeAll(); persist(); },
  syncNow: () => syncNow(),
  async signOut() { await sync.signOut(); toast('Signed out'); },
  async forgot() {
    const email = await ask({ title: 'Reset your password', placeholder: 'you@example.com', ok: 'Send link', type: 'email' });
    if (!email) return;
    try { await sync.resetPassword(email); toast('Check your email for a reset link', 4000); } catch (e) { toast(e.message || 'Could not send the email'); }
  },
  async install() { if (!installEvt) return; installEvt.prompt(); await installEvt.userChoice; installEvt = null; $('#installBtn').hidden = true; render(true); },
  hideInstall: () => { lsSet('tempo:hideInstall', true); render(true); },
};
const PLAY_ACTS = new Set(['play', 'toggle', 'next', 'prev', 'playAll', 'shuffleAll', 'playAlbum', 'playRemotePl', 'qnext', 'qadd', 'dj', 'djSwitch']);
addEventListener('keydown', (e) => {
  if (e.key !== 'Enter' || e.target.id !== 'q') return;
  const v = e.target.value.trim();
  const btn = $('#results [data-act=importPl], #results [data-act=addSC], #results [data-act=addYT]');
  if (btn) btn.click();
  else if (v && ytSearchOn && !sc.isLink(v) && !yt.isLink(v)) runYouTubeSearch();
});
document.addEventListener('click', (e) => {
  const el = e.target.closest('[data-act]');
  const inMenu = el?.closest('#menu');
  if (!el) { if (!menu.hidden && !e.target.closest('#menu')) closeMenu(); return; }
  const act = el.dataset.act;
  if (act !== 'go' && el.tagName !== 'A') e.preventDefault();
  if (act !== 'more' || !menu.hidden) closeMenu();
  if (PLAY_ACTS.has(act)) unlock();
  if ((act === 'dj' || act === 'djSwitch') && DJ.voice && 'speechSynthesis' in window) { try { speechSynthesis.speak(new SpeechSynthesisUtterance('')); } catch {} }
  A[act]?.(el, e);
  if (inMenu) closeMenu();
});
scrim.addEventListener('click', closeMenu);
document.addEventListener('submit', (e) => {
  if (e.target.id !== 'authForm') return;
  e.preventDefault();
  onAuthForm(e.target, e.submitter?.value === 'signup' ? 'signup' : 'signin');
});

/* inputs */
document.addEventListener('input', (e) => {
  if (e.target.id === 'q') { searchQ = e.target.value; updateSearch(); }
  if (e.target.classList.contains('seek')) {
    seeking = true;
    const v = e.target.value / 10;
    e.target.style.setProperty('--p', v + '%');
    const d = loadedId ? P.dur() : current()?.duration || 0;
    $$('[data-t=cur]').forEach((el) => { el.textContent = fmt((v / 100) * d); });
  }
  if (e.target.id === 'vol') { audio.volume = +e.target.value; audio.muted = false; updateVolUI(); setVolumeAll(); }
});
document.addEventListener('change', (e) => {
  if (e.target.classList.contains('seek')) {
    const frac = e.target.value / 1000;
    if (loadedId && isFinite(P.dur())) P.seek(frac * P.dur());
    else if (current()) pendingSeek = frac * (current().duration || 0);
    seeking = false; updateTime(); persist();
  }
  if (e.target.id === 'sort') { lsSet('tempo:sort', e.target.value); render(true); }
  if (e.target.id === 'vol') persist();
});
function updateVolUI() {
  const v = audio.muted ? 0 : audio.volume;
  const vol = $('#vol'); vol.value = v; vol.style.setProperty('--p', v * 100 + '%');
  $('#muteBtn').innerHTML = icon(v === 0 ? 'mute' : 'volume');
}
$('#fileIn').addEventListener('change', (e) => { importFiles(e.target.files); e.target.value = ''; });
$('#dirIn').addEventListener('change', (e) => { importFiles(e.target.files); e.target.value = ''; });

/* drag & drop */
let dragDepth = 0;
const hasFiles = (e) => [...(e.dataTransfer?.types || [])].includes('Files');
addEventListener('dragenter', (e) => { if (!hasFiles(e)) return; e.preventDefault(); dragDepth++; $('#drop').hidden = false; });
addEventListener('dragover', (e) => { if (hasFiles(e)) e.preventDefault(); });
addEventListener('dragleave', () => { if (--dragDepth <= 0) { dragDepth = 0; $('#drop').hidden = true; } });
addEventListener('drop', async (e) => {
  if (!hasFiles(e)) return;
  e.preventDefault(); dragDepth = 0; $('#drop').hidden = true;
  importFiles(await filesFromDrop(e.dataTransfer));
});

/* keyboard */
addEventListener('keydown', (e) => {
  if (e.target.closest('input,textarea,select,dialog') || e.metaKey || e.ctrlKey || e.altKey) return;
  if (e.key === ' ') { e.preventDefault(); unlock(); togglePlay(); }
  else if (e.key === 'ArrowRight' && e.shiftKey) next();
  else if (e.key === 'ArrowLeft' && e.shiftKey) prev();
  else if (e.key === 'ArrowRight' && loadedId) P.seek(Math.min(P.dur() || 0, P.time() + 5));
  else if (e.key === 'ArrowLeft' && loadedId) P.seek(Math.max(0, P.time() - 5));
  else if (e.key === 'Escape') { closeMenu(); $('#np').hidden = true; }
  else if (e.key === '/') { e.preventDefault(); location.hash = '#/search'; setTimeout(() => $('#q')?.focus(), 0); }
  else if (e.key.toLowerCase() === 's') toggleShuffle();
  else if (e.key.toLowerCase() === 'r') cycleRepeat();
  else if (e.key.toLowerCase() === 'l' && current()) toggleLike(current().id);
});

/* keep body.np-open in sync with the Now Playing sheet (the YouTube video moves into it) */
new MutationObserver(() => document.body.classList.toggle('np-open', !$('#np').hidden)).observe($('#np'), { attributes: true, attributeFilter: ['hidden'] });

/* swipe down to close the now-playing sheet */
(() => {
  const np = $('#np'); let y0 = null;
  np.addEventListener('touchstart', (e) => { if (!e.target.closest('input')) y0 = e.touches[0].clientY; }, { passive: true });
  np.addEventListener('touchend', (e) => { if (y0 != null && e.changedTouches[0].clientY - y0 > 90) np.hidden = true; y0 = null; });
})();

/* install */
let installEvt = null;
const isIOS = () => /iphone|ipad|ipod/i.test(navigator.userAgent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
const isStandalone = () => matchMedia('(display-mode: standalone)').matches || navigator.standalone === true;
addEventListener('beforeinstallprompt', (e) => { e.preventDefault(); installEvt = e; $('#installBtn').hidden = false; if (route().name === 'home') render(true); });
addEventListener('appinstalled', () => { installEvt = null; $('#installBtn').hidden = true; toast('Tempo installed'); });

/* ================= boot ================= */
async function boot() {
  fillIcons();
  if (!('webkitdirectory' in document.createElement('input')) || isIOS()) $$('[data-act=importDir]').forEach((b) => { b.hidden = true; });
  likes = lsGet('tempo:likes', {});
  plTomb = lsGet('tempo:plTomb', {});
  scDeleted = lsGet('tempo:scDel', {});
  try {
    const [tracks, pls, ck] = await Promise.all([idb.all('tracks'), idb.all('playlists'), idb.keys('covers')]);
    tracks.forEach((t) => { if (isStream(t)) t._saved = true; else t.source ??= 'file'; S.tracks.set(t.id, t); if (t.liked && likes[t.id] === undefined) likes[t.id] = t.likedAt || 1; });
    pls.forEach((p) => S.playlists.set(p.id, p));
    ck.forEach((k) => coverKeys.add(k));
  } catch (e) {
    console.error(e);
    toast('Storage is unavailable here (private browsing?). Your likes won\'t be saved.', 6000);
  }
  restore();
  setupMediaSession();
  updateModesUI(); updateVolUI();
  if (current()) updateTrackUI(); else updatePlayUI();
  addEventListener('hashchange', () => { closeMenu(); $('#np').hidden = true; render(); });
  render(); renderSidebar();
  addEventListener('pagehide', persist);
  let lastPull = 0;
  document.addEventListener('visibilitychange', () => {
    if (document.hidden) { persist(); return; }
    if (sync.currentUser() && Date.now() - lastPull > 30e3) { lastPull = Date.now(); syncNow(); }
  });
  addEventListener('online', () => { if (['home', 'search', 'genre', 'a', 'p'].includes(route().name)) render(true); });
  if ('serviceWorker' in navigator && location.protocol !== 'file:') navigator.serviceWorker.register('sw.js').catch(() => {});
  yt.searchEnabled().then((on) => { ytSearchOn = on; if (['search', 'account'].includes(route().name)) render(true); });
  if (sync.enabled) {
    sync.onAuthChange((user) => {
      authMsg = '';
      renderSidebar();
      if (user) { toast(`Signed in as ${user.email}`); lastPull = Date.now(); syncNow(); if (route().name === 'account') render(true); }
      else { setSyncState('idle'); render(true); }
    });
    try {
      const user = await sync.init();
      renderSidebar();
      if (user) { lastPull = Date.now(); syncNow(); }
      if (route().name === 'account' || route().name === 'home') render(true);
    } catch (e) { console.warn('Accounts unavailable', e); }
  }
}
boot();

// exposed for debugging in the browser console
window.tempo = { S, importFiles, readTags, snapshot, syncNow, addSoundCloud, importPlaylist, addYouTube, startDJ, recommend, DJ };
