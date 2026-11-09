// Shared helpers for the serverless functions (files starting with _ are not routes).
export const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36';
export const ytKey = () => process.env.YOUTUBE_API_KEY || '';

export function send(res, status, body, cacheSeconds = 0) {
  res.statusCode = status;
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  if (cacheSeconds && status === 200) res.setHeader('Cache-Control', `public, s-maxage=${cacheSeconds}, stale-while-revalidate=${cacheSeconds}`);
  res.end(JSON.stringify(body));
}

export async function getJSON(url) {
  const r = await fetch(url, { headers: { 'User-Agent': UA } });
  const d = await r.json().catch(() => ({}));
  if (!r.ok || d.error) throw new Error(d.error?.message || `Request failed (${r.status})`);
  return d;
}

// "PT3M21S" -> 201
export function isoDuration(s = '') {
  const m = s.match(/P(?:(\d+)D)?T?(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?/) || [];
  return (+m[1] || 0) * 86400 + (+m[2] || 0) * 3600 + (+m[3] || 0) * 60 + (+m[4] || 0);
}
export const bestThumb = (t = {}) => (t.maxres || t.standard || t.high || t.medium || t.default || {}).url || '';
export const cleanChannel = (c = '') => c.replace(/ - Topic$/, '').replace(/VEVO$/i, '').trim();
