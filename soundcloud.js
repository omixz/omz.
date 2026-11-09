// SoundCloud songs play through SoundCloud's official embedded player (the Widget API),
// which is free and needs no developer key. People add songs by pasting a SoundCloud link.
let apiP = null, widget = null, frame = null;

export const isLink = (s) => /^(https?:\/\/)?((www|m)\.)?(soundcloud\.com|on\.soundcloud\.com|snd\.sc)\/\S+/i.test(String(s).trim());

export async function lookup(link) {
  let url = String(link).trim();
  if (!/^https?:\/\//i.test(url)) url = 'https://' + url;
  url = url.replace('://m.soundcloud.com', '://soundcloud.com').split('?')[0];
  const res = await fetch('https://soundcloud.com/oembed?format=json&url=' + encodeURIComponent(url));
  if (!res.ok) throw new Error(res.status === 404 ? "That SoundCloud link doesn't exist or is private" : `SoundCloud lookup failed (${res.status})`);
  const d = await res.json();
  const apiUrl = decodeURIComponent((d.html.match(/[?&]url=([^&"]+)/) || [])[1] || '');
  const artist = d.author_name || 'SoundCloud';
  let title = d.title || 'Untitled';
  if (title.endsWith(' by ' + artist)) title = title.slice(0, -(' by ' + artist).length);
  const art = d.thumbnail_url || '';
  return {
    title, artist, artistUrl: d.author_url || '', url: apiUrl || url, permalink: url,
    isSet: /\/playlists\//.test(apiUrl) || /\/sets\//.test(url),
    art480: art, art150: art.replace('-t500x500', '-large'), art1000: art,
  };
}

function loadApi() {
  return (apiP ??= new Promise((res, rej) => {
    const s = document.createElement('script');
    s.src = 'https://w.soundcloud.com/player/api.js';
    s.onload = () => res(window.SC);
    s.onerror = () => { apiP = null; rej(new Error("Couldn't load the SoundCloud player")); };
    document.head.appendChild(s);
  }));
}
const opts = (autoplay) => ({ auto_play: autoplay, visual: false, show_comments: false, hide_related: true, show_teaser: false, show_reposts: false, buying: false, sharing: false, download: false });

// Loads a song into the player inside `box` and resolves with its duration in seconds.
export async function load(box, on, url, autoplay) {
  const SC = await loadApi();
  if (!widget) {
    frame = document.createElement('iframe');
    frame.title = 'SoundCloud player';
    frame.allow = 'autoplay; encrypted-media';
    const q = new URLSearchParams({ url, ...Object.fromEntries(Object.entries(opts(autoplay)).map(([k, v]) => [k, String(v)])) });
    frame.src = 'https://w.soundcloud.com/player/?' + q;
    box.appendChild(frame);
    widget = SC.Widget(frame);
    await new Promise((r) => widget.bind(SC.Widget.Events.READY, r));
    const E = SC.Widget.Events;
    widget.bind(E.PLAY, on.play);
    widget.bind(E.PAUSE, on.pause);
    widget.bind(E.FINISH, on.finish);
    widget.bind(E.PLAY_PROGRESS, (e) => on.progress(e.currentPosition / 1000));
    widget.bind(E.ERROR, on.error);
    if (autoplay) widget.play();
    return new Promise((r) => widget.getDuration((ms) => r(ms / 1000)));
  }
  return new Promise((r) => widget.load(url, { ...opts(autoplay), callback: () => widget.getDuration((ms) => r(ms / 1000)) }));
}
export const play = () => widget?.play();
export const pause = () => widget?.pause();
export const seek = (s) => widget?.seekTo(Math.max(0, s) * 1000);
export const volume = (v) => widget?.setVolume(Math.round(v * 100));

// List the songs behind a profile, playlist ("set") or album link without disturbing playback,
// using a separate, off-screen copy of the player. Resolves to [{ id, title, artist, url, permalink, art, duration }].
export async function listSounds(link) {
  const SC = await loadApi();
  let url = String(link).trim();
  if (!/^https?:\/\//i.test(url)) url = 'https://' + url;
  url = url.replace('://m.soundcloud.com', '://soundcloud.com').split('?')[0];
  const f = document.createElement('iframe');
  f.style.cssText = 'position:fixed;left:-9999px;top:0;width:300px;height:300px;border:0';
  f.src = 'https://w.soundcloud.com/player/?' + new URLSearchParams({ url, auto_play: 'false' });
  document.body.appendChild(f);
  try {
    const w = SC.Widget(f);
    await new Promise((res, rej) => { const t = setTimeout(() => rej(new Error("SoundCloud didn't respond. Check the link")), 20000); w.bind(SC.Widget.Events.READY, () => { clearTimeout(t); res(); }); });
    let sounds = [];
    for (let i = 0; i < 12; i++) {
      sounds = await new Promise((r) => w.getSounds(r));
      if (sounds.length && sounds.every((s) => s.title)) break;
      await new Promise((r) => setTimeout(r, 1000));
    }
    const user = await new Promise((r) => w.getCurrentSound((s) => r(s?.user?.username || '')));
    return {
      owner: user,
      sounds: sounds.filter((s) => s.title && s.streamable !== false).map((s) => {
        const art = s.artwork_url || s.user?.avatar_url || '';
        return {
          id: s.id, title: s.title, artist: s.user?.username || user || 'SoundCloud', artistUrl: s.user?.permalink_url || '',
          url: 'https://api.soundcloud.com/tracks/' + s.id, permalink: s.permalink_url,
          art150: art.replace('-large', '-t200x200'), art480: art.replace('-large', '-t500x500'), art1000: art.replace('-large', '-t500x500'),
          duration: Math.round((s.duration || 0) / 1000), genre: s.genre || '',
        };
      }),
    };
  } finally { f.remove(); }
}
export const isCollectionLink = (s) => /soundcloud\.com\/[^/?#]+\/?(?:$|[?#])|\/sets\/|\/albums|\/tracks\/?$|\/popular-tracks/i.test(String(s).trim());
