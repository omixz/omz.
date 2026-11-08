# Tempo: your own music player

Tempo is a music player you can install on your phone and computer. It has no subscription and no account, and it doesn't track you.
You add songs you own, and Tempo keeps them on the device so they play offline.

## Features
- Home, Search and Your Library (Songs / Albums / Artists / Playlists)
- Album and artist pages, Liked Songs, playlists you can create, rename and delete
- Play, pause, next, previous, seek, shuffle, repeat (all / one), volume
- A queue with "Play next", "Add to queue" and "Clear queue"
- Full-screen Now Playing view on phones (swipe down to close)
- Lock-screen and headphone controls (Media Session API)
- Reads song title, artist, album, track number, genre and **cover art** from MP3, M4A/AAC, and FLAC files.
  Untagged files use the file name (`Artist - Title.mp3`).
- Drag and drop files or whole folders onto the window (desktop)
- Remembers your queue, position, shuffle/repeat and volume between visits
- Keyboard: `Space` play/pause, `←/→` seek 5s, `Shift+←/→` previous/next, `S` shuffle, `R` repeat, `L` like, `/` search
- Installable (PWA) and works offline

## Run it locally
It's plain HTML/CSS/JS with no build step:

```bash
cd music-player
python3 -m http.server 8080
# open http://localhost:8080
```

## Put it on your phone
Installing and offline mode need **HTTPS**, so host the `music-player` folder on any free static host:

- **Vercel**: `npx vercel deploy music-player --prod`
- **Netlify**: drag the `music-player` folder onto https://app.netlify.com/drop
- **GitHub Pages / Cloudflare Pages**: point them at the `music-player` folder

Then open the URL:
- **iPhone/iPad (Safari):** Share → *Add to Home Screen*
- **Android (Chrome):** menu → *Install app*
- **Mac/Windows (Chrome/Edge):** the install icon in the address bar

## Good to know
- Songs are stored **per device** in the browser's storage (IndexedDB), so add your music on each device you use.
  Clearing the site's data in your browser deletes the songs Tempo stored.
- To keep **one library synced across all your devices**, run a self-hosted music server such as
  [Navidrome](https://www.navidrome.org/) on a home computer and use any Subsonic-compatible app with it.
- Format support depends on the browser. MP3, AAC/M4A and WAV play everywhere. FLAC plays in modern Safari and Chrome.
  OGG/Opus won't play on older iPhones.
