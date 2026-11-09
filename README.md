# Tempo

A music streaming app you own. It runs on phones and computers, is free, needs no subscription, and has your own name on it.

**Where the music comes from**
- **YouTube (the big catalog):** almost every mainstream song, played through YouTube's official embedded player.
  Paste YouTube or YouTube Music links, search YouTube from inside the app, and imported Spotify songs are matched to YouTube automatically.
  YouTube search and matching need a free YouTube API key (step 3 below).
- **Free catalog (Audius):** trending charts, genres, search, artist pages and playlists, streamed in full with no key.
  [Audius](https://audius.co) is an open platform where artists upload their own music.
- **SoundCloud (unreleased songs):** paste any public song or playlist link, or link your SoundCloud profile to bring in its uploads.
- **Your own files:** MP3, M4A/AAC, FLAC, WAV, stored on the device and playable offline.

**Bring your playlists:** paste a Spotify, YouTube, YouTube Music or SoundCloud playlist link (Search box, or Library → *Import playlist*)
and it is rebuilt as a Tempo playlist. Importing the same link again refreshes it.

**DJ Tempo:** your personal DJ. It builds sets from your likes and most-played songs, mixes in new finds and genre picks,
and talks between songs using your device's built-in voice (with captions). Tap *Switch it up* for a different vibe.

**Smart shuffle:** tap shuffle twice (✦). Tempo mixes songs picked for you into whatever you're playing, marked "✦ Recommended".

**Everything else:** Home, Search, Your Library (playlists, songs, albums, artists), Liked Songs, queue, shuffle, repeat,
lock-screen and headphone controls, a full-screen player on phones, keyboard shortcuts (`Space`, `←/→`, `Shift+←/→`, `S`, `R`, `L`, `/`), and install as an app.

**Accounts (optional):** sign up with email and password to sync Liked Songs, playlists and added songs across devices.

---

## 1. Put it online
The app is plain HTML/CSS/JS with no build step, plus three small serverless functions in `api/`
(playlist import and YouTube search). Deploy it on **Vercel** so the functions run:
import this repo at https://vercel.com/new (no settings needed), or run `npx vercel deploy --prod`.
On a static-only host (Netlify Drop, GitHub Pages) everything works except importing Spotify/YouTube playlists and YouTube search.

Then install it:
- **iPhone/iPad (Safari):** Share → *Add to Home Screen*
- **Android (Chrome):** menu → *Install app*
- **Mac/Windows (Chrome/Edge):** the install icon in the address bar

To try it locally: `python3 -m http.server 8080`, then open http://localhost:8080.

## 2. Turn on accounts (about 5 minutes, free)
1. Create a free project at https://supabase.com.
2. In the project, open **SQL Editor**, paste the contents of [`supabase/schema.sql`](supabase/schema.sql) and click **Run**.
   This creates one table, and its security rules make sure each person can only read and write their own library.
3. Open **Project Settings → API** and copy the **Project URL** and the **anon public** key into [`config.js`](config.js).
   The anon key is designed to be public.
4. Under **Authentication → URL Configuration**, set **Site URL** to your app's address (for example `https://your-app.vercel.app`).
5. Optional: under **Authentication → Sign In / Providers → Email**, turn off *Confirm email* if you want people to sign in right after signing up.

Redeploy, and the **Account** tab shows sign-up and sign-in.

## 3. Turn on YouTube search (free, about 5 minutes)
This lets Tempo search YouTube and play imported Spotify songs.
1. Go to https://console.cloud.google.com, create a project, then open **APIs & Services → Library**, find **YouTube Data API v3** and click **Enable**.
2. Open **APIs & Services → Credentials → Create credentials → API key**. Under *API restrictions*, restrict it to **YouTube Data API v3**.
3. In Vercel, open the project → **Settings → Environment Variables**, add `YOUTUBE_API_KEY` with that key, then redeploy.

The free quota is 10,000 units a day. A YouTube search costs about 100, so that's roughly 100 searches a day.
Each imported song is matched once, the first time it plays, and then remembered. Results are cached for a day.

## 4. Make it your brand
- Name: change `Tempo` in `index.html` (`<title>`, `apple-mobile-web-app-title`, the sidebar brand) and `manifest.webmanifest`.
- Colors: the `--accent`, `--accent2` and `--grad` values at the top of `styles.css`.
- Logo: replace `icon.svg`, `icon-192.png` and `icon-512.png`.

## Good to know
- **YouTube** songs play in YouTube's official player, which YouTube requires to stay visible (it sits in a small box, and fills the artwork spot in Now Playing).
  Tempo never downloads or rips audio, which is what keeps it within YouTube's rules. YouTube may show ads, and on phones YouTube songs usually stop when the screen locks.
- **SoundCloud** has no open search API, so songs come in by link, playlist or linked profile. Like YouTube, they may pause when a phone screen locks.
  Audius songs and your own files keep playing in the background.
- **Spotify import** reads the public track list (titles and artists) of public playlists. Private playlists can't be read, so make a playlist public before importing it.
- Music files you add stay on the device you added them on, and only your likes and playlists sync. Clearing the site's data in the browser removes those files.
- Format support depends on the browser. MP3, AAC/M4A and WAV play everywhere, and FLAC plays in modern Safari and Chrome.

## Files
| File | What it does |
|---|---|
| `index.html`, `styles.css` | Layout and look |
| `app.js` | The app: screens, player, library, playlists, sync logic |
| `audius.js` | Free catalog: trending, search, artists, playlists, streaming |
| `soundcloud.js` | SoundCloud link lookup, profile/playlist listing, embedded player |
| `youtube.js` | YouTube embedded player, link parsing, song matching |
| `api/` | Serverless functions: `import` (Spotify/YouTube playlists), `youtube` (search + video info), `status` |
| `tags.js` | Reads song info and cover art from MP3/M4A/FLAC files |
| `sync.js`, `config.js`, `supabase/schema.sql` | Accounts and cloud sync (Supabase) |
| `sw.js`, `manifest.webmanifest`, icons | Install as an app and load offline |
