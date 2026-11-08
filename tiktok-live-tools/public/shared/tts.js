// Browser text-to-speech queue (uses the device's built-in voices — free, no API key).
(function () {
  const queue = [];
  let speaking = false;
  const TTS = {
    enabled: false,
    voiceURI: '',
    rate: 1,
    pitch: 1,
    volume: 1,
    maxQueue: 8,
    onChange: null,
    voices() { return window.speechSynthesis ? speechSynthesis.getVoices() : []; },
    supported: 'speechSynthesis' in window,
    say(text) {
      if (!TTS.enabled || !TTS.supported || !text) return;
      if (queue.length >= TTS.maxQueue) queue.shift(); // drop oldest when chat floods
      queue.push(text);
      next();
    },
    skip() { if (TTS.supported) speechSynthesis.cancel(); },
    clear() { queue.length = 0; TTS.skip(); },
    get pending() { return queue.length; },
  };
  function next() {
    if (speaking || !queue.length) return;
    speaking = true;
    const u = new SpeechSynthesisUtterance(queue.shift());
    const v = TTS.voices().find((x) => x.voiceURI === TTS.voiceURI);
    if (v) { u.voice = v; u.lang = v.lang; }
    u.rate = TTS.rate; u.pitch = TTS.pitch; u.volume = TTS.volume;
    const done = () => { speaking = false; TTS.onChange?.(); setTimeout(next, 150); };
    u.onend = done; u.onerror = done;
    speechSynthesis.speak(u);
    TTS.onChange?.();
    // Some mobile browsers never fire onend; don't let the queue get stuck.
    setTimeout(() => { if (speaking && !speechSynthesis.speaking) done(); }, 15000);
  }
  if (TTS.supported) speechSynthesis.onvoiceschanged = () => TTS.onChange?.();
  window.TTS = TTS;
})();
