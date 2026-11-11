#!/usr/bin/env python3
"""AFTERTIDE original sound pack: every sound is synthesised from scratch here (numpy),
so the whole pack is our own work: no samples, no licences, no copyright risk.

Output: aftertide/audio/<Key>.ogg (key names match src/shared/Config/Sounds.luau)
Usage:  python3 tools/make_sounds.py        (needs numpy + ffmpeg)
Then upload the .ogg files to Roblox (docs/08-audio.md) and paste the IDs into Sounds.luau.
"""
import os
import subprocess
import tempfile
import wave

import numpy as np

SR = 44100
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(os.path.dirname(HERE), "audio")
rng = np.random.default_rng(1137)


# ---------------------------------------------------------------- building blocks
def t(seconds):
    return np.arange(int(SR * seconds)) / SR


def noise(seconds):
    return rng.standard_normal(int(SR * seconds))


def env(n, attack=0.002, decay=0.3, curve=1.0):
    """Fast attack, exponential decay envelope over n samples."""
    x = np.arange(n) / SR
    a = np.clip(x / max(attack, 1e-4), 0, 1)
    d = np.exp(-x / max(decay, 1e-4)) ** curve
    return a * d


def fft_filter(x, low=None, high=None, q=None, gain_curve=None):
    """Static band/low/high-pass via FFT mask (smooth roll-offs)."""
    n = len(x)
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1 / SR)
    mask = np.ones_like(f)
    if high is not None:  # low-pass at `high`
        mask *= 1 / (1 + (f / high) ** 4)
    if low is not None:  # high-pass at `low`
        mask *= 1 - 1 / (1 + (f / max(low, 1)) ** 4)
    if gain_curve is not None:
        mask *= gain_curve(f)
    return np.fft.irfft(spec * mask, n)


def sweep_filter(x, start, end, width=0.35, chunk=2048):
    """Time-varying band-pass (formant sweep) by overlapping FFT chunks."""
    out = np.zeros(len(x) + chunk)
    win = np.hanning(chunk)
    hop = chunk // 4
    steps = max(1, (len(x) - chunk) // hop + 1)
    for i in range(steps):
        a = i * hop
        seg = x[a:a + chunk]
        if len(seg) < chunk:
            seg = np.pad(seg, (0, chunk - len(seg)))
        frac = i / max(1, steps - 1)
        centre = start * (end / start) ** frac
        f = np.fft.rfftfreq(chunk, 1 / SR)
        mask = np.exp(-((np.log2(np.maximum(f, 1) / centre)) ** 2) / (2 * width ** 2))
        out[a:a + chunk] += np.fft.irfft(np.fft.rfft(seg * win) * mask, chunk) * win
    return out[: len(x)] / 1.5


def tone(freq, seconds, kind="sine", detune=0.0):
    x = t(seconds)
    if callable(freq):
        phase = 2 * np.pi * np.cumsum(freq(x)) / SR
    else:
        phase = 2 * np.pi * freq * (1 + detune) * x
    if kind == "sine":
        return np.sin(phase)
    if kind == "saw":
        return 2 * ((phase / (2 * np.pi)) % 1) - 1
    if kind == "tri":
        return 2 * np.abs(2 * ((phase / (2 * np.pi)) % 1) - 1) - 1
    raise ValueError(kind)


def reverb(x, seconds=1.2, mix=0.25, damp=3000):
    """Convolution with a decaying-noise impulse (a smallish, wet room or outdoor slap)."""
    ir = noise(seconds) * np.exp(-np.arange(int(SR * seconds)) / (SR * seconds / 5))
    ir = fft_filter(ir, high=damp)
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    n = len(x) + len(ir)
    wet = np.fft.irfft(np.fft.rfft(x, n) * np.fft.rfft(ir, n), n)
    dry = np.pad(x, (0, len(ir)))
    return dry * (1 - mix) + wet * mix


def pad(x, seconds):
    return np.pad(x, (0, int(SR * seconds)))


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def at(x, seconds, total):
    out = np.zeros(int(SR * total))
    a = int(SR * seconds)
    end = min(len(out), a + len(x))
    out[a:end] += x[: end - a]
    return out


def normalise(x, peak=0.89):
    m = np.max(np.abs(x)) + 1e-9
    return x / m * peak


def loopable(x, fade=0.5):
    """Crossfade the tail into the head so the loop is seamless."""
    n = int(SR * fade)
    head, tail = x[:n], x[-n:]
    ramp = np.linspace(0, 1, n)
    x = x[:-n].copy()
    x[:n] = head * ramp + tail * (1 - ramp)
    return x


def lfo(seconds, rate, depth, base=1.0, phase=0.0):
    return base + depth * np.sin(2 * np.pi * rate * t(seconds) + phase)


# ---------------------------------------------------------------- weapons
def gunshot(body_hz, crack_hi, decay, tail, thump=1.0, size=1.0):
    n = noise(0.6 * size)
    crack = fft_filter(n, low=1500, high=crack_hi) * env(len(n), 0.0005, 0.012 * size)
    blast = fft_filter(n, low=120, high=3000) * env(len(n), 0.001, decay)
    boom = tone(lambda x: body_hz * (1 + 2.5 * np.exp(-x / 0.02)), 0.6 * size) * env(int(SR * 0.6 * size), 0.001, 0.09 * size) * thump
    shot = mix(crack * 1.1, blast * 0.9, boom * 0.8)
    return normalise(reverb(np.tanh(shot * 2.2), seconds=tail, mix=0.35, damp=2500))


def mech_click(seconds=0.05, freq=3200, decay=0.006):
    n = noise(seconds)
    return fft_filter(n, low=freq * 0.5, high=freq * 2) * env(len(n), 0.0002, decay)


def reload_seq():
    total = 1.2
    x = mix(
        at(mech_click(0.06, 2400, 0.01), 0.05, total),
        at(mech_click(0.06, 1800, 0.012) * 0.8, 0.35, total),
        at(fft_filter(noise(0.25), low=300, high=2500) * env(int(SR * 0.25), 0.02, 0.08) * 0.3, 0.45, total),
        at(mech_click(0.08, 3000, 0.02) * 1.2, 0.85, total),
        at(mech_click(0.05, 4200, 0.008), 1.0, total),
    )
    return normalise(reverb(x, 0.4, 0.12))


def bow_shot():
    twang = tone(lambda x: 110 * (1 + 0.4 * np.exp(-x / 0.05)), 0.7, "tri") * env(int(SR * 0.7), 0.001, 0.12)
    twang += tone(220, 0.7) * env(int(SR * 0.7), 0.001, 0.05) * 0.4
    whoosh = sweep_filter(noise(0.5), 600, 2500, 0.5) * env(int(SR * 0.5), 0.03, 0.12)
    return normalise(reverb(mix(twang, whoosh * 0.7), 0.5, 0.15))


# ---------------------------------------------------------------- impacts & world
def impact_world():
    n = noise(0.4)
    thunk = fft_filter(n, low=80, high=1200) * env(len(n), 0.0005, 0.03)
    debris = mix(*[at(fft_filter(noise(0.04), low=2000, high=9000) * env(int(SR * 0.04), 0.0002, 0.008) * rng.uniform(0.2, 0.6), rng.uniform(0.02, 0.25), 0.4) for _ in range(7)])
    return normalise(reverb(mix(thunk, debris), 0.6, 0.2))


def impact_salt():
    n = noise(0.35)
    crunch = fft_filter(n, low=600, high=6000) * env(len(n), 0.0005, 0.05)
    grains = mix(*[at(fft_filter(noise(0.02), low=3000, high=12000) * env(int(SR * 0.02), 0.0002, 0.004) * rng.uniform(0.3, 0.8), rng.uniform(0.0, 0.2), 0.35) for _ in range(14)])
    thud = tone(90, 0.3) * env(int(SR * 0.3), 0.001, 0.04)
    return normalise(mix(crunch, grains * 0.7, thud * 0.6))


def glass_break():
    total = 1.4
    shards = []
    for _ in range(26):
        f = rng.uniform(2500, 9000)
        dur = rng.uniform(0.08, 0.5)
        ring = tone(f, dur) * env(int(SR * dur), 0.0003, dur / 4) * rng.uniform(0.1, 0.35)
        shards.append(at(ring, rng.uniform(0.0, 0.5) ** 1.7, total))
    burst = fft_filter(noise(0.4), low=1500, high=12000) * env(int(SR * 0.4), 0.0005, 0.06)
    return normalise(reverb(mix(burst, *shards), 0.8, 0.25, 6000))


def explosion():
    total = 3.5
    n = noise(total)
    boom = fft_filter(n, high=400) * env(len(n), 0.003, 0.5)
    crack = fft_filter(noise(0.3), low=800, high=8000) * env(int(SR * 0.3), 0.0005, 0.03)
    sub = tone(lambda x: 45 * (1 + 2 * np.exp(-x / 0.05)), total) * env(int(SR * total), 0.002, 0.35)
    rumble = fft_filter(n, high=200) * env(len(n), 0.2, 1.2) * 0.5
    return normalise(reverb(np.tanh(mix(boom * 1.4, crack, sub, rumble) * 1.6), 2.0, 0.35, 1500))


def fire_loop():
    s = 6
    hiss = fft_filter(noise(s), low=800, high=7000) * lfo(s, 0.7, 0.3) * 0.25
    crackle = mix(*[at(fft_filter(noise(0.01), low=2000, high=9000) * env(int(SR * 0.01), 0.0001, 0.002) * rng.uniform(0.3, 1), rng.uniform(0, s - 0.02), s) for _ in range(160)])
    roar = fft_filter(noise(s), high=300) * lfo(s, 0.4, 0.4) * 0.6
    return normalise(loopable(mix(hiss, crackle, roar)), 0.8)


def gas_hiss():
    s = 2.5
    return normalise(fft_filter(noise(s), low=2500, high=10000) * env(int(SR * s), 0.05, 0.9), 0.7)


def door_creak():
    s = 1.3
    creak = sweep_filter(np.tanh(tone(lambda x: 90 + 40 * np.sin(2 * np.pi * 1.3 * x) + 30 * x, s, "saw") * 2), 700, 1300, 0.25)
    creak *= env(int(SR * s), 0.15, 0.6)
    thud = at(tone(70, 0.3) * env(int(SR * 0.3), 0.001, 0.06), 1.1, s + 0.3)
    return normalise(reverb(mix(creak, thud * 0.8), 0.6, 0.2))


def rummage():
    s = 1.0
    x = mix(*[at(fft_filter(noise(0.09), low=500, high=5000) * env(int(SR * 0.09), 0.01, 0.03) * rng.uniform(0.3, 1), rng.uniform(0, 0.85), s) for _ in range(9)])
    clinks = mix(*[at(tone(rng.uniform(1800, 4000), 0.15) * env(int(SR * 0.15), 0.0005, 0.03) * 0.25, rng.uniform(0.1, 0.8), s) for _ in range(3)])
    return normalise(mix(x, clinks))


def pickup():
    s = 0.35
    rustle = fft_filter(noise(s), low=800, high=6000) * env(int(SR * s), 0.01, 0.06)
    clink = tone(2600, s) * env(int(SR * s), 0.0005, 0.04) * 0.3
    return normalise(mix(rustle, clink), 0.7)


# ---------------------------------------------------------------- footsteps & body
def footstep(surface="concrete"):
    s = 0.3
    n = noise(s)
    if surface == "water":
        splash = fft_filter(n, low=400, high=5000) * env(len(n), 0.01, 0.08)
        bubbles = mix(*[at(tone(rng.uniform(500, 1400), 0.05) * env(int(SR * 0.05), 0.001, 0.015) * 0.2, rng.uniform(0.02, 0.2), s) for _ in range(5)])
        return normalise(mix(splash, bubbles), 0.75)
    heel = fft_filter(n, low=60, high=900) * env(len(n), 0.001, 0.025)
    scuff = fft_filter(noise(s), low=1200, high=7000) * env(len(n), 0.01, 0.05) * 0.35
    grit = mix(*[at(fft_filter(noise(0.01), low=3000, high=10000) * env(int(SR * 0.01), 0.0001, 0.002) * 0.2, rng.uniform(0.0, 0.1), s) for _ in range(5)])
    return normalise(mix(heel, scuff, grit), 0.7)


def whoosh(seconds=0.45, lo=300, hi=2500):
    return normalise(sweep_filter(noise(seconds), lo, hi, 0.6) * env(int(SR * seconds), seconds * 0.4, seconds * 0.25), 0.8)


def melee_hit():
    n = noise(0.3)
    thud = fft_filter(n, low=60, high=700) * env(len(n), 0.0005, 0.04)
    body = tone(lambda x: 110 * (1 + np.exp(-x / 0.02)), 0.3) * env(int(SR * 0.3), 0.0005, 0.05)
    return normalise(np.tanh(mix(thud, body * 0.8, impact_salt()[: int(SR * 0.3)] * 0.4) * 1.5))


def heartbeat():
    s = 1.0
    beat = lambda: tone(lambda x: 55 * (1 + 0.6 * np.exp(-x / 0.03)), 0.25) * env(int(SR * 0.25), 0.004, 0.05)
    return normalise(mix(at(beat(), 0.0, s), at(beat() * 0.7, 0.28, s)), 0.8)


def hurt():
    s = 0.6
    impact = fft_filter(noise(s), low=80, high=1500) * env(int(SR * s), 0.001, 0.05)
    breath = sweep_filter(noise(s), 900, 500, 0.4) * env(int(SR * s), 0.05, 0.2) * 0.6
    return normalise(mix(impact, breath))


def bandage():
    s = 1.6
    rip = sweep_filter(noise(0.6), 1500, 5000, 0.5) * env(int(SR * 0.6), 0.02, 0.2)
    wrap = mix(*[at(fft_filter(noise(0.18), low=600, high=4000) * env(int(SR * 0.18), 0.03, 0.06) * 0.5, 0.6 + i * 0.25, s) for i in range(4)])
    return normalise(mix(rip, wrap))


# ---------------------------------------------------------------- the Hushed
def breath_loop(base=170, rasp=0.6, seconds=6.0):
    """Wet, rasping breath cycle: inhale/exhale formant noise, slow and uneven."""
    out = np.zeros(int(SR * seconds))
    pos = 0.0
    while pos < seconds - 0.5:
        dur = rng.uniform(0.7, 1.3)
        seg = sweep_filter(noise(dur), base * rng.uniform(2.5, 3.5), base * rng.uniform(1.5, 2.2), 0.45)
        gravel = fft_filter(noise(dur), low=60, high=400) * rasp
        am = (np.abs(np.sin(2 * np.pi * rng.uniform(25, 40) * t(dur))) ** 3) * rasp
        seg = (seg + gravel * am) * np.sin(np.pi * np.linspace(0, 1, int(SR * dur))) ** 1.5
        out += at(seg, pos, seconds)
        pos += dur + rng.uniform(0.2, 0.7)
    return normalise(loopable(out, 0.3), 0.7)


def growl(seconds=1.4, pitch=80, bright=900):
    x = t(seconds)
    f0 = pitch * (1 + 0.15 * np.sin(2 * np.pi * 5.5 * x) + 0.1 * rng.standard_normal(len(x)) * 0)
    voice = np.tanh(tone(lambda q: pitch * (1 + 0.12 * np.sin(2 * np.pi * 6 * q)), seconds, "saw") * 3)
    voice = sweep_filter(voice + noise(seconds) * 0.4, bright, bright * 0.6, 0.35)
    flutter = 0.6 + 0.4 * np.abs(np.sin(2 * np.pi * 18 * x))
    _ = f0
    return normalise(reverb(voice * flutter * env(len(x), 0.08, seconds * 0.5), 1.0, 0.3, 2500))


def shriek(seconds=1.3):
    x = t(seconds)
    pitch = lambda q: 520 + 380 * np.sin(np.pi * np.clip(q / seconds, 0, 1)) + 40 * np.sin(2 * np.pi * 9 * q)
    voice = np.tanh(tone(pitch, seconds, "saw") * 2.5) * 0.6 + noise(seconds) * 0.5
    voice = sweep_filter(voice, 1500, 3200, 0.5)
    voice = fft_filter(voice, low=400, high=8000)
    return normalise(reverb(voice * env(len(x), 0.04, seconds * 0.45), 1.4, 0.35, 4000))


def salt_grind(seconds=3.0):
    """The Seeker's sound: a slow crunching of crust as it moves (no clicks)."""
    def crunch():
        d = rng.uniform(0.05, 0.2)
        return fft_filter(noise(d), low=300, high=4000) * env(int(SR * d), 0.02, 0.05) * rng.uniform(0.2, 1)

    out = mix(*[at(crunch(), rng.uniform(0, seconds - 0.25), seconds) for _ in range(28)])
    moan = sweep_filter(noise(seconds), 260, 200, 0.3) * lfo(seconds, 0.3, 0.5) * 0.4
    return normalise(loopable(mix(out, moan), 0.3), 0.7)


def tidewalker_groan(seconds=3.0):
    x = t(seconds)
    voice = np.tanh(tone(lambda q: 42 + 6 * np.sin(2 * np.pi * 0.7 * q), seconds, "saw") * 2.5)
    voice = fft_filter(voice + noise(seconds) * 0.2, high=700)
    creak = sweep_filter(noise(seconds), 200, 500, 0.4) * 0.4
    return normalise(reverb((voice + creak) * env(len(x), 0.4, seconds * 0.6), 1.8, 0.35, 1200))


def hum(seconds=3.0):
    x = t(seconds)
    voices = sum(tone(f, seconds, "saw") for f in (73, 73.6, 110.2, 146.4)) / 4
    voices = fft_filter(voices, high=900) * (0.7 + 0.3 * np.sin(2 * np.pi * 3.2 * x))
    return normalise(reverb(voices * env(len(x), 0.6, seconds * 0.8), 2.2, 0.45, 1500))


def disperse():
    s = 2.2
    crumble = mix(*[at(fft_filter(noise(0.05), low=1000, high=8000) * env(int(SR * 0.05), 0.0005, 0.01) * rng.uniform(0.1, 0.6), rng.uniform(0, 1.0) ** 1.5, s) for _ in range(60)])
    sigh = sweep_filter(noise(s), 1200, 300, 0.4) * env(int(SR * s), 0.05, 0.6) * 0.7
    return normalise(reverb(mix(crumble, sigh), 1.0, 0.3))


# ---------------------------------------------------------------- ambience & music
def amb_wind(seconds=24):
    n = noise(seconds)
    body = fft_filter(n, low=80, high=900) * lfo(seconds, 0.07, 0.45, 0.6) * lfo(seconds, 0.23, 0.2, 1, 1.3)
    whistle = sweep_filter(noise(seconds), 700, 1100, 0.15) * lfo(seconds, 0.11, 0.5, 0.4) * 0.25
    return normalise(loopable(body + whistle, 2.0), 0.6)


def amb_sea(seconds=24):
    out = np.zeros(int(SR * seconds))
    pos = 0.0
    while pos < seconds:
        dur = rng.uniform(4, 7)
        wave_ = fft_filter(noise(dur), low=100, high=2500) * (np.sin(np.pi * np.linspace(0, 1, int(SR * dur))) ** 2)
        out += at(wave_ * rng.uniform(0.5, 1), pos, seconds)
        pos += dur * rng.uniform(0.55, 0.8)
    return normalise(loopable(out, 2.0), 0.55)


def amb_drone(seconds=32):
    x = t(seconds)
    pad_ = sum(tone(f, seconds, "saw", d) for f, d in ((55, 0), (55, 0.004), (82.4, 0.002), (110, -0.003), (130.8, 0.001)))
    pad_ = fft_filter(pad_ / 5, high=600) * lfo(seconds, 1 / 16, 0.3, 0.7)
    air = fft_filter(noise(seconds), low=2000, high=6000) * 0.05 * lfo(seconds, 1 / 8, 0.5)
    return normalise(loopable(reverb(pad_ + air, 3.0, 0.5, 1200)[: len(x)], 3.0), 0.5)


def music_tension(seconds=16):
    x = t(seconds)
    bpm = 90
    beat = 60 / bpm
    pulse = np.zeros(len(x))
    for i in range(int(seconds / beat)):
        hit = tone(lambda q: 49 * (1 + 0.5 * np.exp(-q / 0.04)), 0.4) * env(int(SR * 0.4), 0.002, 0.12)
        pulse += at(hit, i * beat, seconds) * (1 if i % 4 == 0 else 0.55)
    strings = sum(tone(lambda q, f=f: f * (1 + 0.004 * np.sin(2 * np.pi * 5 * q)), seconds, "saw") for f in (98, 103.8, 146.8))
    strings = fft_filter(strings / 3, high=1400) * lfo(seconds, 1 / 8, 0.4, 0.6)
    return normalise(loopable(reverb(mix(pulse, strings * 0.5), 2.0, 0.35)[: len(x)], 1.0), 0.7)


def stinger_spotted():
    s = 2.8
    x = t(s)
    cluster = sum(tone(f, s, "saw", d) for f, d in ((116.5, 0), (123.5, 0.002), (174.6, -0.002), (246.9, 0.001)))
    cluster = sweep_filter(cluster / 4, 400, 2200, 0.8) * env(len(x), 0.08, 0.9)
    hitlow = tone(lambda q: 41 * (1 + np.exp(-q / 0.05)), s) * env(len(x), 0.002, 0.4)
    return normalise(reverb(mix(cluster, hitlow), 2.5, 0.4))


def stinger_clear():
    s = 4.0
    x = t(s)
    chord = sum(tone(f, s, "tri") for f in (130.8, 196.0, 261.6, 329.6)) / 4
    return normalise(reverb(fft_filter(chord, high=2500) * env(len(x), 0.6, 1.4), 3.0, 0.5))


def ui_tick():
    s = 0.12
    return normalise(tone(1800, s) * env(int(SR * s), 0.0005, 0.012) + fft_filter(noise(s), low=3000) * env(int(SR * s), 0.0002, 0.004) * 0.3, 0.6)


def ui_confirm():
    s = 0.5
    return normalise(mix(tone(660, s, "tri") * env(int(SR * s), 0.002, 0.08), at(tone(990, s, "tri") * env(int(SR * s), 0.002, 0.1), 0.07, s)), 0.6)


# ---------------------------------------------------------------- export
SOUNDS = {
    "Gun_revolver": lambda: gunshot(95, 9000, 0.06, 1.4),
    "Gun_carbine": lambda: gunshot(85, 10000, 0.07, 1.6),
    "Gun_rifle": lambda: gunshot(70, 12000, 0.1, 2.2, 1.3, 1.2),
    "Gun_shotgun": lambda: gunshot(60, 7000, 0.12, 2.0, 1.5, 1.2),
    "Gun_bow": bow_shot,
    "Reload": reload_seq,
    "DryFire": lambda: normalise(mech_click(0.1, 2600, 0.01), 0.6),
    "Equip": lambda: normalise(mix(whoosh(0.3, 400, 1500) * 0.6, at(mech_click(0.06, 2000, 0.015), 0.22, 0.4)), 0.7),
    "ImpactWorld": impact_world,
    "ImpactSalt": impact_salt,
    "BottleBreak": glass_break,
    "Explosion": explosion,
    "FireLoop": fire_loop,
    "FogHiss": gas_hiss,
    "Door": door_creak,
    "Search": rummage,
    "Pickup": pickup,
    "Step": lambda: footstep("concrete"),
    "StepWater": lambda: footstep("water"),
    "Dodge": lambda: whoosh(0.4, 250, 1800),
    "Swing": lambda: whoosh(0.25, 600, 3500),
    "MeleeHit": melee_hit,
    "Heartbeat": heartbeat,
    "Hurt": hurt,
    "Bandage": bandage,
    "Throw": lambda: whoosh(0.35, 400, 2200),
    "Hushed_Breath": breath_loop,
    "Hushed_Growl": lambda: growl(1.4, 75, 850),
    "Hushed_Attack": lambda: growl(0.8, 95, 1300),
    "Rusher_Shriek": shriek,
    "Seeker_Grind": salt_grind,
    "Tidewalker_Groan": tidewalker_groan,
    "Hum": hum,
    "Disperse": disperse,
    "Amb_Wind": amb_wind,
    "Amb_Sea": amb_sea,
    "Amb_Drone": amb_drone,
    "Music_Tension": music_tension,
    "Stinger_Spotted": stinger_spotted,
    "Stinger_Clear": stinger_clear,
    "Ui_Tick": ui_tick,
    "Ui_Confirm": ui_confirm,
}


def write_ogg(name, data):
    data = np.clip(data, -1, 1)
    pcm = (data * 32767).astype(np.int16)
    with tempfile.TemporaryDirectory() as tmp:
        wav_path = os.path.join(tmp, name + ".wav")
        with wave.open(wav_path, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        out = os.path.join(OUT, name + ".ogg")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path, "-c:a", "libvorbis", "-q:a", "5", out], check=True)


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, fn in SOUNDS.items():
        write_ogg(name, fn())
        print("wrote", name)


if __name__ == "__main__":
    main()
