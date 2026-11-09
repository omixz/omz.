// YouTube songs play through YouTube's official embedded player (IFrame API).
// YouTube's rules require the player to stay visible (at least 200x200) while it plays.
let apiP = null, player = null, pollTimer = null, on = null, readyP = null;
let status = null;

export const videoId = (s) => {
  const m = String(s).match(/(?:youtu\.be\/|[?&]v=|\/shorts\/|\/embed\/|\/live\/)([\w-]{11})/);
  return m ? m[1] : null;
};
export const isLink = (s) => /^(https?:\/\/)?((www|m|music)\.)?(youtube\.com|youtu\.be)\//i.test(String(s).trim());
export const isPlaylistLink = (s) => isLink(s) && /[?&]list=[\w-]+/.test(s) && !/[?&]list=(RD|UL)/.test(s);

async function api(path) {
  const r = await fetch(path);
  const d = await r.json().catch(() => ({}));
  if (!r.ok) { const e = new Error(d.error || `Request failed (${r.status})`); e.status = r.status; throw e; }
  return d;
}
// Is YouTube search switched on for this deployment? (needs the server functions + an API key)
export async function searchEnabled() {
  if (status) return status.youtubeSearch;
  try { status = await api('api/status'); } catch { status = { youtubeSearch: false, noServer: true }; }
  return status.youtubeSearch;
}
export const hasServer = () => status && !status.noServer;
export const search = async (q) => (await api('api/youtube?q=' + encodeURIComponent(q))).results;
export const info = (vid) => api('api/youtube?id=' + encodeURIComponent(vid));
export const importPlaylist = (url) => api('api/import?url=' + encodeURIComponent(url));

// Pick the result most likely to be the actual song (not a cover, live take or reaction).
export function bestMatch(results, title, artist, duration = 0) {
  const norm = (s) => String(s).toLowerCase().normalize('NFKD').replace(/[^\w\s]/g, ' ');
  const want = norm(`${title} ${artist}`);
  const tw = norm(title).split(/\s+/).filter((w) => w.length > 1);
  const aw = norm(artist.split(/,|&| feat/i)[0]).split(/\s+/).filter(Boolean);
  let best = null, bestScore = -1e9;
  for (const r of results) {
    const t = norm(r.title + ' ' + r.channel);
    let sc = 0;
    sc += tw.filter((w) => t.includes(w)).length * 2;
    sc += aw.filter((w) => t.includes(w)).length * 2;
    if (r.topic) sc += 4;
    if (/official (audio|music video|video)|\baudio\b/.test(t)) sc += 2;
    for (const bad of ['live', 'cover', 'karaoke', 'reaction', 'remix', 'sped up', 'slowed', 'instrumental', '8d', 'nightcore', 'lyrics']) {
      if (t.includes(bad) && !want.includes(bad)) sc -= bad === 'lyrics' ? 1 : 4;
    }
    if (duration && r.duration) { const d = Math.abs(r.duration - duration); sc += d < 5 ? 4 : d < 15 ? 2 : d > 60 ? -4 : 0; }
    if (sc > bestScore) { bestScore = sc; best = r; }
  }
  return best;
}

function loadApi() {
  return (apiP ??= new Promise((res, rej) => {
    if (window.YT?.Player) return res(window.YT);
    const prev = window.onYouTubeIframeAPIReady;
    window.onYouTubeIframeAPIReady = () => { prev?.(); res(window.YT); };
    const s = document.createElement('script');
    s.src = 'https://www.youtube.com/iframe_api';
    s.onerror = () => { apiP = null; rej(new Error("Couldn't load the YouTube player")); };
    document.head.appendChild(s);
  }));
}
function poll() {
  clearInterval(pollTimer);
  pollTimer = setInterval(() => {
    if (!player?.getCurrentTime) return;
    on?.progress(player.getCurrentTime() || 0, player.getDuration() || 0);
  }, 500);
}

// Load a video into the player inside `box`. Resolves once it is cued or playing.
export async function load(box, handlers, vid, autoplay, start = 0) {
  on = handlers;
  const YT = await loadApi();
  if (!player) {
    const el = document.createElement('div');
    box.appendChild(el);
    readyP = new Promise((res) => {
      player = new YT.Player(el, {
        width: '100%', height: '100%', videoId: vid,
        playerVars: { autoplay: autoplay ? 1 : 0, playsinline: 1, rel: 0, start: Math.floor(start) || 0, origin: location.origin },
        events: {
          onReady: () => { if (autoplay) player.playVideo(); res(); },
          onStateChange: (e) => {
            const S = YT.PlayerState;
            if (e.data === S.PLAYING) { on?.play(); poll(); }
            else if (e.data === S.PAUSED) on?.pause();
            else if (e.data === S.ENDED) { clearInterval(pollTimer); on?.finish(); }
          },
          // 2 bad id, 5 html5 error, 100 removed/private, 101/150 owner blocked embedding
          onError: (e) => on?.error(e.data),
        },
      });
    });
    await readyP;
    return player.getDuration?.() || 0;
  }
  await readyP;
  if (autoplay) player.loadVideoById({ videoId: vid, startSeconds: Math.floor(start) || 0 });
  else player.cueVideoById({ videoId: vid, startSeconds: Math.floor(start) || 0 });
  return player.getDuration?.() || 0;
}
export const play = () => player?.playVideo?.();
export const pause = () => player?.pauseVideo?.();
export const stop = () => { clearInterval(pollTimer); player?.pauseVideo?.(); };
export const seek = (s) => player?.seekTo?.(Math.max(0, s), true);
export const volume = (v) => { if (!player?.setVolume) return; player.setVolume(Math.round(v * 100)); if (v > 0) player.unMute?.(); };
// 0..1: how much of the wanted title (and artist) appears in a result.
export function quality(r, title, artist) {
  const norm = (s) => String(s).toLowerCase().normalize('NFKD').replace(/[^\w\s]/g, ' ');
  const hay = norm(`${r.title} ${r.channel || r.artist || ''}`);
  const tw = norm(title.replace(/\(.*?\)|\[.*?\]/g, '')).split(/\s+/).filter((w) => w.length > 1);
  const aw = norm(artist.split(/,|&| feat/i)[0]).split(/\s+/).filter((w) => w.length > 1);
  const tf = tw.length ? tw.filter((w) => hay.includes(w)).length / tw.length : 0;
  const af = aw.length ? aw.filter((w) => hay.includes(w)).length / aw.length : 0;
  return tf * 0.7 + af * 0.3;
}
