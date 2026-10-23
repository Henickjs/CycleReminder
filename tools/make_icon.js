// 生成应用图标 AppIcon.png（1024x1024，RGB 无透明通道）。
// 设计：青绿→靛蓝对角渐变底，白色时钟表盘（指针 10:10），右上角琥珀色通知徽标。
// 用法：node tools/make_icon.js   （产物已随仓库提供，通常无需重新运行）
'use strict';

const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const S = 1024;

const BG1 = [0x2d / 255, 0xd4 / 255, 0xbf / 255]; // 左上 青绿
const BG2 = [0x4f / 255, 0x46 / 255, 0xe5 / 255]; // 右下 靛蓝
const WHITE = [0.972, 0.976, 0.984];
const AMBER = [0.976, 0.729, 0.145];

const CX = 512, CY = 532;
const RING_R = 270, RING_HALF = 20;      // 表盘圆环
const HAND_HALF = 21;                    // 指针半宽（圆头线段）
const HOUR_END = [CX - 130, CY - 75];    // 指向 10 点
const MINUTE_END = [CX + 191, CY - 110]; // 指向 2 点
const DOT_R = 38;                        // 中心圆点
const BADGE = [796, 248];
const BADGE_OUTER = 96, BADGE_FILL = 82; // 白底圆 + 琥珀内圆

const clamp01 = (v) => (v < 0 ? 0 : v > 1 ? 1 : v);

// 距场 edge 距离（dist - half）的带 1.3px 抗锯齿覆盖率
function coverage(edgeDist) {
  return clamp01(-edgeDist / 1.3 + 0.5);
}

function segDist(px, py, ax, ay, bx, by) {
  const vx = bx - ax, vy = by - ay;
  const wx = px - ax, wy = py - ay;
  const c1 = vx * wx + vy * wy;
  if (c1 <= 0) return Math.hypot(px - ax, py - ay);
  const c2 = vx * vx + vy * vy;
  if (c2 <= c1) return Math.hypot(px - bx, py - by);
  const t = c1 / c2;
  return Math.hypot(px - (ax + t * vx), py - (ay + t * vy));
}

function blend(base, top, alpha) {
  return [
    base[0] + (top[0] - base[0]) * alpha,
    base[1] + (top[1] - base[1]) * alpha,
    base[2] + (top[2] - base[2]) * alpha,
  ];
}

function writePng(filePath, w, h, rgb) {
  const raw = Buffer.alloc((w * 3 + 1) * h);
  for (let y = 0; y < h; y++) {
    raw[y * (w * 3 + 1)] = 0; // filter: none
    Buffer.from(rgb.buffer, y * w * 3, w * 3).copy(raw, y * (w * 3 + 1) + 1);
  }
  function chunk(tag, data) {
    const len = Buffer.alloc(4);
    len.writeUInt32BE(data.length);
    const body = Buffer.concat([tag, data]);
    const crc = Buffer.alloc(4);
    crc.writeUInt32BE(zlib.crc32(body) >>> 0);
    return Buffer.concat([len, body, crc]);
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0);
  ihdr.writeUInt32BE(h, 4);
  ihdr[8] = 8;  // bit depth
  ihdr[9] = 2;  // color type: truecolor RGB
  const png = Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk(Buffer.from('IHDR'), ihdr),
    chunk(Buffer.from('IDAT'), zlib.deflateSync(raw, { level: 9 })),
    chunk(Buffer.from('IEND'), Buffer.alloc(0)),
  ]);
  fs.writeFileSync(filePath, png);
}

function main() {
  const rgb = Buffer.alloc(S * S * 3);
  for (let y = 0; y < S; y++) {
    for (let x = 0; x < S; x++) {
      const u = clamp01((x + y) / (2 * (S - 1)));
      let col = blend(BG1, BG2, u);

      const dCenter = Math.hypot(x - CX, y - CY);
      // 表盘圆环
      col = blend(col, WHITE, coverage(Math.abs(dCenter - RING_R) - RING_HALF));
      // 指针
      const dHour = segDist(x, y, CX, CY, HOUR_END[0], HOUR_END[1]) - HAND_HALF;
      const dMinute = segDist(x, y, CX, CY, MINUTE_END[0], MINUTE_END[1]) - HAND_HALF;
      col = blend(col, WHITE, Math.max(coverage(dHour), coverage(dMinute)));
      // 中心圆点
      col = blend(col, WHITE, coverage(dCenter - DOT_R));
      // 通知徽标：白圈 + 琥珀圆
      const dBadge = Math.hypot(x - BADGE[0], y - BADGE[1]);
      col = blend(col, WHITE, coverage(dBadge - BADGE_OUTER));
      col = blend(col, AMBER, coverage(dBadge - BADGE_FILL));

      const i = (y * S + x) * 3;
      rgb[i] = Math.round(clamp01(col[0]) * 255);
      rgb[i + 1] = Math.round(clamp01(col[1]) * 255);
      rgb[i + 2] = Math.round(clamp01(col[2]) * 255);
    }
  }
  const outDir = path.join(__dirname, '..', 'CycleReminder', 'Assets.xcassets', 'AppIcon.appiconset');
  fs.mkdirSync(outDir, { recursive: true });
  const outPath = path.join(outDir, 'AppIcon.png');
  writePng(outPath, S, S, rgb);
  console.log(`wrote ${outPath}`);
}

main();
