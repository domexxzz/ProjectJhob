/**
 * Function-calling tools ของพี่เงิน — ให้ LLM เข้าถึงข้อมูลจริงและลงมือทำงานให้ผู้ใช้ได้
 *
 * หลักการ:
 * - LLM คุยกันด้วยหน่วย "บาท" (float) เสมอ; ตัวแปลง satang↔baht อยู่ในไฟล์นี้ที่เดียว
 * - runTool() ไม่เคย throw ออกไป — error ถูกห่อเป็น { error } เพื่อให้ LLM แก้ตัว/ถามผู้ใช้ต่อได้
 * - ทุก tool ผูกกับ userId เสมอ (ownership) — LLM แตะข้อมูลของคนอื่นไม่ได้
 */
import { prisma } from '../../lib/prisma';
import { cache } from '../../lib/cache';
import { autoCategorize } from '../transactions/parser';
import { runBudgetTriggers } from '../notifications/triggers';
import { runPredictionTriggers } from '../predictions/prediction_triggers';

const satangToBaht = (satang: number) => Math.round(satang) / 100;
const bahtToSatang = (baht: number) => Math.round(baht * 100);

/** ข้อมูลการ์ด "จดสำเร็จ" ที่ส่งให้ mobile วาด — เกิดเมื่อ AI บันทึกรายการผ่านแชท */
export interface TxnCard {
  id: string;
  type: 'income' | 'expense';
  amountBaht: number;
  category: string;
  categoryId: string | null; // ให้ mobile แก้ไขโดยคงหมวดเดิมได้
  note: string;
  date: string; // YYYY-MM-DD
}

/** นิยาม tool ในรูปแบบ OpenAI tools (ใช้ได้กับ Typhoon/Groq/OpenAI ที่ compatible) */
export const TOOLS = [
  {
    type: 'function',
    function: {
      name: 'query_transactions',
      description:
        'ค้นหา/สรุปรายการรายรับ-รายจ่ายจริงของผู้ใช้ ใช้เมื่อผู้ใช้ถามยอดเงิน จำนวนครั้ง หรือสรุปการใช้จ่าย เช่น "เดือนนี้จ่ายค่าอาหารไปเท่าไหร่", "รายจ่ายก้อนใหญ่สุดสัปดาห์นี้". คืนยอดรวมและรายการ (หน่วยบาท)',
      parameters: {
        type: 'object',
        properties: {
          // ไม่ใช้ enum เข้ม เพราะบาง provider (Groq) validate ฝั่ง API แล้ว 400 เมื่อโมเดลส่ง "" หรือ "all"; โค้ดกรองเองด้านล่าง
          type: { type: 'string', description: 'กรองประเภท: ใส่ "income" หรือ "expense"; เว้นว่างหรือ "all" = ทั้งรายรับและรายจ่าย' },
          category: { type: 'string', description: 'ชื่อหมวด ไทยหรืออังกฤษ เช่น "อาหาร", "Food", "เดินทาง" (เว้นว่าง = ทุกหมวด)' },
          month: { type: 'string', description: 'เดือนที่ต้องการ รูปแบบ YYYY-MM เช่น "2026-07" (เว้นว่าง = เดือนปัจจุบัน ถ้าไม่ระบุ from/to)' },
          from: { type: 'string', description: 'วันเริ่ม YYYY-MM-DD (ใช้คู่กับ to สำหรับช่วงกำหนดเอง)' },
          to: { type: 'string', description: 'วันสิ้นสุด YYYY-MM-DD (รวมวันนี้)' },
        },
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'create_transaction',
      description:
        'บันทึกรายการรายรับหรือรายจ่ายใหม่ให้ผู้ใช้ ใช้เมื่อผู้ใช้บอกชัดเจนว่าเพิ่งจ่ายหรือได้รับเงิน เช่น "จ่ายค่ากาแฟ 50 บาท", "ได้เงินเดือน 25000". หลังบันทึกให้ยืนยันสั้น ๆ ว่าบันทึกอะไรไป',
      parameters: {
        type: 'object',
        properties: {
          type: { type: 'string', enum: ['income', 'expense'], description: 'รายรับหรือรายจ่าย' },
          amountBaht: { type: 'number', description: 'จำนวนเงินหน่วยบาท เช่น 50 หรือ 25000 (ต้องมากกว่า 0)' },
          category: { type: 'string', description: 'ชื่อหมวด ไทยหรืออังกฤษ (เว้นว่าง = ระบบจัดหมวดให้อัตโนมัติจากโน้ต)' },
          note: { type: 'string', description: 'บันทึกช่วยจำ เช่น "กาแฟร้านหน้าออฟฟิศ" (ช่วยจัดหมวดและค้นหาภายหลัง)' },
        },
        required: ['type', 'amountBaht'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_budget_status',
      description: 'ดูสถานะงบประมาณรายเดือนของผู้ใช้ตอนนี้ — แต่ละหมวดตั้งงบไว้เท่าไร ใช้ไปแล้วเท่าไร เหลือ/เกินเท่าไร (หน่วยบาท)',
      parameters: { type: 'object', properties: {} },
    },
  },
  {
    type: 'function',
    function: {
      name: 'list_goals',
      description: 'ดูเป้าหมายการออมทั้งหมดของผู้ใช้ — ชื่อเป้า ยอดเป้า ยอดที่ออมแล้ว เปอร์เซ็นต์ความคืบหน้า และเดดไลน์ (หน่วยบาท)',
      parameters: { type: 'object', properties: {} },
    },
  },
  {
    type: 'function',
    function: {
      name: 'create_goal',
      description:
        'สร้างเป้าหมายการออมใหม่ ใช้เมื่อผู้ใช้บอกว่าอยากเก็บเงินเพื่ออะไรสักอย่าง เช่น "อยากเก็บเงินซื้อโน้ตบุ๊ค 30000", "ตั้งเป้าออม 50000 ภายในสิ้นปี" — นี่คือ "เป้าหมาย" ไม่ใช่รายจ่าย ห้ามใช้ create_transaction กับกรณีนี้',
      parameters: {
        type: 'object',
        properties: {
          name: { type: 'string', description: 'ชื่อเป้าหมาย เช่น "ซื้อโน้ตบุ๊ค", "เที่ยวญี่ปุ่น" (ถ้าผู้ใช้ไม่ระบุให้ตั้งให้สั้น ๆ ตามบริบท)' },
          targetBaht: { type: 'number', description: 'จำนวนเงินเป้าหมาย หน่วยบาท (ต้องมากกว่า 0)' },
          deadline: { type: 'string', description: 'วันครบกำหนด YYYY-MM-DD (ไม่ระบุก็ได้)' },
        },
        required: ['name', 'targetBaht'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'add_to_goal',
      description:
        'เพิ่มเงินออมเข้าเป้าหมายที่มีอยู่ ใช้เมื่อผู้ใช้บอกว่าเก็บเงินเข้าเป้าได้แล้ว เช่น "วันนี้หยอดกระปุกเป้าโน้ตบุ๊ค 500"',
      parameters: {
        type: 'object',
        properties: {
          goalName: { type: 'string', description: 'ชื่อเป้าหมาย (ตรงหรือใกล้เคียงกับที่มีอยู่)' },
          amountBaht: { type: 'number', description: 'จำนวนเงินที่เพิ่มเข้าเป้า หน่วยบาท' },
        },
        required: ['goalName', 'amountBaht'],
      },
    },
  },
] as const;

/** หา category จากชื่อ (ไทยหรืออังกฤษ) — โหลดทั้งตาราง (เล็ก ~32 แถว) แล้ว match ใน JS กัน case/มาตรฐานภาษา */
async function resolveCategory(name: string, type?: 'income' | 'expense') {
  const cats = await prisma.category.findMany();
  const q = name.trim().toLowerCase();
  const pool = type ? cats.filter((c) => c.type === type) : cats;
  return (
    pool.find((c) => c.nameTh.toLowerCase() === q || c.name.toLowerCase() === q) ??
    pool.find((c) => c.nameTh.toLowerCase().includes(q) || c.name.toLowerCase().includes(q)) ??
    null
  );
}

/** สร้างหน้าต่างเวลาจาก args — คืน { gte, lt } (half-open) หรือ null ถ้าไม่ระบุ */
function resolveDateRange(args: { month?: string; from?: string; to?: string }): { gte: Date; lt: Date } | null {
  if (args.from && args.to && /^\d{4}-\d{2}-\d{2}$/.test(args.from) && /^\d{4}-\d{2}-\d{2}$/.test(args.to)) {
    const [fy, fm, fd] = args.from.split('-').map(Number);
    const [ty, tm, td] = args.to.split('-').map(Number);
    return { gte: new Date(fy, fm - 1, fd), lt: new Date(ty, tm - 1, td + 1) }; // รวมวัน to
  }
  if (args.month && /^\d{4}-\d{2}$/.test(args.month)) {
    const [y, m] = args.month.split('-').map(Number);
    return { gte: new Date(y, m - 1, 1), lt: new Date(y, m, 1) };
  }
  return null;
}

type ToolResult = Record<string, unknown>;

async function queryTransactions(userId: string, args: any): Promise<ToolResult> {
  const where: any = { userId };
  if (args.type === 'income' || args.type === 'expense') where.type = args.type;

  const range = resolveDateRange(args);
  if (range) {
    where.occurredAt = { gte: range.gte, lt: range.lt };
  } else {
    // ค่าเริ่มต้น: เดือนปัจจุบัน
    const now = new Date();
    where.occurredAt = { gte: new Date(now.getFullYear(), now.getMonth(), 1), lt: new Date(now.getFullYear(), now.getMonth() + 1, 1) };
  }

  let categoryLabel: string | undefined;
  if (args.category) {
    const cat = await resolveCategory(String(args.category), args.type);
    if (!cat) return { count: 0, totalBaht: 0, items: [], note: `ไม่พบหมวด "${args.category}"` };
    where.categoryId = cat.id;
    categoryLabel = cat.nameTh;
  }

  const limit = Math.min(Math.max(Number(args.limit) || 20, 1), 50);
  const txns = await prisma.transaction.findMany({
    where,
    orderBy: { occurredAt: 'desc' },
    include: { category: true },
  });

  const totalSatang = txns.reduce((s, t) => s + t.amount, 0);
  return {
    count: txns.length,
    totalBaht: satangToBaht(totalSatang),
    category: categoryLabel,
    items: txns.slice(0, limit).map((t) => ({
      date: t.occurredAt.toISOString().split('T')[0],
      type: t.type,
      amountBaht: satangToBaht(t.amount),
      category: t.category?.nameTh ?? 'ไม่ระบุ',
      note: t.note ?? '',
    })),
  };
}

async function createTransaction(userId: string, args: any): Promise<ToolResult> {
  const type = args.type === 'income' ? 'income' : args.type === 'expense' ? 'expense' : null;
  if (!type) return { error: 'ต้องระบุ type เป็น income หรือ expense' };
  const amountBaht = Number(args.amountBaht);
  if (!Number.isFinite(amountBaht) || amountBaht <= 0) return { error: 'amountBaht ต้องเป็นตัวเลขมากกว่า 0' };
  const amount = bahtToSatang(amountBaht);

  const note: string | undefined = args.note ? String(args.note).slice(0, 280) : undefined;

  // หา categoryId: ระบุมา → resolve; ไม่ระบุ → ให้ระบบจัดหมวดอัตโนมัติจากโน้ต (เรียนรู้จากประวัติผู้ใช้)
  let categoryId: string | null = null;
  let categoryLabel = 'ไม่ระบุ';
  if (args.category) {
    const cat = await resolveCategory(String(args.category), type);
    if (cat) {
      categoryId = cat.id;
      categoryLabel = cat.nameTh;
    }
  }
  if (!categoryId) {
    categoryId = await autoCategorize(note ?? '', note ?? '', type, userId, args.fallbackCategory);
    if (categoryId) {
      const cat = await prisma.category.findUnique({ where: { id: categoryId } });
      categoryLabel = cat?.nameTh ?? categoryLabel;
    }
  }

  // ใช้เวลาปัจจุบันเสมอ — LLM ไม่รู้วันที่จริงและมักใส่วันผิด; การแก้ย้อนหลังทำผ่านฟอร์มในแอป
  const txn = await prisma.transaction.create({
    data: { userId, type, amount, note, source: 'manual', categoryId },
    include: { category: true },
  });

  await cache.delPattern(`user:${userId}:*`);
  // เตือนงบ + พยากรณ์ใหม่แบบ background เหมือนตอนบันทึกผ่านฟอร์ม
  Promise.all([runBudgetTriggers(userId), runPredictionTriggers(userId)]).catch((e) =>
    console.error('[tools] background triggers failed:', e),
  );

  return {
    ok: true,
    id: txn.id,
    type: txn.type,
    amountBaht: satangToBaht(txn.amount),
    category: txn.category?.nameTh ?? categoryLabel,
    categoryId: txn.categoryId,
    date: txn.occurredAt.toISOString().split('T')[0],
    note: txn.note ?? '',
  };
}

async function getBudgetStatus(userId: string): Promise<ToolResult> {
  const now = new Date();
  const start = new Date(now.getFullYear(), now.getMonth(), 1);
  const end = new Date(now.getFullYear(), now.getMonth() + 1, 1);

  const budgets = await prisma.budget.findMany({ where: { userId }, include: { category: true } });
  if (!budgets.length) return { budgets: [], note: 'ยังไม่ได้ตั้งงบประมาณ' };

  const out = [];
  for (const b of budgets) {
    const agg = await prisma.transaction.aggregate({
      _sum: { amount: true },
      where: {
        userId,
        type: 'expense',
        occurredAt: { gte: start, lt: end },
        ...(b.categoryId ? { categoryId: b.categoryId } : {}),
      },
    });
    const spent = agg._sum.amount ?? 0;
    out.push({
      category: b.category?.nameTh ?? b.name ?? 'งบรวม',
      budgetBaht: satangToBaht(b.amount),
      spentBaht: satangToBaht(spent),
      remainingBaht: satangToBaht(b.amount - spent),
      overBudget: spent > b.amount,
    });
  }
  return { budgets: out };
}

async function listGoals(userId: string): Promise<ToolResult> {
  const goals = await prisma.goal.findMany({ where: { userId }, orderBy: { createdAt: 'desc' } });
  return {
    goals: goals.map((g) => ({
      name: g.name,
      targetBaht: satangToBaht(g.target),
      currentBaht: satangToBaht(g.current),
      progressPct: g.target > 0 ? Math.round((g.current / g.target) * 100) : 0,
      deadline: g.deadline ? g.deadline.toISOString().split('T')[0] : null,
    })),
  };
}

/** คำที่บ่งบอกว่าเป็น "รายรับ" (นอกนั้นถือเป็นรายจ่าย) */
export const INCOME_HINT =
  /เงินเข้า|เงินโอนเข้า|โอนเข้า|เข้าบัญชี|รับโอน|ได้รับเงิน|เงินเดือน|โบนัส|ค่าจ้าง|ฟรีแลนซ์|freelance|พาร์ทไทม์|part.?time|รับเงิน|ได้เงิน|เงินได้|รายได้|เงินคืน|ขายของ|ขายได้|ดอกเบี้ย|ปันผล|ค่าขนม|เงินทอน|refund|cashback/i;
/** คำถาม/คำสั่งที่ไม่ใช่การจดรายการ — กัน quick-log ทำงานผิด */
const NOT_A_LOG =
  /[?？]|เท่าไหร่|เท่าไร|กี่บาท|กี่ครั้ง|อะไรบ้าง|มีอะไร|ไหม|หรือเปล่า|ทำไม|ยังไง|เมื่อไหร่|สรุป|ดูรายการ|ขอดู|รายงาน|ไฟล์|export|ส่งออก|ดาวน์โหลด/i;

/**
 * ประโยค "ตั้งใจ/วางแผน" ไม่ใช่การจ่ายเงินจริง — ต้องส่งให้ AI คุยแทนการจดทันที
 * เช่น "อยากเก็บเงินซื้อโน้ตบุ๊ค 30,000" เคยถูกจดเป็นรายจ่าย 30,000 ทั้งที่ยังไม่ได้จ่าย
 */
const INTENT_NOT_SPENT =
  /อยาก|ตั้งเป้า|เป้าหมาย|วางแผน|เก็บเงิน|ออมเงิน|ควร|ช่วยคิด|ช่วยวางแผน|แนะนำ|กำลังคิด|คิดจะ|ถ้า.*จะ|จะซื้อ|จะเก็บ|จะออม|น่าจะ|ผ่อนไหว|พอไหม/i;

/**
 * ตรวจ "การจดแบบสั้น" สไตล์ป้านวล เช่น "ก๋วยเตี๋ยว 55", "เงินเดือน 30000", "ชอปปี้ (ของใช้) 354"
 * → แกะเองในโค้ด สร้างรายการได้เลยโดยไม่ต้องพึ่ง LLM เรียก tool (การ์ดขึ้นชัวร์ 100%)
 * คืน null ถ้าไม่เข้าเงื่อนไข (เช่นเป็นคำถาม/ประโยคยาว) → ให้ LLM จัดการต่อ
 */
export function detectQuickLog(
  message: string,
): { type: 'income' | 'expense'; amountBaht: number; note: string } | null {
  const m = message.trim();
  if (NOT_A_LOG.test(m)) return null;
  // ตั้งใจ/วางแผน ≠ จ่ายจริง → ให้ AI คุยเรื่องเป้าหมายแทนการจดเป็นรายจ่าย
  if (INTENT_NOT_SPENT.test(m)) return null;
  // <ชื่อ ≤38 ตัว> <จำนวน> [บาท/฿] ท้ายบรรทัด
  const match = m.match(/^(\D.{0,38}?)\s+(\d[\d,]*(?:\.\d{1,2})?)\s*(?:บาท|฿|บ\.)?\s*$/);
  if (!match) return null;
  const amountBaht = Number(match[2].replace(/,/g, ''));
  if (!Number.isFinite(amountBaht) || amountBaht <= 0) return null;
  const type = INCOME_HINT.test(m) ? 'income' : 'expense';
  // ตัดกริยานำหน้าออกให้ note สะอาด: "จ่ายค่างวดรถ" → "ค่างวดรถ", "ซื้อกาแฟ" → "กาแฟ"
  const note = match[1].replace(/^(จ่าย|ซื้อ|ชำระ)\s*/, '').replace(/\s*ค่า\s*$/, '').trim();
  return { type, amountBaht, note: note || (type === 'income' ? 'รายรับ' : 'รายจ่าย') };
}

/** สร้างรายการแบบ deterministic (ใช้กับ quick-log) → คืนการ์ด หรือ null ถ้าล้มเหลว */
export async function quickCreate(
  userId: string,
  q: { type: 'income' | 'expense'; amountBaht: number; note: string; fallbackCategory?: string },
): Promise<TxnCard | null> {
  const r = (await createTransaction(userId, q)) as Record<string, unknown>;
  if (!r.ok) return null;
  const c = r as unknown as TxnCard;
  return { id: c.id, type: c.type, amountBaht: c.amountBaht, category: c.category, categoryId: c.categoryId, note: c.note, date: c.date };
}


/** สร้างเป้าหมายการออมใหม่ — คนละเรื่องกับ create_transaction (เป้าหมาย ≠ เงินที่จ่ายไปแล้ว) */
async function createGoal(userId: string, args: any): Promise<ToolResult> {
  const name = String(args.name ?? '').trim().slice(0, 80);
  if (!name) return { error: 'ต้องระบุชื่อเป้าหมาย' };
  const targetBaht = Number(args.targetBaht);
  if (!Number.isFinite(targetBaht) || targetBaht <= 0) {
    return { error: 'targetBaht ต้องเป็นตัวเลขมากกว่า 0' };
  }

  let deadline: Date | null = null;
  if (typeof args.deadline === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(args.deadline)) {
    const [y, m, d] = args.deadline.split('-').map(Number);
    deadline = new Date(Date.UTC(y, m - 1, d, 12, 0, 0));
  }

  const goal = await prisma.goal.create({
    data: { userId, name, target: bahtToSatang(targetBaht), deadline },
  });
  await cache.delPattern(`user:${userId}:*`);

  // ถ้ามีเดดไลน์ บอกด้วยว่าต้องเก็บเดือนละเท่าไหร่ (ผู้ใช้ได้ประโยชน์ทันที)
  let perMonthBaht: number | undefined;
  if (deadline) {
    const months = Math.max(
      1,
      Math.ceil((deadline.getTime() - Date.now()) / (1000 * 60 * 60 * 24 * 30)),
    );
    perMonthBaht = Math.ceil(targetBaht / months);
  }

  return {
    ok: true,
    id: goal.id,
    name: goal.name,
    targetBaht: satangToBaht(goal.target),
    currentBaht: 0,
    deadline: deadline ? deadline.toISOString().split('T')[0] : null,
    perMonthBaht,
  };
}

/** เพิ่มเงินเข้าเป้าหมายที่มีอยู่ (จับคู่ชื่อแบบยืดหยุ่น) */
async function addToGoal(userId: string, args: any): Promise<ToolResult> {
  const q = String(args.goalName ?? '').trim().toLowerCase();
  const amountBaht = Number(args.amountBaht);
  if (!Number.isFinite(amountBaht) || amountBaht <= 0) {
    return { error: 'amountBaht ต้องเป็นตัวเลขมากกว่า 0' };
  }

  const goals = await prisma.goal.findMany({ where: { userId } });
  if (goals.length === 0) return { error: 'ยังไม่มีเป้าหมายในระบบ — สร้างก่อนด้วย create_goal' };

  const goal =
    goals.find((g) => g.name.toLowerCase() === q) ??
    goals.find((g) => g.name.toLowerCase().includes(q) || q.includes(g.name.toLowerCase()));
  if (!goal) {
    return { error: `ไม่พบเป้าหมายชื่อ "${args.goalName}" — ที่มีอยู่: ${goals.map((g) => g.name).join(', ')}` };
  }

  const updated = await prisma.goal.update({
    where: { id: goal.id },
    data: { current: goal.current + bahtToSatang(amountBaht) },
  });
  await cache.delPattern(`user:${userId}:*`);

  const targetBaht = satangToBaht(updated.target);
  const currentBaht = satangToBaht(updated.current);
  return {
    ok: true,
    name: updated.name,
    addedBaht: amountBaht,
    currentBaht,
    targetBaht,
    progressPct: targetBaht > 0 ? Math.round((currentBaht / targetBaht) * 100) : 0,
    remainingBaht: Math.max(0, targetBaht - currentBaht),
  };
}

/** ตัวรัน tool กลาง — เรียกจาก tool loop ใน coach.ts. ไม่ throw: ห่อ error เป็น { error } */
export async function runTool(name: string, args: any, userId: string): Promise<ToolResult> {
  try {
    switch (name) {
      case 'query_transactions':
        return await queryTransactions(userId, args ?? {});
      case 'create_transaction':
        return await createTransaction(userId, args ?? {});
      case 'get_budget_status':
        return await getBudgetStatus(userId);
      case 'list_goals':
        return await listGoals(userId);
      case 'create_goal':
        return await createGoal(userId, args ?? {});
      case 'add_to_goal':
        return await addToGoal(userId, args ?? {});
      default:
        return { error: `ไม่รู้จัก tool "${name}"` };
    }
  } catch (e) {
    console.error(`[tools] ${name} error:`, (e as Error).message);
    return { error: `เรียก ${name} ไม่สำเร็จ: ${(e as Error).message}` };
  }
}
