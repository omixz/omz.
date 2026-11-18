# Steve LIVE Hub (private website)

A small static site on Vercel: live status lights, a live preview of the stream, one-tap links to
your server's control panel, the setup checklist and the gift ladder.

- **Private**: the Vercel project uses *Vercel Authentication*, so only people logged into your Vercel
  account can open it. It is also marked `noindex`.
- **Server address**: set `window.HUB_URL` in `config.js` (or type it on the site; it's saved per device).
  The status lights read the server's read-only `/api/status`.
- The game itself runs on your always-on server (`tiktok-live-tools/`), not on Vercel.
