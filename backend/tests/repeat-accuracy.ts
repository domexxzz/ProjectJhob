/**
 * ทดสอบ "ถามคำถามเดิมซ้ำ N ครั้ง" — วัดความแม่นยำ + ความนิ่งของพี่เงินเป็นสถิติ
 *
 *   npm run test:repeat                 ถามซ้ำ 100 ครั้ง (production)
 *   npm run test:repeat -- --n 50       กำหนดจำนวนครั้ง
 *   npm run test:repeat -- --local      ทดสอบเครื่องตัวเอง
 *   npm run test:repeat -- --delay 1000 หน่วงระหว่างคำถาม (ms) กัน rate limit
 *   npm run test:repeat -- --q "..."    เปลี่ยนคำถาม (ถ้าเปลี่ยนต้องกำหนด --expect เป็นบาทด้วย)
 *
 * ตอบโจทย์: "ถามคำถามเดิม 100 ครั้ง จะได้ความแม่นยำเท่าไหร่"
 * วิธี: ป้อนข้อมูลที่รู้คำตอบล่วงหน้า → ถามคำถามเดิมซ้ำ ๆ → นับว่าตอบตรงกี่ครั้ง
 *       ระบบ AI มีความสุ่ม (non-deterministic) การวัดซ้ำหลายครั้งจึงสะท้อนความน่าเชื่อถือจริง
 */
const args = process.argv.slice(2);
function argVal(name: string, def: string): string {
  const i = args.indexOf(name);
  return i >= 0 && args[i + 1] ? args[i + 1] : def;
}
const LOCAL = args.includes('--local');
const N = Math.max(1, parseInt(argVal('--n', '100'), 10) || 100);
const DELAY = Math.max(0, parseInt(argVal('--delay', '900'), 10) || 900);
const BASE = LOCAL ? 'http://localhost:4000' : 'https://phee-ngern.onrender.com';
const API = `${BASE}/api/v1`;

const C = {
  reset: '\x1b[0m', red: '\x1b[31m', green: '\x1b[32m', yellow: '\x1b[33m',
  cyan: '\x1b[36m', gray: '\x1b[90m', bold: '\x1b[1m', blue: '\x1b[34m',
};

type Res = { status: number; body: any };
async function call(method: string, path: string, opts: { token?: string; body?: unknown } = {}): Promise<Res> {
  const res = await fetch(`${API}${path}`, {
    method,
    headers: { 'Content-Type': 'application/json', ...(opts.token ? { Authorization: `Bearer ${opts.token}` } : {}) },
    ...(opts.body !== undefined ? { body: JSON.stringify(opts.body) } : {}),
  });
  let body: any = null;
  try { body = await res.json(); } catch { /* not json */ }
  return { status: res.status, body };
}
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));
const baht = (satang: number): string => (satang / 100).toLocaleString('th-TH', { minimumFractionDigits: 2 });
function replyText(body: any): string {
  const v = body?.message?.content ?? body?.text ?? body?.reply ?? '';
  return typeof v === 'string' ? v : JSON.stringify(v);
}
function mentionsBaht(reply: string, satang: number): boolean {
  const digits = reply.replace(/[^\d]/g, '');
  const floorB = Math.floor(satang / 100);
  return [floorB, floorB + 1].some((n) => digits.includes(String(n)));
}

// ข้อมูลที่รู้คำตอบล่วงหน้า
const SEED = [
  { type: 'income', amount: 25_000_00, note: 'เงินเดือน' },
  { type: 'income', amount: 3_500_00, note: 'งานพิเศษ' },
  { type: 'income', amount: 1_250_50, note: 'ขายของมือสอง' },
  { type: 'expense', amount: 8_500_00, note: 'ค่าหอ' },
  { type: 'expense', amount: 4_200_25, note: 'ค่ากิน' },
  { type: 'expense', amount: 1_899_00, note: 'ค่าเดินทาง' },
  { type: 'expense', amount: 599_99, note: 'ค่าเน็ต' },
  { type: 'expense', amount: 120_01, note: 'ค่ากาแฟ' },
] as const;
const EXPECT_EXPENSE = SEED.filter((s) => s.type === 'expense').reduce((a, b) => a + b.amount, 0);

const QUESTION = argVal('--q', 'เดือนนี้ฉันใช้จ่ายไปทั้งหมดเท่าไหร่');
const EXPECT_BAHT = parseInt(argVal('--expect', String(Math.floor(EXPECT_EXPENSE / 100))), 10);
const EXPECT_SATANG = EXPECT_BAHT * 100;

// หมวดผลลัพธ์ของแต่ละครั้ง
type Outcome = 'correct' | 'scope_refused' | 'fallback' | 'wrong';
const OUT_LABEL: Record<Outcome, string> = {
  correct: 'ตอบถูก (ตรงข้อมูล)',
  scope_refused: 'ถูกปฏิเสธผิด (scope-guard)',
  fallback: 'AI ล่ม (คำตอบสำรอง)',
  wrong: 'เลขผิด / ไม่ระบุ',
};
const OUT_COLOR: Record<Outcome, string> = { correct: C.green, scope_refused: C.yellow, fallback: C.red, wrong: C.red };

function classify(body: any): Outcome {
  const source = body?.source ?? '';
  const reply = replyText(body);
  if (source === 'finance-scope-guard') return 'scope_refused';
  if (source === 'fallback') return 'fallback';
  if (mentionsBaht(reply, EXPECT_SATANG)) return 'correct';
  return 'wrong';
}

function pctile(sorted: number[], p: number): number {
  if (!sorted.length) return 0;
  const idx = Math.min(sorted.length - 1, Math.floor(sorted.length * p));
  return sorted[idx];
}

async function main(): Promise<void> {
  console.log(`${C.bold}\n🔁 ทดสอบถามคำถามเดิมซ้ำ ${N} ครั้ง — พี่เงิน${C.reset}`);
  console.log(`${C.gray}   คำถาม: "${QUESTION}"${C.reset}`);
  console.log(`${C.gray}   คำตอบที่ถูก: ${baht(EXPECT_SATANG)} บาท · เป้าหมาย: ${BASE}${C.reset}`);

  // เตรียมบัญชี + ข้อมูล
  const stamp = `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 7)}`;
  const EMAIL = `reptest-${stamp}@example.invalid`;
  const reg = await call('POST', '/auth/register', {
    body: { email: EMAIL, password: 'TestOnly!2569', displayName: 'บัญชีทดสอบซ้ำ 100 ครั้ง' },
  });
  const token: string | undefined = reg.body?.token ?? reg.body?.accessToken;
  if (!token) {
    console.log(`${C.red}✘ สร้างบัญชีทดสอบไม่สำเร็จ (HTTP ${reg.status})${C.reset}\n`);
    process.exit(1);
  }
  for (const s of SEED) {
    await call('POST', '/transactions', { token, body: { type: s.type, amount: s.amount, note: s.note } });
  }
  console.log(`${C.gray}   เตรียมบัญชี + ${SEED.length} ธุรกรรมแล้ว · เริ่มยิงคำถาม...${C.reset}\n`);

  const counts: Record<Outcome, number> = { correct: 0, scope_refused: 0, fallback: 0, wrong: 0 };
  const latencies: number[] = [];
  let rateLimited = 0;

  for (let i = 1; i <= N; i++) {
    let t0 = Date.now();
    let r = await call('POST', '/chat', { token, body: { message: QUESTION } });
    // เจอ rate limit ของระบบเราเอง → รอแล้วยิงใหม่ (ไม่นับเป็นตอบผิด)
    if (r.status === 429) {
      rateLimited++;
      process.stdout.write(`${C.yellow}[rate limit — รอ 60s]${C.reset} `);
      await sleep(60_000);
      t0 = Date.now(); // reset นาฬิกา: วัดเฉพาะเวลายิงจริง ไม่รวมเวลารอ rate limit
      r = await call('POST', '/chat', { token, body: { message: QUESTION } });
    }
    latencies.push(Date.now() - t0);
    const outcome = classify(r.body);
    counts[outcome]++;

    // แถบความคืบหน้าแบบสด
    const mark = outcome === 'correct' ? `${C.green}●${C.reset}` : outcome === 'scope_refused' ? `${C.yellow}●${C.reset}` : `${C.red}●${C.reset}`;
    process.stdout.write(mark);
    if (i % 20 === 0) process.stdout.write(` ${i}/${N}\n`);
    if (DELAY) await sleep(DELAY);
  }
  if (N % 20 !== 0) process.stdout.write('\n');

  // เก็บกวาด
  await call('DELETE', '/auth/me', { token });

  // ── สรุปสถิติ ──
  const done = counts.correct + counts.scope_refused + counts.fallback + counts.wrong;
  const accPct = ((counts.correct / done) * 100).toFixed(1);
  latencies.sort((a, b) => a - b);
  const avg = Math.round(latencies.reduce((a, b) => a + b, 0) / latencies.length);

  console.log(`\n${C.bold}${'═'.repeat(60)}${C.reset}`);
  console.log(`${C.bold}📈 ผลถามซ้ำ ${done} ครั้ง — "${QUESTION.slice(0, 34)}"${C.reset}`);
  console.log(`${C.bold}${'─'.repeat(60)}${C.reset}`);
  (Object.keys(counts) as Outcome[]).forEach((o) => {
    const n = counts[o];
    const pct = Math.round((n / done) * 100);
    const bars = Math.round((n / done) * 30);
    const bar = '█'.repeat(bars) + '░'.repeat(30 - bars);
    console.log(`  ${OUT_COLOR[o]}${OUT_LABEL[o].padEnd(28, ' ')}${C.reset} ${String(n).padStart(3)}/${done}  ${String(pct).padStart(3)}%  ${OUT_COLOR[o]}${bar}${C.reset}`);
  });
  console.log(`${C.bold}${'─'.repeat(60)}${C.reset}`);
  const accColor = Number(accPct) >= 95 ? C.green : Number(accPct) >= 80 ? C.yellow : C.red;
  console.log(`  ${C.bold}ความแม่นยำ (Accuracy):${C.reset} ${accColor}${counts.correct}/${done} = ${accPct}%${C.reset}`);
  if (counts.scope_refused > 0) {
    console.log(`  ${C.yellow}⚠ ถูก scope-guard ปฏิเสธผิด ${counts.scope_refused} ครั้ง (${Math.round((counts.scope_refused / done) * 100)}%) — บั๊กที่ทำให้คำตอบไม่นิ่ง${C.reset}`);
  }
  console.log(`  ${C.bold}เวลาตอบสนอง:${C.reset} เฉลี่ย ${avg}ms · กลาง(p50) ${pctile(latencies, 0.5)}ms · ช้าสุด(p95) ${pctile(latencies, 0.95)}ms`);
  if (rateLimited) console.log(`  ${C.gray}(เจอ rate limit ระหว่างทาง ${rateLimited} ครั้ง — รอแล้วยิงใหม่ ไม่นับเป็นตอบผิด)${C.reset}`);
  console.log('');
  process.exit(0);
}

main().catch((e) => {
  console.error(`\n${C.red}สคริปต์ล้มเหลว:${C.reset}`, e);
  process.exit(1);
});
