import { send, getJSON, ytKey, isoDuration, bestThumb, cleanChannel } from './_lib.js';

// GET /api/youtube?q=...  -> search music videos (needs YOUTUBE_API_KEY; ~101 quota units per search)
// GET /api/youtube?id=... -> details for one video (works without a key, via YouTube oEmbed)
export default async function handler(req, res) {
  const q = String(req.query.q || '').trim().slice(0, 200);
  const id = String(req.query.id || '').trim();
  try {
    if (id) {
      if (!/^[\w-]{11}$/.test(id)) return send(res, 400, { error: 'Bad video id' });
      const d = await getJSON(`https://www.youtube.com/oembed?format=json&url=${encodeURIComponent('https://www.youtube.com/watch?v=' + id)}`);
      return send(res, 200, { vid: id, title: d.title, channel: cleanChannel(d.author_name), art: `https://i.ytimg.com/vi/${id}/hqdefault.jpg` }, 86400);
    }
    if (!q) return send(res, 400, { error: 'Missing q' });
    const key = ytKey();
    if (!key) return send(res, 501, { error: 'YouTube search is not set up on this deployment (no YOUTUBE_API_KEY).' });
    const s = await getJSON(`https://www.googleapis.com/youtube/v3/search?part=snippet&type=video&videoEmbeddable=true&videoCategoryId=10&maxResults=10&q=${encodeURIComponent(q)}&key=${key}`);
    const ids = s.items.map((i) => i.id.videoId).filter(Boolean);
    const durations = {};
    if (ids.length) {
      const v = await getJSON(`https://www.googleapis.com/youtube/v3/videos?part=contentDetails&id=${ids.join(',')}&key=${key}`);
      for (const it of v.items) durations[it.id] = isoDuration(it.contentDetails.duration);
    }
    const results = s.items.filter((i) => i.id.videoId).map((i) => ({
      vid: i.id.videoId, title: decode(i.snippet.title), channel: cleanChannel(decode(i.snippet.channelTitle)),
      topic: / - Topic$/.test(i.snippet.channelTitle), art: bestThumb(i.snippet.thumbnails), duration: durations[i.id.videoId] || 0,
    }));
    send(res, 200, { results }, 86400);
  } catch (e) {
    send(res, 502, { error: e.message });
  }
}
const decode = (s = '') => s.replace(/&amp;/g, '&').replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&lt;/g, '<').replace(/&gt;/g, '>');
