/**
 * Browser audio manager using Web Audio API procedural synthesis.
 * Port of the Godot audio_manager.gd -- generates short PCM buffers
 * at init time and plays them via AudioBufferSourceNode on demand.
 */

const SAMPLE_RATE = 44100;

const SOUND_DEFS = {
  move:         { dur: 0.08, layers: [{ wave: "triangle", freq: 420, gain: 0.65 }], noise: 0.18, attack: 0.003 },
  push:         { dur: 0.12, layers: [{ wave: "triangle", freq: 210, gain: 0.32 }, { wave: "square", freq: 310, gain: 0.14 }], noise: 0.22, attack: 0.004 },
  wait:         { dur: 0.06, layers: [{ wave: "sine", freq: 280, gain: 0.32 }], noise: 0.04, attack: 0.002 },
  switch_layer: { dur: 0.18, layers: [{ wave: "sine", freq: 370, gain: 0.32 }, { wave: "triangle", freq: 554, gain: 0.24 }], noise: 0.06, attack: 0.01 },
  transfer:     { dur: 0.16, layers: [{ wave: "square", freq: 260, gain: 0.24 }, { wave: "triangle", freq: 390, gain: 0.18 }], noise: 0.1, attack: 0.008 },
  undo:         { dur: 0.12, layers: [{ wave: "sine", freq: 260, gain: 0.32 }], noise: 0.04, attack: 0.004 },
  redo:         { dur: 0.12, layers: [{ wave: "sine", freq: 330, gain: 0.32 }], noise: 0.04, attack: 0.004 },
  reset:        { dur: 0.20, layers: [{ wave: "triangle", freq: 180, gain: 0.16 }, { wave: "sine", freq: 96, gain: 0.12 }], noise: 0.18, attack: 0.012 },
  hint:         { dur: 0.14, layers: [{ wave: "sine", freq: 620, gain: 0.26 }], noise: 0.03, attack: 0.004 },
  enter:        { dur: 0.22, layers: [{ wave: "triangle", freq: 240, gain: 0.16 }, { wave: "sine", freq: 360, gain: 0.14 }], noise: 0.12, attack: 0.008 },
  solve:        { dur: 0.36, layers: [{ wave: "sine", freq: 392, gain: 0.20 }, { wave: "triangle", freq: 523.25, gain: 0.18 }, { wave: "sine", freq: 659.25, gain: 0.14 }], noise: 0.05, attack: 0.012 },
};

function waveform(type, phase) {
  const t = phase % 1;
  switch (type) {
    case "sine":     return Math.sin(t * Math.PI * 2);
    case "square":   return t < 0.5 ? 1 : -1;
    case "triangle": return 4 * Math.abs(t - 0.5) - 1;
    default:         return 0;
  }
}

function envelope(t, dur, attack) {
  const release = dur * 0.35;
  if (t < attack) return t / attack;
  if (t > dur - release) return Math.max(0, (dur - t) / release);
  return 1;
}

function buildBuffer(ctx, def) {
  const len = Math.ceil(def.dur * SAMPLE_RATE);
  const buffer = ctx.createBuffer(1, len, SAMPLE_RATE);
  const data = buffer.getChannelData(0);

  for (let i = 0; i < len; i++) {
    const t = i / SAMPLE_RATE;
    const env = envelope(t, def.dur, def.attack);
    let sample = 0;

    for (const layer of def.layers) {
      const phase = t * layer.freq;
      sample += waveform(layer.wave, phase) * layer.gain;
    }

    // Add noise texture
    if (def.noise > 0) {
      sample += (Math.random() * 2 - 1) * def.noise;
    }

    data[i] = sample * env;
  }

  return buffer;
}

export class AudioManager {
  constructor() {
    this._ctx = null;
    this._buffers = {};
    this._sfxGain = null;
    this._masterGain = null;
    this._ambientOsc = null;
    this._ambientGain = null;
    this._enabled = true;
    this._volume = 0.6;
    this._initialized = false;
  }

  /** Must be called from a user gesture (click/keydown) to satisfy autoplay policy. */
  init() {
    if (this._initialized) return;
    try {
      this._ctx = new (window.AudioContext || window.webkitAudioContext)();
    } catch {
      this._enabled = false;
      return;
    }
    this._initialized = true;

    // Master -> SFX gain chain
    this._masterGain = this._ctx.createGain();
    this._masterGain.gain.value = this._volume;
    this._masterGain.connect(this._ctx.destination);

    this._sfxGain = this._ctx.createGain();
    this._sfxGain.gain.value = 0.5; // -6dB relative
    this._sfxGain.connect(this._masterGain);

    // Pre-build all sound buffers
    for (const [name, def] of Object.entries(SOUND_DEFS)) {
      this._buffers[name] = buildBuffer(this._ctx, def);
    }
  }

  /** Resume context if suspended (happens on some browsers after tab switch). */
  _ensureRunning() {
    if (this._ctx && this._ctx.state === "suspended") {
      this._ctx.resume().catch(() => {});
    }
  }

  /** Play a named sound effect. */
  play(name) {
    if (!this._enabled || !this._initialized) return;
    const buffer = this._buffers[name];
    if (!buffer) return;
    this._ensureRunning();

    const source = this._ctx.createBufferSource();
    source.buffer = buffer;
    source.connect(this._sfxGain);
    source.start();
  }

  /** Start a low ambient drone. */
  startAmbient() {
    if (!this._enabled || !this._initialized || this._ambientOsc) return;
    this._ensureRunning();

    this._ambientGain = this._ctx.createGain();
    this._ambientGain.gain.value = 0;
    this._ambientGain.connect(this._masterGain);

    // Warm low-frequency pad
    this._ambientOsc = this._ctx.createOscillator();
    this._ambientOsc.type = "triangle";
    this._ambientOsc.frequency.value = 72;

    // Filter for warmth
    const filter = this._ctx.createBiquadFilter();
    filter.type = "lowpass";
    filter.frequency.value = 200;
    filter.Q.value = 1.2;

    this._ambientOsc.connect(filter);
    filter.connect(this._ambientGain);
    this._ambientOsc.start();

    // Fade in over 2 seconds
    this._ambientGain.gain.linearRampToValueAtTime(0.04, this._ctx.currentTime + 2);
  }

  /** Stop ambient drone with fade-out. */
  stopAmbient() {
    if (!this._ambientOsc || !this._ambientGain) return;
    const now = this._ctx.currentTime;
    this._ambientGain.gain.linearRampToValueAtTime(0, now + 0.8);
    const osc = this._ambientOsc;
    const gain = this._ambientGain;
    setTimeout(() => {
      try { osc.stop(); } catch { /* already stopped */ }
      try { osc.disconnect(); gain.disconnect(); } catch { /* ok */ }
    }, 1000);
    this._ambientOsc = null;
    this._ambientGain = null;
  }

  setEnabled(enabled) {
    this._enabled = enabled;
    if (!enabled) this.stopAmbient();
  }

  setVolume(v) {
    this._volume = Math.max(0, Math.min(1, v));
    if (this._masterGain) {
      this._masterGain.gain.value = this._volume;
    }
  }

  get enabled() { return this._enabled; }
  get volume() { return this._volume; }
}
