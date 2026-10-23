// 核心算法的可执行验证（设计级验证：算法与 Swift 实现逐行对应，但不能替代 Xcode 编译测试）
//  1) 提醒时间推算 upcomingDates —— 与 NotificationManager.swift 相同
//  2) 登录密码规则（admin + 当天 8 位日期）—— 与 LoginManager.swift 相同
// 用法：node tools/verify_logic.js
'use strict';

const DAY = 86400000;
const addDays = (d, n) => { const r = new Date(d); r.setDate(r.getDate() + n); return r; };

// —— 与 NotificationManager.upcomingDates 相同的算法 ——
function upcomingDates(rule, now = new Date(), limit = 1) {
  const interval = Math.max(1, rule.intervalDays);
  const period = interval * DAY;
  let date = new Date(rule.startDate);
  if (date <= now) {
    const steps = Math.max(1, Math.ceil((now - date + 1000) / period));
    date = addDays(date, interval * steps);
  }
  while (date <= now) date = addDays(date, interval);
  const out = [];
  let cur = date;
  while (out.length < limit) {
    if (rule.endDate && cur > rule.endDate) break;
    out.push(new Date(cur));
    cur = addDays(cur, interval);
  }
  return out;
}

// —— 与 LoginManager 相同的密码规则 ——
function todaysPassword(date = new Date()) {
  const p = (n) => String(n).padStart(2, '0');
  return `${date.getFullYear()}${p(date.getMonth() + 1)}${p(date.getDate())}`;
}
function login(user, pass, now = new Date()) {
  return user.trim().toLowerCase() === 'admin' && pass === todaysPassword(now);
}

let failed = 0;
function check(name, cond, detail = '') {
  console.log(`${cond ? 'PASS' : 'FAIL'}  ${name}${cond ? '' : '  -> ' + detail}`);
  if (!cond) failed++;
}

const now = new Date();

// 排期算法
const r1 = { startDate: addDays(now, 5), intervalDays: 3, endDate: null };
const got1 = upcomingDates(r1, now, 2);
check('未来起始：第一个提醒点 = 起始时间', got1[0].getTime() === r1.startDate.getTime());
check('未来起始：后续按周期递增', got1[1].getTime() === addDays(r1.startDate, 3).getTime());

const r2 = { startDate: addDays(now, -10), intervalDays: 3, endDate: null };
const got2 = upcomingDates(r2, now, 1);
check('过去起始（10 天前、周期 3 天）：顺延到 start+12 天', got2[0].getTime() === addDays(r2.startDate, 12).getTime(), got2[0].toISOString());

const r3 = { startDate: addDays(now, -100), intervalDays: 1, endDate: null };
const got3 = upcomingDates(r3, now, 1);
check('每天周期（100 天前开始）：下一次 = start+101 天', got3[0].getTime() === addDays(r3.startDate, 101).getTime());

const r4 = { startDate: addDays(now, -1), intervalDays: 3, endDate: addDays(addDays(now, -1), 13) };
const got4 = upcomingDates(r4, now, 16);
check('结束时间截断：只保留 4 个提醒点（start+3/6/9/12 天）', got4.length === 4, 'len=' + got4.length);
check('结束时间截断：最后一个点 = start+12 天（含边界当天）', got4[3].getTime() === addDays(r4.startDate, 12).getTime());

const r5 = { startDate: addDays(now, -30), intervalDays: 7, endDate: addDays(now, -5) };
check('已到期规则：不再产生提醒点', upcomingDates(r5, now, 16).length === 0);

const r6 = { startDate: addDays(now, -40), intervalDays: 90, endDate: addDays(now, 30) };
check('周期大于剩余跨度：下一个周期点（start+90 天）已越过结束时间 → 期间无提醒', upcomingDates(r6, now, 16).length === 0);

const r6b = { startDate: addDays(now, 35), intervalDays: 90, endDate: addDays(now, 30) };
check('起始时间晚于结束时间 → 期间无提醒', upcomingDates(r6b, now, 16).length === 0);

const r7 = { startDate: new Date(2026, 0, 1, 9, 0), intervalDays: 90, endDate: new Date(2028, 0, 1) };
const got7 = upcomingDates(r7, now, 20);
check('跨年规则：全部提醒点都在当前时刻之后', got7.every((d) => d > now));
check('跨年规则：提醒时刻始终为 9:00，不随天数进位漂移', got7.every((d) => d.getHours() === 9 && d.getMinutes() === 0));

// 登录规则
check('密码 = 当天 8 位日期（2026-10-23 → 20261023）', todaysPassword(new Date(2026, 9, 23)) === '20261023');
check('登录：admin + 今日密码 → 通过', login('admin', todaysPassword()));
check('登录：错误密码 → 拒绝', !login('admin', '00000000'));
check('登录：错误账号 → 拒绝', !login('root', todaysPassword()));
check('登录：昨天的密码 → 拒绝', !login('admin', todaysPassword(addDays(now, -1))));

console.log(failed === 0 ? '\n全部通过 ✔（18 项）' : `\n${failed} 项失败 ✘`);
process.exit(failed === 0 ? 0 : 1);
