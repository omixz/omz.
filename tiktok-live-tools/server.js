// TikTok LIVE Tools — a lightweight, self-hosted alternative to desktop LIVE
// interaction apps. One small Node process: it connects to your TikTok LIVE,
// runs your rules (alerts, sounds, TTS) and pushes everything to a phone-friendly
// dashboard and to OBS / TikTok LIVE Studio browser-source overlays.
import express from 'express';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { spawn, spawnSync } from 'node:child_process';
import { Server } from 'socket.io';
import { TikTokLiveConnection, WebcastEvent, ControlEvent } from 'tiktok-live-connector';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PORT = Number(process.env.PORT) || 3000;
const ADMIN_KEY = process.env.ADMIN_KEY || '';
const DATA_DIR = process.env.DATA_DIR || path.join(__dirname, 'data');
const SETTINGS_FILE = path.join(DATA_DIR, 'settings.json');
const STREAM_FILE = path.join(DATA_DIR, 'stream.json'); // read by stream.sh (cloud streaming)
const OFFLINE_RETRY_MS = 60_000; // how often to check whether you went live
const MAX_FEED = 200;

// ---------------------------------------------------------------- settings --

const DEFAULT_SETTINGS = {
  username: process.env.TIKTOK_USERNAME || '',
  autoConnect: true,
  mcPresetApplied: false, // Minecraft actions are added automatically the first time the hero joins
  tts: {
    mode: 'command', // off | all | command
    command: '!tts',
    readGifts: false, // gift thank-yous are handled by rules' "speak" text
    maxLength: 150,
    skipLinks: true,
    bannedWords: '',
  },
  goal: { type: 'likes', target: 1000, title: 'Like goal' },
  // Castle Clash game (public/game.html)
  game: {
    teamA: 'RED',
    teamB: 'BLUE',
    joinA: '1, red',
    joinB: '2, blue',
    likesPerSoldier: 5,
    castleHp: 2000,
    knightCoins: 1,
    giantCoins: 10,
    dragonCoins: 99,
    meteorCoins: 500,
    followUnits: 2,
    shareUnits: 5,
    intermission: 10,
  },
  rules: [
    {
      id: 'r-any-gift',
      enabled: true,
      name: 'Any gift',
      trigger: { type: 'gift', giftName: '', minCoins: 1 },
      alert: { show: true, text: '{user} sent {count}x {gift}!', duration: 5 },
      sound: 'coin',
      speak: 'Thank you {user} for the {gift}',
      cooldown: 0,
    },
    {
      id: 'r-big-gift',
      enabled: true,
      name: 'Big gift (100+ coins)',
      trigger: { type: 'gift', giftName: '', minCoins: 100 },
      alert: { show: true, text: 'WOW! {user} sent {count}x {gift} ({coins} coins)!', duration: 8 },
      sound: 'fanfare',
      speak: 'Wow! Huge thanks {user}!',
      cooldown: 0,
    },
    {
      id: 'r-follow',
      enabled: true,
      name: 'New follower',
      trigger: { type: 'follow' },
      alert: { show: true, text: '{user} just followed!', duration: 4 },
      sound: 'chime',
      speak: '',
      cooldown: 0,
    },
    {
      id: 'r-share',
      enabled: true,
      name: 'Share',
      trigger: { type: 'share' },
      alert: { show: true, text: '{user} shared the LIVE!', duration: 4 },
      sound: 'pop',
      speak: '',
      cooldown: 10,
    },
    {
      id: 'r-likes',
      enabled: false,
      name: 'Every 500 likes',
      trigger: { type: 'likes', every: 500 },
      alert: { show: true, text: '{totalLikes} likes! Keep tapping!', duration: 4 },
      sound: 'chime',
      speak: '',
      cooldown: 0,
    },
    {
      id: 'r-hello',
      enabled: true,
      name: 'Chat command !hello',
      trigger: { type: 'command', command: '!hello' },
      alert: { show: false, text: '', duration: 3 },
      sound: '',
      speak: 'Hello {user}!',
      cooldown: 5,
    },
  ],
};

function deepMerge(base, extra) {
  if (Array.isArray(base)) return Array.isArray(extra) ? extra : base;
  if (base && typeof base === 'object') {
    const out = { ...base };
    if (extra && typeof extra === 'object' && !Array.isArray(extra)) {
      for (const k of Object.keys(extra)) out[k] = k in base ? deepMerge(base[k], extra[k]) : extra[k];
    }
    return out;
  }
  return extra === undefined ? base : extra;
}

let settingsFromDisk = false;
function loadSettings() {
  try {
    const saved = JSON.parse(fs.readFileSync(SETTINGS_FILE, 'utf8'));
    settingsFromDisk = true;
    return deepMerge(DEFAULT_SETTINGS, saved);
  } catch {
    return structuredClone(DEFAULT_SETTINGS);
  }
}

function saveSettings() {
  try {
    fs.mkdirSync(DATA_DIR, { recursive: true });
    fs.writeFileSync(SETTINGS_FILE, JSON.stringify(settings, null, 2));
    settingsFromDisk = true;
  } catch (err) {
    console.error('[settings] could not save:', err.message);
  }
}

function sanitizeSettings(input) {
  const s = deepMerge(DEFAULT_SETTINGS, input || {});
  s.username = String(s.username || '').trim().replace(/^@/, '').replace(/^https?:\/\/(www\.)?tiktok\.com\/@?/, '').replace(/\/live.*$/, '');
  s.autoConnect = Boolean(s.autoConnect);
  s.mcPresetApplied = Boolean(s.mcPresetApplied);
  s.tts.maxLength = clamp(Number(s.tts.maxLength) || 150, 10, 500);
  s.goal.target = Math.max(1, Number(s.goal.target) || 1);
  const g = s.game;
  g.teamA = String(g.teamA || 'RED').slice(0, 16);
  g.teamB = String(g.teamB || 'BLUE').slice(0, 16);
  g.joinA = String(g.joinA || '').slice(0, 100);
  g.joinB = String(g.joinB || '').slice(0, 100);
  for (const k of ['likesPerSoldier', 'castleHp', 'knightCoins', 'giantCoins', 'dragonCoins', 'meteorCoins', 'followUnits', 'shareUnits', 'intermission']) {
    g[k] = Math.max(k.endsWith('Units') ? 0 : 1, Math.round(Number(g[k]) || DEFAULT_SETTINGS.game[k]));
  }
  s.rules = (Array.isArray(s.rules) ? s.rules : []).slice(0, 100).map((r) => ({
    id: String(r.id || crypto.randomUUID()),
    enabled: r.enabled !== false,
    name: String(r.name || 'Rule').slice(0, 80),
    trigger: {
      type: String(r.trigger?.type || 'gift'),
      giftName: String(r.trigger?.giftName || ''),
      minCoins: Math.max(0, Number(r.trigger?.minCoins) || 0),
      maxCoins: Math.max(0, Number(r.trigger?.maxCoins) || 0),
      command: String(r.trigger?.command || ''),
      every: Math.max(1, Number(r.trigger?.every) || 100),
    },
    alert: {
      show: Boolean(r.alert?.show),
      text: String(r.alert?.text || '').slice(0, 300),
      duration: clamp(Number(r.alert?.duration) || 5, 1, 60),
    },
    sound: String(r.sound || '').slice(0, 500),
    speak: String(r.speak || '').slice(0, 300),
    mc: String(r.mc || '').slice(0, 3000), // Minecraft commands, one per line (run by minecraft/bridge.js)
    keys: String(r.keys || '').slice(0, 200), // key presses for any game in the virtual screen
    cooldown: Math.max(0, Number(r.cooldown) || 0),
  }));
  return s;
}

const clamp = (n, lo, hi) => Math.min(hi, Math.max(lo, n));

// ---------------------------------------------------------- Minecraft preset --
// "Hero vs viewers": gifts either hurt the bot (mobs, TNT) or help it (gear,
// food). Added from the dashboard; every line is a normal editable action.
const mob = (type, extra = '') => `execute at {bot} run summon minecraft:${type} ~{rx} ~1 ~{rz} {CustomName:'"{user}"',CustomNameVisible:1b${extra}}`;
const mcRule = (id, name, trigger, mc, cooldown = 0) => ({
  id: 'mc-' + id,
  enabled: true,
  name,
  trigger: { type: 'gift', giftName: '', minCoins: 0, maxCoins: 0, command: '', every: 100, ...trigger },
  alert: { show: false, text: '{user}: ' + name, duration: 4 },
  sound: '',
  speak: '',
  mc: mc.join('\n'),
  keys: '',
  cooldown,
});
const MINECRAFT_PRESET = [
  mcRule('zombie', '🧟 Zombie', { minCoins: 1, maxCoins: 4 }, [mob('zombie')]),
  mcRule('skeleton', '💀 Skeleton', { minCoins: 5, maxCoins: 9 }, [mob('skeleton')]),
  mcRule('iron', '🛡️ Iron gear (help)', { minCoins: 10, maxCoins: 29 }, [
    'give {bot} minecraft:iron_sword', 'give {bot} minecraft:iron_helmet', 'give {bot} minecraft:iron_chestplate',
    'give {bot} minecraft:iron_leggings', 'give {bot} minecraft:iron_boots', 'give {bot} minecraft:cooked_beef 8',
  ]),
  mcRule('creepers', '💥 Creeper squad', { minCoins: 30, maxCoins: 98 }, [mob('creeper'), mob('creeper'), mob('creeper')]),
  mcRule('diamond', '💎 Diamond gear (help)', { minCoins: 99, maxCoins: 198 }, [
    'give {bot} minecraft:diamond_sword', 'give {bot} minecraft:diamond_helmet', 'give {bot} minecraft:diamond_chestplate',
    'give {bot} minecraft:diamond_leggings', 'give {bot} minecraft:diamond_boots', 'give {bot} minecraft:golden_apple 2',
  ]),
  mcRule('tnt', '🧨 TNT rain', { minCoins: 199, maxCoins: 499 }, Array(6).fill('execute at {bot} run summon minecraft:tnt ~{rx} ~5 ~{rz} {fuse:50}')),
  mcRule('boss', '👹 Boss raid', { minCoins: 500 }, [
    'execute at {bot} run summon minecraft:lightning_bolt ~{rx} ~ ~{rz}', mob('ravager'), mob('vindicator'), mob('vindicator'), mob('witch'),
  ]),
  mcRule('follow', '🍎 Golden apple (help)', { type: 'follow' }, ['give {bot} minecraft:golden_apple 1']),
  mcRule('share', '❤️‍🩹 Instant heal (help)', { type: 'share' }, ['effect give {bot} minecraft:instant_health 1 1']),
  mcRule('likes', '✨ Regeneration (help)', { type: 'likes', every: 100 }, ['effect give {bot} minecraft:regeneration 5 1']),
  mcRule('cmd-zombie', '🧟 Chat zombie', { type: 'command', command: '!zombie' }, [mob('zombie')], 15),
];

function applyMinecraftPreset() {
  settings = sanitizeSettings({
    ...settings,
    mcPresetApplied: true,
    rules: [...settings.rules.filter((r) => !r.id.startsWith('mc-')), ...MINECRAFT_PRESET],
  });
  saveSettings();
  ruleRuntime.clear();
  io.emit('settings', settings);
  io.emit('legend', gameLegend());
  console.log('[minecraft] Minecraft actions enabled');
}

function describeTrigger(t) {
  switch (t.type) {
    case 'gift':
      if (t.giftName) return `🎁 ${t.giftName}`;
      return t.maxCoins ? `${t.minCoins}–${t.maxCoins}🪙` : `${t.minCoins}+🪙`;
    case 'follow': return '➕ Follow';
    case 'share': return '🔁 Share';
    case 'likes': return `❤️ ${t.every} likes`;
    case 'command': return `💬 ${t.command}`;
    case 'keyword': return `💬 "${t.command}"`;
    case 'join': return '👋 Join';
    default: return t.type;
  }
}
// What the Minecraft stream page shows viewers ("10–29🪙 → Iron gear").
const gameLegend = () =>
  settings.rules.filter((r) => r.enabled && (r.mc || r.keys)).map((r) => ({ name: r.name, trigger: describeTrigger(r.trigger), type: r.trigger.type, min: r.trigger.minCoins || 0 }));

let settings = loadSettings();

// ------------------------------------------------------------------- state --

function freshStats() {
  return { viewers: 0, likes: 0, diamonds: 0, follows: 0, shares: 0, gifts: 0, chats: 0, joins: 0, gifters: {} };
}

let stats = freshStats();
let mcStatus = null; // last status reported by minecraft/bridge.js
let feed = [];
let lastRoomId = null;
const status = { state: 'idle', username: '', roomId: null, message: '', since: Date.now() };

let connection = null;
let wantConnected = false;
let retryTimer = null;
let retryDelay = 5_000;
const ruleRuntime = new Map(); // ruleId -> { lastFired, likeBucket }

// ------------------------------------------------------------------ server --

const app = express();
const server = http.createServer(app);
const io = new Server(server, { cors: { origin: '*' } });

app.use(express.static(path.join(__dirname, 'public'), { extensions: ['html'] }));
app.get('/healthz', (_req, res) => res.json({ ok: true, status: status.state }));

function publicStats() {
  const top = Object.values(stats.gifters)
    .sort((a, b) => b.coins - a.coins)
    .slice(0, 10);
  const { gifters, likeBaseline, ...rest } = stats;
  return { ...rest, top };
}

function setStatus(state, message = '') {
  Object.assign(status, { state, message, username: settings.username, roomId: connection?.roomId || status.roomId, since: Date.now() });
  io.emit('status', status);
  console.log(`[status] ${state}${message ? ' — ' + message : ''}`);
}

let statsTimer = null;
function emitStatsSoon() {
  if (statsTimer) return;
  statsTimer = setTimeout(() => {
    statsTimer = null;
    io.emit('stats', publicStats());
  }, 250);
}

function pushFeed(ev) {
  feed.push(ev);
  if (feed.length > MAX_FEED) feed = feed.slice(-MAX_FEED);
  io.emit('event', ev);
}

// --------------------------------------------------------- normalization --

const firstUrl = (img) => img?.urlList?.[0] || img?.url_list?.[0] || img?.urls?.[0] || '';

function normUser(u = {}) {
  return {
    id: String(u.userId || u.id || ''),
    uniqueId: u.uniqueId || u.displayId || u.display_id || '',
    nickname: u.nickname || u.uniqueId || u.displayId || 'Someone',
    avatar: firstUrl(u.avatarThumb) || firstUrl(u.avatarMedium) || u.profilePictureUrl || '',
  };
}

function normGift(d) {
  const g = d.gift || {};
  const ext = d.extendedGiftInfo || {};
  const det = d.giftDetails || {};
  const count = Number(d.repeatCount) || 1;
  const coinsEach = Number(g.diamondCount ?? det.diamondCount ?? ext.diamond_count ?? 0) || 0;
  return {
    id: String(d.giftId || g.id || ''),
    name: g.name || det.giftName || ext.name || 'Gift',
    image: firstUrl(g.image) || firstUrl(g.icon) || firstUrl(det.giftImage) || firstUrl(ext.image) || '',
    type: Number(g.type ?? det.giftType ?? 0),
    count,
    coinsEach,
    coins: coinsEach * count,
  };
}

// ---------------------------------------------------------------- pipeline --

function handleEvent(ev) {
  ev.ts = ev.ts || Date.now();
  ev.id = ev.id || crypto.randomUUID();

  switch (ev.type) {
    case 'chat':
      stats.chats++;
      break;
    case 'gift': {
      stats.gifts += ev.gift.count;
      stats.diamonds += ev.gift.coins;
      const key = ev.user.id || ev.user.uniqueId || ev.user.nickname;
      const g = (stats.gifters[key] ||= { ...ev.user, coins: 0 });
      g.coins += ev.gift.coins;
      g.avatar = ev.user.avatar || g.avatar;
      break;
    }
    case 'like':
      // TikTok reports the room's running total; count from when we connected so
      // like goals start at 0 (and we don't miss likes TikTok batches together).
      if (ev.totalLikes && stats.likeBaseline === undefined) stats.likeBaseline = ev.totalLikes - stats.likes - ev.likes;
      stats.likes = Math.max(stats.likes + ev.likes, ev.totalLikes ? ev.totalLikes - stats.likeBaseline : 0);
      ev.totalLikes = stats.likes;
      break;
    case 'follow':
      stats.follows++;
      break;
    case 'share':
      stats.shares++;
      break;
    case 'join':
      stats.joins++;
      break;
  }

  // likes and joins are high-volume: keep them out of the feed history to save memory
  if (ev.type !== 'like' && ev.type !== 'join') pushFeed(ev);
  else io.emit('event', ev);

  emitStatsSoon();
  runRules(ev);
  maybeTts(ev);
}

function fill(template, ev) {
  if (!template) return '';
  const map = {
    user: ev.user?.nickname || 'Someone',
    username: ev.user?.uniqueId || ev.user?.nickname || '',
    gift: ev.gift?.name || '',
    count: ev.gift?.count ?? '',
    coins: ev.gift?.coins ?? '',
    comment: ev.comment || '',
    args: ev.args || '',
    likes: ev.likes ?? '',
    totalLikes: stats.likes,
    viewers: stats.viewers,
  };
  return template.replace(/\{(\w+)\}/g, (m, k) => (k in map ? String(map[k]) : m));
}

function ruleMatches(rule, ev) {
  const t = rule.trigger;
  switch (t.type) {
    case 'gift': {
      if (ev.type !== 'gift') return false;
      if (t.giftName && t.giftName.trim().toLowerCase() !== ev.gift.name.toLowerCase()) return false;
      // Game actions repeat once per gift in a combo, so they compare the price
      // of ONE gift; screen alerts compare the combo's total.
      const coins = rule.mc || rule.keys ? ev.gift.coinsEach ?? ev.gift.coins : ev.gift.coins;
      if (t.minCoins && coins < t.minCoins) return false;
      if (t.maxCoins && coins > t.maxCoins) return false;
      return true;
    }
    case 'follow':
    case 'share':
    case 'join':
      return ev.type === t.type;
    case 'command': {
      if (ev.type !== 'chat' || !t.command) return false;
      const text = ev.comment.trim().toLowerCase();
      const cmd = t.command.trim().toLowerCase();
      if (text === cmd || text.startsWith(cmd + ' ')) {
        ev.args = ev.comment.trim().slice(cmd.length).trim();
        return true;
      }
      return false;
    }
    case 'keyword':
      return ev.type === 'chat' && !!t.command && ev.comment.toLowerCase().includes(t.command.toLowerCase());
    case 'likes': {
      if (ev.type !== 'like') return false;
      const rt = runtimeFor(rule.id);
      const bucket = Math.floor(stats.likes / t.every);
      if (rt.likeBucket === undefined) rt.likeBucket = Math.floor((stats.likes - ev.likes) / t.every);
      if (bucket > rt.likeBucket) {
        rt.likeBucket = bucket;
        return true;
      }
      return false;
    }
    default:
      return false;
  }
}

function runtimeFor(id) {
  if (!ruleRuntime.has(id)) ruleRuntime.set(id, {});
  return ruleRuntime.get(id);
}

function fireRule(rule, ev) {
  const action = {
    id: crypto.randomUUID(),
    ruleId: rule.id,
    ruleName: rule.name,
    eventType: ev.type,
    user: ev.user,
    image: ev.gift?.image || ev.user?.avatar || '',
    alert: rule.alert.show ? { text: fill(rule.alert.text, ev), duration: rule.alert.duration } : null,
    sound: rule.sound || '',
    speak: fill(rule.speak, ev),
    // one action per gift in a combo (capped) so "5x Rose" spawns 5 mobs
    repeat: ev.type === 'gift' ? Math.min(Math.max(1, ev.gift?.count || 1), 20) : 1,
    mc: rule.mc
      ? rule.mc
          .split('\n')
          .map((l) => fillGame(l.trim(), ev))
          .filter((l) => l && !l.startsWith('#'))
          .map((l) => l.replace(/^\//, ''))
      : [],
  };
  io.emit('action', action);
  if (rule.keys) pressKeys(rule.keys, action.repeat);
}

// Placeholders inside game commands: user names are reduced to safe
// characters so a viewer's nickname can never break or inject a command.
const safeName = (s) => String(s || '').replace(/[^\p{L}\p{N} _.\-]/gu, '').trim().slice(0, 16) || 'viewer';
function fillGame(template, ev) {
  return fill(template, {
    ...ev,
    comment: '',
    args: '',
    user: { ...ev.user, nickname: safeName(ev.user?.nickname), uniqueId: safeName(ev.user?.uniqueId) },
    gift: ev.gift && { ...ev.gift, name: safeName(ev.gift.name) },
  });
}

// ------------------------------------------------- key presses (any game) --
// Works when the server runs next to a game on a (virtual) screen, e.g. in the
// streamer container: "space", "Left", "ctrl+r", "w w w"... uses xdotool.
const HAS_XDOTOOL = Boolean(process.env.DISPLAY) && spawnSync('sh', ['-c', 'command -v xdotool']).status === 0;
const keyQueue = [];
let keyBusy = false;
function pressKeys(spec, times = 1) {
  if (!HAS_XDOTOOL) return;
  const keys = String(spec)
    .split(/\s+/)
    .filter((k) => /^[A-Za-z0-9_+]{1,24}$/.test(k))
    .slice(0, 20);
  if (!keys.length) return;
  for (let i = 0; i < times && keyQueue.length < 200; i++) keyQueue.push(keys);
  drainKeys();
}
function drainKeys() {
  if (keyBusy || !keyQueue.length) return;
  keyBusy = true;
  const keys = keyQueue.shift();
  const p = spawn('xdotool', ['key', '--delay', '60', ...keys], { stdio: 'ignore' });
  p.on('error', () => {});
  p.on('exit', () => setTimeout(() => ((keyBusy = false), drainKeys()), 80));
}

function runRules(ev) {
  // For "gift" rules only the most specific matching rule fires (highest
  // minCoins, then named gift), so a 100-coin gift doesn't trigger both the
  // "any gift" and the "big gift" alert.
  const matching = settings.rules.filter((r) => r.enabled && ruleMatches(r, ev));
  if (!matching.length) return;
  // Picked separately for game rules (Minecraft / keys) and screen-alert
  // rules, so a gift can both show an alert and do something in the game.
  const giftRules = matching.filter((r) => r.trigger.type === 'gift');
  const others = matching.filter((r) => r.trigger.type !== 'gift');
  const isGame = (r) => Boolean(r.mc || r.keys);
  for (const group of [giftRules.filter(isGame), giftRules.filter((r) => !isGame(r))]) {
    if (!group.length) continue;
    group.sort((a, b) => (b.trigger.giftName ? 1 : 0) - (a.trigger.giftName ? 1 : 0) || b.trigger.minCoins - a.trigger.minCoins);
    others.unshift(group[0]);
  }
  const now = Date.now();
  for (const rule of others) {
    const rt = runtimeFor(rule.id);
    if (rule.cooldown && rt.lastFired && now - rt.lastFired < rule.cooldown * 1000) continue;
    rt.lastFired = now;
    fireRule(rule, ev);
  }
}

function cleanForSpeech(text) {
  let t = String(text || '');
  if (settings.tts.skipLinks) t = t.replace(/https?:\/\/\S+/gi, 'link');
  const banned = settings.tts.bannedWords
    .split(',')
    .map((w) => w.trim().toLowerCase())
    .filter(Boolean);
  if (banned.some((w) => t.toLowerCase().includes(w))) return '';
  return t.slice(0, settings.tts.maxLength);
}

function maybeTts(ev) {
  const tts = settings.tts;
  let text = '';
  if (ev.type === 'chat' && tts.mode !== 'off') {
    if (tts.mode === 'all') {
      // don't read commands that a rule already handles
      if (!ev.comment.trim().startsWith('!')) text = `${ev.user.nickname} says ${ev.comment}`;
    } else if (tts.mode === 'command' && tts.command) {
      const cmd = tts.command.trim().toLowerCase();
      const c = ev.comment.trim();
      if (c.toLowerCase().startsWith(cmd + ' ')) text = `${ev.user.nickname} says ${c.slice(cmd.length).trim()}`;
    }
  } else if (ev.type === 'gift' && tts.readGifts) {
    text = `${ev.user.nickname} sent ${ev.gift.count} ${ev.gift.name}`;
  }
  text = cleanForSpeech(text);
  if (text) io.emit('tts', { id: crypto.randomUUID(), text });
}

// ------------------------------------------------------------ TikTok link --

function clearRetry() {
  if (retryTimer) clearTimeout(retryTimer);
  retryTimer = null;
}

function scheduleRetry(ms, why) {
  clearRetry();
  if (!wantConnected) return;
  setStatus(status.state === 'offline' ? 'offline' : 'reconnecting', `${why} Retrying in ${Math.round(ms / 1000)}s.`);
  retryTimer = setTimeout(connectTikTok, ms);
}

async function teardown() {
  const c = connection;
  connection = null;
  if (c) {
    c.removeAllListeners();
    c.on('error', () => {}); // swallow late errors
    try {
      await c.disconnect();
    } catch {}
  }
}

async function connectTikTok() {
  clearRetry();
  if (!settings.username) {
    setStatus('idle', 'Set your TikTok username first.');
    return;
  }
  await teardown();
  wantConnected = true;
  setStatus('connecting', `Connecting to @${settings.username}…`);

  const c = new TikTokLiveConnection(settings.username, {
    signApiKey: process.env.SIGN_API_KEY || undefined,
    processInitialData: false,
    enableExtendedGiftInfo: false,
  });
  connection = c;
  wire(c);

  try {
    const state = await c.connect();
    if (connection !== c) return;
    retryDelay = 5_000;
    if (state.roomId !== lastRoomId) {
      // new stream => fresh leaderboard / counters
      stats = freshStats();
      ruleRuntime.clear();
      lastRoomId = state.roomId;
      io.emit('stats', publicStats());
    }
    status.roomId = state.roomId;
    setStatus('live', `Connected to @${settings.username}'s LIVE.`);
  } catch (err) {
    if (connection !== c) return;
    const msg = err?.message || String(err);
    const offline = err?.constructor?.name === 'UserOfflineError' || /offline|isn't online|not live|status.*4/i.test(msg);
    await teardown();
    if (offline) {
      status.state = 'offline';
      scheduleRetry(OFFLINE_RETRY_MS, `@${settings.username} is not live right now.`);
    } else {
      scheduleRetry(retryDelay, `Connection failed: ${msg}.`);
      retryDelay = Math.min(retryDelay * 2, 5 * 60_000);
    }
  }
}

function wire(c) {
  const on = (event, fn) =>
    c.on(event, (data) => {
      if (connection !== c) return;
      try {
        fn(data || {});
      } catch (err) {
        console.error(`[${event}] handler error:`, err);
      }
    });

  on(WebcastEvent.CHAT, (d) => {
    const comment = String(d.comment ?? d.content ?? '').trim();
    if (comment) handleEvent({ type: 'chat', user: normUser(d.user), comment });
  });

  on(WebcastEvent.GIFT, (d) => {
    const gift = normGift(d);
    const user = normUser(d.user);
    // Streakable gifts (type 1) fire repeatedly while the streak runs; only the
    // final event (repeatEnd) carries the real count.
    if (gift.type === 1 && !d.repeatEnd) {
      io.emit('event', { type: 'giftStreak', user, gift, ts: Date.now(), id: `streak-${user.id}-${gift.id}` });
      return;
    }
    handleEvent({ type: 'gift', user, gift });
  });

  on(WebcastEvent.LIKE, (d) => {
    const likes = Number(d.likeCount ?? d.count) || 1;
    const totalLikes = Number(d.totalLikeCount ?? d.total) || 0;
    handleEvent({ type: 'like', user: normUser(d.user), likes, totalLikes });
  });

  on(WebcastEvent.FOLLOW, (d) => handleEvent({ type: 'follow', user: normUser(d.user) }));
  on(WebcastEvent.SHARE, (d) => handleEvent({ type: 'share', user: normUser(d.user) }));
  on(WebcastEvent.MEMBER, (d) => handleEvent({ type: 'join', user: normUser(d.user) }));

  on(WebcastEvent.ROOM_USER, (d) => {
    const v = Number(d.viewerCount ?? d.total ?? d.totalUser) || 0;
    if (v) {
      stats.viewers = v;
      emitStatsSoon();
    }
  });

  on(WebcastEvent.STREAM_END, () => {
    status.state = 'offline';
    scheduleRetry(OFFLINE_RETRY_MS, 'Stream ended.');
  });

  on(ControlEvent.DISCONNECTED, (d) => {
    if (!wantConnected || status.state === 'offline') return;
    scheduleRetry(retryDelay, `Disconnected${d?.reason ? ` (${d.reason})` : ''}.`);
  });

  on(ControlEvent.ERROR, (e) => {
    console.warn('[tiktok] error:', e?.info || '', e?.exception?.message || e?.exception || '');
  });
}

async function disconnectTikTok() {
  wantConnected = false;
  clearRetry();
  await teardown();
  setStatus('idle', 'Disconnected.');
}

// ------------------------------------------------------------- simulation --

const SAMPLE_GIFTS = [
  { name: 'Rose', coinsEach: 1, type: 1 },
  { name: 'TikTok', coinsEach: 1, type: 1 },
  { name: 'Finger Heart', coinsEach: 5, type: 1 },
  { name: 'Doughnut', coinsEach: 30, type: 1 },
  { name: 'Hand Hearts', coinsEach: 100, type: 0 },
  { name: 'Galaxy', coinsEach: 1000, type: 0 },
];
const SAMPLE_NAMES = ['Mia', 'Leo', 'Zara', 'Omar', 'Kai', 'Noor', 'Ivy', 'Sam'];

function fakeUser(name) {
  const n = name || SAMPLE_NAMES[Math.floor(Math.random() * SAMPLE_NAMES.length)];
  return { id: 'test-' + n.toLowerCase(), uniqueId: n.toLowerCase() + '_test', nickname: n, avatar: '' };
}

function simulate(p = {}) {
  const user = fakeUser(p.user);
  switch (p.type) {
    case 'gift': {
      const base = SAMPLE_GIFTS.find((g) => g.name.toLowerCase() === String(p.giftName || '').toLowerCase()) || SAMPLE_GIFTS[Math.floor(Math.random() * SAMPLE_GIFTS.length)];
      const count = Math.max(1, Number(p.count) || 1);
      const coinsEach = Number(p.coins) || base.coinsEach;
      handleEvent({ type: 'gift', user, gift: { id: 'test', name: p.giftName || base.name, image: '', type: base.type, count, coinsEach, coins: coinsEach * count }, test: true });
      break;
    }
    case 'chat':
      handleEvent({ type: 'chat', user, comment: String(p.comment || 'Hello from the test button!'), test: true });
      break;
    case 'like':
      handleEvent({ type: 'like', user, likes: Number(p.likes) || 50, totalLikes: 0, test: true });
      break;
    case 'follow':
    case 'share':
    case 'join':
      handleEvent({ type: p.type, user, test: true });
      break;
  }
}

// --------------------------------------------------------- cloud stream --
// The RTMP stream key lives in its own file (never in settings, never sent
// back to browsers) so stream.sh can pick it up and switch without a restart.
function readStream() {
  try {
    return JSON.parse(fs.readFileSync(STREAM_FILE, 'utf8'));
  } catch {
    return {};
  }
}
function streamInfo() {
  const s = readStream();
  return { url: s.url || '', keyHint: s.key ? '••••' + String(s.key).slice(-4) : '', configured: Boolean(s.url && s.key) };
}
function writeStream({ url, key } = {}) {
  url = String(url || '').trim();
  key = String(key || '').trim();
  if (url && !/^rtmps?:\/\//i.test(url)) throw new Error('Server URL must start with rtmp:// or rtmps://');
  const cur = readStream();
  const next = { url, key: key || (url ? cur.key || '' : '') };
  fs.mkdirSync(DATA_DIR, { recursive: true });
  fs.writeFileSync(STREAM_FILE, JSON.stringify(next), { mode: 0o600 });
  return streamInfo();
}

// ------------------------------------------------------------------ socket --

io.on('connection', (socket) => {
  let isAdmin = !ADMIN_KEY;

  socket.on('auth', (key, ack) => {
    if (typeof ack !== 'function') return;
    isAdmin = !ADMIN_KEY || (typeof key === 'string' && key.length === ADMIN_KEY.length && crypto.timingSafeEqual(Buffer.from(key), Buffer.from(ADMIN_KEY)));
    ack?.({ ok: isAdmin, keyRequired: Boolean(ADMIN_KEY) });
  });

  socket.on('getState', (ack) =>
    typeof ack === 'function' &&
    ack({
      status,
      stats: publicStats(),
      feed: feed.slice(-60),
      // overlays get only what they need; the dashboard gets everything
      settings: isAdmin ? settings : { goal: settings.goal, game: settings.game },
      settingsFromDisk,
      mc: mcStatus,
      legend: gameLegend(),
      keysAvailable: HAS_XDOTOOL,
      stream: isAdmin ? streamInfo() : undefined,
      admin: isAdmin,
      keyRequired: Boolean(ADMIN_KEY),
    }),
  );

  const admin = (event, fn) =>
    socket.on(event, async (...args) => {
      const ack = typeof args.at(-1) === 'function' ? args.pop() : () => {};
      const payload = args[0];
      if (!isAdmin) return ack({ ok: false, error: 'Not authorised — enter your admin key.' });
      try {
        const result = await fn(payload);
        ack({ ok: true, ...(result || {}) });
      } catch (err) {
        ack({ ok: false, error: err?.message || String(err) });
      }
    });

  admin('saveSettings', (s) => {
    const prevUser = settings.username;
    settings = sanitizeSettings(s);
    saveSettings();
    ruleRuntime.clear();
    socket.broadcast.emit('settings', settings); // other open dashboards
    io.emit('goal', settings.goal);
    io.emit('game', settings.game);
    io.emit('legend', gameLegend());
    if (settings.username !== prevUser && wantConnected) connectTikTok();
    return { settings };
  });

  admin('tiktokConnect', (username) => {
    if (typeof username === 'string' && username.trim()) {
      settings = sanitizeSettings({ ...settings, username });
      saveSettings();
      io.emit('settings', settings);
    }
    connectTikTok();
  });

  admin('tiktokDisconnect', () => disconnectTikTok());
  admin('simulate', (p) => simulate(p));
  admin('testRule', (id) => {
    const rule = settings.rules.find((r) => r.id === id);
    if (!rule) throw new Error('Rule not found');
    const user = fakeUser();
    const ev = { type: rule.trigger.type, user, comment: rule.trigger.command || 'test', likes: rule.trigger.every || 100, gift: { name: rule.trigger.giftName || 'Rose', count: 1, coins: rule.trigger.minCoins || 1, image: '' } };
    fireRule(rule, ev);
  });
  admin('speak', (text) => {
    const t = cleanForSpeech(text);
    if (t) io.emit('tts', { id: crypto.randomUUID(), text: t });
  });
  admin('skipAlert', () => io.emit('control', { cmd: 'skip' }));
  admin('gameReset', () => io.emit('control', { cmd: 'gameReset' }));
  admin('setStream', (p) => ({ stream: writeStream(p) }));
  // Minecraft: manual command from the dashboard, and live status from the bridge
  admin('addMinecraftPreset', () => {
    applyMinecraftPreset();
    return { settings };
  });
  admin('mcRun', (cmd) => {
    const line = String(cmd || '').trim().replace(/^\//, '').slice(0, 500);
    if (!line || /[\r\n]/.test(line)) throw new Error('Enter one command');
    io.emit('mcRun', { cmd: line });
  });
  admin('mcStatus', (st) => {
    mcStatus = { ...st, ts: Date.now() };
    // hands-free: the first time a hero joins, switch on the Minecraft actions
    if (st?.online && !settings.mcPresetApplied) {
      if (!settings.rules.some((r) => r.mc)) applyMinecraftPreset();
      else ((settings.mcPresetApplied = true), saveSettings());
    }
    io.emit('mcStatus', mcStatus);
  });
  admin('resetStats', () => {
    stats = freshStats();
    feed = [];
    ruleRuntime.clear();
    io.emit('stats', publicStats());
    io.emit('feedReset');
  });
});

// ------------------------------------------------------------------- boot --

server.listen(PORT, () => {
  console.log(`TikTok LIVE Tools running on http://localhost:${PORT}`);
  if (ADMIN_KEY) console.log('Dashboard is protected by ADMIN_KEY.');
  else console.log('Tip: set ADMIN_KEY so nobody else can control your dashboard.');
  if (settings.autoConnect && settings.username) connectTikTok();
});

for (const sig of ['SIGINT', 'SIGTERM']) {
  process.on(sig, async () => {
    await teardown();
    process.exit(0);
  });
}
