import { send, getJSON, ytKey, UA, bestThumb, cleanChannel } from './_lib.js';

// GET /api/import?url=<playlist link>
// Reads the public track list (title + artist) of a Spotify playlist/album/track,
// or a YouTube / YouTube Music playlist, so the app can rebuild it as a playlist.
export default async function handler(req, res) {
  const url = String(req.query.url || '').trim();
  try {
    const sp = url.match(/open\.spotify\.com\/(?:intl-[\w-]+\/)?(?:embed\/)?(playlist|album|track)\/([A-Za-z0-9]+)/);
    const list = url.match(/[?&]list=([\w-]+)/);
    if (sp) return send(res, 200, await spotify(sp[1], sp[2]), 600);
    if (list && /youtu\.?be|youtube\.com/.test(url)) return send(res, 200, await youtubePlaylist(list[1]), 600);
    send(res, 400, { error: 'Paste a link to a Spotify, YouTube or YouTube Music playlist.' });
  } catch (e) {
    send(res, 502, { error: e.message });
  }
}

async function spotify(type, id) {
  const r = await fetch(`https://open.spotify.com/embed/${type}/${id}`, { headers: { 'User-Agent': UA, 'Accept-Language': 'en' } });
  if (r.status === 404) throw new Error("That Spotify playlist doesn't exist or is private.");
  if (!r.ok) throw new Error(`Spotify returned an error (${r.status}).`);
  const html = await r.text();
  const m = html.match(/<script id="__NEXT_DATA__" type="application\/json">([\s\S]*?)<\/script>/);
  const e = m && JSON.parse(m[1])?.props?.pageProps?.state?.data?.entity;
  if (!e) throw new Error("Couldn't read that Spotify page. Make sure the playlist is public.");
  const items = e.trackList?.length ? e.trackList
    : [{ title: e.title || e.name, subtitle: (e.artists || []).map((a) => a.name).join(', '), duration: e.duration?.totalMilliseconds ?? e.duration }];
  const art = (e.coverArt?.sources || e.visualIdentity?.image || []).slice().sort((a, b) => (b.width || 0) - (a.width || 0))[0]?.url || '';
  return {
    name: e.name || e.title || 'Spotify playlist', from: 'Spotify', art,
    tracks: items.filter((t) => t.title).map((t) => ({
      title: t.title, artist: String(t.subtitle || '').replace(/ /g, ' ').trim(), duration: Math.round((+t.duration || 0) / 1000),
    })),
  };
}

async function youtubePlaylist(id) {
  const key = ytKey();
  if (!key) throw new Error('Importing YouTube playlists needs a YouTube API key on this deployment (see the README).');
  const meta = await getJSON(`https://www.googleapis.com/youtube/v3/playlists?part=snippet&id=${id}&key=${key}`);
  const info = meta.items?.[0]?.snippet;
  if (!info) throw new Error("That YouTube playlist doesn't exist or is private.");
  const items = []; let page = '';
  do {
    const d = await getJSON(`https://www.googleapis.com/youtube/v3/playlistItems?part=snippet,contentDetails&maxResults=50&playlistId=${id}&key=${key}${page ? '&pageToken=' + page : ''}`);
    items.push(...d.items); page = d.nextPageToken;
  } while (page && items.length < 500);
  return {
    name: info.title, from: 'YouTube', art: bestThumb(info.thumbnails),
    tracks: items.filter((i) => i.snippet.videoOwnerChannelTitle).map((i) => ({
      vid: i.contentDetails.videoId, title: i.snippet.title, artist: cleanChannel(i.snippet.videoOwnerChannelTitle),
      art: bestThumb(i.snippet.thumbnails), duration: 0,
    })),
  };
}
