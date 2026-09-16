#!/usr/bin/env tsx
/**
 * test-repeat.ts — ทดสอบความแม่นยำและความเร็ว AI Coach "พี่เงิน"
 *
 * วิธีใช้ (ใน cmd ไม่ใช่ PowerShell):
 *   npm run test:repeat                       → production 10 ครั้ง
 *   npm run test:repeat -- --n 50             → production 50 ครั้ง
 *   npm run test:repeat -- --local            → localhost:4000
 *   npm run test:repeat -- --n 40 --delay 0  → rate limit test
 */

// ─── Parse args ───────────────────────────────────────────────────────────────
function getArg(flag: string, fallback: string): string {
  const i = process.argv.indexOf(flag);
  return i !== -1 && process.argv[i + 1] ? process.argv[i + 1] : fallback;
}
const N        = parseInt(getArg('--n', '10'));
const DELAY_MS = parseInt(getArg('--delay', '2000'));
const LOCAL    = process.argv.includes('--local');
const BASE_URL = LOCAL ? 'http://localhost:4000' : 'https://phee-ngern.onrender.com';

// ─── Test transactions ─────────────────────────────────────────────────────────
// NOTE: amount ใช้หน่วย "สตางค์" (integer) — 1 บาท = 100
// รายจ่ายรวม = 15,000 บาท (ตัวเลขสะอาด ตรวจง่าย)
const TEST_TRANSACTIONS = [
  { note: 'ค่าเช่า',         amount: 500000, type: 'expense' }, // 5,000 บาท
  { note: 'ค่าอาหารเย็น',    amount: 25000,  type: 'expense' }, // 250 บาท
  { note: 'ค่ากาแฟ',         amount: 8500,   type: 'expense' }, // 85 บาท
  { note: 'ค่าไฟฟ้า',        amount: 120000, type: 'expense' }, // 1,200 บาท
  { note: 'ค่าอินเทอร์เน็ต', amount: 59900,  type: 'expense' }, // 599 บาท
  { note: 'ค่าขนม',          amount: 18500,  type: 'expense' }, // 185 บาท
  { note: 'ค่ายา',           amount: 300000, type: 'expense' }, // 3,000 บาท
  { note: 'ค่ารถ Grab',      amount: 468100, type: 'expense' }, // 4,681 บาท → รวม = 15,000 บาท
  // income — ไม่นับในรายจ่าย
  { note: 'เงินเดือน',       amount: 2500000, type: 'income'  }, // 25,000 บาท
];

// รายจ่ายรวม = 500000+25000+8500+120000+59900+18500+300000+468100 = 1,500,000 สตางค์ = 15,000 บาท
const EXPECTED_EXPENSE_BAHT = 15000;
const TOLERANCE_BAHT        = 10; // ยอมรับความคลาดเคลื่อน ±10 บาท (AI อาจปัดเศษ)

// ─── Helpers ───────────────────────────────────────────────────────────────────
function sleep(ms: number) { return new Promise(r => setTimeout(r, ms)); }

async function apiPost(path: string, body: object, token?: string) {
  const res = await fetch(`${BASE_URL}${path}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(90_000),
  });
  let data: any;
  try { data = await res.json(); } catch { data = {}; }
  return { ok: res.ok, status: res.status, data };
}

function percentile(arr: number[], p: number): number {
  if (!arr.length) return 0;
  const sorted = [...arr].sort((a, b) => a - b);
  const idx = Math.ceil((p / 100) * sorted.length) - 1;
  return sorted[Math.max(0, idx)];
}

function extractNumbers(text: string): number[] {
  // ดึงตัวเลขจากข้อความ รองรับ comma เช่น "15,000" หรือ "15,000.00"
  return (text.replace(/,/g, '').match(/\d+(?:\.\d+)?/g) ?? []).map(Number);
}

// ─── Main ──────────────────────────────────────────────────────────────────────
async function main() {
  console.log('');
  console.log('╔══════════════════════════════════════════════════════════╗');
  console.log('║       🧪  พี่เงิน Accuracy & Latency Test               ║');
  console.log('╚══════════════════════════════════════════════════════════╝');
  console.log(`  Target  : ${BASE_URL}`);
  console.log(`  Rounds  : ${N}`);
  console.log(`  Delay   : ${DELAY_MS}ms ระหว่าง request`);
  console.log(`  Expected: ${EXPECTED_EXPENSE_BAHT.toLocaleString()} บาท (±${TOLERANCE_BAHT} บาท)`);
  console.log('');

  // ── 0. Health check ──────────────────────────────────────────────────────────
  process.stdout.write('  [0/5] Health check ... ');
  let health: any = {};
  try {
    const r = await fetch(`${BASE_URL}/health`, { signal: AbortSignal.timeout(90_000) });
    health = await r.json();
  } catch (e: any) {
    console.log(`❌ เชื่อมต่อไม่ได้: ${e.message}`);
    process.exit(1);
  }
  if (health.status !== 'ok') {
    console.log('❌ server ไม่ปกติ:', JSON.stringify(health));
    process.exit(1);
  }
  console.log(`✅ ok  (uptime: ${health.uptime}s, db: ${health.db})`);
  if ((health.uptime ?? 999) < 60) {
    console.log('  ⚠️  uptime น้อย — รอ 5 วิให้เซิร์ฟเวอร์เสถียรก่อน...');
    await sleep(5000);
  }

  // ── 1. สร้าง user ทดสอบ ──────────────────────────────────────────────────────
  const testEmail = `autotest_${Date.now()}@test-repeat.local`;
  const testPass  = 'AutoTest1234!';
  process.stdout.write('  [1/5] สร้าง user ทดสอบ ... ');
  const reg = await apiPost('/api/v1/auth/register', {
    email      : testEmail,
    password   : testPass,
    displayName: 'AutoTestBot',
  });
  if (!reg.ok) {
    console.log(`❌ ${reg.status}:`, reg.data?.message ?? JSON.stringify(reg.data));
    process.exit(1);
  }
  const token = reg.data.token as string;
  console.log(`✅  ${testEmail}`);

  // ── 2. ใส่ธุรกรรมทดสอบ ────────────────────────────────────────────────────────
  process.stdout.write(`  [2/5] เพิ่มธุรกรรม ${TEST_TRANSACTIONS.length} รายการ ... `);
  let txOk = 0, txFail = 0;
  for (const tx of TEST_TRANSACTIONS) {
    const r = await apiPost('/api/v1/transactions', {
      type  : tx.type,
      amount: tx.amount,   // สตางค์ (integer)
      note  : tx.note,
    }, token);
    if (r.ok) { txOk++; }
    else { txFail++; console.log(`\n    ⚠️  "${tx.note}" → ${r.status}: ${r.data?.message ?? ''}`); }
  }
  console.log(txFail === 0 ? `✅ ${txOk} รายการ` : `⚠️  ${txOk} สำเร็จ, ${txFail} ล้มเหลว`);

  // ── 3. ยิงคำถามซ้ำ N ครั้ง ────────────────────────────────────────────────────
  const QUESTION = 'เดือนนี้ฉันมีรายจ่ายรวมเท่าไหร่?';
  console.log(`\n  [3/5] ยิงคำถาม "${QUESTION}" จำนวน ${N} ครั้ง...\n`);

  type Result = { outcome: 'correct' | 'wrong_number' | 'rejected' | 'ai_error'; latencyMs: number; answer: string };
  const results: Result[] = [];

  for (let i = 1; i <= N; i++) {
    if (DELAY_MS > 0 && i > 1) await sleep(DELAY_MS);

    const t0 = Date.now();
    try {
      const chat = await apiPost('/api/v1/chat', { message: QUESTION }, token);
      const latencyMs = Date.now() - t0;

      if (chat.status === 429) {
        const msg = chat.data?.message ?? 'rate limited';
        console.log(`  [${i.toString().padStart(3)}/${N}] ⚠️  429 ${msg}`);
        results.push({ outcome: 'rejected', latencyMs, answer: '429 rate limit' });
        console.log('      รอ 65 วิแล้วยิงต่อ...');
        await sleep(65_000);
        continue;
      }

      // ดึง content จาก response — format: { message: { content: "...", role: "assistant" } }
      const msgObj   = chat.data?.message;
      const rawText  = (typeof msgObj === 'object' ? msgObj?.content : msgObj) ?? JSON.stringify(chat.data);
      const answerText = String(rawText).slice(0, 200);

      // ตรวจว่า AI ปฏิเสธ
      const refused = /ไม่มีข้อมูล|ไม่ทราบ|ไม่สามารถ|ขออภัย|no data|finance-scope-guard/i.test(answerText);

      // ดึงตัวเลขทั้งหมดจากคำตอบ แล้วเช็กว่ามีค่าที่ใกล้ EXPECTED ไหม
      const nums = extractNumbers(answerText);
      const hasCorrect = nums.some(n => Math.abs(n - EXPECTED_EXPENSE_BAHT) <= TOLERANCE_BAHT);

      let outcome: Result['outcome'];
      if      (refused)     outcome = 'rejected';
      else if (hasCorrect)  outcome = 'correct';
      else                  outcome = 'wrong_number';

      const icons = { correct: '✅', rejected: '⚠️ ', wrong_number: '❌', ai_error: '💥' };
      const preview = answerText.replace(/\n/g, ' ').slice(0, 70);
      console.log(`  [${i.toString().padStart(3)}/${N}] ${icons[outcome]} ${String(latencyMs).padStart(5)}ms  "${preview}"`);
      results.push({ outcome, latencyMs, answer: answerText });

    } catch (err: any) {
      const latencyMs = Date.now() - t0;
      const msg = err?.message ?? String(err);
      console.log(`  [${i.toString().padStart(3)}/${N}] 💥 ${String(latencyMs).padStart(5)}ms  ${msg.slice(0, 70)}`);
      results.push({ outcome: 'ai_error', latencyMs, answer: msg });
    }
  }

  // ── 4. ลบ user ทดสอบ ──────────────────────────────────────────────────────────
  process.stdout.write('\n  [4/5] ลบ user ทดสอบ ... ');
  try {
    const { PrismaClient } = await import('@prisma/client');
    const prisma = new PrismaClient();
    const deleted = await prisma.user.deleteMany({ where: { email: testEmail } });
    await prisma.$disconnect();
    console.log(deleted.count > 0 ? `✅ ลบ ${deleted.count} user` : `⚠️  ไม่พบ user (อาจถูกลบแล้ว)`);
  } catch (e: any) {
    console.log(`⚠️  ลบ local DB ไม่ได้: ${e.message?.slice(0, 80)}`);
    console.log('      → ถ้าใช้ production ให้ลบเองใน Prisma Studio ของ production ครับ');
  }

  // ── 5. สรุปผล ─────────────────────────────────────────────────────────────────
  const correct     = results.filter(r => r.outcome === 'correct').length;
  const wrongNumber = results.filter(r => r.outcome === 'wrong_number').length;
  const rejected    = results.filter(r => r.outcome === 'rejected').length;
  const aiError     = results.filter(r => r.outcome === 'ai_error').length;
  const total       = results.length;
  const accuracy    = total > 0 ? ((correct / total) * 100).toFixed(1) : '0.0';

  const goodLatencies = results.filter(r => r.outcome !== 'ai_error').map(r => r.latencyMs);
  const avg = goodLatencies.length ? Math.round(goodLatencies.reduce((a, b) => a + b, 0) / goodLatencies.length) : 0;
  const p50 = Math.round(percentile(goodLatencies, 50));
  const p95 = Math.round(percentile(goodLatencies, 95));

  console.log('');
  console.log('╔══════════════════════════════════════════════════════════╗');
  console.log('║                   📊  ผลการทดสอบ                        ║');
  console.log('╠══════════════════════════════════════════════════════════╣');
  console.log(`║  ✅ ตอบถูก           ${String(correct).padStart(4)} / ${String(total).padEnd(4)}                      ║`);
  console.log(`║  ⚠️  ถูกปฏิเสธผิด   ${String(rejected).padStart(4)}                               ║`);
  console.log(`║  ❌ เลขผิด           ${String(wrongNumber).padStart(4)}                               ║`);
  console.log(`║  💥 AI/Network err  ${String(aiError).padStart(4)}                               ║`);
  console.log(`║  🎯 ความแม่นยำ      ${accuracy}%                             ║`);
  console.log('╠══════════════════════════════════════════════════════════╣');
  console.log(`║  ⏱️  เฉลี่ย (avg)    ${String(avg).padStart(6)}ms                          ║`);
  console.log(`║  ⏱️  กลาง   (p50)    ${String(p50).padStart(6)}ms                          ║`);
  console.log(`║  ⏱️  ช้าสุด (p95)    ${String(p95).padStart(6)}ms                          ║`);
  console.log('╠══════════════════════════════════════════════════════════╣');
  console.log(`║  Expected: ${EXPECTED_EXPENSE_BAHT.toLocaleString().padEnd(10)} บาท  (±${TOLERANCE_BAHT} บาท)            ║`);
  console.log('╚══════════════════════════════════════════════════════════╝');

  if (wrongNumber > 0) {
    console.log('\n  ❌ ตัวอย่างคำตอบที่เลขผิด:');
    results.filter(r => r.outcome === 'wrong_number').slice(0, 3).forEach((r, i) => {
      console.log(`  ${i + 1}) "${r.answer.replace(/\n/g,' ').slice(0, 100)}"`);
    });
  }
  console.log('');

  process.exit(correct === total && aiError === 0 ? 0 : 1);
}

main().catch(err => {
  console.error('\nFatal error:', err);
  process.exit(1);
});
