/**
 * ตรวจจับเจตนา "ตั้งเป้าหมายออม" จากข้อความ โดยไม่พึ่ง LLM
 *
 * ทำไมต้องมี: ระบบมี tool `create_goal` ให้ LLM เรียกอยู่แล้ว แต่ทดสอบกับ
 * production พบว่าโมเดลไม่เรียกเลยสักครั้ง ซ้ำร้ายยังตอบว่า "ตั้งไว้ในระบบ
 * เรียบร้อยแล้ว" ทั้งที่ไม่มีเป้าหมายเกิดขึ้นจริง — ผู้ใช้เชื่อว่ามีแล้วแต่ไม่มี
 *
 * ใช้แนวทางเดียวกับ detectQuickLog ที่แก้ปัญหาเดียวกันนี้กับการจดรายรับ-รายจ่าย
 * (ดูคอมเมนต์ใน chat.routes.ts: "ไม่ต้องพึ่ง LLM เรียก tool ซึ่งบางโมเดลไม่นิ่ง")
 * ยังคง tool `create_goal` ไว้สำหรับสำนวนที่ตัวตรวจจับนี้จับไม่ได้
 *
 * หลักการออกแบบ: ยอมพลาด (ไม่จับ) ดีกว่าจับผิด — สร้างเป้าหมายที่ผู้ใช้ไม่ได้ขอ
 * สร้างความสับสนมากกว่าไม่สร้างเลย จึงต้องเข้าเงื่อนไขครบทุกข้อจึงจะจับ
 */

export interface GoalIntent {
  name: string;
  targetBaht: number;
  /** จำนวนเดือนถึงกำหนด — null = ผู้ใช้ไม่ได้ระบุ */
  months: number | null;
}

/** ต้องมีคำที่บ่งบอกว่าเป็น "เป้าหมาย/การออม" ชัดเจน */
const GOAL_VERB =
  /ตั้งเป้า|เป้าหมาย|อยากเก็บเงิน|อยากออม|อยากเก็บตัง|วางแผนเก็บเงิน|วางแผนออม|เก็บเงินซื้อ|เก็บตังซื้อ|ออมเงินซื้อ|เก็บเงินไป|เก็บเงินเพื่อ/;

/** คำถาม — ผู้ใช้ถามข้อมูล ไม่ได้สั่งให้สร้าง */
const IS_QUESTION = /ไหม|มั้ย|รึเปล่า|หรือเปล่า|บ้าง|อะไรบ้าง|เท่าไหร่|เท่าไร|ยังไง|อย่างไร|\?/;

/** เพิ่มเงินเข้าเป้าที่มีอยู่แล้ว ไม่ใช่สร้างใหม่ → ปล่อยให้ add_to_goal จัดการ */
const IS_ADD_TO_GOAL = /หยอด|เก็บเข้า|ใส่เข้า|เพิ่มเข้า|โอนเข้าเป้า|สะสมเข้า/;

/** จ่ายไปแล้วจริง ไม่ใช่เป้าหมาย → ปล่อยให้ create_transaction จัดการ */
const ALREADY_PAID = /จ่ายไปแล้ว|ซื้อไปแล้ว|ซื้อแล้ว|จ่ายค่า|ชำระ|เพิ่งจ่าย|เพิ่งซื้อ/;

/** ขอไฟล์/ตาราง → เป็นคำขอส่งออก ไม่ใช่สร้างเป้าหมาย */
const WANTS_FILE = /ไฟล์|export|ส่งออก|ดาวน์โหลด|ดาวโหลด|ทำตาราง|เป็นตาราง|excel|pdf/i;

/**
 * ดึงชื่อเป้าหมายจากข้อความ เช่น "เก็บเงินซื้อโน้ตบุ๊ค 30000" → "ซื้อโน้ตบุ๊ค"
 * ถ้าจับไม่ได้ให้ใช้ชื่อกลาง ๆ ว่า "เป้าหมายออม"
 */
function extractName(message: string): string {
  const patterns = [
    /(?:เก็บเงิน|เก็บตัง|ออมเงิน|ออม)\s*(ซื้อ[^\d]{1,30}?)(?=\s*\d|$)/,
    /(?:เพื่อ|ไป|สำหรับ)\s*([^\d]{2,30}?)(?=\s*\d|$)/,
    /(?:ซื้อ)\s*([^\d]{2,30}?)(?=\s*\d|$)/,
    /(?:เที่ยว)\s*([^\d]{2,30}?)(?=\s*\d|$)/,
  ];
  for (const re of patterns) {
    const m = message.match(re);
    if (m) {
      const raw = m[1]
        .replace(/(?:บาท|฿|ภายใน|ให้หน่อย|หน่อย|ครับ|ค่ะ|นะ|จ้า)/g, '')
        .replace(/\s{2,}/g, ' ')
        .trim();
      if (raw.length >= 2) return raw.slice(0, 80);
    }
  }
  return 'เป้าหมายออม';
}

/** "ภายใน 10 เดือน" / "ใน 2 ปี" → จำนวนเดือน */
function extractMonths(message: string): number | null {
  const m = message.match(/(\d{1,3})\s*(ปี|เดือน)/);
  if (!m) return null;
  const n = Number(m[1]);
  if (!Number.isFinite(n) || n <= 0) return null;
  const months = m[2] === 'ปี' ? n * 12 : n;
  return months > 600 ? null : months; // เกิน 50 ปี = ไม่สมเหตุสมผล
}

/**
 * จำนวนเงินเป้าหมาย — เอาเลขที่ "ใหญ่ที่สุด" ในข้อความ
 * เพราะเลขอื่นมักเป็นระยะเวลา ("10 เดือน") ซึ่งน้อยกว่าจำนวนเงินเสมอ
 */
function extractTargetBaht(message: string): number | null {
  const nums = [...message.matchAll(/(\d[\d,]*(?:\.\d{1,2})?)/g)]
    .map((m) => Number(m[1].replace(/,/g, '')))
    .filter((n) => Number.isFinite(n) && n >= 100); // ต่ำกว่า 100 บาทไม่น่าใช่เป้าหมายออม
  if (nums.length === 0) return null;
  const max = Math.max(...nums);
  return max <= 20_000_000 ? max : null; // เกินเพดานระบบ (ดู money_limits)
}

/**
 * คืน GoalIntent ถ้ามั่นใจว่าผู้ใช้สั่งให้สร้างเป้าหมายออม · คืน null ถ้าไม่แน่ใจ
 */
export function detectGoalIntent(message: string): GoalIntent | null {
  const m = message.trim();
  if (!GOAL_VERB.test(m)) return null;
  if (IS_QUESTION.test(m)) return null;
  if (IS_ADD_TO_GOAL.test(m)) return null;
  if (ALREADY_PAID.test(m)) return null;
  if (WANTS_FILE.test(m)) return null;

  const targetBaht = extractTargetBaht(m);
  if (targetBaht === null) return null;

  return { name: extractName(m), targetBaht, months: extractMonths(m) };
}

/** แปลงจำนวนเดือนเป็นวันครบกำหนดแบบ YYYY-MM-DD (ส่งต่อให้ createGoal) */
export function deadlineFromMonths(months: number | null, now = new Date()): string | undefined {
  if (months === null) return undefined;
  const d = new Date(now);
  d.setMonth(d.getMonth() + months);
  return d.toISOString().slice(0, 10);
}
