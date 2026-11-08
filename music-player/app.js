// Tempo — a personal music player.
// Your songs are stored on this device (IndexedDB). Nothing is uploaded anywhere.

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
const hash = (str) => { let h = 2166136261; for (let i = 0; i < str.length; i++) { h ^= str.charCodeAt(i); h = Math.imul(h, 16777619); } return (h >>> 0).toString(36); };
const hue = (str) => parseInt(hash(str || 'x'), 36) % 360;
const plural = (n, w) => `${n} ${w}${n === 1 ? '' : 's'}`;
const isMobile = () => matchMedia('(max-width:760px)').matches;
const shuffleArr = (a) => { for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; } return a; };
const byText = (k) => (a, b) => (a[k] || '').localeCompare(b[k] || '', undefined, { sensitivity: 'base', numeric: true });

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
  music: 'M9 18V5l12-2v13M9 18a3 3 0 1 1-6 0 3 3 0 0 1 6 0zM21 16a3 3 0 1 1-6 0 3 3 0 0 1 6 0z',
  edit: 'M12 20h9M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4z',
  x: 'M6 6l12 12M18 6 6 18',
  album: 'M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zM12 10a2 2 0 1 0 0 4 2 2 0 0 0 0-4z',
  user: 'M20 21a8 8 0 0 0-16 0M12 3a4 4 0 1 0 0 8 4 4 0 0 0 0-8z',
  playNext: 'M3 6h11M3 12h11M3 18h7M17 10v8M13 14h8',
  share: 'M4 12v7a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-7M12 3v12M8 7l4-4 4 4',
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
  del: (st, k) => tx(st, 'readwrite', (s) => s.delete(k)),
};

/* ================= tag readers (ID3v2 / MP4 / FLAC) ================= */
const syncsafe = (b, o) => ((b[o] & 0x7f) << 21) | ((b[o + 1] & 0x7f) << 14) | ((b[o + 2] & 0x7f) << 7) | (b[o + 3] & 0x7f);
const u32 = (b, o) => ((b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3]) >>> 0;
const num = (v) => parseInt(v, 10) || 0;

function decodeText(e, bytes) {
  let label = 'iso-8859-1';
  if (e === 1) {
    if (bytes[0] === 0xfe && bytes[1] === 0xff) { label = 'utf-16be'; bytes = bytes.subarray(2); }
    else { label = 'utf-16le'; if (bytes[0] === 0xff && bytes[1] === 0xfe) bytes = bytes.subarray(2); }
  } else if (e === 2) label = 'utf-16be';
  else if (e === 3) label = 'utf-8';
  return new TextDecoder(label).decode(bytes).replace(/\0[\s\S]*$/, '').trim();
}
function unsync(b) {
  const r = new Uint8Array(b.length); let n = 0;
  for (let i = 0; i < b.length; i++) { r[n++] = b[i]; if (b[i] === 0xff && b[i + 1] === 0) i++; }
  return r.subarray(0, n);
}
async function readID3(file) {
  const out = {};
  const h = new Uint8Array(await file.slice(0, 10).arrayBuffer());
  const ver = h[3], flags = h[5], size = syncsafe(h, 6);
  if (ver < 3 || ver > 4) return out;
  let b = new Uint8Array(await file.slice(10, 10 + size).arrayBuffer());
  if (flags & 0x80 && ver === 3) b = unsync(b);
  let o = 0;
  if (flags & 0x40) o = ver === 4 ? syncsafe(b, 0) : u32(b, 0) + 4;
  while (o + 10 <= b.length) {
    const id = String.fromCharCode(b[o], b[o + 1], b[o + 2], b[o + 3]);
    if (!/^[A-Z0-9]{4}$/.test(id)) break;
    const sz = ver === 4 ? syncsafe(b, o + 4) : u32(b, o + 4);
    if (sz <= 0 || o + 10 + sz > b.length) break;
    const d = b.subarray(o + 10, o + 10 + sz);
    o += 10 + sz;
    if (id[0] === 'T' && id !== 'TXXX') {
      const v = decodeText(d[0], d.subarray(1));
      if (!v) continue;
      if (id === 'TIT2') out.title = v;
      else if (id === 'TPE1') out.artist = v;
      else if (id === 'TALB') out.album = v;
      else if (id === 'TPE2') out.albumArtist = v;
      else if (id === 'TRCK') out.track = num(v);
      else if (id === 'TPOS') out.disc = num(v);
      else if (id === 'TYER' || id === 'TDRC') out.year = num(v);
      else if (id === 'TCON') out.genre = v.replace(/^\(\d+\)/, '').trim() || v;
    } else if (id === 'APIC' && !out.picture) {
      const e = d[0]; let p = 1;
      while (p < d.length && d[p] !== 0) p++;
      let mime = new TextDecoder('iso-8859-1').decode(d.subarray(1, p)).toLowerCase() || 'image/jpeg';
      if (!mime.includes('/')) mime = 'image/' + (mime === 'jpg' ? 'jpeg' : mime);
      p += 2; // null + picture type
      if (e === 1 || e === 2) { while (p + 1 < d.length && !(d[p] === 0 && d[p + 1] === 0)) p += 2; p += 2; }
      else { while (p < d.length && d[p] !== 0) p++; p++; }
      if (p < d.length) out.picture = new Blob([d.slice(p)], { type: mime });
    }
  }
  return out;
}
function applyKV(out, k, v) {
  if (!v) return;
  const map = {
    TITLE: 'title', ARTIST: 'artist', ALBUM: 'album', ALBUMARTIST: 'albumArtist', 'ALBUM ARTIST': 'albumArtist',
    TRACKNUMBER: 'track', DISCNUMBER: 'disc', DATE: 'year', YEAR: 'year', GENRE: 'genre',
  };
  const f = map[k];
  if (!f || out[f]) return;
  out[f] = ['track', 'disc', 'year'].includes(f) ? num(v) : v;
}
async function readFLAC(file) {
  const out = {}; let o = 4;
  for (let n = 0; n < 128; n++) {
    const hd = new Uint8Array(await file.slice(o, o + 4).arrayBuffer());
    if (hd.length < 4) break;
    const last = hd[0] & 0x80, type = hd[0] & 0x7f, len = (hd[1] << 16) | (hd[2] << 8) | hd[3];
    if (type === 4 || (type === 6 && !out.picture)) {
      const b = new Uint8Array(await file.slice(o + 4, o + 4 + len).arrayBuffer());
      const dv = new DataView(b.buffer);
      if (type === 4) {
        let p = 0; const td = new TextDecoder();
        p += 4 + dv.getUint32(p, true);
        const cnt = dv.getUint32(p, true); p += 4;
        for (let i = 0; i < cnt && p + 4 <= b.length; i++) {
          const l = dv.getUint32(p, true); p += 4;
          const s = td.decode(b.subarray(p, p + l)); p += l;
          const eq = s.indexOf('=');
          if (eq > 0) applyKV(out, s.slice(0, eq).toUpperCase(), s.slice(eq + 1).trim());
        }
      } else {
        let p = 4; const ml = dv.getUint32(p); p += 4;
        const mime = new TextDecoder().decode(b.subarray(p, p + ml)); p += ml;
        p += 4 + dv.getUint32(p) + 16;
        const L = dv.getUint32(p); p += 4;
        out.picture = new Blob([b.slice(p, p + L)], { type: mime || 'image/jpeg' });
      }
    }
    o += 4 + len;
    if (last) break;
  }
  return out;
}
async function readMP4(file) {
  const out = {}; let o = 0, moov = null;
  while (o + 8 <= file.size) {
    const hb = await file.slice(o, o + 16).arrayBuffer();
    const h = new DataView(hb);
    let sz = h.getUint32(0); let hdr = 8;
    const type = String.fromCharCode(h.getUint8(4), h.getUint8(5), h.getUint8(6), h.getUint8(7));
    if (sz === 1 && hb.byteLength >= 16) { sz = Number(h.getBigUint64(8)); hdr = 16; }
    else if (sz === 0) sz = file.size - o;
    if (sz < hdr) break;
    if (type === 'moov') { moov = new Uint8Array(await file.slice(o + hdr, o + sz).arrayBuffer()); break; }
    o += sz;
  }
  if (!moov) return out;
  const child = (b, name) => {
    const dv = new DataView(b.buffer, b.byteOffset, b.byteLength); let p = 0;
    while (p + 8 <= b.length) {
      const s = dv.getUint32(p);
      if (s < 8) return null;
      if (String.fromCharCode(b[p + 4], b[p + 5], b[p + 6], b[p + 7]) === name) return b.subarray(p + 8, p + s);
      p += s;
    }
    return null;
  };
  const udta = child(moov, 'udta'); if (!udta) return out;
  let meta = child(udta, 'meta'); if (!meta) return out;
  if (String.fromCharCode(meta[4], meta[5], meta[6], meta[7]) !== 'hdlr') meta = meta.subarray(4); // full box
  const ilst = child(meta, 'ilst'); if (!ilst) return out;
  const dv = new DataView(ilst.buffer, ilst.byteOffset, ilst.byteLength); const td = new TextDecoder();
  let p = 0;
  while (p + 8 <= ilst.length) {
    const s = dv.getUint32(p); if (s < 8) break;
    const t = String.fromCharCode(ilst[p + 4], ilst[p + 5], ilst[p + 6], ilst[p + 7]);
    const item = ilst.subarray(p + 8, p + s); p += s;
    if (item.length < 16) continue;
    const dsz = Math.min(new DataView(item.buffer, item.byteOffset, item.byteLength).getUint32(0), item.length);
    const dtype = item[11]; const pl = item.subarray(16, dsz);
    const str = () => td.decode(pl).trim();
    switch (t) {
      case '©nam': out.title = str(); break;
      case '©ART': out.artist = str(); break;
      case '©alb': out.album = str(); break;
      case 'aART': out.albumArtist = str(); break;
      case '©day': out.year = num(str()); break;
      case '©gen': out.genre = str(); break;
      case 'trkn': if (pl.length >= 4) out.track = (pl[2] << 8) | pl[3]; break;
      case 'disk': if (pl.length >= 4) out.disc = (pl[2] << 8) | pl[3]; break;
      case 'covr': if (!out.picture) out.picture = new Blob([pl.slice()], { type: dtype === 14 ? 'image/png' : 'image/jpeg' }); break;
    }
  }
  return out;
}
async function readTags(file) {
  try {
    const h = new Uint8Array(await file.slice(0, 12).arrayBuffer());
    const a = String.fromCharCode(...h.subarray(0, 4)), b = String.fromCharCode(...h.subarray(4, 8));
    if (a.startsWith('ID3')) return await readID3(file);
    if (a === 'fLaC') return await readFLAC(file);
    if (b === 'ftyp') return await readMP4(file);
  } catch (e) { console.warn('Could not read tags for', file.name, e); }
  return {};
}
function parseName(name) {
  let base = name.replace(/\.[^.]+$/, '').replace(/_/g, ' ').trim();
  base = base.replace(/^\d{1,3}\s*[-.)]\s*|^\d{1,3}\s+/, '');
  const parts = base.split(/\s+[-–—]\s+/);
  if (parts.length >= 2) return { artist: parts[0].trim(), title: parts.slice(1).join(' - ').trim() };
  return { title: base || name };
}
const MIME = { mp3: 'audio/mpeg', m4a: 'audio/mp4', aac: 'audio/aac', flac: 'audio/flac', wav: 'audio/wav', ogg: 'audio/ogg', oga: 'audio/ogg', opus: 'audio/ogg', webm: 'audio/webm', aif: 'audio/aiff', aiff: 'audio/aiff' };
const extOf = (n) => (n.match(/\.([^.]+)$/)?.[1] || '').toLowerCase();
const isAudio = (f) => /^audio\//.test(f.type) || extOf(f.name) in MIME;

/* ================= state ================= */
const S = {
  tracks: new Map(),
  playlists: new Map(),
  queue: [], qi: -1, order: null,
  shuffle: false, repeat: 'off', // off | all | one
  from: { label: 'Your Library', href: '#/library' },
  recent: [],
};
const coverKeys = new Set();
const coverURL = new Map();
let lists = {}, froms = {};
const albumKey = (t) => `${t.albumArtist || t.artist}\u001f${t.album}`;
const current = () => S.tracks.get(S.queue[S.qi]);

function persist() {
  try {
    localStorage.setItem('tempo:state', JSON.stringify({
      queue: S.queue, qi: S.qi, order: S.order, shuffle: S.shuffle, repeat: S.repeat, from: S.from,
      recent: S.recent, time: loadedId ? audio.currentTime : pendingSeek, vol: audio.volume, muted: audio.muted,
    }));
  } catch {}
}
function restore() {
  let st;
  try { st = JSON.parse(localStorage.getItem('tempo:state') || 'null'); } catch {}
  if (!st) return;
  const ok = (id) => S.tracks.has(id);
  S.shuffle = !!st.shuffle; S.repeat = ['off', 'all', 'one'].includes(st.repeat) ? st.repeat : 'off';
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

/* ================= covers ================= */
async function ensureCover(k) {
  if (!coverKeys.has(k)) return null;
  if (coverURL.has(k)) return coverURL.get(k);
  const b = await idb.get('covers', k);
  if (!b) { coverKeys.delete(k); return null; }
  const u = URL.createObjectURL(b);
  coverURL.set(k, u);
  return u;
}
async function hydrateCovers(root = document) {
  for (const el of $$('[data-cover]', root)) {
    const k = el.dataset.cover;
    if (el.dataset.done === k) continue;
    const u = await ensureCover(k);
    el.dataset.done = k;
    if (u) { el.style.backgroundImage = `url("${u}")`; el.classList.add('has-img'); }
    else { el.style.backgroundImage = ''; el.classList.remove('has-img'); }
  }
}
function art(key, label, cls = 'sm') {
  return `<div class="art ${cls}" data-cover="${esc(key)}" style="--h:${hue(key)}"><span>${esc((label || '?').trim().charAt(0).toUpperCase())}</span></div>`;
}
const trackArt = (t, cls) => art(albumKey(t), t.album !== 'Unknown Album' ? t.album : t.title, cls);
function setArt(el, t, extraCls) {
  const k = t ? albumKey(t) : '';
  el.style.setProperty('--h', hue(k));
  el.dataset.cover = k;
  delete el.dataset.done;
  el.innerHTML = `<span>${esc(t ? (t.album !== 'Unknown Album' ? t.album : t.title).charAt(0).toUpperCase() : '')}</span>`;
  if (extraCls) el.classList.add(extraCls);
  hydrateCovers(el.parentElement);
}

/* ================= grouping ================= */
function getAlbums() {
  const m = new Map();
  for (const t of S.tracks.values()) {
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
  for (const t of S.tracks.values()) {
    const k = t.artist;
    let a = m.get(k);
    if (!a) { a = { name: k, tracks: [], cover: albumKey(t) }; m.set(k, a); }
    a.tracks.push(t);
    if (!coverKeys.has(a.cover) && coverKeys.has(albumKey(t))) a.cover = albumKey(t);
  }
  return [...m.values()].sort(byText('name'));
}
const allTracks = () => [...S.tracks.values()];
const likedTracks = () => allTracks().filter((t) => t.liked).sort((a, b) => (b.likedAt || 0) - (a.likedAt || 0));
const plTracks = (pl) => pl.ids.map((id) => S.tracks.get(id)).filter(Boolean);
const totalDur = (ts) => ts.reduce((s, t) => s + (t.duration || 0), 0);

/* ================= templates ================= */
function row(t, i, ctx, o = {}) {
  return `<div class="row" data-act="play" data-ctx="${esc(ctx)}" data-i="${i}" data-id="${t.id}">
    <span class="idx"><span class="n">${o.album ? (t.track || i + 1) : i + 1}</span><span class="eq"><i></i><i></i><i></i></span></span>
    <div class="lead">${o.album ? '' : trackArt(t, 'xs')}<div class="meta"><div class="ttl">${esc(t.title)}</div><div class="sub"><a href="#/artist/${enc(t.artist)}" data-act="go">${esc(t.artist)}</a></div></div></div>
    <div class="col-alb"><a href="#/album/${enc(albumKey(t))}" data-act="go">${esc(t.album)}</a></div>
    <button class="ib like ${t.liked ? 'on' : ''}" data-act="like" data-id="${t.id}" aria-label="${t.liked ? 'Remove from Liked Songs' : 'Save to Liked Songs'}">${icon(t.liked ? 'heartFill' : 'heart')}</button>
    <span class="dur">${t.duration ? fmt(t.duration) : '–'}</span>
    <button class="ib more" data-act="more" data-id="${t.id}" data-ctx="${esc(ctx)}" data-i="${i}" aria-label="More options">${icon('more')}</button>
  </div>`;
}
function trackList(tracks, ctx, o = {}) {
  lists[ctx] = tracks.map((t) => t.id);
  if (o.from) froms[ctx] = o.from;
  if (!tracks.length) return `<p class="empty-sm">${o.empty || 'No songs here yet.'}</p>`;
  const head = o.noHead ? '' : `<div class="thead d-only"><span>#</span><span>Title</span><span class="col-alb">${o.album ? '' : 'Album'}</span><span></span><span style="text-align:right">⏱</span><span></span></div>`;
  return `<div class="tracks ${o.album ? 'is-album' : ''}">${head}${tracks.map((t, i) => row(t, i, ctx, o)).join('')}</div>`;
}
const albumCard = (a) => `<div class="card" data-act="nav" data-href="#/album/${enc(a.key)}">
  <div class="cart">${art(a.key, a.name, 'md')}<button class="fab cplay" data-act="playAlbum" data-key="${esc(a.key)}" aria-label="Play ${esc(a.name)}">${icon('play')}</button></div>
  <div class="ttl">${esc(a.name)}</div><div class="sub">${a.year ? a.year + ' · ' : ''}${esc(a.artist)}</div></div>`;
const artistCard = (a) => `<div class="card" data-act="nav" data-href="#/artist/${enc(a.name)}">
  ${art(a.cover, a.name, 'md round')}
  <div class="ttl">${esc(a.name)}</div><div class="sub">${plural(a.tracks.length, 'song')}</div></div>`;
const plCard = (p) => {
  const ts = plTracks(p);
  return `<div class="card" data-act="nav" data-href="#/playlist/${p.id}">
  ${ts[0] ? art(albumKey(ts[0]), p.name, 'md') : art('pl' + p.id, p.name, 'md')}
  <div class="ttl">${esc(p.name)}</div><div class="sub">Playlist · ${plural(ts.length, 'song')}</div></div>`;
};
const likedCard = () => `<div class="card" data-act="nav" data-href="#/liked"><div class="art md liked">${icon('heartFill')}</div>
  <div class="ttl">Liked Songs</div><div class="sub">${plural(likedTracks().length, 'song')}</div></div>`;
const backBtn = () => `<button class="ib backbtn" data-act="back" aria-label="Back">${icon('back')}</button>`;
const playActions = (ctx, extra = '') => `<div class="actions">
  <button class="fab" data-act="playAll" data-ctx="${esc(ctx)}" aria-label="Play">${icon('play')}</button>
  <button class="ib big" data-act="shuffleAll" data-ctx="${esc(ctx)}" aria-label="Shuffle play">${icon('shuffle')}</button>${extra}</div>`;

/* ================= views ================= */
function vWelcome() {
  return `<div class="welcome">
    <img src="icon.svg" alt="">
    <h1>Welcome to Tempo</h1>
    <p>Your own music player, with no subscription. Add songs you own (MP3, M4A/AAC, FLAC, WAV, OGG) and they're saved on this device, so they play offline.</p>
    <div class="btns">
      <button class="btn primary" data-act="import">${icon('upload')}Add songs</button>
      <button class="btn d-only" data-act="importDir">${icon('folder')}Add a whole folder</button>
    </div>
    <div class="steps">
      <div><b>1. Add music</b>Pick files or drag a folder here. Song names, artists, albums and cover art are read from the files.</div>
      <div><b>2. Install it</b>${isIOS() ? 'In Safari, tap Share → “Add to Home Screen”.' : 'Use your browser\'s “Install app” option to get it on your home screen or dock.'}</div>
      <div><b>3. Play anywhere</b>Lock-screen controls, playlists, shuffle, repeat, queue and Liked Songs all work.</div>
    </div>
  </div>`;
}
function installBanner() {
  if (isStandalone() || localStorage.getItem('tempo:hideInstall')) return '';
  if (isIOS()) return `<div class="banner">${icon('share')}<p>Install Tempo: tap <b>Share</b> then <b>Add to Home Screen</b>.</p><button class="ib" data-act="hideInstall" aria-label="Dismiss">${icon('x')}</button></div>`;
  if (installEvt) return `<div class="banner">${icon('download')}<p>Install Tempo as an app on this device.</p><button class="btn primary" data-act="install">Install</button><button class="ib" data-act="hideInstall" aria-label="Dismiss">${icon('x')}</button></div>`;
  return '';
}
function vHome() {
  if (!S.tracks.size) return `<div class="view">${vWelcome()}</div>`;
  const hr = new Date().getHours();
  const greet = hr < 5 ? 'Good night' : hr < 12 ? 'Good morning' : hr < 18 ? 'Good afternoon' : 'Good evening';
  const albums = getAlbums().sort((a, b) => b.addedAt - a.addedAt);
  const recent = S.recent.map((id) => S.tracks.get(id)).filter(Boolean);
  const recentAlbums = [...new Map(recent.map((t) => [albumKey(t), t])).values()].slice(0, 5);
  const artists = getArtists().sort((a, b) => b.tracks.reduce((s, t) => s + (t.plays || 0), 0) - a.tracks.reduce((s, t) => s + (t.plays || 0), 0));
  const most = allTracks().filter((t) => t.plays).sort((a, b) => b.plays - a.plays).slice(0, 10);
  const quick = [
    `<div class="q" data-act="nav" data-href="#/liked"><div class="art liked">${icon('heartFill')}</div><span class="l">Liked Songs</span></div>`,
    `<div class="q" data-act="shuffleLibrary"><div class="art" style="--h:280">${icon('shuffle')}</div><span class="l">Shuffle everything</span></div>`,
    ...recentAlbums.map((t) => `<div class="q" data-act="nav" data-href="#/album/${enc(albumKey(t))}">${trackArt(t, '')}<span class="l">${esc(t.album)}</span></div>`),
  ].slice(0, 6);
  return `<div class="view" style="--h:${hue(S.queue[S.qi] ? albumKey(current()) : 'home')}"><div class="hero-grad"></div>
    ${installBanner()}
    <div class="view-head"><h1>${greet}</h1><button class="btn m-only" data-act="import">${icon('plus')}Add</button></div>
    <div class="quick">${quick.join('')}</div>
    ${recent.length ? `<section class="sec"><div class="sec-head"><h2>Recently played</h2></div>${trackList(recent.slice(0, 8), 'recent', { from: { label: 'Recently played', href: '#/home' }, noHead: true })}</section>` : ''}
    <section class="sec"><div class="sec-head"><h2>Recently added</h2><a href="#/library/albums">Show all</a></div><div class="shelf">${albums.slice(0, 12).map(albumCard).join('')}</div></section>
    ${most.length >= 3 ? `<section class="sec"><div class="sec-head"><h2>Your top songs</h2></div>${trackList(most, 'top', { from: { label: 'Your top songs', href: '#/home' }, noHead: true })}</section>` : ''}
    <section class="sec"><div class="sec-head"><h2>Your artists</h2><a href="#/library/artists">Show all</a></div><div class="shelf">${artists.slice(0, 12).map(artistCard).join('')}</div></section>
  </div>`;
}
let searchQ = '';
function vSearch() {
  return `<div class="view">
    <div class="view-head"><h1>Search</h1></div>
    <label class="searchbox">${icon('search')}<input id="q" type="search" placeholder="Songs, artists or albums" value="${esc(searchQ)}" autocomplete="off" enterkeyhint="search"></label>
    <div id="results">${searchResults()}</div>
  </div>`;
}
function searchResults() {
  const q = searchQ.trim().toLowerCase();
  if (!S.tracks.size) return `<p class="empty-sm">Your library is empty. <a href="#/home" style="color:var(--accent)">Add some music</a> first.</p>`;
  if (!q) {
    const g = new Map();
    for (const t of S.tracks.values()) if (t.genre) g.set(t.genre, (g.get(t.genre) || 0) + 1);
    const genres = [...g.entries()].sort((a, b) => b[1] - a[1]).slice(0, 24);
    if (!genres.length) return `<p class="empty-sm">Type to search your ${plural(S.tracks.size, 'song')}.</p>`;
    return `<section class="sec"><h2>Browse your genres</h2><div class="genres">${genres.map(([n]) => `<button class="genre" style="--h:${hue(n)}" data-act="searchFor" data-q="${esc(n)}">${esc(n)}</button>`).join('')}</div></section>`;
  }
  const words = q.split(/\s+/);
  const hit = (s) => words.every((w) => s.includes(w));
  const songs = allTracks().filter((t) => hit(`${t.title} ${t.artist} ${t.album} ${t.genre}`.toLowerCase())).sort(byText('title'));
  const artists = getArtists().filter((a) => hit(a.name.toLowerCase()));
  const albums = getAlbums().filter((a) => hit(`${a.name} ${a.artist}`.toLowerCase()));
  if (!songs.length && !artists.length && !albums.length) return `<p class="empty-sm">No results for “${esc(searchQ)}”.</p>`;
  return `${songs.length ? `<section class="sec"><div class="sec-head"><h2>Songs</h2></div>${trackList(songs.slice(0, 50), 'search', { from: { label: `Search: ${searchQ}`, href: '#/search' }, noHead: true })}</section>` : ''}
    ${artists.length ? `<section class="sec"><div class="sec-head"><h2>Artists</h2></div><div class="shelf">${artists.map(artistCard).join('')}</div></section>` : ''}
    ${albums.length ? `<section class="sec"><div class="sec-head"><h2>Albums</h2></div><div class="shelf">${albums.map(albumCard).join('')}</div></section>` : ''}`;
}
function vLibrary(tab) {
  const tabs = [['songs', 'Songs'], ['albums', 'Albums'], ['artists', 'Artists'], ['playlists', 'Playlists']];
  let body = '';
  if (tab === 'albums') body = `<div class="grid" style="margin-top:18px">${getAlbums().sort(byText('name')).map(albumCard).join('') || '<p class="empty-sm">No albums yet.</p>'}</div>`;
  else if (tab === 'artists') body = `<div class="grid" style="margin-top:18px">${getArtists().map(artistCard).join('') || '<p class="empty-sm">No artists yet.</p>'}</div>`;
  else if (tab === 'playlists') body = `<div class="grid" style="margin-top:18px">${likedCard()}${[...S.playlists.values()].sort((a, b) => b.updatedAt - a.updatedAt).map(plCard).join('')}
      <div class="card new" data-act="newPlaylist"><div class="art md">${icon('plus')}</div><div class="ttl">New playlist</div><div class="sub">Make one from your songs</div></div></div>`;
  else {
    const sort = localStorage.getItem('tempo:sort') || 'added';
    const ts = allTracks();
    if (sort === 'title') ts.sort(byText('title'));
    else if (sort === 'artist') ts.sort((a, b) => byText('artist')(a, b) || byText('album')(a, b) || (a.track - b.track));
    else if (sort === 'album') ts.sort((a, b) => byText('album')(a, b) || (a.disc - b.disc) || (a.track - b.track));
    else ts.sort((a, b) => b.addedAt - a.addedAt);
    body = `<div class="toolbar"><span class="muted">${plural(ts.length, 'song')} · ${fmtLong(totalDur(ts))}</span>
      <select class="sort" id="sort" aria-label="Sort songs">${[['added', 'Recently added'], ['title', 'Title'], ['artist', 'Artist'], ['album', 'Album']].map(([v, l]) => `<option value="${v}" ${v === sort ? 'selected' : ''}>${l}</option>`).join('')}</select></div>
      ${ts.length ? playActions('songs') : ''}
      ${trackList(ts, 'songs', { from: { label: 'Your Library', href: '#/library' }, empty: 'No songs yet. Tap “Add” to bring in your music.' })}`;
  }
  return `<div class="view">
    <div class="view-head"><h1>Your Library</h1><div style="display:flex;gap:8px"><button class="btn" data-act="import">${icon('plus')}Add</button></div></div>
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
  const a = getArtists().find((x) => x.name === name);
  if (!a) return vMissing('artist');
  const albums = getAlbums().filter((al) => al.tracks.some((t) => t.artist === name) || al.artist === name).sort((x, y) => (y.year || 0) - (x.year || 0));
  const popular = [...a.tracks].sort((x, y) => (y.plays || 0) - (x.plays || 0) || byText('title')(x, y)).slice(0, 5);
  const all = [...a.tracks].sort((x, y) => byText('album')(x, y) || (x.disc - y.disc) || (x.track - y.track));
  const from = { label: a.name, href: `#/artist/${enc(a.name)}` };
  lists.artistAll = all.map((t) => t.id); froms.artistAll = from;
  return `<div class="view" style="--h:${hue(a.cover)}"><div class="hero-grad"></div>${backBtn()}
    <div class="dhead">${art(a.cover, a.name, 'lg round')}<div class="info"><small>Artist</small><h1>${esc(a.name)}</h1>
      <div class="by">${plural(a.tracks.length, 'song')} · ${plural(albums.length, 'album')}</div></div></div>
    ${playActions('artistAll')}
    <section class="sec" style="margin-top:8px"><div class="sec-head"><h2>Popular</h2></div>${trackList(popular, 'artistTop', { from, noHead: true })}</section>
    <section class="sec"><div class="sec-head"><h2>Albums</h2></div><div class="shelf">${albums.map(albumCard).join('')}</div></section>
    <section class="sec"><div class="sec-head"><h2>All songs</h2></div>${trackList(all, 'artistAll', { from })}</section></div>`;
}
function vPlaylist(id) {
  const p = S.playlists.get(id);
  if (!p) return vMissing('playlist');
  const ts = plTracks(p);
  const key = ts[0] ? albumKey(ts[0]) : 'pl' + p.id;
  return `<div class="view" style="--h:${hue(key)}"><div class="hero-grad"></div>${backBtn()}
    <div class="dhead">${art(key, p.name, 'lg')}<div class="info"><small>Playlist</small><h1>${esc(p.name)}</h1>
      <div class="by">${plural(ts.length, 'song')}${ts.length ? `, ${fmtLong(totalDur(ts))}` : ''}</div></div></div>
    ${ts.length ? playActions('pl:' + p.id, `<button class="ib big" data-act="plRename" data-pl="${p.id}" aria-label="Rename">${icon('edit')}</button><button class="ib big" data-act="plDelete" data-pl="${p.id}" aria-label="Delete playlist">${icon('trash')}</button>`)
      : `<div class="actions"><button class="btn" data-act="plRename" data-pl="${p.id}">${icon('edit')}Rename</button><button class="btn" data-act="plDelete" data-pl="${p.id}">${icon('trash')}Delete</button></div>`}
    ${trackList(ts, 'pl:' + p.id, { from: { label: p.name, href: `#/playlist/${p.id}` }, empty: 'This playlist is empty. On any song, tap ⋯ then “Add to playlist”.' })}</div>`;
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
  const up = S.queue.slice(S.qi + 1).map((id) => S.tracks.get(id)).filter(Boolean);
  lists.queue = S.queue.slice();
  const rows = S.queue.map((id, i) => [S.tracks.get(id), i]).filter(([t, i]) => t && i > S.qi);
  return `<div class="view">${backBtn()}<div class="view-head"><h1>Queue</h1>${up.length ? `<button class="btn" data-act="clearQueue">Clear queue</button>` : ''}</div>
    ${cur ? `<section class="sec" style="margin-top:0"><div class="sec-head"><h2>Now playing</h2></div><div class="tracks">${row(cur, S.qi, 'queue')}</div></section>` : '<p class="empty-sm">Nothing is playing.</p>'}
    ${rows.length ? `<section class="sec"><div class="sec-head"><h2>Next up</h2><span class="muted">${plural(rows.length, 'song')}</span></div><div class="tracks">${rows.map(([t, i]) => row(t, i, 'queue')).join('')}</div></section>` : cur ? '<p class="empty-sm">Nothing queued after this song.</p>' : ''}</div>`;
}
const vMissing = (w) => `<div class="view">${backBtn()}<p class="empty-sm">This ${w} isn't in your library anymore.</p></div>`;

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
  if (keepScroll && name === 'search' && $('#q') && $('#results')) {
    lists = {}; froms = {};
    $('#results').innerHTML = searchResults(); hydrateCovers($('#results')); markPlaying();
    return;
  }
  lists = {}; froms = {};
  let html;
  switch (name) {
    case 'search': html = vSearch(); break;
    case 'library': html = vLibrary(arg || 'songs'); break;
    case 'album': html = vAlbum(arg); break;
    case 'artist': html = vArtist(arg); break;
    case 'playlist': html = vPlaylist(arg); break;
    case 'liked': html = vLiked(); break;
    case 'queue': html = vQueue(); break;
    default: html = vHome();
  }
  $('#view').innerHTML = html;
  main.scrollTop = keepScroll ? top : 0;
  const nav = ['home', 'search'].includes(name) ? name : name === 'queue' ? '' : 'library';
  $$('[data-nav]').forEach((a) => a.classList.toggle('on', a.dataset.nav === nav));
  $$('#sidePl a').forEach((a) => a.classList.toggle('on', a.getAttribute('href') === location.hash));
  hydrateCovers($('#view'));
  markPlaying();
}
function renderSidebar() {
  const pls = [...S.playlists.values()].sort((a, b) => b.updatedAt - a.updatedAt);
  $('#sidePl').innerHTML = `<a href="#/liked"><div class="art xs liked">${icon('heartFill')}</div><div class="meta"><div class="ttl">Liked Songs</div><div class="sub">${plural(likedTracks().length, 'song')}</div></div></a>` +
    pls.map((p) => { const t = plTracks(p)[0]; return `<a href="#/playlist/${p.id}">${t ? trackArt(t, 'xs') : art('pl' + p.id, p.name, 'xs')}<div class="meta"><div class="ttl">${esc(p.name)}</div><div class="sub">Playlist</div></div></a>`; }).join('');
  hydrateCovers($('#sidePl'));
  $$('#sidePl a').forEach((a) => a.classList.toggle('on', a.getAttribute('href') === location.hash));
}
async function updateStorage() {
  try {
    const e = await navigator.storage?.estimate?.();
    if (!e) return;
    const gb = (n) => (n > 1e9 ? (n / 1e9).toFixed(1) + ' GB' : Math.round(n / 1e6) + ' MB');
    $('#storage').textContent = `${plural(S.tracks.size, 'song')} · ${gb(e.usage || 0)} used`;
  } catch {}
}
const refresh = () => { render(true); renderSidebar(); updateStorage(); };

/* ================= playback ================= */
const audio = $('#audio');
let curURL = null, loadedId = null, pendingSeek = 0, loadToken = 0, errCount = 0, unlocked = false, silent = false;
let pre = { id: null, url: null };

function silentURL() {
  const n = 800, b = new ArrayBuffer(44 + n), v = new DataView(b);
  const w = (o, s) => { for (let i = 0; i < s.length; i++) v.setUint8(o + i, s.charCodeAt(i)); };
  w(0, 'RIFF'); v.setUint32(4, 36 + n, true); w(8, 'WAVE'); w(12, 'fmt '); v.setUint32(16, 16, true);
  v.setUint16(20, 1, true); v.setUint16(22, 1, true); v.setUint32(24, 8000, true); v.setUint32(28, 8000, true);
  v.setUint16(32, 1, true); v.setUint16(34, 8, true); w(36, 'data'); v.setUint32(40, n, true);
  for (let i = 0; i < n; i++) v.setUint8(44 + i, 128);
  return URL.createObjectURL(new Blob([b], { type: 'audio/wav' }));
}
// iOS only lets audio start from a tap. Our song files load asynchronously, so we
// "unlock" the audio element synchronously on the first tap with a tiny silent clip.
function unlock() {
  if (unlocked || loadedId) return;
  unlocked = true; silent = true;
  audio.src = silentURL();
  audio.play().catch(() => {});
}

async function load(id, autoplay = true, seek = 0) {
  const tok = ++loadToken;
  const t = S.tracks.get(id);
  if (!t) return;
  let url;
  if (pre.id === id) { url = pre.url; pre = { id: null, url: null }; }
  else {
    const blob = await idb.get('files', id);
    if (tok !== loadToken) return;
    if (!blob) { toast(`The file for “${t.title}” is missing`); return; }
    url = URL.createObjectURL(blob);
  }
  if (curURL && curURL !== url) URL.revokeObjectURL(curURL);
  curURL = url; loadedId = id; silent = false; pendingSeek = 0;
  audio.src = url;
  if (seek > 0) audio.addEventListener('loadedmetadata', () => { audio.currentTime = Math.min(seek, (audio.duration || seek + 1) - 0.5); }, { once: true });
  updateTrackUI();
  if (autoplay) {
    try { await audio.play(); } catch (e) { if (e.name === 'NotAllowedError') toast('Tap play to start'); }
    t.plays = (t.plays || 0) + 1; t.lastPlayed = Date.now();
    idb.put('tracks', t);
    S.recent = [id, ...S.recent.filter((x) => x !== id)].slice(0, 50);
  }
  persist();
  prefetchNext();
}
function nextIndex() {
  if (S.repeat === 'one') return S.qi;
  if (S.qi < S.queue.length - 1) return S.qi + 1;
  return S.repeat === 'all' ? 0 : -1;
}
async function prefetchNext() {
  const ni = nextIndex();
  const id = ni >= 0 ? S.queue[ni] : null;
  if (!id || id === loadedId || pre.id === id) return;
  const blob = await idb.get('files', id);
  if (!blob) return;
  if (pre.url) URL.revokeObjectURL(pre.url);
  pre = { id, url: URL.createObjectURL(blob) };
}
function playList(ids, i = 0, from) {
  if (!ids?.length) return;
  i = Math.max(0, Math.min(i, ids.length - 1));
  if (from) S.from = from;
  if (S.shuffle) {
    S.order = ids.slice();
    const rest = shuffleArr(ids.filter((_, j) => j !== i));
    S.queue = [ids[i], ...rest]; S.qi = 0;
  } else { S.queue = ids.slice(); S.order = null; S.qi = i; }
  load(S.queue[S.qi]);
}
function shufflePlay(ids, from) {
  if (!ids?.length) return;
  if (!S.shuffle) { S.shuffle = true; updateModesUI(); }
  playList(ids, Math.floor(Math.random() * ids.length), from);
}
function togglePlay() {
  if (!S.queue.length) {
    const ids = allTracks().sort((a, b) => b.addedAt - a.addedAt).map((t) => t.id);
    if (ids.length) playList(ids, 0, { label: 'Your Library', href: '#/library' });
    return;
  }
  if (!loadedId) { load(S.queue[S.qi], true, pendingSeek); return; }
  if (audio.paused) audio.play().catch(() => {}); else audio.pause();
}
function next(auto = false) {
  if (!S.queue.length) return;
  if (auto && S.repeat === 'one') { audio.currentTime = 0; audio.play().catch(() => {}); return; }
  if (S.qi < S.queue.length - 1) S.qi++;
  else if (S.repeat === 'all' || S.repeat === 'one') S.qi = 0;
  else { S.qi = 0; load(S.queue[0], false); return; } // end of the queue: stop on the first song
  load(S.queue[S.qi]);
}
function prev() {
  if (!S.queue.length) return;
  if (audio.currentTime > 3 || (S.qi === 0 && S.repeat === 'off')) { audio.currentTime = 0; return; }
  S.qi = S.qi > 0 ? S.qi - 1 : S.queue.length - 1;
  load(S.queue[S.qi]);
}
function toggleShuffle() {
  S.shuffle = !S.shuffle;
  if (S.queue.length) {
    const cur = S.queue[S.qi];
    if (S.shuffle) {
      S.order = S.queue.slice();
      S.queue = [cur, ...shuffleArr(S.queue.filter((_, j) => j !== S.qi))]; S.qi = 0;
    } else if (S.order) {
      S.queue = S.order; S.order = null; S.qi = Math.max(0, S.queue.indexOf(cur));
    }
  }
  toast(S.shuffle ? 'Shuffle on' : 'Shuffle off');
  updateModesUI(); persist(); prefetchNext();
  if (route().name === 'queue') render(true);
}
function cycleRepeat() {
  S.repeat = { off: 'all', all: 'one', one: 'off' }[S.repeat];
  toast({ off: 'Repeat off', all: 'Repeating your queue', one: 'Repeating this song' }[S.repeat]);
  updateModesUI(); persist(); prefetchNext();
}
function playNext(id) {
  if (!S.queue.length) { playList([id], 0); return; }
  S.queue.splice(S.qi + 1, 0, id);
  if (S.order) { const p = S.order.indexOf(S.queue[S.qi]); S.order.splice(p + 1, 0, id); }
  toast('Playing next'); persist(); prefetchNext();
}
function addToQueue(id) {
  if (!S.queue.length) { playList([id], 0); return; }
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
audio.addEventListener('ended', () => { if (!silent) next(true); });
audio.addEventListener('loadedmetadata', () => {
  if (silent) return;
  const t = S.tracks.get(loadedId);
  if (t && isFinite(audio.duration) && Math.abs((t.duration || 0) - audio.duration) > 1) {
    t.duration = audio.duration; idb.put('tracks', t);
  }
  updateTime();
});
audio.addEventListener('error', () => {
  if (silent || !loadedId) return;
  const t = S.tracks.get(loadedId);
  toast(`Can't play “${t?.title}” on this device`);
  if (++errCount < 3 && S.queue.length > 1) setTimeout(() => next(true), 900);
});
let lastSave = 0;
audio.addEventListener('timeupdate', () => {
  if (silent) return;
  updateTime();
  const now = Date.now();
  if (now - lastSave > 4000) { lastSave = now; persist(); }
});

/* ---------- player UI ---------- */
let seeking = false;
function updateTime() {
  const d = loadedId ? audio.duration : current()?.duration;
  const c = loadedId ? audio.currentTime : pendingSeek;
  const p = d ? Math.min(100, (c / d) * 100) : 0;
  if (!seeking) {
    $$('.seek').forEach((el) => { el.value = Math.round(p * 10); el.style.setProperty('--p', p + '%'); });
    $$('[data-t=cur]').forEach((el) => { el.textContent = fmt(c); });
  }
  $$('[data-t=dur]').forEach((el) => { el.textContent = fmt(d); });
  $('#mProg').style.width = p + '%';
  if ('mediaSession' in navigator && loadedId && isFinite(audio.duration) && audio.duration > 0) {
    try { navigator.mediaSession.setPositionState({ duration: audio.duration, position: Math.min(audio.currentTime, audio.duration), playbackRate: audio.playbackRate || 1 }); } catch {}
  }
}
function updatePlayUI() {
  const playing = !audio.paused && !silent;
  document.body.classList.toggle('is-playing', playing);
  $$('[data-act=toggle]').forEach((b) => { b.innerHTML = icon(playing ? 'pause' : 'play'); b.setAttribute('aria-label', playing ? 'Pause' : 'Play'); });
  if ('mediaSession' in navigator) navigator.mediaSession.playbackState = loadedId ? (playing ? 'playing' : 'paused') : 'none';
}
function updateModesUI() {
  $$('[data-act=shuffle]').forEach((b) => b.classList.toggle('on', S.shuffle));
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
  $('#npArtist').href = `#/artist/${enc(t.artist)}`;
  $('#npFrom').textContent = S.from?.label || 'Your Library';
  $('#npFrom').href = S.from?.href || '#/library';
  $('#player').style.setProperty('--h', hue(k));
  setArt($('#pArt'), t); setArt($('#npArt'), t);
  const bg = $('#npBg');
  bg.style.setProperty('--h', hue(k));
  updateLikeUI(); updateTime(); updatePlayUI(); markPlaying();
  document.title = `${t.title} · ${t.artist}`;
  const u = await ensureCover(k);
  if (current() !== t) return;
  bg.classList.toggle('has-img', !!u);
  bg.style.backgroundImage = u ? `url("${u}")` : '';
  if ('mediaSession' in navigator) {
    let artwork = [{ src: new URL('icon-512.png', location.href).href, sizes: '512x512', type: 'image/png' }];
    if (u) {
      const b = await idb.get('covers', k);
      artwork = [{ src: u, sizes: '512x512', type: b?.type || 'image/jpeg' }];
    }
    navigator.mediaSession.metadata = new MediaMetadata({ title: t.title, artist: t.artist, album: t.album, artwork });
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
  h('pause', () => audio.pause());
  h('previoustrack', prev);
  h('nexttrack', () => next());
  h('seekto', (d) => { if (d.seekTime != null) audio.currentTime = d.seekTime; });
  h('seekbackward', (d) => { audio.currentTime = Math.max(0, audio.currentTime - (d.seekOffset || 10)); });
  h('seekforward', (d) => { audio.currentTime = Math.min(audio.duration || 0, audio.currentTime + (d.seekOffset || 10)); });
}

/* ================= library editing ================= */
async function toggleLike(id) {
  const t = S.tracks.get(id); if (!t) return;
  t.liked = !t.liked; t.likedAt = t.liked ? Date.now() : 0;
  await idb.put('tracks', t);
  $$(`.like[data-id="${id}"]`).forEach((b) => { b.classList.toggle('on', t.liked); b.innerHTML = icon(t.liked ? 'heartFill' : 'heart'); });
  updateLikeUI();
  toast(t.liked ? 'Added to Liked Songs' : 'Removed from Liked Songs');
  renderSidebar();
  if (route().name === 'liked') render(true);
}
async function newPlaylist(withId) {
  const name = await ask({ title: 'New playlist', placeholder: 'My playlist', value: `My Playlist #${S.playlists.size + 1}`, ok: 'Create' });
  if (!name) return null;
  const p = { id: hash(name + Date.now() + Math.random()), name, ids: withId ? [withId] : [], createdAt: Date.now(), updatedAt: Date.now() };
  S.playlists.set(p.id, p);
  await idb.put('playlists', p);
  renderSidebar();
  if (withId) toast(`Added to ${name}`); else location.hash = `#/playlist/${p.id}`;
  return p;
}
async function addToPlaylist(id) {
  const pls = [...S.playlists.values()].sort((a, b) => b.updatedAt - a.updatedAt);
  const choice = await pick('Add to playlist', [{ value: '__new', label: 'New playlist', html: `<div class="art xs" style="--h:0;background:var(--surface)">${icon('plus')}</div>` },
    ...pls.map((p) => { const t = plTracks(p)[0]; return { value: p.id, label: p.name, sub: plural(p.ids.length, 'song'), html: t ? trackArt(t, 'xs') : art('pl' + p.id, p.name, 'xs') }; })]);
  if (!choice) return;
  if (choice === '__new') { await newPlaylist(id); return; }
  const p = S.playlists.get(choice);
  if (p.ids.includes(id) && !(await confirmBox('Already added', `This song is already in “${p.name}”. Add it again?`, 'Add anyway'))) return;
  p.ids.push(id); p.updatedAt = Date.now();
  await idb.put('playlists', p);
  toast(`Added to ${p.name}`);
  refresh();
}
async function removeFromPlaylist(plId, i) {
  const p = S.playlists.get(plId); if (!p) return;
  p.ids.splice(i, 1); p.updatedAt = Date.now();
  await idb.put('playlists', p);
  toast(`Removed from ${p.name}`);
  refresh();
}
async function deleteTrack(id) {
  const t = S.tracks.get(id); if (!t) return;
  if (!(await confirmBox('Delete from library?', `“${t.title}” will be removed from this device and from your playlists.`))) return;
  const wasCurrent = S.queue[S.qi] === id;
  S.tracks.delete(id);
  await idb.del('tracks', id); await idb.del('files', id);
  for (const p of S.playlists.values()) if (p.ids.includes(id)) { p.ids = p.ids.filter((x) => x !== id); await idb.put('playlists', p); }
  const curId = S.queue[S.qi];
  const before = S.queue.slice(0, S.qi).filter((x) => x === id).length;
  S.queue = S.queue.filter((x) => x !== id);
  S.order = S.order?.filter((x) => x !== id) || null;
  S.recent = S.recent.filter((x) => x !== id);
  if (wasCurrent) {
    audio.pause(); audio.removeAttribute('src'); loadedId = null;
    S.qi = Math.min(S.qi - before, S.queue.length - 1);
    if (S.qi >= 0) load(S.queue[S.qi], false); else { S.qi = -1; updateTrackUI(); updatePlayUI(); }
  } else S.qi = S.queue.indexOf(curId);
  const k = albumKey(t);
  if (![...S.tracks.values()].some((x) => albumKey(x) === k)) {
    await idb.del('covers', k); coverKeys.delete(k);
    if (coverURL.has(k)) { URL.revokeObjectURL(coverURL.get(k)); coverURL.delete(k); }
  }
  if (pre.id === id) { URL.revokeObjectURL(pre.url); pre = { id: null, url: null }; }
  persist(); toast('Deleted'); refresh();
}

/* ================= import ================= */
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
  if (importing) { toast('Already adding songs — hang on'); return; }
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
        id, title: tags.title || fn.title, artist: tags.artist || fn.artist || 'Unknown Artist',
        album: tags.album || 'Unknown Album', albumArtist: tags.albumArtist || '',
        track: tags.track || 0, disc: tags.disc || 0, year: tags.year || 0, genre: tags.genre || '',
        duration: 0, size: f.size, type, file: f.name, addedAt: Date.now() + i, liked: false, plays: 0,
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
  tst.set([added && `Added ${plural(added, 'song')}`, skipped && `${skipped} already in library`, failed && `${failed} failed`].filter(Boolean).join(' · ') || 'Nothing added');
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
function ask({ title, value = '', placeholder = '', ok = 'Save' }) {
  const p = openDialog(`<form method="dialog"><h3>${esc(title)}</h3><input name="v" value="${esc(value)}" placeholder="${esc(placeholder)}" maxlength="100" required autocomplete="off">
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
    ['goAlbum', 'album', 'Go to album'], ['goArtist', 'user', 'Go to artist'],
  ];
  if (ctx.startsWith('pl:')) items.push(['rmpl', 'x', 'Remove from this playlist']);
  if (ctx === 'queue' && +i !== S.qi) items.push(['qremove', 'x', 'Remove from queue']);
  items.push(['del', 'trash', 'Delete from library', 'danger']);
  menu.innerHTML = `<div class="mh">${trackArt(t, 'xs')}<div class="meta"><div class="ttl">${esc(t.title)}</div><div class="sub">${esc(t.artist)}</div></div></div>` +
    items.map(([a, ic, l, c]) => `<button data-act="${a}" data-id="${id}" data-ctx="${esc(ctx)}" data-i="${i}" class="${c || ''}">${icon(ic)}${esc(l)}</button>`).join('');
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
const albumIds = (key) => getAlbums().find((a) => a.key === key)?.tracks.map((t) => t.id) || [];
const A = {
  go() {},
  nav: (el) => { location.hash = el.dataset.href; },
  back: () => { if (history.length > 1) history.back(); else location.hash = '#/home'; },
  play(el) {
    const { ctx, i } = el.dataset;
    if (ctx === 'queue') { S.qi = +i; load(S.queue[S.qi]); return; }
    if ((loadedId || S.queue[S.qi]) === el.dataset.id && ctxList(ctx)[+i] === el.dataset.id && S.from?.href === ctxFrom(ctx).href) { togglePlay(); return; }
    playList(ctxList(ctx), +i, ctxFrom(ctx));
  },
  playAll: (el) => { const ids = ctxList(el.dataset.ctx); if (S.shuffle) { S.shuffle = false; updateModesUI(); } playList(ids, 0, ctxFrom(el.dataset.ctx)); },
  shuffleAll: (el) => shufflePlay(ctxList(el.dataset.ctx), ctxFrom(el.dataset.ctx)),
  shuffleLibrary: () => shufflePlay(allTracks().map((t) => t.id), { label: 'Your Library', href: '#/library' }),
  playAlbum: (el) => { const a = getAlbums().find((x) => x.key === el.dataset.key); if (a) playList(albumIds(a.key), 0, { label: a.name, href: `#/album/${enc(a.key)}` }); },
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
  goArtist: (el) => { location.hash = `#/artist/${enc(S.tracks.get(el.dataset.id).artist)}`; },
  del: (el) => deleteTrack(el.dataset.id),
  newPlaylist: () => newPlaylist(),
  async plRename(el) {
    const p = S.playlists.get(el.dataset.pl);
    const name = await ask({ title: 'Rename playlist', value: p.name });
    if (!name) return;
    p.name = name; p.updatedAt = Date.now(); await idb.put('playlists', p); refresh();
  },
  async plDelete(el) {
    const p = S.playlists.get(el.dataset.pl);
    if (!(await confirmBox('Delete playlist?', `“${p.name}” will be deleted. The songs stay in your library.`))) return;
    S.playlists.delete(p.id); await idb.del('playlists', p.id);
    location.hash = '#/library/playlists'; renderSidebar(); toast('Playlist deleted');
  },
  import: () => $('#fileIn').click(),
  importDir: () => $('#dirIn').click(),
  openNP: () => { if (!current()) return; $('#np').hidden = false; hydrateCovers($('#np')); },
  closeNP: () => { $('#np').hidden = true; },
  queue: () => { $('#np').hidden = true; location.hash = '#/queue'; },
  mute: () => { audio.muted = !audio.muted; updateVolUI(); persist(); },
  searchFor: (el) => { searchQ = el.dataset.q; render(); },
  async install() { if (!installEvt) return; installEvt.prompt(); await installEvt.userChoice; installEvt = null; $('#installBtn').hidden = true; render(true); },
  hideInstall: () => { try { localStorage.setItem('tempo:hideInstall', '1'); } catch {} render(true); },
};
const PLAY_ACTS = new Set(['play', 'toggle', 'next', 'prev', 'playAll', 'shuffleAll', 'shuffleLibrary', 'playAlbum', 'qnext', 'qadd']);
document.addEventListener('click', (e) => {
  const el = e.target.closest('[data-act]');
  const inMenu = el?.closest('#menu');
  if (!el) { if (!menu.hidden && !e.target.closest('#menu')) closeMenu(); return; }
  const act = el.dataset.act;
  if (act !== 'go' && el.tagName !== 'A') e.preventDefault();
  if (act !== 'more' || !menu.hidden) closeMenu();
  if (PLAY_ACTS.has(act)) unlock();
  A[act]?.(el, e);
  if (inMenu) closeMenu();
});
scrim.addEventListener('click', closeMenu);

/* inputs */
document.addEventListener('input', (e) => {
  if (e.target.id === 'q') { searchQ = e.target.value; lists = {}; froms = {}; $('#results').innerHTML = searchResults(); hydrateCovers($('#results')); markPlaying(); }
  if (e.target.classList.contains('seek')) {
    seeking = true;
    const v = e.target.value / 10;
    e.target.style.setProperty('--p', v + '%');
    const d = loadedId ? audio.duration : current()?.duration || 0;
    $$('[data-t=cur]').forEach((el) => { el.textContent = fmt((v / 100) * d); });
  }
  if (e.target.id === 'vol') { audio.volume = +e.target.value; audio.muted = false; updateVolUI(); }
});
document.addEventListener('change', (e) => {
  if (e.target.classList.contains('seek')) {
    const frac = e.target.value / 1000;
    if (loadedId && isFinite(audio.duration)) audio.currentTime = frac * audio.duration;
    else if (current()) pendingSeek = frac * (current().duration || 0);
    seeking = false; updateTime(); persist();
  }
  if (e.target.id === 'sort') { try { localStorage.setItem('tempo:sort', e.target.value); } catch {} render(true); }
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
  else if (e.key === 'ArrowRight' && loadedId) audio.currentTime = Math.min(audio.duration || 0, audio.currentTime + 5);
  else if (e.key === 'ArrowLeft' && loadedId) audio.currentTime = Math.max(0, audio.currentTime - 5);
  else if (e.key === 'Escape') { closeMenu(); $('#np').hidden = true; }
  else if (e.key === '/') { e.preventDefault(); location.hash = '#/search'; setTimeout(() => $('#q')?.focus(), 0); }
  else if (e.key.toLowerCase() === 's') toggleShuffle();
  else if (e.key.toLowerCase() === 'r') cycleRepeat();
  else if (e.key.toLowerCase() === 'l' && current()) toggleLike(current().id);
});

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
  try {
    const [tracks, pls, ck] = await Promise.all([idb.all('tracks'), idb.all('playlists'), idb.keys('covers')]);
    tracks.forEach((t) => S.tracks.set(t.id, t));
    pls.forEach((p) => S.playlists.set(p.id, p));
    ck.forEach((k) => coverKeys.add(k));
  } catch (e) {
    console.error(e);
    toast('Storage is unavailable here (private browsing?). Songs won\'t be saved.', 6000);
  }
  restore();
  setupMediaSession();
  updateModesUI(); updateVolUI();
  if (current()) updateTrackUI(); else updatePlayUI();
  addEventListener('hashchange', () => { closeMenu(); render(); });
  render(); renderSidebar(); updateStorage();
  addEventListener('pagehide', persist);
  document.addEventListener('visibilitychange', () => { if (document.hidden) persist(); });
  if ('serviceWorker' in navigator && location.protocol !== 'file:') navigator.serviceWorker.register('sw.js').catch(() => {});
}
boot();

// exposed for debugging in the browser console
window.tempo = { S, importFiles, readTags };
