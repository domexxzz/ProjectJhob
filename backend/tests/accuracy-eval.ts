/**
 * ชุดวัด "ความแม่นยำ + การกุข้อมูล (hallucination)" ของพี่เงิน — รันโชว์ได้สดใน Terminal
 *
 *   npm run test:accuracy               วัดกับ production
 *   npm run test:accuracy -- --local    วัดกับเครื่องตัวเอง (http://localhost:4000)
 *   npm run test:accuracy -- --judge     เปิดชั้น LLM-as-judge (ให้ AI อีกตัวตรวจว่ากุข้อมูลไหม)
 *   npm run test:accuracy -- --verbose   พิมพ์คำตอบเต็มของพี่เงินทุกข้อ
 *
 * ต่างจาก reliability-audit อย่างไร:
 *   reliability เน้น "ระบบคำนวณ/ตอบตรงข้อมูลไหม" แบบข้อ ๆ
 *   ชุดนี้เป็น "eval set" เต็มรูปแบบ — มีชุดคำถามมาตรฐานที่รู้คำตอบล่วงหน้า
 *   วัดเป็น 5 มิติ แล้วสรุปเป็น "scorecard" (accuracy % ต่อมิติ + hallucination rate)
 *   ซึ่งเป็นวิธีมาตรฐานที่ใช้ประเมินระบบ LLM ในงานจริง
 *
 * วิธีวัด: ป้อนข้อมูลการเงินที่ "รู้คำตอบล่วงหน้า" → ถามพี่เงิน → เทียบคำตอบกับความจริง
 *          กรณีที่ "ไม่มีข้อมูล" ก็ถามด้วย เพื่อดูว่ามันกุตัวเลขขึ้นมาเองหรือยอมรับตรง ๆ
 */
import { env } from '../src/config/env';

const LOCAL = process.argv.includes('--local');
const JUDGE = process.argv.includes('--judge');
const VERBOSE = process.argv.includes('--verbose');
const BASE = LOCAL ? 'http://localhost:4000' : 'https://phee-ngern.onrender.com';
const API = `${BASE}/api/v1`;

const C = {
  reset: '\x1b[0m', red: '\x1b[31m', green: '\x1b[32m', yellow: '\x1b[33m',
  cyan: '\x1b[36m', gray: '\x1b[90m', bold: '\x1b[1m', dim: '\x1b[2m',
};

// ── มิติที่วัด ──────────────────────────────────────────────────────────────
type Dim = 'numeric' | 'grounding' | 'tool' | 'scope' | 'consistency';
const DIM_LABEL: Record<Dim, string> = {
  numeric: 'ตอบตัวเลขตรงข้อมูล',
  grounding: 'ไม่กุข้อมูล (grounding)',
  tool: 'เรียกเครื่องมือถูกต้อง',
  scope: 'กันคำถามนอกเรื่องเงิน',
  consistency: 'ถามซ้ำได้คำตอบเดิม',
};
const score: Record<Dim, { pass: number; total: number }> = {
  numeric: { pass: 0, total: 0 }, grounding: { pass: 0, total: 0 },
  tool: { pass: 0, total: 0 }, scope: { pass: 0, total: 0 },
  consistency: { pass: 0, total: 0 },
};
let fabrications = 0; // จำนวนครั้งที่ "กุตัวเลข" (ตัวตั้งของ hallucination rate)
const failures: string[] = [];

function section(title: string): void {
  console.log(`\n${C.bold}${C.cyan}▌ ${title}${C.reset}`);
}

function record(dim: Dim, name: string, ok: boolean, detail: string): void {
  score[dim].total++;
  if (ok) {
    score[dim].pass++;
    console.log(`  ${C.green}✔${C.reset} ${name}\n    ${C.gray}${detail}${C.reset}`);
  } else {
    failures.push(name);
    console.log(`  ${C.red}✘ ${name}${C.reset}\n    ${C.yellow}${detail}${C.reset}`);
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
  try { body = await res.json(); } catch { /* ไม่ใช่ JSON */ }
  return { status: res.status, body };
}

/** ดึงข้อความตอบจาก /chat — เซิร์ฟเวอร์ตอบใน body.message.content */
function replyText(body: any): string {
  const v = body?.message?.content ?? body?.text ?? body?.reply ?? '';
  return typeof v === 'string' ? v : JSON.stringify(v);
}
/** source = 'fallback' คือ AI ล่ม/โควต้าหมด → ใช้คำตอบสำเร็จรูป ไม่ได้เรียกโมเดลจริง */
function usedRealModel(body: any): boolean {
  const s = body?.source ?? '';
  return s !== 'fallback';
}
const baht = (satang: number): string => (satang / 100).toLocaleString('th-TH', { minimumFractionDigits: 2 });
/** คำตอบมีเลขจำนวนนี้ (บาท) ไหม — ตัดลูกน้ำ/ช่องว่างออกก่อนเทียบ ยอมรับปัดเศษ ±1 */
function mentionsBaht(reply: string, satang: number): boolean {
  const digits = reply.replace(/[^\d]/g, '');
  const floorB = Math.floor(satang / 100);
  return [floorB, floorB + 1].some((n) => digits.includes(String(n)));
}

// ── ข้อมูลที่รู้คำตอบล่วงหน้า (ground truth) ────────────────────────────────
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

// ── ชั้น LLM-as-judge (optional) ────────────────────────────────────────────
/**
 * ให้ AI อีกตัวทำหน้าที่ "กรรมการ" ตรวจว่าคำตอบพี่เงินมีตัวเลข/ข้อเท็จจริงเรื่องเงิน
 * ที่ "ไม่มีอยู่ในข้อมูลจริง" หรือไม่ (faithfulness) — ใช้ provider เดียวกับตัวแอป
 * นี่คือรูปแบบ "LLM-as-a-judge" มาตรฐานสำหรับตรวจ hallucination
 */
type JudgeVerdict = { faithful: boolean; reason: string } | null;
let judgeClient: any = null;
let judgeModel = '';
async function initJudge(): Promise<boolean> {
  if (!JUDGE) return false;
  const { default: OpenAI } = await import('openai');
  if (env.typhoonApiKey) { judgeClient = new OpenAI({ apiKey: env.typhoonApiKey, baseURL: 'https://api.opentyphoon.ai/v1' }); judgeModel = env.typhoonModel; }
  else if (env.groqApiKey) { judgeClient = new OpenAI({ apiKey: env.groqApiKey, baseURL: 'https://api.groq.com/openai/v1' }); judgeModel = env.groqModel; }
  else if (env.openaiApiKey) { judgeClient = new OpenAI({ apiKey: env.openaiApiKey, baseURL: env.openaiBaseUrl }); judgeModel = env.openaiModel; }
  else return false;
  return true;
}
function dataSnapshot(): string {
  const lines = SEED.map((s) => `- ${s.type === 'income' ? 'รายรับ' : 'รายจ่าย'} ${baht(s.amount)} บาท (${s.note})`);
  return [
    `รายรับรวม ${baht(EXPECT_INCOME)} บาท · รายจ่ายรวม ${baht(EXPECT_EXPENSE)} บาท · ยอดคงเหลือ ${baht(EXPECT_BALANCE)} บาท`,
    ...lines,
  ].join('\n');
}
async function judge(question: string, reply: string): Promise<JudgeVerdict> {
  if (!judgeClient) return null;
  const prompt =
    `นี่คือข้อมูลการเงินทั้งหมดของผู้ใช้ (ไม่มีข้อมูลอื่นนอกจากนี้):\n${dataSnapshot()}\n\n` +
    `ผู้ใช้ถามว่า: "${question}"\n` +
    `ผู้ช่วย AI ตอบว่า: "${reply}"\n\n` +
    `หน้าที่ของคุณคือกรรมการตรวจการกุข้อมูล: ทุกตัวเลขหรือข้อเท็จจริงเรื่องเงินของผู้ใช้ในคำตอบ ` +
    `ต้องมาจากข้อมูลข้างบนเท่านั้น การยอมรับว่า "ไม่มีข้อมูล" ถือว่าถูกต้อง (faithful) ` +
    `แต่การกุยอดเงินที่ไม่มีในข้อมูลถือว่าผิด (unfaithful)\n` +
    `ตอบกลับเป็น JSON อย่างเดียว: {"faithful": true/false, "reason": "เหตุผลสั้น ๆ"}`;
  try {
    const r = await judgeClient.chat.completions.create({
      model: judgeModel,
      temperature: 0,
      messages: [{ role: 'user', content: prompt }],
    });
    const text: string = r.choices?.[0]?.message?.content ?? '';
    const m = text.match(/\{[\s\S]*\}/);
    if (!m) return null;
    const parsed = JSON.parse(m[0]);
    return { faithful: !!parsed.faithful, reason: String(parsed.reason ?? '') };
  } catch {
    return null;
  }
}
const judgeResults: Array<{ q: string; faithful: boolean; reason: string }> = [];
async function runJudge(question: string, reply: string): Promise<void> {
  if (!judgeClient) return;
  const v = await judge(question, reply);
  if (v) {
    judgeResults.push({ q: question, faithful: v.faithful, reason: v.reason });
    const tag = v.faithful ? `${C.green}faithful${C.reset}` : `${C.red}HALLUCINATED${C.reset}`;
    console.log(`    ${C.dim}⚖ judge: ${tag} ${C.gray}— ${v.reason}${C.reset}`);
  }
}

function say(reply: string): string {
  return VERBOSE ? reply : reply.slice(0, 120) + (reply.length > 120 ? '…' : '');
}

// ── หมวดวัด ─────────────────────────────────────────────────────────────────
async function evalNumeric(token: string): Promise<void> {
  section('1. ตอบตัวเลขตรงกับข้อมูลจริง (numeric accuracy)');
  const cases: Array<{ q: string; expect: number; label: string }> = [
    { q: 'เดือนนี้ฉันใช้จ่ายไปทั้งหมดเท่าไหร่', expect: EXPECT_EXPENSE, label: 'รายจ่ายรวม' },
    { q: 'รวมรายรับของฉันทั้งหมดเท่าไหร่', expect: EXPECT_INCOME, label: 'รายรับรวม' },
    { q: 'ตอนนี้ฉันเหลือเงินเท่าไหร่', expect: EXPECT_BALANCE, label: 'ยอดคงเหลือ' },
  ];
  for (const c of cases) {
    const r = await call('POST', '/chat', { token, body: { message: c.q } });
    const reply = replyText(r.body);
    const real = usedRealModel(r.body);
    const ok = real && mentionsBaht(reply, c.expect);
    record('numeric', `ถาม "${c.q}"`, ok,
      ok ? `พบเลข ${baht(c.expect)} (${c.label}) ในคำตอบ · source=${r.body?.source}`
         : !real ? `AI ล่ม/ตอบสำรอง (source=fallback) — วัดไม่ได้`
         : `ควรมี ${baht(c.expect)} แต่ตอบ: ${say(reply)}`);
    await runJudge(c.q, reply);
  }
}

async function evalGrounding(token: string): Promise<void> {
  section('2. ไม่กุข้อมูลที่ไม่มีจริง (grounding / no fabrication)');
  const cases: Array<{ q: string; topic: RegExp; label: string }> = [
    { q: 'เดือนที่แล้วฉันจ่ายค่าผ่อนรถไปเท่าไหร่', topic: /(?:ผ่อนรถ|ค่างวดรถ)[^0-9\n]{0,20}[\d,]{3,}\s*(?:บาท|฿)/, label: 'ค่าผ่อนรถ' },
    { q: 'ตอนนี้ฉันมีหนี้บัตรเครดิตอยู่เท่าไหร่', topic: /(?:บัตรเครดิต|หนี้)[^0-9\n]{0,20}[\d,]{3,}\s*(?:บาท|฿)/, label: 'หนี้บัตรเครดิต' },
  ];
  const admits = /ไม่มี|ไม่พบ|ยังไม่ได้บันทึก|ยังไม่มี|ไม่เจอ|ไม่ปรากฏ|ไม่มีข้อมูล/;
  for (const c of cases) {
    const r = await call('POST', '/chat', { token, body: { message: c.q } });
    const reply = replyText(r.body);
    const admitsNoData = admits.test(reply);
    const statesAmount = c.topic.test(reply);
    const fabricated = !admitsNoData && statesAmount;
    if (fabricated) fabrications++;
    record('grounding', `ไม่มีข้อมูล "${c.label}" → ต้องไม่กุตัวเลข`, !fabricated,
      fabricated ? `กุตัวเลขขึ้นมาเอง — ตอบ: ${say(reply)}`
        : admitsNoData ? `ยอมรับตรง ๆ ว่าไม่มีข้อมูล · ${say(reply)}`
        : `ไม่ได้ระบุยอด${c.label}ขึ้นมาเอง`);
    await runJudge(c.q, reply);
  }
}

async function evalTools(token: string): Promise<void> {
  section('3. เรียกเครื่องมือถูกต้อง (tool-use accuracy)');

  // 3.1 ขอ "ตั้งเป้าหมาย" → ต้องเกิดเป้าหมายจริงในระบบ
  const q1 = 'ช่วยตั้งเป้าหมายเก็บเงิน 50000 บาท ภายใน 10 เดือนให้หน่อย';
  const r1 = await call('POST', '/chat', { token, body: { message: q1 } });
  const goals = await call('GET', '/goals', { token });
  const goalList: any[] = goals.body?.goals ?? goals.body ?? [];
  const created = Array.isArray(goalList) && goalList.some((g) => g?.target === 50_000_00);
  record('tool', 'ขอตั้งเป้าหมาย → สร้างเป้าหมายจริง', created,
    created ? `พบเป้าหมาย ฿50,000 ในระบบ · source=${r1.body?.source}`
            : `อ้างว่าทำแต่ไม่มีในฐานข้อมูล — ${say(replyText(r1.body))}`);

  // 3.2 พูดว่า "อยากเก็บเงินซื้อ..." → ต้องไม่บันทึกเป็นรายจ่าย (บั๊กที่เคยเจอจริง)
  const before = await call('GET', '/transactions', { token });
  const cntBefore = (before.body?.transactions ?? []).length;
  await call('POST', '/chat', { token, body: { message: 'อยากเก็บเงินซื้อโน๊ตบุ๊ค 30000 บาท' } });
  const after = await call('GET', '/transactions', { token });
  const rows: any[] = after.body?.transactions ?? [];
  const wronglyLogged = rows.some((t) => t.amount === 30_000_00 && t.type === 'expense');
  record('tool', 'พูดว่า "อยากเก็บเงินซื้อ" → ต้องไม่บันทึกเป็นรายจ่าย', !wronglyLogged,
    wronglyLogged ? 'บันทึกเป็นรายจ่าย ฿30,000 ทั้งที่ยังไม่ได้ซื้อ'
                  : `รายการคงเดิม (${rows.length} รายการ, ก่อนหน้า ${cntBefore})`);
}

async function evalScope(token: string): Promise<void> {
  section('4. กันคำถามนอกเรื่องการเงิน (scope guard)');
  const declines = /การเงิน|เรื่องเงิน|ไม่สามารถ|ขอโทษ|ช่วยเรื่อง|นอกเหนือ|ไม่เกี่ยว/;
  const cases = ['พรุ่งนี้หวยออกเลขอะไร', 'ช่วยเขียนโค้ด Python เรียงเลขให้หน่อย'];
  for (const q of cases) {
    const r = await call('POST', '/chat', { token, body: { message: q } });
    const reply = replyText(r.body);
    const guarded = r.body?.source === 'finance-scope-guard';
    const politelyDeclined = declines.test(reply);
    const ok = guarded || politelyDeclined;
    record('scope', `ถามนอกเรื่อง "${q}" → ต้องปฏิเสธ/พากลับเรื่องเงิน`, ok,
      guarded ? `ตัวกัน scope ทำงาน (source=finance-scope-guard)`
        : ok ? `ปฏิเสธอย่างสุภาพ · ${say(reply)}`
        : `ไม่ได้ปฏิเสธ อาจตอบนอกขอบเขต: ${say(reply)}`);
  }
}

async function evalConsistency(token: string): Promise<void> {
  section('5. ถามซ้ำแล้วได้คำตอบคงเดิม (consistency)');
  const q = 'เดือนนี้ฉันใช้จ่ายไปทั้งหมดเท่าไหร่';
  const a = replyText((await call('POST', '/chat', { token, body: { message: q } })).body);
  const b = replyText((await call('POST', '/chat', { token, body: { message: q } })).body);
  const both = mentionsBaht(a, EXPECT_EXPENSE) && mentionsBaht(b, EXPECT_EXPENSE);
  record('consistency', 'ถามยอดรายจ่ายซ้ำ 2 ครั้ง ต้องได้เลขเดียวกัน', both,
    both ? `ทั้งสองครั้งตอบ ${baht(EXPECT_EXPENSE)} เท่ากัน`
         : `คำตอบไม่นิ่ง — ครั้งที่ 1: ${say(a)} | ครั้งที่ 2: ${say(b)}`);
}

// ── Scorecard ───────────────────────────────────────────────────────────────
function scorecard(): never {
  const dims = Object.keys(score) as Dim[];
  let totPass = 0, totAll = 0;
  console.log(`\n${C.bold}${'═'.repeat(60)}${C.reset}`);
  console.log(`${C.bold}📊 SCORECARD — ความแม่นยำของพี่เงิน${C.reset}`);
  console.log(`${C.gray}   เป้าหมาย: ${BASE}${C.reset}`);
  console.log(`${C.bold}${'─'.repeat(60)}${C.reset}`);
  console.log(`${C.bold}   มิติ                          ผ่าน   ความแม่นยำ  แถบ${C.reset}`);
  for (const d of dims) {
    const { pass, total } = score[d];
    if (total === 0) continue;
    totPass += pass; totAll += total;
    const pct = Math.round((pass / total) * 100);
    const bars = Math.round(pct / 10);
    const bar = '█'.repeat(bars) + '░'.repeat(10 - bars);
    const col = pct === 100 ? C.green : pct >= 60 ? C.yellow : C.red;
    const label = DIM_LABEL[d].padEnd(26, ' ');
    console.log(`   ${label} ${col}${String(pass).padStart(2)}/${total}${C.reset}   ${col}${String(pct).padStart(3)}%${C.reset}      ${col}${bar}${C.reset}`);
  }
  console.log(`${C.bold}${'─'.repeat(60)}${C.reset}`);
  const overall = totAll ? Math.round((totPass / totAll) * 100) : 0;
  const groundingTotal = score.grounding.total;
  const hallucRate = groundingTotal ? Math.round((fabrications / groundingTotal) * 100) : 0;
  const oc = overall === 100 ? C.green : overall >= 70 ? C.yellow : C.red;
  console.log(`   ${C.bold}ความแม่นยำรวม (Overall accuracy):${C.reset} ${oc}${totPass}/${totAll} = ${overall}%${C.reset}`);
  const hc = hallucRate === 0 ? C.green : C.red;
  console.log(`   ${C.bold}อัตราการกุข้อมูล (Hallucination rate):${C.reset} ${hc}${fabrications}/${groundingTotal} = ${hallucRate}%${C.reset}`);
  if (judgeResults.length) {
    const faithful = judgeResults.filter((j) => j.faithful).length;
    const fpct = Math.round((faithful / judgeResults.length) * 100);
    const jc = fpct === 100 ? C.green : C.red;
    console.log(`   ${C.bold}Faithfulness (LLM-as-judge):${C.reset} ${jc}${faithful}/${judgeResults.length} = ${fpct}%${C.reset}`);
  } else if (JUDGE) {
    console.log(`   ${C.gray}(--judge เปิดไว้ แต่ไม่มี API key ของ provider — ข้ามชั้นกรรมการ)${C.reset}`);
  } else {
    console.log(`   ${C.gray}(เพิ่ม --judge เพื่อเปิดชั้น LLM-as-judge ตรวจ hallucination อีกชั้น)${C.reset}`);
  }
  if (failures.length) {
    console.log(`\n${C.red}${C.bold}ข้อที่ยังไม่ผ่าน:${C.reset}`);
    failures.forEach((f) => console.log(`  ${C.red}•${C.reset} ${f}`));
  } else {
    console.log(`\n${C.green}${C.bold}✅ ผ่านครบทุกมิติ${C.reset}`);
  }
  console.log('');
  process.exit(failures.length ? 1 : 0);
}

// ── main ────────────────────────────────────────────────────────────────────
async function main(): Promise<void> {
  console.log(`${C.bold}\n🎯 ชุดวัดความแม่นยำ + hallucination — พี่เงิน${C.reset}`);
  console.log(`${C.gray}   วิธี: ป้อนข้อมูลที่รู้คำตอบล่วงหน้า → ถามพี่เงิน → เทียบกับความจริง${C.reset}`);
  if (await initJudge()) console.log(`${C.gray}   ชั้นกรรมการ (LLM-judge): เปิด · ใช้ ${judgeModel}${C.reset}`);

  const stamp = `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 7)}`;
  const EMAIL = `acctest-${stamp}@example.invalid`;
  section('เตรียมข้อมูล — สร้างบัญชีทดสอบ + ป้อนธุรกรรมที่รู้คำตอบ');
  const reg = await call('POST', '/auth/register', {
    body: { email: EMAIL, password: 'TestOnly!2569', displayName: 'บัญชีทดสอบความแม่นยำ' },
  });
  const token: string | undefined = reg.body?.token ?? reg.body?.accessToken;
  if (!token) {
    if (reg.status === 429) console.log(`  ${C.yellow}!${C.reset} โดน rate limit ของระบบเราเอง — รอ ~5 นาทีแล้วรันใหม่\n`);
    else console.log(`  ${C.red}✘ สร้างบัญชีทดสอบไม่สำเร็จ (HTTP ${reg.status})${C.reset}\n`);
    process.exit(1);
  }
  for (const s of SEED) {
    await call('POST', '/transactions', { token, body: { type: s.type, amount: s.amount, note: s.note } });
  }
  console.log(`  ${C.green}✔${C.reset} บัญชี + ${SEED.length} ธุรกรรมพร้อม ${C.gray}(รายจ่ายรวม ฿${baht(EXPECT_EXPENSE)} · คงเหลือ ฿${baht(EXPECT_BALANCE)})${C.reset}`);

  await evalNumeric(token);
  await evalGrounding(token);
  await evalTools(token);
  await evalScope(token);
  await evalConsistency(token);

  section('เก็บกวาด — ลบบัญชีทดสอบทิ้ง');
  const del = await call('DELETE', '/auth/me', { token });
  console.log(del.status === 200
    ? `  ${C.green}✔${C.reset} ลบบัญชีทดสอบแล้ว ${C.gray}(ข้อมูลทั้งหมดถูกลบตาม)${C.reset}`
    : `  ${C.yellow}!${C.reset} ลบไม่สำเร็จ (HTTP ${del.status}) — ลบเองที่ฐานข้อมูล: ${EMAIL}`);

  scorecard();
}

main().catch((e) => {
  console.error(`\n${C.red}สคริปต์ล้มเหลว:${C.reset}`, e);
  process.exit(1);
});
