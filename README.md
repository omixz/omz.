# Tempo

A music streaming app you own. It runs on phones and computers, is free, needs no subscription, and has your own name on it.

**Where the music comes from**
- **Free catalog (Audius):** trending charts, genres, search, artist pages and playlists, streamed in full.
  [Audius](https://audius.co) is an open music platform where artists upload their own songs and allow free streaming through its public API. It needs no API key.
- **SoundCloud links:** paste any public SoundCloud song link (great for unreleased tracks) into Search or Library → *SoundCloud link*.
  These play through SoundCloud's official embedded player, which shows up in a small "Playing from SoundCloud" box while the song plays.
- **Your own files:** MP3, M4A/AAC, FLAC, WAV. They're stored on the device and play offline, with title, artist, album and cover art read from the file.

**Features:** Home with trending songs and playlists, Search, Your Library (playlists, songs, albums, artists), Liked Songs,
your own playlists (or save a copy of any catalog playlist), queue, shuffle, repeat, lock-screen and headphone controls,
full-screen Now Playing on phones, keyboard shortcuts (`Space`, `←/→`, `Shift+←/→`, `S`, `R`, `L`, `/`), and install as an app.

**Accounts (optional):** people sign up with email and password, and their Liked Songs, playlists and SoundCloud songs sync across every device they sign in on.

---

## 1. Put it online
It's plain HTML/CSS/JS with no build step. Host this folder on any static host with HTTPS:

- **Vercel:** import this repo at https://vercel.com/new (no settings needed), or run `npx vercel deploy --prod`
- **Netlify:** drag this folder onto https://app.netlify.com/drop
- **Cloudflare Pages / GitHub Pages:** point them at the repo root

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

## 3. Make it your brand
- Name: change `Tempo` in `index.html` (`<title>`, `apple-mobile-web-app-title`, the sidebar brand) and `manifest.webmanifest`.
- Colors: the `--accent`, `--accent2` and `--grad` values at the top of `styles.css`.
- Logo: replace `icon.svg`, `icon-192.png` and `icon-512.png`.

## Good to know
- **Why not YouTube?** Pulling the audio out of YouTube videos breaks YouTube's terms, and apps that do it get taken down.
  YouTube's official embedded player has to stay visible and stops when a phone screen locks, which makes it a poor music player.
- **SoundCloud** has no open search API (new developer keys aren't being issued), so songs are added by link rather than searched in the app.
  On phones, SoundCloud songs may pause when the screen locks, because they play inside SoundCloud's embedded player. Catalog songs and your own files keep playing in the background.
- Music files you add stay on the device you added them on, and only your likes and playlists sync. Clearing the site's data in the browser removes those files.
- Format support depends on the browser. MP3, AAC/M4A and WAV play everywhere, and FLAC plays in modern Safari and Chrome.

## Files
| File | What it does |
|---|---|
| `index.html`, `styles.css` | Layout and look |
| `app.js` | The app: screens, player, library, playlists, sync logic |
| `audius.js` | Free catalog: trending, search, artists, playlists, streaming |
| `soundcloud.js` | SoundCloud link lookup and embedded player |
| `tags.js` | Reads song info and cover art from MP3/M4A/FLAC files |
| `sync.js`, `config.js`, `supabase/schema.sql` | Accounts and cloud sync (Supabase) |
| `sw.js`, `manifest.webmanifest`, icons | Install as an app and load offline |
