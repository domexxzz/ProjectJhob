import { prisma } from '../../lib/prisma';
import { baht } from '../chat/persona';
import { sendPush } from './fcm';

/** สร้าง notification (บันทึก DB + ยิง push) แบบกันซ้ำ — type+title เดิมภายใน ~20 ชม. จะไม่สร้างซ้ำ */
async function createNotification(
  userId: string,
  type: string,
  title: string,
  body: string,
  data?: Record<string, unknown>,
) {
  const since = new Date(Date.now() - 20 * 60 * 60 * 1000);
  const dup = await prisma.notification.findFirst({ where: { userId, type, title, createdAt: { gte: since } } });
  if (dup) return null;

  const n = await prisma.notification.create({
    data: { userId, type, title, body, data: data ? JSON.stringify(data) : null },
  });
  await sendPush(userId, title, body); // no-op ถ้ายังไม่ตั้ง FCM
  return n;
}

/** ตรวจงบรายเดือน → แจ้งเตือน "ใกล้เต็มงบ (≥80%)" / "เกินงบ" */
export async function runBudgetTriggers(userId: string) {
  const now = new Date();
  const start = new Date(now.getFullYear(), now.getMonth(), 1);
  const end = new Date(now.getFullYear(), now.getMonth() + 1, 1);

  const budgets = await prisma.budget.findMany({ where: { userId, period: 'monthly' }, include: { category: true } });

  const created = [];
  for (const b of budgets) {
    if (b.amount <= 0) continue;
    const agg = await prisma.transaction.aggregate({
      _sum: { amount: true },
      where: { userId, type: 'expense', categoryId: b.categoryId ?? null, occurredAt: { gte: start, lt: end } },
    });
    const spent = agg._sum.amount ?? 0;
    const ratio = spent / b.amount;
    const cat = b.category?.nameTh ?? 'งบรวม';

    if (ratio >= 1) {
      const n = await createNotification(
        userId,
        'budget_over',
        `ใช้เกินงบ ${cat} แล้วนะ`,
        `${cat} ใช้ไป ${baht(spent)} จากงบ ${baht(b.amount)} (เกิน ${baht(spent - b.amount)}) ลองคุมอีกนิดนะ! 😅`,
        { categoryId: b.categoryId },
      );
      if (n) created.push(n);
    } else if (ratio >= 0.8) {
      const n = await createNotification(
        userId,
        'budget_near',
        `ใกล้เต็มงบ ${cat} แล้ว`,
        `${cat} ใช้ไป ${baht(spent)} จาก ${baht(b.amount)} (${Math.round(ratio * 100)}%) เหลือ ${baht(b.amount - spent)} 👀`,
        { categoryId: b.categoryId },
      );
      if (n) created.push(n);
    }
  }
  return created;
}

/** สรุปรายวัน — รายรับ/รายจ่ายเดือนนี้ (เรียกจาก scheduled job) */
export async function runDailySummary(userId: string) {
  const now = new Date();
  const start = new Date(now.getFullYear(), now.getMonth(), 1);
  const end = new Date(now.getFullYear(), now.getMonth() + 1, 1);
  const rows = await prisma.transaction.groupBy({
    by: ['type'],
    _sum: { amount: true },
    where: { userId, occurredAt: { gte: start, lt: end } },
  });
  const income = rows.find((r) => r.type === 'income')?._sum.amount ?? 0;
  const expense = rows.find((r) => r.type === 'expense')?._sum.amount ?? 0;
  return createNotification(
    userId,
    'daily_summary',
    'สรุปการเงินวันนี้ 📊',
    `เดือนนี้รับ ${baht(income)} จ่าย ${baht(expense)} เหลือ ${baht(income - expense)}`,
  );
}

/** รันทริกเกอร์งบให้ทุก user (ใช้ใน scheduled job) */
export async function runAllUsersBudgetTriggers() {
  const users = await prisma.user.findMany({ select: { id: true } });
  for (const u of users) {
    try {
      await runBudgetTriggers(u.id);
    } catch (e) {
      console.error('[notif] trigger ล้มเหลว user', u.id, (e as Error).message);
    }
  }
}

let timer: NodeJS.Timeout | null = null;

/** เริ่ม scheduled job (เปิดด้วย env NOTIF_CRON=on) — ตรวจงบทุก N ชม. ด้วย setInterval (ไม่ต้องพึ่ง lib) */
export function startNotificationScheduler() {
  if (process.env.NOTIF_CRON !== 'on') {
    console.log('[notif] scheduler ปิดอยู่ (ตั้ง NOTIF_CRON=on เพื่อเปิด)');
    return;
  }
  const everyMs = Number(process.env.NOTIF_CRON_MS ?? 6 * 60 * 60 * 1000); // default 6 ชม.
  if (timer) clearInterval(timer);
  timer = setInterval(() => {
    runAllUsersBudgetTriggers().catch(() => {});
  }, everyMs);
  console.log(`[notif] scheduler เปิด (ทุก ~${Math.round(everyMs / 60000)} นาที)`);
}
