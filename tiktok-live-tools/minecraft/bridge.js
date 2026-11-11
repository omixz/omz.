// Minecraft bridge for TikTok LIVE Tools.
//
//  - Runs "Steve", a bot player on a real Minecraft server, in a survival
//    challenge: viewers' likes and gifts spawn mobs (named after them) and Steve
//    fights them off on his own. The longer he survives the more he levels up
//    (better gear). When he falls, the round goes to the viewer whose mob won it
//    (read from Minecraft's own message), and he respawns for the next round.
//  - Serves a live first-person 3D camera (prismarine-viewer), which the
//    /minecraft page shows and the streamer sends to TikTok.
//  - Executes the Minecraft commands from your Actions (gifts, likes, follows,
//    chat commands) through RCON.
//  - Keeps the arena tidy so it can run unattended for days.
import mineflayer from 'mineflayer';
import pathfinderPkg from 'mineflayer-pathfinder';
import pvpPkg from 'mineflayer-pvp';
import armorManager from 'mineflayer-armor-manager';
import viewerPkg from 'prismarine-viewer';
import { Rcon } from 'rcon-client';
import { io } from 'socket.io-client';
import fs from 'node:fs';
import path from 'node:path';

const { pathfinder, Movements, goals } = pathfinderPkg;
const { plugin: pvp } = pvpPkg;
const { mineflayer: startViewer } = viewerPkg;

const env = (k, d) => process.env[k] ?? d;
const CFG = {
  host: env('MC_HOST', 'localhost'),
  port: Number(env('MC_PORT', 25565)),
  version: env('MC_VERSION', '1.21.4'),
  bot: env('MC_BOT_NAME', 'Steve'),
  firstPerson: env('MC_FIRST_PERSON', '1') !== '0', // camera through Steve's eyes
  // what Steve gets every time he (re)spawns, comma separated
  kit: env('MC_RESPAWN_KIT', 'iron_sword, iron_helmet, iron_chestplate, iron_leggings, iron_boots, cooked_beef 16'),
  levelUpSeconds: Number(env('MC_LEVEL_UP_SECONDS', 150)), // Steve upgrades his gear every N seconds he survives (0 = off)
  dataFile: path.join(env('DATA_DIR', path.join(process.cwd(), '..', 'data')), 'minecraft-scores.json'),
  rconHost: env('RCON_HOST', env('MC_HOST', 'localhost')),
  rconPort: Number(env('RCON_PORT', 25575)),
  rconPassword: env('RCON_PASSWORD', ''),
  viewPort: Number(env('MC_VIEW_PORT', 3007)),
  viewDistance: Number(env('MC_VIEW_DISTANCE', 4)),
  appUrl: env('APP_URL', `http://localhost:${env('PORT', 3000)}`),
  adminKey: env('ADMIN_KEY', ''),
  arena: Number(env('MC_ARENA_RADIUS', 24)), // the hero stays near 0,0
  idleMobSeconds: Number(env('MC_IDLE_MOB_SECONDS', 25)), // keep the stream lively when quiet (0 = off)
  setup: env('MC_SETUP', '1') !== '0', // apply the arena game rules on start
};
const log = (...a) => console.log('[minecraft]', ...a);

// ------------------------------------------------------------------ RCON --
// One persistent connection, a queue and a gentle rate limit, so a gift combo
// of 50 roses can't flood the server.
const rcon = {
  conn: null,
  connecting: null,
  queue: [],
  running: false,
  async get() {
    if (this.conn) return this.conn;
    if (!CFG.rconPassword) throw new Error('RCON_PASSWORD is not set');
    this.connecting ||= Rcon.connect({ host: CFG.rconHost, port: CFG.rconPort, password: CFG.rconPassword, timeout: 5000 })
      .then((c) => {
        this.conn = c;
        c.on('end', () => (this.conn = null));
        c.on('error', () => (this.conn = null));
        log('RCON connected');
        return c;
      })
      .finally(() => (this.connecting = null));
    return this.connecting;
  },
  run(cmd) {
    if (this.queue.length > 400) this.queue.shift();
    this.queue.push(cmd);
    this.pump();
  },
  async pump() {
    if (this.running) return;
    this.running = true;
    while (this.queue.length) {
      const cmd = this.queue.shift();
      try {
        const c = await this.get();
        const out = await c.send(cmd);
        if (out && /unknown|incorrect|expected|error/i.test(out)) log(`command problem: ${cmd} -> ${out.slice(0, 160)}`);
      } catch (err) {
        log('RCON failed:', err.message, '- retrying in 5s');
        this.conn = null;
        this.queue.unshift(cmd);
        await sleep(5000);
      }
      await sleep(40); // ~25 commands per second max
    }
    this.running = false;
  },
};
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const rand = (a, b) => Math.round(a + Math.random() * (b - a));
const randOffset = () => (Math.random() < 0.5 ? -1 : 1) * rand(3, 7);

// {bot}, {rx}, {rz} (random offset 3–7 blocks), {ry} (random 0–2)
const expand = (cmd) =>
  cmd.replaceAll('{bot}', CFG.bot).replace(/\{rx\}/g, () => randOffset()).replace(/\{rz\}/g, () => randOffset()).replace(/\{ry\}/g, () => rand(0, 2));

function setupArena() {
  if (!CFG.setup) return;
  const r = CFG.arena + 8;
  [
    'gamerule doDaylightCycle false',
    'time set 6000',
    'gamerule doWeatherCycle false',
    'weather clear',
    'gamerule doMobSpawning false', // only viewers spawn mobs
    'gamerule mobGriefing false', // creepers don't wreck the arena
    'gamerule keepInventory false', // Steve starts fresh with his kit after each death
    'gamerule doImmediateRespawn true',
    'gamerule announceAdvancements false',
    'gamerule showDeathMessages true',
    'difficulty normal',
    'setworldspawn 0 -60 0',
    `worldborder center 0 0`,
    `worldborder set ${r * 2}`,
    `gamemode survival ${CFG.bot}`,
  ].forEach((c) => rcon.run(c));
}

// Repairs TNT holes and clears clutter so the arena survives days of gifts.
// Too many mobs make the server (and the stream) lag: remove the furthest ones.
const MOB_CAP = Number(env('MC_MOB_CAP', 60));
setInterval(() => {
  if (stats.hostiles > MOB_CAP) rcon.run(`kill @e[type=!minecraft:player,type=!minecraft:item,limit=${stats.hostiles - MOB_CAP},sort=furthest]`);
}, 5000);

function maintainArena() {
  const r = CFG.arena + 6;
  rcon.run(`fill -${r} -63 -${r} ${r} -62 ${r} minecraft:dirt replace minecraft:air`);
  rcon.run(`fill -${r} -61 -${r} ${r} -61 ${r} minecraft:grass_block replace minecraft:air`);
  rcon.run('kill @e[type=minecraft:item]');
  rcon.run('kill @e[type=minecraft:experience_orb]');
}

// ------------------------------------------------------------------- bot --
// Internally "deaths" = rounds Steve lost; "killers" = viewers who won a round.
const stats = { online: false, health: 20, food: 20, deaths: 0, kills: 0, aliveSince: Date.now(), best: 0, hostiles: 0, lastKiller: '', lastDeathAt: 0, level: 1, levelUpAt: 0 };
const killers = new Map(); // viewer name -> rounds won (saved, so the leaderboard survives restarts)

// ---- scores survive restarts (24/7 streams) ----
try {
  const saved = JSON.parse(fs.readFileSync(CFG.dataFile, 'utf8'));
  stats.deaths = saved.rounds || 0;
  stats.best = saved.best || 0;
  stats.kills = saved.mobs || 0;
  for (const [n, k] of saved.winners || []) killers.set(n, k);
} catch {}
const saveScores = debounce(() => {
  try {
    fs.mkdirSync(path.dirname(CFG.dataFile), { recursive: true });
    fs.writeFileSync(CFG.dataFile, JSON.stringify({ rounds: stats.deaths, best: stats.best, mobs: stats.kills, winners: [...killers].sort((a, b) => b[1] - a[1]).slice(0, 200) }));
  } catch (e) {
    log('could not save scores:', e.message);
  }
}, 2000);

// ---- levels: the longer Steve survives, the better his gear ----
const LEVELS = [
  null,
  { name: 'Iron', give: [] }, // level 1 = the respawn kit
  { name: 'Diamond sword', give: ['diamond_sword', 'golden_apple 1'] },
  { name: 'Diamond armor', give: ['diamond_helmet', 'diamond_chestplate'] },
  { name: 'Full diamond', give: ['diamond_leggings', 'diamond_boots', 'golden_apple 2'] },
  { name: 'Netherite', give: ['netherite_sword', 'netherite_chestplate', 'golden_apple 2'], effect: 'resistance 30 0' },
];
function levelUp() {
  if (stats.level >= LEVELS.length - 1) return;
  stats.level++;
  stats.levelUpAt = Date.now();
  const L = LEVELS[stats.level];
  for (const item of L.give) {
    const [name, n] = item.split(/\s+/);
    rcon.run(`give ${CFG.bot} minecraft:${name} ${Number(n) || 1}`);
  }
  if (L.effect) rcon.run(`effect give ${CFG.bot} minecraft:${L.effect}`);
  log(`Steve reached level ${stats.level} (${L.name})`);
}
let lastAttacker = { name: '', at: 0 }; // fallback credit (TNT, lightning…)

// "Steve was slain by Mia" / "Steve was blown up by Omar" / "...whilst fighting Kai"
function killerFromDeathMessage(msg) {
  const m = msg.match(/(?:whilst fighting|to escape)\s+(.+?)(?:\s+using\s+.+)?$/) || msg.match(/\bby\s+(.+?)(?:\s+using\s+.+)?$/);
  const k = m ? m[1].trim() : '';
  return /^(lightning|magic|Block of TNT|Primed TNT|TNT)$/i.test(k) ? '' : k.slice(0, 32);
}

function giveKit() {
  rcon.run(`clear ${CFG.bot}`);
  for (const item of CFG.kit.split(',').map((x) => x.trim()).filter(Boolean)) {
    const [name, n] = item.split(/\s+/);
    if (/^[a-z0-9_:]+$/.test(name)) rcon.run(`give ${CFG.bot} ${name.includes(':') ? name : 'minecraft:' + name} ${Number(n) || 1}`);
  }
  rcon.run(`effect clear ${CFG.bot}`);
}
let bot = null;
let reconnectTimer = null;
let lastViewerBot = null;

const isHostile = (e) => e && e !== bot?.entity && (e.type === 'hostile' || e.kind === 'Hostile mobs');

function createBot() {
  clearTimeout(reconnectTimer);
  log(`joining ${CFG.host}:${CFG.port} as ${CFG.bot} (Minecraft ${CFG.version})`);
  const b = mineflayer.createBot({ host: CFG.host, port: CFG.port, username: CFG.bot, version: CFG.version, auth: 'offline', hideErrors: true });
  bot = b;
  b.loadPlugin(pathfinder);
  b.loadPlugin(pvp);
  b.loadPlugin(armorManager);

  b.once('spawn', () => {
    log(`${CFG.bot} spawned`);
    stats.level = 1;
    stats.online = true;
    stats.aliveSince = Date.now();
    const moves = new Movements(b);
    moves.canDig = false;
    moves.allow1by1towers = false;
    b.pathfinder.setMovements(moves);
    b.pvp.movements = moves;
    if (lastViewerBot?.viewer?.close) {
      try {
        lastViewerBot.viewer.close();
      } catch {}
    }
    startViewer(b, { port: CFG.viewPort, prefix: '/cam', firstPerson: CFG.firstPerson, viewDistance: CFG.viewDistance }); // the app serves it at /cam/
    lastViewerBot = b;
    log(`${CFG.firstPerson ? 'first-person ' : ''}camera on http://localhost:${CFG.viewPort}/cam/ (shown by the app at /cam/)`);
    setupArena();
    giveKit();
    setTimeout(gearUp, 1500);
    // re-check weapon/armor whenever the inventory changes (gifts arrive via /give)
    b.inventory.on('updateSlot', debounce(gearUp, 400));
  });

  b.on('respawn', () => {
    stats.aliveSince = Date.now();
    stats.level = 1;
    // fresh round: clear the mobs left over from the last one
    rcon.run('kill @e[type=!minecraft:player]');
    giveKit();
    setTimeout(gearUp, 1000);
  });
  let deathMsg = '';
  let deathMsgAt = 0;
  b.on('messagestr', (msg) => {
    if (msg.startsWith(CFG.bot + ' ') && !msg.includes('<')) ((deathMsg = msg), (deathMsgAt = Date.now())); // system death message
  });
  b.on('death', () => {
    stats.deaths++;
    stats.level = 1;
    stats.best = Math.max(stats.best, Date.now() - stats.aliveSince);
    b.pvp.stop();
    // the death message usually arrives a moment after the death event
    setTimeout(() => {
      let killer = deathMsg && Date.now() - deathMsgAt < 3000 ? killerFromDeathMessage(deathMsg) : '';
      if (!killer && Date.now() - lastAttacker.at < 20_000) killer = lastAttacker.name;
      if (/^(Zombie|Skeleton|Creeper|Witch|Ravager|Vindicator|Block of TNT)$/i.test(killer) && Date.now() - lastAttacker.at < 20_000) killer = lastAttacker.name;
      stats.lastKiller = killer || 'the arena';
      stats.lastDeathAt = Date.now();
      if (killer) killers.set(killer, (killers.get(killer) || 0) + 1);
      saveScores();
      log(`round ${stats.deaths} over: ${deathMsg || 'no message'} -> won by ${stats.lastKiller}`);
      deathMsg = '';
      pushStatus();
    }, 600);
  });
  b.on('entityDead', (e) => {
    if (isHostile(e) && b.entity && e.position.distanceTo(b.entity.position) < 6) ((stats.kills++), saveScores());
  });
  b.on('health', () => {
    stats.health = b.health;
    stats.food = b.food;
  });
  b.on('kicked', (reason) => log('kicked:', typeof reason === 'string' ? reason : JSON.stringify(reason).slice(0, 200)));
  b.on('error', (err) => log('error:', err.message));
  b.on('end', (reason) => {
    stats.online = false;
    log(`disconnected (${reason}); reconnecting in 10s`);
    pushStatus();
    if (bot === b) reconnectTimer = setTimeout(createBot, 10_000);
  });
}

function debounce(fn, ms) {
  let t;
  return (...a) => {
    clearTimeout(t);
    t = setTimeout(() => fn(...a), ms);
  };
}

const WEAPONS = ['netherite_sword', 'diamond_sword', 'iron_sword', 'stone_sword', 'golden_sword', 'wooden_sword', 'netherite_axe', 'diamond_axe', 'iron_axe'];
async function gearUp() {
  const b = bot;
  if (!b?.entity || b.health <= 0) return;
  try {
    await b.armorManager.equipAll();
  } catch {}
  const weapon = WEAPONS.map((n) => b.inventory.items().find((i) => i.name === n)).find(Boolean);
  if (weapon && b.heldItem?.name !== weapon.name) {
    try {
      await b.equip(weapon, 'hand');
    } catch {}
  }
}

const FOODS = ['enchanted_golden_apple', 'golden_apple', 'cooked_beef', 'cooked_porkchop', 'golden_carrot', 'bread', 'cooked_chicken', 'baked_potato', 'apple', 'carrot'];
let eating = false;
async function maybeEat() {
  const b = bot;
  if (eating || !b?.entity) return;
  const hungry = b.food < 18 || (b.health < 12 && b.food < 20);
  if (!hungry) return;
  const food = FOODS.map((n) => b.inventory.items().find((i) => i.name === n)).find(Boolean);
  if (!food) return;
  eating = true;
  try {
    await b.equip(food, 'off-hand').catch(() => b.equip(food, 'hand'));
    await b.consume();
  } catch {}
  eating = false;
  gearUp();
}

// The hero's brain, a few times a second: fight the nearest monster, eat when
// hurt, otherwise walk back to the middle of the arena.
let lastHostileSeen = Date.now();
setInterval(() => {
  const b = bot;
  if (!b?.entity || b.health <= 0 || !b.pvp) return;
  const me = b.entity.position;
  let hostiles = 0;
  let target = null;
  let best = Infinity;
  for (const e of Object.values(b.entities)) {
    if (!isHostile(e)) continue;
    const d = e.position.distanceTo(me);
    if (d < 40) hostiles++;
    if (d < 24 && d < best) {
      best = d;
      target = e;
    }
  }
  stats.hostiles = hostiles;
  if (hostiles) lastHostileSeen = Date.now();
  if (b.health < 8) maybeEat();
  // level up while surviving
  const aliveFor = Date.now() - stats.aliveSince;
  if (CFG.levelUpSeconds && aliveFor > stats.level * CFG.levelUpSeconds * 1000) levelUp();
  // badly hurt and nothing to eat: back off from the nearest mob for a moment to regenerate
  const hasFood = FOODS.some((n) => b.inventory.items().some((i) => i.name === n));
  if (target && b.health <= 5 && !hasFood && best < 6) {
    if (b.pvp.target) b.pvp.stop();
    const away = me.minus(target.position).normalize().scaled(8).plus(me);
    b.pathfinder.setGoal(new goals.GoalNear(away.x, away.y, away.z, 1));
    b.setControlState('sprint', true);
    return;
  }
  b.setControlState('sprint', false);
  if (target) {
    if (b.pvp.target !== target) b.pvp.attack(target);
  } else {
    if (b.pvp.target) b.pvp.stop();
    maybeEat();
    // idle: stroll around the arena and look around, so the first-person view stays alive
    const fromCenter = Math.hypot(me.x, me.z);
    if (!b.pathfinder.isMoving()) {
      if (fromCenter > CFG.arena - 4 || Math.random() < 0.01) b.pathfinder.setGoal(new goals.GoalNear(rand(-8, 8), me.y, rand(-8, 8), 1));
      else b.look(b.entity.yaw + 0.015, 0, true).catch(() => {});
    }
  }
  // When nobody is interacting, a lone zombie wanders in so the stream never looks frozen.
  if (CFG.idleMobSeconds && !hostiles && Date.now() - lastHostileSeen > CFG.idleMobSeconds * 1000 && Date.now() - lastAction > CFG.idleMobSeconds * 1000) {
    lastHostileSeen = Date.now();
    rcon.run(expand(`execute at {bot} run summon minecraft:zombie ~{rx} ~1 ~{rz}`));
  }
}, 250);

setInterval(maintainArena, 60_000);

// --------------------------------------------------------- app connection --
let lastAction = 0;
const app = io(CFG.appUrl, { reconnection: true, reconnectionDelayMax: 10_000 });
app.on('connect', () => {
  log(`connected to LIVE Tools at ${CFG.appUrl}`);
  app.emit('auth', CFG.adminKey, (r) => r?.ok || log('warning: ADMIN_KEY does not match the app (status display will be off)'));
});
app.on('action', (a) => {
  if (!a?.mc?.length) return;
  lastAction = Date.now();
  if (a.user?.nickname) lastAttacker = { name: String(a.user.nickname).replace(/[^\p{L}\p{N} _.\-]/gu, '').trim().slice(0, 16), at: Date.now() };
  const times = Math.min(Math.max(1, a.repeat || 1), 20);
  for (let i = 0; i < times; i++) for (const cmd of a.mc) rcon.run(expand(cmd));
});
app.on('mcRun', ({ cmd } = {}) => cmd && rcon.run(expand(cmd)));

function pushStatus() {
  const alive = stats.online && bot?.health > 0 ? Date.now() - stats.aliveSince : 0;
  const top = [...killers].sort((a, b) => b[1] - a[1]).slice(0, 5).map(([name, kills]) => ({ name, kills }));
  app.emit('mcStatus', { ...stats, bot: CFG.bot, alive, best: Math.max(stats.best, alive), top }, () => {});
}
setInterval(pushStatus, 1000);

createBot();
process.on('unhandledRejection', (e) => log('unhandled:', e?.message || e));
for (const sig of ['SIGINT', 'SIGTERM']) process.on(sig, () => process.exit(0));
