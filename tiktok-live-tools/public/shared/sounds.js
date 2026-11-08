// Built-in alert sounds synthesised with the Web Audio API (no audio files to
// host), plus support for any custom sound URL (mp3/ogg/wav).
(function () {
  let ctx = null;
  const getCtx = () => {
    if (!ctx) ctx = new (window.AudioContext || window.webkitAudioContext)();
    if (ctx.state === 'suspended') ctx.resume();
    return ctx;
  };

  function tone(freq, start, dur, { type = 'sine', gain = 0.25, slide = 0 } = {}) {
    const c = getCtx();
    const t0 = c.currentTime + start;
    const osc = c.createOscillator();
    const g = c.createGain();
    osc.type = type;
    osc.frequency.setValueAtTime(freq, t0);
    if (slide) osc.frequency.exponentialRampToValueAtTime(freq * slide, t0 + dur);
    g.gain.setValueAtTime(0.0001, t0);
    g.gain.exponentialRampToValueAtTime(gain * Sounds.volume, t0 + 0.01);
    g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
    osc.connect(g).connect(c.destination);
    osc.start(t0);
    osc.stop(t0 + dur + 0.05);
  }

  const BUILT_IN = {
    coin: () => { tone(988, 0, 0.08, { type: 'square', gain: 0.12 }); tone(1319, 0.08, 0.35, { type: 'square', gain: 0.12 }); },
    chime: () => { [784, 988, 1175].forEach((f, i) => tone(f, i * 0.09, 0.6, { gain: 0.2 })); },
    pop: () => tone(400, 0, 0.12, { gain: 0.35, slide: 2.5 }),
    fanfare: () => {
      [[523, 0, 0.15], [659, 0.15, 0.15], [784, 0.3, 0.15], [1047, 0.45, 0.6]].forEach(([f, s, d]) => {
        tone(f, s, d, { type: 'sawtooth', gain: 0.1 });
        tone(f * 2, s, d, { type: 'triangle', gain: 0.06 });
      });
    },
    airhorn: () => { for (let i = 0; i < 3; i++) { tone(440, i * 0.22, 0.18, { type: 'sawtooth', gain: 0.15 }); tone(554, i * 0.22, 0.18, { type: 'sawtooth', gain: 0.1 }); } },
    drumroll: () => { for (let i = 0; i < 16; i++) tone(120 + Math.random() * 40, i * 0.05, 0.05, { type: 'triangle', gain: 0.3 }); tone(150, 0.85, 0.5, { type: 'triangle', gain: 0.4, slide: 0.5 }); },
    boing: () => tone(150, 0, 0.5, { type: 'sine', gain: 0.35, slide: 4 }),
    laser: () => tone(1800, 0, 0.3, { type: 'square', gain: 0.1, slide: 0.15 }),
    levelup: () => { [523, 659, 784, 1047, 1319].forEach((f, i) => tone(f, i * 0.07, 0.2, { type: 'square', gain: 0.08 })); },
  };

  const Sounds = {
    volume: 1,
    names: Object.keys(BUILT_IN),
    unlock() { try { getCtx(); } catch {} },
    play(sound) {
      if (!sound) return;
      try {
        if (BUILT_IN[sound]) return BUILT_IN[sound]();
        if (/^(https?:|data:|\/)/.test(sound)) {
          const a = new Audio(sound);
          a.volume = Math.min(1, Sounds.volume);
          a.play().catch(() => {});
        }
      } catch (e) { console.warn('sound failed', e); }
    },
  };
  window.Sounds = Sounds;
})();
