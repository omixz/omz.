// Shared helpers for the dashboard and overlays.
window.LT = {
  params: new URLSearchParams(location.search),
  esc(s) {
    return String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  },
  fmt(n) {
    n = Number(n) || 0;
    if (n >= 1e6) return (n / 1e6).toFixed(1).replace(/\.0$/, '') + 'M';
    if (n >= 1e4) return (n / 1e3).toFixed(1).replace(/\.0$/, '') + 'K';
    return n.toLocaleString();
  },
  avatar(url, name) {
    if (url) return `<img class="av" src="${LT.esc(url)}" referrerpolicy="no-referrer" alt="">`;
    const ch = (String(name || '?').trim()[0] || '?').toUpperCase();
    return `<span class="av av-fallback">${LT.esc(ch)}</span>`;
  },
};
