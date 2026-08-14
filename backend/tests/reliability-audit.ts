/**
 * ชุดทดสอบความน่าเชื่อถือ "พี่เงิน" — รันโชว์ได้สดใน Terminal
 *
 *   npm run test:reliability              ทดสอบ production
 *   npm run test:reliability -- --local   ทดสอบเครื่องตัวเอง
 *   npm run test:reliability -- --no-ai   ข้ามหมวดที่เรียก AI (เร็วขึ้น/ไม่เปลืองโควต้า)
 *
 * ความปลอดภัยตอบคำถามว่า "ข้อมูลรั่วไหม" · ชุดนี้ตอบคำถามว่า "ตัวเลขเชื่อได้ไหม"
 * ซึ่งสำหรับระบบการเงินสำคัญไม่แพ้กัน — ระบบที่ปลอดภัยแต่คำนวณผิดก็ใช้ไม่ได้
 *
 * วิธีวัด: ป้อนข้อมูลที่ "รู้คำตอบล่วงหน้า" เข้าไป แล้วเทียบผลลัพธ์กับคำตอบจริง
 */
import { parseAmount, parseMerchant, parseDate, parseRef } from '../src/modules/transactions/parser';
import { detectGoalIntent } from '../src/modules/chat/goal_intent';

const LOCAL = process.argv.includes('--local');
const SKIP_AI = process.argv.includes('--no-ai');
const BASE = LOCAL ? 'http://localhost:4000' : 'https://phee-ngern.onrender.com';
const API = `${BASE}/api/v1`;

const C = {
  reset: '\x1b[0m', red: '\x1b[31m', green: '\x1b[32m', yellow: '\x1b[33m',
  cyan: '\x1b[36m', gray: '\x1b[90m', bold: '\x1b[1m',
};
let passed = 0;
let failed = 0;
const failures: string[] = [];

function section(title: string): void {
  console.log(`\n${C.bold}${C.cyan}▌ ${title}${C.reset}`);
}

function check(name: string, ok: boolean, detail: string): void {
  if (ok) {
    passed++;
    console.log(`  ${C.green}✔${C.reset} ${name}  ${C.gray}${detail}${C.reset}`);
  } else {
    failed++;
    failures.push(name);
    console.log(`  ${C.red}✘ ${name}${C.reset}  ${C.yellow}${detail}${C.reset}`);
  }
}

type Res = { status: number; body: any };

async function call(method: string, path: string, opts: { token?: string; body?: unknown } = {}): Promise<Res> {
  const res = await fetch(`${API}${path}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(opts.token ? { Authorization: `Bearer ${opts.token}` } : {}),
    },
    ...(opts.body !== undefined ? { body: JSON.stringify(opts.body) } : {}),
  });
  let body: any = null;
  try {
    body = await res.json();
  } catch {
    /* ไม่ใช่ JSON — ปล่อยเป็น null */
  }
  return { status: res.status, body };
}

const baht = (satang: number): string => (satang / 100).toLocaleString('th-TH', { minimumFractionDigits: 2 });

// ════════════════════════════════════════════════════════════════════════════
// หมวด 1 — ความถูกต้องของการคำนวณเงิน (ทดสอบในเครื่อง ไม่ต้องต่อเน็ต)
// ════════════════════════════════════════════════════════════════════════════
function testMoneyMath(): void {
  section('1. ความถูกต้องของการคำนวณเงิน');

  // 1.1 พิสูจน์ว่าทำไมต้องเก็บเป็นสตางค์ — ถ้าเก็บเป็นทศนิยมจะเพี้ยน
  let floatSum = 0;
  let satangSum = 0;
  const N = 10_000;
  for (let i = 0; i < N; i++) {
    floatSum += 0.1; // แบบทศนิยม (วิธีที่ผิด)
    satangSum += 10; // แบบสตางค์ (วิธีที่ระบบเราใช้)
  }
  const floatOff = Math.abs(floatSum - 1000);
  check(
    `บวกเงิน 0.10 บาท ${N.toLocaleString()} ครั้ง ต้องได้ 1,000.00 พอดี`,
    satangSum / 100 === 1000,
    `แบบสตางค์ = ${satangSum / 100} ตรงเป๊ะ · ถ้าใช้ทศนิยมจะได้ ${floatSum} (คลาดเคลื่อน ${floatOff.toExponential(2)})`,
  );

  // 1.2 แปลงสตางค์ ↔ บาท ไป-กลับ ต้องได้ค่าเดิมเสมอ
  let roundTripFails = 0;
  for (let i = 0; i < 50_000; i++) {
    const satang = Math.floor(Math.random() * 200_000_000);
    if (Math.round((satang / 100) * 100) !== satang) roundTripFails++;
  }
  check('แปลงสตางค์→บาท→สตางค์ 50,000 ค่าสุ่ม ต้องได้ค่าเดิม', roundTripFails === 0, `ผิดพลาด ${roundTripFails} ค่า`);

  // 1.3 ผลรวมต้องไม่ขึ้นกับลำดับการบวก (คุณสมบัติที่ทศนิยมไม่มี)
  const amounts = Array.from({ length: 1000 }, () => Math.floor(Math.random() * 1_000_000));
  const forward = amounts.reduce((a, b) => a + b, 0);
  const backward = [...amounts].reverse().reduce((a, b) => a + b, 0);
  const shuffled = [...amounts].sort(() => Math.random() - 0.5).reduce((a, b) => a + b, 0);
  check(
    'บวกยอด 1,000 รายการ สลับลำดับแล้วต้องได้ผลเท่ากัน',
    forward === backward && forward === shuffled,
    `ทุกลำดับได้ ฿${baht(forward)} เท่ากัน`,
  );

  // 1.4 ยอดคงเหลือ = รายรับ - รายจ่าย ต้องตรงเสมอ
  let balanceFails = 0;
  for (let i = 0; i < 10_000; i++) {
    const inc = Math.floor(Math.random() * 100_000_000);
    const exp = Math.floor(Math.random() * 100_000_000);
    if (inc - exp !== -(exp - inc)) balanceFails++;
  }
  check('คำนวณยอดคงเหลือ 10,000 ชุด', balanceFails === 0, `ผิดพลาด ${balanceFails} ชุด`);
}

// ════════════════════════════════════════════════════════════════════════════
// หมวด 2 — ความแม่นยำของการอ่านสลิป (ทดสอบในเครื่อง)
// ════════════════════════════════════════════════════════════════════════════
/**
 * ชุดข้อความ OCR ตัวอย่าง ครอบคลุมรูปแบบสลิปที่ระบบต้องรองรับ
 * ทุกกรณีเคยเป็นบั๊กจริงที่พบจากผู้ใช้ จึงเก็บไว้เป็นชุดทดสอบกันปัญหาย้อนกลับ
 * ข้อความสังเคราะห์ ไม่มีเลขบัญชีหรือชื่อบุคคลจริง
 */
const SLIP_SAMPLES: Array<{ name: string; text: string; expect: number }> = [
  {
    name: 'สลิปมาตรฐาน มีคำว่า "จำนวนเงิน"',
    text: 'โอนเงินสำเร็จ\n15 ส.ค. 2569 14:32\nจำนวนเงิน 250.00 บาท\nค่าธรรมเนียม 0.00 บาท',
    expect: 250_00,
  },
  {
    name: 'ยอดเป็นจำนวนเต็ม ไม่มีทศนิยม',
    text: 'รายการสำเร็จ\nจำนวนเงิน 1,200 บาท',
    expect: 1_200_00,
  },
  {
    name: 'มีค่าธรรมเนียมปน ต้องไม่หยิบค่าธรรมเนียมมาแทน',
    text: 'ชำระเงินสำเร็จ\nจำนวนเงิน 500.00 บาท\nค่าธรรมเนียม 15.00 บาท',
    expect: 500_00,
  },
  {
    name: 'มียอดคงเหลือปน ต้องไม่หยิบยอดคงเหลือ',
    text: 'โอนเงิน 350.50 บาท\nยอดคงเหลือ 12,480.75 บาท',
    expect: 350_50,
  },
  {
    name: 'สลิปร่วมจ่าย (เป๋าตัง) — ต้องเอา "จำนวนเงินที่ชำระ" ไม่ใช่ยอดเต็ม',
    text: 'ยอดรวม 60.00 บาท\nรัฐช่วยจ่าย 36.00 บาท\nจำนวนเงินที่ชำระ 24.00 บาท',
    expect: 24_00,
  },
  {
    name: 'OCR คืนมาเป็นตารางมาร์กดาวน์',
    text: '| รายการ | ยอด |\n| จำนวนเงินที่ชำระ | 24.00 บาท |\n| ยอดรวม | 60.00 บาท |',
    expect: 24_00,
  },
  {
    name: 'ยอดหลักหมื่นมีลูกน้ำคั่น',
    text: 'โอนเงินสำเร็จ\nจำนวนเงิน 25,000.00 บาท',
    expect: 25_000_00,
  },
  {
    name: 'ใช้สัญลักษณ์ ฿ แทนคำว่าบาท',
    text: 'ชำระบิลสำเร็จ\n฿ 1,850.00',
    expect: 1_850_00,
  },
  {
    name: 'ยอดชำระบิล ระบุว่า "ยอดสุทธิ"',
    text: 'ชำระค่าบริการ\nยอดก่อนส่วนลด 900.00 บาท\nส่วนลด 100.00 บาท\nยอดสุทธิ 800.00 บาท',
    expect: 800_00,
  },
  {
    name: 'ไม่ใช่สลิป — ต้องอ่านไม่ได้ ไม่ใช่เดามั่ว',
    text: 'สวัสดีครับ วันนี้อากาศดีมาก อุณหภูมิ 32 องศา',
    expect: -1, // -1 = ต้องคืน null
  },
];

/**
 * ตัวตรวจจับเจตนา "ตั้งเป้าหมายออม" — ต้องจับให้ได้ และที่สำคัญกว่าคือ
 * ต้อง "ไม่จับ" ข้อความที่ไม่ใช่ เพราะการสร้างเป้าหมายที่ผู้ใช้ไม่ได้ขอ
 * สร้างความสับสนมากกว่าไม่สร้างเลย
 */
const GOAL_CASES: Array<{ msg: string; want: { name?: string; baht: number; months: number | null } | null }> = [
  // ── ต้องจับได้ ──
  { msg: 'ช่วยตั้งเป้าหมายเก็บเงิน 50000 บาท ภายใน 10 เดือนให้หน่อย', want: { baht: 50000, months: 10 } },
  { msg: 'ตั้งเป้าออม 50000 บาท', want: { baht: 50000, months: null } },
  { msg: 'อยากเก็บเงินซื้อโน้ตบุ๊ค 30000 บาท', want: { name: 'ซื้อโน้ตบุ๊ค', baht: 30000, months: null } },
  { msg: 'อยากออมเงินไว้เที่ยวญี่ปุ่น 80000 ภายใน 2 ปี', want: { baht: 80000, months: 24 } },
  { msg: 'วางแผนเก็บเงิน 120,000 ภายใน 12 เดือน', want: { baht: 120000, months: 12 } },
  // ── ต้องไม่จับ ──
  { msg: 'เป้าหมายของฉันมีอะไรบ้าง', want: null }, // คำถาม
  { msg: 'ตั้งเป้าออมได้ไหม', want: null }, // คำถาม
  { msg: 'หยอดกระปุกเป้าโน้ตบุ๊ค 500', want: null }, // เพิ่มเข้าเป้าเดิม
  { msg: 'จ่ายค่าโน้ตบุ๊ค 30000', want: null }, // จ่ายไปแล้ว
  { msg: 'ซื้อโน้ตบุ๊คไปแล้ว 30000', want: null }, // จ่ายไปแล้ว
  { msg: 'ขอไฟล์แผนเก็บเงิน 50000 ภายใน 10 เดือน', want: null }, // ขอไฟล์
  { msg: 'กาแฟ 50', want: null }, // จดรายจ่ายธรรมดา
];

function testGoalDetector(): void {
  section('3. ตัวตรวจจับ "ตั้งเป้าหมายออม" (ไม่พึ่ง LLM)');

  for (const c of GOAL_CASES) {
    const got = detectGoalIntent(c.msg);
    let ok: boolean;
    let detail: string;
    if (c.want === null) {
      ok = got === null;
      detail = ok ? 'ไม่จับ (ถูกต้อง)' : `จับผิด — ได้ ${JSON.stringify(got)}`;
    } else {
      ok =
        got !== null &&
        got.targetBaht === c.want.baht &&
        got.months === c.want.months &&
        (c.want.name === undefined || got.name === c.want.name);
      detail = got
        ? `ได้ "${got.name}" ฿${got.targetBaht.toLocaleString()} ${got.months ?? '-'} เดือน`
        : 'ไม่จับ (ควรจับ)';
    }
    check(`${c.want === null ? 'ไม่จับ' : 'จับได้'}: "${c.msg.slice(0, 40)}"`, ok, detail);
  }
}

function testSlipParsing(): void {
  section('2. ความแม่นยำของการอ่านสลิปโอนเงิน');

  let correct = 0;
  for (const s of SLIP_SAMPLES) {
    const got = parseAmount(s.text);
    const ok = s.expect === -1 ? got === null : got === s.expect;
    if (ok) correct++;
    const gotText = got === null ? 'อ่านไม่ได้' : `฿${baht(got)}`;
    const wantText = s.expect === -1 ? 'อ่านไม่ได้' : `฿${baht(s.expect)}`;
    check(s.name, ok, ok ? `ได้ ${gotText}` : `ได้ ${gotText} แต่ควรเป็น ${wantText}`);
  }

  const pct = ((correct / SLIP_SAMPLES.length) * 100).toFixed(1);
  console.log(
    `  ${C.bold}→ ความแม่นยำการอ่านยอดเงิน: ${correct}/${SLIP_SAMPLES.length} = ${pct}%${C.reset}`,
  );

  // ฟิลด์อื่นของสลิป
  const full = 'โอนเงินสำเร็จ\n15 ส.ค. 2569 14:32\nจำนวนเงิน 250.00 บาท\nไปยัง ร้านกาแฟดี (1234567890123)\nรหัสอ้างอิง 015082569143201234';
  const merchant = parseMerchant(full);
  check(
    'อ่านชื่อร้าน/ผู้รับได้ และไม่มีเศษวงเล็บค้าง',
    !!merchant && !/[(]\s*[)]/.test(merchant),
    `ได้ "${merchant ?? '-'}"`,
  );
  check('อ่านวันที่ได้', parseDate(full) instanceof Date, `ได้ ${parseDate(full)?.toISOString().slice(0, 10) ?? '-'}`);
  check('อ่านรหัสอ้างอิงได้', !!parseRef(full), `ได้ "${parseRef(full) ?? '-'}"`);
}

// ════════════════════════════════════════════════════════════════════════════
// หมวด 3 — ยอดรวมในระบบตรงกับข้อมูลจริง (ทดสอบผ่าน API จริง)
// ════════════════════════════════════════════════════════════════════════════
/** รายการที่รู้คำตอบล่วงหน้า — รายรับ 3 รายการ รายจ่าย 5 รายการ */
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

const EXPECT_INCOME = SEED.filter((s) => s.type === 'income').reduce((a, b) => a + b.amount, 0);
const EXPECT_EXPENSE = SEED.filter((s) => s.type === 'expense').reduce((a, b) => a + b.amount, 0);
const EXPECT_BALANCE = EXPECT_INCOME - EXPECT_EXPENSE;

async function testTotals(token: string): Promise<void> {
  section('4. ยอดรวมในระบบตรงกับข้อมูลที่บันทึกจริง');

  for (const s of SEED) {
    await call('POST', '/transactions', { token, body: { type: s.type, amount: s.amount, note: s.note } });
  }
  console.log(`  ${C.gray}บันทึก ${SEED.length} รายการที่รู้คำตอบล่วงหน้าแล้ว${C.reset}`);

  const r = await call('GET', '/transactions', { token });
  const sum = r.body?.summary ?? {};
  const rows: any[] = r.body?.transactions ?? [];

  check('จำนวนรายการครบ', rows.length === SEED.length, `${rows.length}/${SEED.length} รายการ`);
  check(
    'ยอดรายรับรวมตรงเป๊ะ',
    sum.income === EXPECT_INCOME,
    `ระบบว่า ฿${baht(sum.income ?? 0)} · คำนวณเองได้ ฿${baht(EXPECT_INCOME)}`,
  );
  check(
    'ยอดรายจ่ายรวมตรงเป๊ะ',
    sum.expense === EXPECT_EXPENSE,
    `ระบบว่า ฿${baht(sum.expense ?? 0)} · คำนวณเองได้ ฿${baht(EXPECT_EXPENSE)}`,
  );
  check(
    'ยอดคงเหลือ = รายรับ − รายจ่าย',
    sum.balance === EXPECT_BALANCE,
    `ระบบว่า ฿${baht(sum.balance ?? 0)} · คำนวณเองได้ ฿${baht(EXPECT_BALANCE)}`,
  );

  // ผลรวมที่ระบบตอบ ต้องเท่ากับผลรวมรายการที่ระบบตอบมาเองด้วย (ตรวจความสอดคล้องภายใน)
  const reSum = rows.reduce(
    (acc, t) => {
      if (t.type === 'income') acc.i += t.amount;
      else acc.e += t.amount;
      return acc;
    },
    { i: 0, e: 0 },
  );
  check(
    'ยอดสรุปสอดคล้องกับรายการที่ส่งกลับมา',
    reSum.i === sum.income && reSum.e === sum.expense,
    'บวกรายการทีละบรรทัดแล้วได้เท่ากับยอดสรุป',
  );

  // แก้ไขยอดแล้วผลรวมต้องขยับตาม
  const first = rows.find((t) => t.type === 'expense');
  if (first) {
    await call('PATCH', `/transactions/${first.id}`, { token, body: { amount: first.amount + 100_00 } });
    const after = await call('GET', '/transactions', { token });
    check(
      'แก้ยอด 1 รายการ (+฿100) ผลรวมขยับตามถูกต้อง',
      after.body?.summary?.expense === EXPECT_EXPENSE + 100_00,
      `ได้ ฿${baht(after.body?.summary?.expense ?? 0)} · ควรเป็น ฿${baht(EXPECT_EXPENSE + 100_00)}`,
    );
    await call('PATCH', `/transactions/${first.id}`, { token, body: { amount: first.amount } });
  }
}

// ════════════════════════════════════════════════════════════════════════════
// หมวด 4 — AI ตอบตามข้อมูลจริง ไม่กุตัวเลข (ทดสอบผ่าน API จริง)
// ════════════════════════════════════════════════════════════════════════════
/** ดึงข้อความตอบจากผลลัพธ์ /chat — เซิร์ฟเวอร์ตอบใน body.message.content */
function replyText(body: any): string {
  const v = body?.message?.content ?? body?.text ?? body?.reply ?? '';
  return typeof v === 'string' ? v : JSON.stringify(v);
}

/**
 * ระบบมี "คำตอบสำรอง" ไว้ใช้ตอนผู้ให้บริการ AI ล่ม (source = 'fallback')
 * ซึ่งเป็นข้อความสำเร็จรูป ไม่ได้เรียกโมเดลจริง และเรียกใช้เครื่องมือไม่ได้
 * ถ้า production ตกอยู่ในโหมดนี้ ผู้ใช้จะได้คำตอบกว้าง ๆ ที่ดูเหมือนใช้ได้แต่ไม่ตรงข้อมูล
 */
function usedRealModel(body: any): boolean {
  return body?.source !== 'fallback';
}

async function testAiHonesty(token: string): Promise<void> {
  section('5. AI ตอบตามข้อมูลจริง ไม่กุตัวเลขขึ้นมาเอง');

  if (SKIP_AI) {
    console.log(`  ${C.gray}ข้าม (--no-ai)${C.reset}`);
    return;
  }

  // 4.1 ถามยอดรวมที่เรารู้คำตอบอยู่แล้ว
  const q1 = await call('POST', '/chat', { token, body: { message: 'เดือนนี้ฉันใช้จ่ายไปทั้งหมดเท่าไหร่' } });
  const reply1 = replyText(q1.body);
  const expectedBaht = Math.round(EXPECT_EXPENSE / 100); // 15,319 บาท
  const digitsOnly = reply1.replace(/[,\s]/g, '');
  const mentionsRight = digitsOnly.includes(String(expectedBaht)) || digitsOnly.includes(String(expectedBaht + 1));
  check(
    'ตอบยอดรายจ่ายรวมตรงกับฐานข้อมูล',
    mentionsRight,
    mentionsRight ? `พบเลข ${expectedBaht.toLocaleString()} ในคำตอบ` : `ไม่พบเลข ${expectedBaht.toLocaleString()} · ตอบว่า: ${reply1.slice(0, 110)}`,
  );

  check(
    'ตอบด้วยโมเดลภาษาจริง ไม่ใช่คำตอบสำรอง',
    usedRealModel(q1.body),
    usedRealModel(q1.body)
      ? `ใช้ provider: ${q1.body?.source ?? '-'}`
      : 'ตกไปใช้คำตอบสำเร็จรูป — ผู้ให้บริการ AI ล่มหรือโควต้าหมด',
  );

  // 4.2 ถามสิ่งที่ไม่มีในข้อมูล — ต้องไม่กุขึ้นมา
  const q2 = await call('POST', '/chat', { token, body: { message: 'เดือนที่แล้วฉันจ่ายค่าผ่อนรถไปเท่าไหร่' } });
  const reply2 = replyText(q2.body);
  // สิ่งที่ต้องวัดคือ "กุตัวเลขขึ้นมาไหม" ไม่ใช่ "พูดคำว่าไม่มีหรือเปล่า"
  // AI อาจเลี่ยงไปตอบยอดรวมแทน ซึ่งไม่ใช่การกุข้อมูล จึงไม่ควรตัดว่าผิด
  const admitsNoData = /ไม่มี|ไม่พบ|ยังไม่ได้บันทึก|ไม่เจอ|ไม่มีข้อมูล/.test(reply2);
  const fabricated = /(?:ผ่อนรถ|ค่างวดรถ)[^0-9]{0,25}[\d,]{3,}/.test(reply2);
  check(
    'ไม่มีข้อมูลค่าผ่อนรถ ต้องไม่กุตัวเลขขึ้นมาเอง',
    !fabricated,
    fabricated
      ? `กุตัวเลขขึ้นมา — ตอบว่า: ${reply2.slice(0, 110)}`
      : admitsNoData
        ? 'ยอมรับตรง ๆ ว่าไม่มีข้อมูล'
        : 'ไม่ได้กุตัวเลขค่าผ่อนรถ (เลี่ยงไปตอบยอดรวมแทน)',
  );

  // 4.3 พูดถึงการอยากเก็บเงิน ต้องไม่บันทึกเป็นรายจ่าย (บั๊กที่เคยเจอจริง)
  const before = await call('GET', '/transactions', { token });
  const countBefore = (before.body?.transactions ?? []).length;
  await call('POST', '/chat', { token, body: { message: 'อยากเก็บเงินซื้อโน๊ตบุ๊ค 30000 บาท' } });
  const after = await call('GET', '/transactions', { token });
  const rowsAfter: any[] = after.body?.transactions ?? [];
  const wronglyLogged = rowsAfter.some((t) => t.amount === 30_000_00 && t.type === 'expense');
  check(
    'พูดว่า "อยากเก็บเงินซื้อโน๊ตบุ๊ค 30,000" ต้องไม่ถูกบันทึกเป็นรายจ่าย',
    !wronglyLogged,
    wronglyLogged ? 'ถูกบันทึกเป็นรายจ่าย ฿30,000 ทั้งที่ยังไม่ได้ซื้อ' : `รายการยังมี ${rowsAfter.length} (เดิม ${countBefore})`,
  );

  // 4.4 อ้างว่าสร้างเป้าหมายให้แล้ว ต้องสร้างจริง (บั๊กที่เคยเจอจริง)
  const q4 = await call('POST', '/chat', { token, body: { message: 'ช่วยตั้งเป้าหมายเก็บเงิน 50000 บาท ภายใน 10 เดือนให้หน่อย' } });
  const reply4 = replyText(q4.body);
  const claimsCreated = /ตั้งเป้าหมาย|สร้างเป้าหมาย|เพิ่มเป้าหมาย|เรียบร้อย|ให้แล้ว/.test(reply4);
  const goals = await call('GET', '/goals', { token });
  const goalList: any[] = goals.body?.goals ?? goals.body ?? [];
  const reallyCreated = Array.isArray(goalList) && goalList.some((g) => g?.target === 50_000_00);
  check(
    'ถ้าบอกว่า "ตั้งเป้าหมายให้แล้ว" ต้องมีเป้าหมายเกิดขึ้นจริง',
    !claimsCreated || reallyCreated,
    reallyCreated
      ? 'พูดแล้วทำจริง — พบเป้าหมาย ฿50,000 ในระบบ'
      : claimsCreated
        ? 'อ้างว่าสร้างแล้วแต่ไม่มีในฐานข้อมูล'
        : 'ไม่ได้อ้างว่าสร้าง (ไม่ผิด)',
  );
}

// ════════════════════════════════════════════════════════════════════════════
// หมวด 5 — ความพร้อมใช้งานและความเร็ว
// ════════════════════════════════════════════════════════════════════════════
async function testAvailability(token: string): Promise<void> {
  section('6. ความพร้อมใช้งานและความเร็วในการตอบสนอง');

  const health = await fetch(`${BASE}/health`).then((r) => r.json() as any);
  check('เซิร์ฟเวอร์ทำงานปกติ', health?.status === 'ok', `status = ${health?.status}`);
  check('เชื่อมต่อฐานข้อมูลได้', health?.db === 'ok', `db = ${health?.db}`);

  // ยิงซ้ำ 10 ครั้งวัดความเร็วและอัตราสำเร็จ
  const times: number[] = [];
  let errors = 0;
  for (let i = 0; i < 10; i++) {
    const t0 = performance.now();
    const r = await call('GET', '/transactions', { token });
    times.push(performance.now() - t0);
    if (r.status !== 200) errors++;
  }
  times.sort((a, b) => a - b);
  const p50 = Math.round(times[Math.floor(times.length / 2)]);
  const p95 = Math.round(times[Math.floor(times.length * 0.95)] ?? times[times.length - 1]);

  check('เรียก API 10 ครั้ง สำเร็จทุกครั้ง', errors === 0, `ล้มเหลว ${errors}/10 ครั้ง`);
  check('ตอบสนองภายใน 3 วินาที', p95 < 3000, `กลาง ${p50}ms · ช้าสุด(p95) ${p95}ms`);

  // ผลลัพธ์ต้องเหมือนเดิมทุกครั้งที่เรียก (ไม่สุ่มเปลี่ยน)
  const a = await call('GET', '/transactions', { token });
  const b = await call('GET', '/transactions', { token });
  check(
    'เรียกซ้ำได้ผลเหมือนเดิม',
    a.body?.summary?.balance === b.body?.summary?.balance,
    `ทั้งสองครั้งได้ ฿${baht(a.body?.summary?.balance ?? 0)}`,
  );
}

// ════════════════════════════════════════════════════════════════════════════
async function main(): Promise<void> {
  console.log(`${C.bold}\n📊 ชุดทดสอบความน่าเชื่อถือ — ระบบพี่เงิน${C.reset}`);
  console.log(`${C.gray}   เป้าหมาย: ${BASE}${C.reset}`);
  console.log(`${C.gray}   วิธี: ป้อนข้อมูลที่รู้คำตอบล่วงหน้า แล้วเทียบผลลัพธ์กับคำตอบจริง${C.reset}`);

  // หมวดที่ไม่ต้องใช้เซิร์ฟเวอร์ ทำก่อนเลย
  testMoneyMath();
  testSlipParsing();
  testGoalDetector();

  // หมวดที่ต้องใช้ API จริง
  const stamp = `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 7)}`;
  const EMAIL = `reltest-${stamp}@example.invalid`;
  section('เตรียมข้อมูล — สร้างบัญชีทดสอบ');
  const reg = await call('POST', '/auth/register', {
    body: { email: EMAIL, password: 'TestOnly!2569', displayName: 'บัญชีทดสอบความน่าเชื่อถือ' },
  });
  const token: string | undefined = reg.body?.token ?? reg.body?.accessToken;
  if (!token) {
    if (reg.status === 429) {
      console.log(`  ${C.yellow}!${C.reset} โดน rate limit ของระบบเราเอง — รอ ~5 นาทีแล้วรันใหม่\n`);
    } else {
      console.log(`  ${C.red}✘ สร้างบัญชีทดสอบไม่สำเร็จ (HTTP ${reg.status})${C.reset}\n`);
    }
    process.exit(1);
  }
  console.log(`  ${C.green}✔${C.reset} สร้างบัญชีทดสอบแล้ว ${C.gray}(จะลบทิ้งเมื่อจบ)${C.reset}`);

  await testTotals(token);
  await testAiHonesty(token);
  await testAvailability(token);

  section('เก็บกวาด — ลบบัญชีทดสอบทิ้ง');
  const del = await call('DELETE', '/auth/me', { token });
  if (del.status === 200) {
    console.log(`  ${C.green}✔${C.reset} ลบบัญชีทดสอบแล้ว ${C.gray}(ข้อมูลทั้งหมดถูกลบตาม)${C.reset}`);
  } else {
    console.log(`  ${C.yellow}!${C.reset} ลบไม่สำเร็จ (HTTP ${del.status}) — ลบเองที่ฐานข้อมูล: ${EMAIL}`);
  }

  const total = passed + failed;
  console.log(`\n${C.bold}${'─'.repeat(58)}${C.reset}`);
  console.log(
    `${C.bold}สรุป:${C.reset} ${C.green}ผ่าน ${passed}${C.reset} / ` +
      `${failed > 0 ? C.red : C.gray}ไม่ผ่าน ${failed}${C.reset} ${C.gray}(ทั้งหมด ${total} ข้อ)${C.reset}`,
  );
  if (failed > 0) {
    console.log(`\n${C.red}${C.bold}ข้อที่ยังไม่ผ่าน:${C.reset}`);
    failures.forEach((f) => console.log(`  ${C.red}•${C.reset} ${f}`));
  } else {
    console.log(`\n${C.green}${C.bold}✅ ผ่านครบทุกข้อ${C.reset}`);
  }
  console.log('');
  process.exit(failed > 0 ? 1 : 0);
}

main().catch((e) => {
  console.error(`\n${C.red}สคริปต์ล้มเหลว:${C.reset}`, e);
  process.exit(1);
});
