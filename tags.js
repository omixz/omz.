// Reads song info + cover art from MP3 (ID3v2), M4A/AAC (MP4) and FLAC files.
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
export async function readTags(file) {
  try {
    const h = new Uint8Array(await file.slice(0, 12).arrayBuffer());
    const a = String.fromCharCode(...h.subarray(0, 4)), b = String.fromCharCode(...h.subarray(4, 8));
    if (a.startsWith('ID3')) return await readID3(file);
    if (a === 'fLaC') return await readFLAC(file);
    if (b === 'ftyp') return await readMP4(file);
  } catch (e) { console.warn('Could not read tags for', file.name, e); }
  return {};
}
export function parseName(name) {
  let base = name.replace(/\.[^.]+$/, '').replace(/_/g, ' ').trim();
  base = base.replace(/^\d{1,3}\s*[-.)]\s*|^\d{1,3}\s+/, '');
  const parts = base.split(/\s+[-–—]\s+/);
  if (parts.length >= 2) return { artist: parts[0].trim(), title: parts.slice(1).join(' - ').trim() };
  return { title: base || name };
}
export const MIME = { mp3: 'audio/mpeg', m4a: 'audio/mp4', aac: 'audio/aac', flac: 'audio/flac', wav: 'audio/wav', ogg: 'audio/ogg', oga: 'audio/ogg', opus: 'audio/ogg', webm: 'audio/webm', aif: 'audio/aiff', aiff: 'audio/aiff' };
export const extOf = (n) => (n.match(/\.([^.]+)$/)?.[1] || '').toLowerCase();
export const isAudio = (f) => /^audio\//.test(f.type) || extOf(f.name) in MIME;

