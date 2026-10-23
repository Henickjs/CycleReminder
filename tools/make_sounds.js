// 生成 App 内置提示铃声：44.1kHz / 16bit / 单声道 PCM WAV，每段均小于 30 秒。
// 用法：node tools/make_sounds.js   （产物已随仓库提供，通常无需重新运行）
'use strict';

const fs = require('fs');
const path = require('path');

const SR = 44100;
const GAIN = 0.75;
const TAU = Math.PI * 2;
const OUT_DIR = path.join(__dirname, '..', 'CycleReminder', 'Sounds');

// attack-release 包络
function envAr(t, attack, release, dur) {
  if (t < 0 || t > dur) return 0;
  if (t < attack) return t / attack;
  if (t > dur - release) return (dur - t) / release;
  return 1;
}

// 钟声敲击：基频 + 两个非谐泛音，指数衰减
function bellStrike(t, f) {
  const part =
    Math.sin(TAU * f * t) +
    0.4 * Math.sin(TAU * f * 2.76 * t) +
    0.18 * Math.sin(TAU * f * 5.4 * t);
  return part * Math.exp(-4.2 * t);
}

function toneChime(t) {
  let v = 0;
  if (t < 0.9) v += bellStrike(t, 1318.51); // E6
  if (t >= 0.45 && t < 1.4) v += 0.85 * bellStrike(t - 0.45, 1046.5); // C6
  return v;
}

function toneSoft(t) {
  const notes = [523.25, 659.25, 783.99, 1046.5]; // C5 E5 G5 C6
  let v = 0;
  for (let k = 0; k < notes.length; k++) {
    const lt = t - (0.05 + 0.24 * k);
    if (lt >= 0 && lt < 0.5) {
      const vib = notes[k] * (1 + 0.004 * Math.sin(TAU * 5 * lt));
      v += Math.sin(TAU * vib * lt) * envAr(lt, 0.03, 0.22, 0.5);
    }
  }
  return 0.8 * v;
}

function toneAlert(t) {
  const period = 0.17, on = 0.1, beeps = 5;
  const k = Math.floor(t / period);
  if (k >= beeps) return 0;
  const lt = t - k * period;
  if (lt > on) return 0;
  const gate = envAr(lt, 0.006, 0.025, on);
  const s = Math.sin(TAU * 880 * t);
  return (0.62 * s + 0.38 * Math.sign(s)) * gate;
}

function dropOnce(lt) {
  const f = 1500 * Math.exp(-8 * lt) + 500; // 频率快速下滑
  const phase = TAU * ((1500 * (1 - Math.exp(-8 * lt))) / 8 + 500 * lt);
  return Math.sin(phase) * Math.exp(-9 * lt);
}

function toneWater(t) {
  let v = 0;
  const amps = [1, 0.62, 0.38];
  for (let k = 0; k < amps.length; k++) {
    const lt = t - (0.02 + 0.42 * k);
    if (lt >= 0 && lt < 0.6) v += amps[k] * dropOnce(lt) * envAr(lt, 0.004, 0.2, 0.6);
  }
  return v;
}

function chirpOnce(lt) {
  const f = 2350 + 650 * Math.sin(TAU * 16 * lt) + (1000 * lt) / 0.28;
  const v = Math.sin(TAU * f * lt) + 0.45 * Math.sin(TAU * 1.5 * f * lt);
  return v * envAr(lt, 0.02, 0.1, 0.28);
}

function toneBird(t) {
  let v = 0;
  for (let k = 0; k < 3; k++) {
    const lt = t - (0.06 + 0.42 * k);
    if (lt >= 0 && lt < 0.3) v += 0.9 * chirpOnce(lt);
  }
  return v;
}

function toneRing(t) {
  let v = 0;
  for (const start of [0, 1.05]) {
    const lt = t - start;
    if (lt >= 0 && lt < 0.75) {
      const am = 0.55 + 0.45 * Math.sin(TAU * 20 * lt);
      v += Math.sin(TAU * 1720 * lt) * am * envAr(lt, 0.02, 0.06, 0.75);
    }
  }
  return v;
}

function toneUpbeat(t) {
  let v = 0;
  if (t >= 0 && t < 0.55) {
    // 523Hz 起一个八度滑音
    const phase = TAU * 523.25 * (0.55 / Math.log(2)) * (2 ** (t / 0.55) - 1);
    v += (Math.sin(phase) + 0.3 * Math.sin(2 * phase)) * envAr(t, 0.05, 0.15, 0.55);
  }
  const lt = t - 0.62;
  if (lt >= 0 && lt < 0.5) {
    v += (Math.sin(TAU * 1318.51 * lt) + 0.25 * Math.sin(TAU * 1975.53 * lt)) * envAr(lt, 0.02, 0.25, 0.5);
  }
  return v;
}

const TONES = [
  ['chime', 1.8, toneChime],
  ['soft', 1.6, toneSoft],
  ['alert', 1.0, toneAlert],
  ['water', 1.5, toneWater],
  ['bird', 1.5, toneBird],
  ['ring', 2.0, toneRing],
  ['upbeat', 1.3, toneUpbeat],
];

function writeWav(filePath, samples) {
  const dataSize = samples.length * 2;
  const buf = Buffer.alloc(44 + dataSize);
  buf.write('RIFF', 0);
  buf.writeUInt32LE(36 + dataSize, 4);
  buf.write('WAVE', 8);
  buf.write('fmt ', 12);
  buf.writeUInt32LE(16, 16);        // fmt 块长度
  buf.writeUInt16LE(1, 20);         // PCM
  buf.writeUInt16LE(1, 22);         // 单声道
  buf.writeUInt32LE(SR, 24);
  buf.writeUInt32LE(SR * 2, 28);    // 字节速率
  buf.writeUInt16LE(2, 32);         // 块对齐
  buf.writeUInt16LE(16, 34);        // 位深
  buf.write('data', 36);
  buf.writeUInt32LE(dataSize, 40);
  for (let i = 0; i < samples.length; i++) {
    buf.writeInt16LE(Math.max(-32768, Math.min(32767, Math.round(samples[i] * 32767))), 44 + i * 2);
  }
  fs.writeFileSync(filePath, buf);
}

function main() {
  fs.mkdirSync(OUT_DIR, { recursive: true });
  for (const [name, dur, fn] of TONES) {
    const n = Math.floor(SR * dur);
    const samples = new Float64Array(n);
    let peak = 1e-9;
    for (let i = 0; i < n; i++) {
      samples[i] = fn(i / SR);
      const a = Math.abs(samples[i]);
      if (a > peak) peak = a;
    }
    const scale = GAIN / peak;
    const fade = Math.max(1, Math.floor(SR * 0.01)); // 全局 10ms 淡入淡出防爆音
    for (let i = 0; i < fade && i < n; i++) {
      samples[i] *= i / fade;
      samples[n - 1 - i] *= i / fade;
    }
    for (let i = 0; i < n; i++) samples[i] *= scale;
    const outPath = path.join(OUT_DIR, `${name}.wav`);
    writeWav(outPath, samples);
    console.log(`wrote ${outPath} (${dur.toFixed(2)}s)`);
  }
}

main();
