import { send, ytKey } from './_lib.js';
// Tells the app which optional features this deployment has switched on.
export default function handler(req, res) {
  send(res, 200, { youtubeSearch: !!ytKey() });
}
