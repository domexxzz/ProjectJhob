/**
 * ชุดทดสอบความปลอดภัย "พี่เงิน" — รันโชว์ได้สดใน Terminal
 *
 *   npm run test:security              ทดสอบ production
 *   npm run test:security -- --local   ทดสอบเครื่องตัวเอง (localhost:4000)
 *
 * ทดสอบระบบจริงผ่าน HTTP เหมือนผู้โจมตีจริง ไม่ได้เรียกฟังก์ชันภายใน
 * สร้างบัญชีทดสอบ 2 ใบ (ผู้ใช้ ก / ผู้ใช้ ข) แล้วให้ ก พยายามเข้าถึงข้อมูลของ ข
 * เสร็จแล้วลบบัญชีทดสอบทิ้งทั้งหมด ไม่ทิ้งขยะไว้ในฐานข้อมูล
 */
import jwt from 'jsonwebtoken';

const LOCAL = process.argv.includes('--local');
const BASE = LOCAL ? 'http://localhost:4000' : 'https://phee-ngern.onrender.com';
const API = `${BASE}/api/v1`;

// ── การแสดงผล ────────────────────────────────────────────────────────────────
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

/** บันทึกผลทดสอบ 1 ข้อ — ok=true คือระบบป้องกันได้ */
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

// ── ตัวช่วยเรียก API ─────────────────────────────────────────────────────────
type Res = { status: number; body: any; headers: Headers };

async function call(
  method: string,
  path: string,
  opts: { token?: string; body?: unknown } = {},
): Promise<Res> {
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
    /* บาง response ไม่ใช่ JSON (เช่นไฟล์ export) — ไม่เป็นไร */
  }
  return { status: res.status, body, headers: res.headers };
}

/** อีเมลสุ่มกันชนกับข้อมูลจริง และกันรันซ้ำแล้วอีเมลซ้ำ */
const stamp = `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 7)}`;
const EMAIL_A = `sectest-a-${stamp}@example.invalid`;
const EMAIL_B = `sectest-b-${stamp}@example.invalid`;
const PASSWORD = 'TestOnly!2569';

async function main(): Promise<void> {
  console.log(`${C.bold}\n🔐 ชุดทดสอบความปลอดภัย — ระบบพี่เงิน${C.reset}`);
  console.log(`${C.gray}   เป้าหมาย: ${BASE}${C.reset}`);
  console.log(`${C.gray}   วิธี: ยิง HTTP จากภายนอกเหมือนผู้โจมตีจริง${C.reset}`);

  // ── เตรียมบัญชีทดสอบ ──────────────────────────────────────────────────────
  section('เตรียมข้อมูล — สร้างผู้ใช้ทดสอบ 2 คน');
  const regA = await call('POST', '/auth/register', {
    body: { email: EMAIL_A, password: PASSWORD, displayName: 'ผู้ใช้ ก (ทดสอบ)' },
  });
  const regB = await call('POST', '/auth/register', {
    body: { email: EMAIL_B, password: PASSWORD, displayName: 'ผู้ใช้ ข (ทดสอบ)' },
  });
  const tokenA: string | undefined = regA.body?.token ?? regA.body?.accessToken;
  const tokenB: string | undefined = regB.body?.token ?? regB.body?.accessToken;

  if (!tokenA || !tokenB) {
    if (regA.status === 429 || regB.status === 429) {
      console.log(`  ${C.yellow}!${C.reset} โดน rate limit ของระบบเราเอง — รอ ~5 นาทีแล้วรันใหม่`);
      console.log(`  ${C.gray}  (นี่คือข้อ 8 ที่กำลังทำงานอยู่จริง ๆ: สมัคร/ล็อกอินรัวเกิน 10 ครั้งใน 5 นาที)${C.reset}
`);
      process.exit(1);
    }
    console.log(`  ${C.red}✘ สร้างบัญชีทดสอบไม่สำเร็จ${C.reset}`);
    console.log(`    ก: HTTP ${regA.status} ${JSON.stringify(regA.body)?.slice(0, 160)}`);
    console.log(`    ข: HTTP ${regB.status} ${JSON.stringify(regB.body)?.slice(0, 160)}`);
    process.exit(1);
  }
  console.log(`  ${C.green}✔${C.reset} สร้างผู้ใช้ ก และ ข เรียบร้อย ${C.gray}(จะลบทิ้งเมื่อจบ)${C.reset}`);

  // ผู้ใช้ ข สร้างข้อมูลการเงินของตัวเอง ไว้ให้ ก ลองแอบเข้าถึง
  const txnB = await call('POST', '/transactions', {
    token: tokenB,
    body: { type: 'expense', amount: 25000, note: 'ข้อมูลลับของผู้ใช้ ข' },
  });
  const goalB = await call('POST', '/goals', {
    token: tokenB,
    body: { name: 'เป้าหมายลับของผู้ใช้ ข', target: 5000000 },
  });
  const chatB = await call('POST', '/chat/sessions', { token: tokenB, body: {} });

  const txnIdB = txnB.body?.transaction?.id ?? txnB.body?.id;
  const goalIdB = goalB.body?.goal?.id ?? goalB.body?.id;
  const sessIdB = chatB.body?.session?.id ?? chatB.body?.id;
  console.log(
    `  ${C.green}✔${C.reset} ผู้ใช้ ข บันทึกรายจ่าย ฿250 + เป้าหมาย ฿50,000 + ห้องแชท ` +
      `${C.gray}(เป็น "ข้อมูลลับ" ที่ ก ต้องห้ามเห็น)${C.reset}`,
  );

  // ── 1. ต้องล็อกอินก่อนถึงเข้าถึงข้อมูลได้ ──────────────────────────────────
  section('1. ไม่ล็อกอิน ต้องเข้าถึงข้อมูลการเงินไม่ได้');
  for (const p of ['/transactions', '/budgets', '/goals', '/chat', '/notifications', '/predictions/forecast']) {
    const r = await call('GET', p);
    check(`GET ${p} โดยไม่มี token`, r.status === 401, `ตอบ HTTP ${r.status} (ต้องเป็น 401)`);
  }

  // ── 2. token ปลอม / หมดอายุ ต้องใช้ไม่ได้ ─────────────────────────────────
  section('2. token ปลอมหรือหมดอายุ ต้องใช้ไม่ได้');

  const fakeRandom = jwt.sign({ sub: 'attacker' }, 'secret-ที่เดาเอาเอง', { expiresIn: '1h' });
  const r1 = await call('GET', '/transactions', { token: fakeRandom });
  check('token ที่เซ็นด้วยกุญแจมั่ว', r1.status === 401, `ตอบ HTTP ${r1.status}`);

  // กุญแจ default ที่เขียนติดมาในซอร์สโค้ด — repo เราเป็น public ใครก็อ่านเจอ
  const fakeDefault = jwt.sign({ sub: 'attacker' }, 'dev-insecure-secret-change-me', { expiresIn: '1h' });
  const r2 = await call('GET', '/transactions', { token: fakeDefault });
  check(
    'token ที่เซ็นด้วยกุญแจ default ในซอร์สโค้ด',
    r2.status === 401,
    r2.status === 401 ? `ตอบ HTTP ${r2.status}` : 'server ยอมรับ! = ลืมตั้ง JWT_SECRET บนเซิร์ฟเวอร์',
  );

  const expired = jwt.sign({ sub: 'attacker' }, 'any', { expiresIn: '-1h' });
  const r3 = await call('GET', '/transactions', { token: expired });
  check('token ที่หมดอายุแล้ว', r3.status === 401, `ตอบ HTTP ${r3.status}`);

  // ต้องเป็น ASCII — HTTP header ใส่ภาษาไทยไม่ได้ (ByteString)
  const r4 = await call('GET', '/transactions', { token: 'not-a-jwt-at-all' });
  check('ข้อความมั่วที่ไม่ใช่ JWT', r4.status === 401, `ตอบ HTTP ${r4.status}`);

  // ── 3. หัวใจของระบบการเงิน: ห้ามเห็นข้อมูลคนอื่น ──────────────────────────
  section('3. ผู้ใช้ ก ต้องเข้าถึงข้อมูลของผู้ใช้ ข ไม่ได้ (IDOR)');

  const listA = await call('GET', '/transactions', { token: tokenA });
  const rowsA: any[] = listA.body?.transactions ?? listA.body?.items ?? [];
  check(
    'ก เปิดรายการของตัวเอง ต้องไม่มีข้อมูลของ ข ปน',
    !rowsA.some((t) => String(t?.note ?? '').includes('ผู้ใช้ ข')),
    `เห็น ${rowsA.length} รายการ ไม่มีของ ข`,
  );

  if (txnIdB) {
    const g = await call('GET', `/transactions/${txnIdB}`, { token: tokenA });
    check('ก เปิดรายการเงินของ ข ตรง ๆ ด้วย id', g.status === 404 || g.status === 403, `ตอบ HTTP ${g.status}`);

    const u = await call('PATCH', `/transactions/${txnIdB}`, { token: tokenA, body: { amount: 1 } });
    check('ก แก้ยอดเงินของ ข', u.status === 404 || u.status === 403, `ตอบ HTTP ${u.status}`);

    const d = await call('DELETE', `/transactions/${txnIdB}`, { token: tokenA });
    check('ก ลบรายการเงินของ ข', d.status === 404 || d.status === 403, `ตอบ HTTP ${d.status}`);
  }

  if (goalIdB) {
    const u = await call('PATCH', `/goals/${goalIdB}`, { token: tokenA, body: { name: 'โดนแก้แล้ว' } });
    check('ก แก้เป้าหมายของ ข', u.status === 404 || u.status === 403, `ตอบ HTTP ${u.status}`);

    const d = await call('DELETE', `/goals/${goalIdB}`, { token: tokenA });
    check('ก ลบเป้าหมายของ ข', d.status === 404 || d.status === 403, `ตอบ HTTP ${d.status}`);
  }

  if (sessIdB) {
    const h = await call('GET', `/chat?sessionId=${sessIdB}`, { token: tokenA });
    check('ก อ่านประวัติแชทของ ข', h.status === 404 || h.status === 403, `ตอบ HTTP ${h.status}`);

    const u = await call('PATCH', `/chat/sessions/${sessIdB}`, { token: tokenA, body: { title: 'โดนแก้' } });
    check('ก เปลี่ยนชื่อห้องแชทของ ข', u.status === 404 || u.status === 403, `ตอบ HTTP ${u.status}`);

    const d = await call('DELETE', `/chat/sessions/${sessIdB}`, { token: tokenA });
    check('ก ลบห้องแชทของ ข', d.status === 404 || d.status === 403, `ตอบ HTTP ${d.status}`);
  }

  // ── 4. ข้อมูลที่ส่งเข้ามาต้องถูกตรวจ ──────────────────────────────────────
  section('4. ข้อมูลผิดรูปแบบต้องถูกปฏิเสธ');
  const bad: Array<[string, unknown]> = [
    ['ยอดเงินติดลบ', { type: 'expense', amount: -50000 }],
    ['ยอดเงินเป็นตัวอักษร', { type: 'expense', amount: 'หนึ่งร้อย' }],
    ['ยอดเงินเป็นทศนิยม (ระบบเก็บเป็นสตางค์)', { type: 'expense', amount: 10.55 }],
    ['ยอดเงินล้นชนิดข้อมูล', { type: 'expense', amount: 1e308 }],
    ['ประเภทรายการที่ไม่มีจริง', { type: 'ลบเงินคนอื่น', amount: 100 }],
  ];
  for (const [name, body] of bad) {
    const r = await call('POST', '/transactions', { token: tokenA, body });
    check(name, r.status === 400, `ตอบ HTTP ${r.status} (ต้องเป็น 400)`);
  }

  // ── 5. รหัสผ่านและการล็อกอิน ─────────────────────────────────────────────
  section('5. รหัสผ่าน');
  const wrong = await call('POST', '/auth/login', { body: { email: EMAIL_A, password: 'รหัสผิด' } });
  check('ล็อกอินด้วยรหัสผ่านผิด', wrong.status === 401 || wrong.status === 400, `ตอบ HTTP ${wrong.status}`);
  check(
    'ข้อความ error ไม่บอกว่า "อีเมลนี้มีอยู่จริง"',
    !/ไม่พบผู้ใช้|user not found|no such user/i.test(JSON.stringify(wrong.body ?? '')),
    'ไม่เผยว่าอีเมลไหนมีในระบบ',
  );

  // ── 6. เซิร์ฟเวอร์ไม่รั่วข้อมูลภายใน ─────────────────────────────────────
  section('6. เซิร์ฟเวอร์ไม่เผยข้อมูลภายในตอนเกิด error');
  const boom = await call('POST', '/transactions', { token: tokenA, body: { type: {}, amount: {} } });
  const txt = JSON.stringify(boom.body ?? '');
  check('ไม่ส่ง stack trace ออกมา', !/at \w+ \(|\.ts:\d+|node_modules/.test(txt), 'ตอบเฉพาะข้อความ error');
  check('ไม่เผยชนิดฐานข้อมูล/ชื่อตาราง', !/prisma|postgres|sql|neon/i.test(txt), 'ไม่บอกว่าใช้ DB อะไร');

  // ── 7. security headers ──────────────────────────────────────────────────
  section('7. HTTP security headers');
  const head = await fetch(`${BASE}/health`);
  const wantHeaders: Array<[string, string]> = [
    ['x-content-type-options', 'กันเบราว์เซอร์เดาชนิดไฟล์เอง'],
    ['x-frame-options', 'กันเว็บอื่นเอาหน้าเราไปฝัง (clickjacking)'],
    ['strict-transport-security', 'บังคับใช้ HTTPS เสมอ'],
  ];
  for (const [h, why] of wantHeaders) {
    const v = head.headers.get(h);
    check(`มี header ${h}`, !!v, v ? `${why}` : `ไม่พบ — ${why}`);
  }
  check(
    'ไม่บอกว่าเซิร์ฟเวอร์รันด้วยอะไร (X-Powered-By)',
    !head.headers.get('x-powered-by'),
    head.headers.get('x-powered-by') ? `เผยว่า: ${head.headers.get('x-powered-by')}` : 'ซ่อนแล้ว',
  );

  // ── 9. OTP ทางอีเมล ──────────────────────────────────────────────────────
  section('9. OTP ทางอีเมล');

  // ขอรหัสกับอีเมลที่ไม่มีในระบบ ต้องตอบเหมือนอีเมลที่มีจริงทุกประการ
  // ถ้าตอบต่างกัน หน้าลืมรหัสผ่านจะกลายเป็นเครื่องมือไล่เช็กว่าใครสมัครไว้บ้าง
  const reqReal = await call('POST', '/auth/otp/request', {
    body: { email: EMAIL_A, purpose: 'reset' },
  });
  const reqFake = await call('POST', '/auth/otp/request', {
    body: { email: `ghost-${stamp}@example.invalid`, purpose: 'reset' },
  });
  check(
    'ขอรหัสกับอีเมลที่ไม่มีในระบบ ต้องตอบเหมือนอีเมลที่มีจริง',
    reqReal.status === reqFake.status &&
      JSON.stringify(reqReal.body) === JSON.stringify(reqFake.body),
    `ทั้งคู่ตอบ HTTP ${reqReal.status} เหมือนกัน (ไม่เผยว่าใครสมัครไว้บ้าง)`,
  );

  // ⚠️ ตอบข้อความเหมือนกันอย่างเดียวไม่พอ — "เวลา" ที่ใช้ตอบก็ต้องใกล้เคียงกันด้วย
  // เคยเจอจริง: อีเมลที่ไม่มีในระบบตอบใน 0.16 วิ ส่วนอีเมลที่มีจริงตอบใน 120 วิ
  // เพราะรอส่งอีเมลให้เสร็จก่อน ต่างกัน 750 เท่า ใครจับเวลาก็รู้ว่าใครมีบัญชี
  const tReal = Date.now();
  await call('POST', '/auth/otp/request', { body: { email: EMAIL_A, purpose: 'reset' } });
  const msReal = Date.now() - tReal;
  const tFake = Date.now();
  await call('POST', '/auth/otp/request', {
    body: { email: `ghost2-${stamp}@example.invalid`, purpose: 'reset' },
  });
  const msFake = Date.now() - tFake;
  const ratio = msFake > 0 ? msReal / msFake : msReal;
  check(
    'เวลาตอบต้องไม่ต่างกันจนเดาได้ว่าอีเมลไหนมีบัญชี',
    msReal < 5000 && ratio < 20,
    `อีเมลจริง ${msReal}ms · ไม่มีในระบบ ${msFake}ms (ต่างกัน ${ratio.toFixed(1)} เท่า)`,
  );

  for (const [name, path] of [
    ['ยืนยันอีเมล', '/auth/otp/verify-email'],
    ['ยืนยันรหัสตั้งรหัสผ่านใหม่', '/auth/otp/verify-reset'],
  ] as const) {
    const r = await call('POST', path, { body: { email: EMAIL_A, code: '000000' } });
    check(`${name} ด้วยรหัสมั่ว ต้องไม่ผ่าน`, r.status === 400, `ตอบ HTTP ${r.status}`);
  }

  const badReset = await call('POST', '/auth/password/reset', {
    body: { resetToken: 'not-a-real-token-at-all', newPassword: 'Hacked!2569' },
  });
  check('ตั้งรหัสผ่านใหม่ด้วย token ปลอม', badReset.status === 400, `ตอบ HTTP ${badReset.status}`);

  // ⚠️ ข้อสำคัญ: token ล็อกอินธรรมดาต้องเอามาตั้งรหัสผ่านใหม่ไม่ได้
  // ถ้าไม่เช็ก purpose ใน token ใครที่ขโมย token ไปได้จะเปลี่ยนรหัสผ่านเหยื่อได้ทันที
  const loginTokenReset = await call('POST', '/auth/password/reset', {
    body: { resetToken: tokenA, newPassword: 'Hacked!2569' },
  });
  check(
    'เอา token ล็อกอินธรรมดามาตั้งรหัสผ่านใหม่ ต้องไม่ได้',
    loginTokenReset.status === 400,
    `ตอบ HTTP ${loginTokenReset.status}`,
  );

  // ── เก็บกวาด ─────────────────────────────────────────────────────────────
  section('เก็บกวาด — ลบบัญชีทดสอบทิ้ง');
  const delA = await call('DELETE', '/auth/me', { token: tokenA });
  const delB = await call('DELETE', '/auth/me', { token: tokenB });
  const okA = delA.status === 200;
  const okB = delB.status === 200;
  if (okA && okB) {
    console.log(
      `  ${C.green}✔${C.reset} ลบบัญชีทดสอบทั้ง 2 ใบแล้ว ` +
        `${C.gray}(ข้อมูลการเงิน/แชทในบัญชีถูกลบตามทั้งหมด)${C.reset}`,
    );
  } else {
    console.log(`  ${C.yellow}!${C.reset} ลบไม่สำเร็จ (ก:${delA.status} ข:${delB.status}) — ลบเองที่ฐานข้อมูล:`);
    console.log(`  ${C.gray}  ${EMAIL_A}, ${EMAIL_B}${C.reset}`);
  }

  // ── 8. จำกัดจำนวนครั้งที่ยิงได้ ──────────────────────────────────────────
  section('8. จำกัดการยิงรัว (กันเดารหัสผ่าน / กันเผาโควต้า AI)');
  const burst = await Promise.all(
    Array.from({ length: 25 }, () =>
      call('POST', '/auth/login', { body: { email: EMAIL_A, password: 'เดารหัสไปเรื่อย' } }),
    ),
  );
  const blocked = burst.filter((r) => r.status === 429).length;
  check(
    'ยิงล็อกอินผิด 25 ครั้งรวด ต้องโดนบล็อก',
    blocked > 0,
    blocked > 0 ? `โดนบล็อก ${blocked}/25 ครั้ง (HTTP 429)` : 'ไม่โดนบล็อกเลย — เดารหัสผ่านได้ไม่จำกัด',
  );

  // ── สรุป ─────────────────────────────────────────────────────────────────
  const total = passed + failed;
  console.log(`\n${C.bold}${'─'.repeat(58)}${C.reset}`);
  console.log(
    `${C.bold}สรุป:${C.reset} ${C.green}ผ่าน ${passed}${C.reset} / ` +
      `${failed > 0 ? C.red : C.gray}ไม่ผ่าน ${failed}${C.reset} ` +
      `${C.gray}(ทั้งหมด ${total} ข้อ)${C.reset}`,
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
