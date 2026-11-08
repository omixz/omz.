// Free music catalog: Audius (https://audius.co), an open music platform where
// artists upload their own songs. Its public API needs no key and allows streaming.
const API = 'https://api.audius.co/v1';
const APP = 'Tempo';
const cache = new Map();

async function get(path, params = {}, ttl = 5 * 60e3) {
  const q = new URLSearchParams({ ...params, app_name: APP });
  const url = `${API}${path}?${q}`;
  const hit = cache.get(url);
  if (hit && Date.now() - hit.at < ttl) return hit.data;
  const res = await fetch(url);
  if (!res.ok) throw new Error(`Catalog request failed (${res.status})`);
  const data = (await res.json()).data;
  cache.set(url, { at: Date.now(), data });
  return data;
}

const playable = (d) => d && d.is_streamable !== false && !d.stream_conditions && !d.is_delete && !d.is_unlisted;

export function mapTrack(d) {
  const a = d.artwork || {};
  return {
    id: 'au:' + d.id, source: 'audius', rid: d.id,
    title: d.title || 'Untitled', artist: d.user?.name || 'Unknown Artist', artistId: d.user?.id || '',
    album: '', albumArtist: '', genre: d.genre || '', mood: d.mood || '',
    duration: d.duration || 0, track: 0, disc: 0, year: d.release_date ? new Date(d.release_date).getFullYear() || 0 : 0,
    art150: a['150x150'] || '', art480: a['480x480'] || a['150x150'] || '', art1000: a['1000x1000'] || a['480x480'] || '',
    permalink: d.permalink ? `https://audius.co${d.permalink}` : '', playCount: d.play_count || 0,
    addedAt: 0, liked: false, plays: 0,
  };
}
const mapUser = (u) => ({
  id: u.id, name: u.name, handle: u.handle, followers: u.follower_count || 0, tracks: u.track_count || 0,
  bio: u.bio || '', pic: u.profile_picture?.['480x480'] || u.profile_picture?.['150x150'] || '',
  cover: u.cover_photo?.['640x'] || '', verified: !!u.is_verified,
});
const mapPlaylist = (p) => ({
  id: p.id, name: p.playlist_name, by: p.user?.name || '', count: p.track_count ?? (p.tracks?.length || 0),
  art: p.artwork?.['480x480'] || p.artwork?.['150x150'] || '', description: p.description || '', isAlbum: !!p.is_album,
});
const tracks = (list) => (list || []).filter(playable).map(mapTrack);

export const streamURL = (rid) => `${API}/tracks/${encodeURIComponent(rid)}/stream?app_name=${APP}`;
export const trending = async (genre = '', time = 'week') => tracks(await get('/tracks/trending', genre ? { genre, time } : { time }));
export const searchTracks = async (query) => tracks(await get('/tracks/search', { query, limit: 30 }, 60e3));
export const searchArtists = async (query) => (await get('/users/search', { query, limit: 12 }, 60e3)).filter((u) => !u.is_deactivated && u.track_count > 0).map(mapUser);
export const searchPlaylists = async (query) => (await get('/playlists/search', { query, limit: 12 }, 60e3)).filter((p) => !p.is_private).map(mapPlaylist);
export const artist = async (id) => mapUser(await get(`/users/${encodeURIComponent(id)}`));
export const artistTracks = async (id) => tracks(await get(`/users/${encodeURIComponent(id)}/tracks`, { limit: 50, sort: 'plays' }));
export const trendingPlaylists = async () => (await get('/playlists/trending', { time: 'week' })).filter((p) => !p.is_private).slice(0, 16).map(mapPlaylist);
export async function playlist(id) {
  const [info] = await get(`/playlists/${encodeURIComponent(id)}`);
  const list = await get(`/playlists/${encodeURIComponent(id)}/tracks`);
  return { ...mapPlaylist(info), tracks: tracks(list) };
}
export const GENRES = ['Electronic', 'Hip-Hop/Rap', 'Pop', 'Alternative', 'R&B/Soul', 'Lo-Fi', 'House', 'Rock', 'Jazz', 'Ambient', 'Dubstep', 'Techno', 'Acoustic', 'Latin', 'Classical', 'Country', 'Reggae', 'Soundtrack', 'Folk', 'Metal', 'Drum & Bass', 'Trap', 'Funk', 'World'];
