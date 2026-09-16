import { prisma } from '../../lib/prisma';
import { baht } from '../chat/persona';
import { createNotification } from './create';
import { runAllUsersSubscriptionReminders } from '../subscriptions/reminders';
import { runAllUsersPredictionTriggers } from '../predictions/prediction_triggers';

/** ตรวจงบรายเดือนและรายสัปดาห์ → แจ้งเตือน "ใกล้เต็มงบ (≥80%)" / "เกินงบ" */
export async function runBudgetTriggers(userId: string) {
  const now = new Date();
  const monthlyStart = new Date(now.getFullYear(), now.getMonth(), 1);
  const monthlyEnd = new Date(now.getFullYear(), now.getMonth() + 1, 1);

  const day = now.getDay();
  const diffToMon = (day === 0 ? -6 : 1 - day);
  const weeklyStart = new Date(now.getFullYear(), now.getMonth(), now.getDate() + diffToMon);
  weeklyStart.setHours(0, 0, 0, 0);
  const weeklyEnd = new Date(weeklyStart);
  weeklyEnd.setDate(weeklyEnd.getDate() + 7);

  const budgets = await prisma.budget.findMany({ where: { userId }, include: { category: true } });

  const created = [];
  for (const b of budgets) {
    if (b.amount <= 0) continue;

    const start = b.period === 'weekly' ? weeklyStart : monthlyStart;
    const end = b.period === 'weekly' ? weeklyEnd : monthlyEnd;

    const agg = await prisma.transaction.aggregate({
      _sum: { amount: true },
      // งบรวม (categoryId=null) ต้องนับรายจ่าย "ทุกหมวด" ไม่ใช่เฉพาะรายการที่ไม่มีหมวด
      where: { userId, type: 'expense', ...(b.categoryId ? { categoryId: b.categoryId } : {}), occurredAt: { gte: start, lt: end } },
    });
    const spent = agg._sum.amount ?? 0;
    const ratio = spent / b.amount;
    const cat = b.category?.nameTh ?? (b.name || 'งบรวม');

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

/** รันทริกเกอร์งบให้ทุก user (ใช้ cursor-based pagination ดึงทีละ 100 คน) */
export async function runAllUsersBudgetTriggers() {
  const BATCH_SIZE = 100;
  let cursor: string | undefined = undefined;

  while (true) {
    const users: { id: string }[] = await prisma.user.findMany({
      take: BATCH_SIZE,
      skip: cursor ? 1 : 0,
      cursor: cursor ? { id: cursor } : undefined,
      select: { id: true },
      orderBy: { id: 'asc' },
    });

    if (users.length === 0) break;

    for (const u of users) {
      try {
        await runBudgetTriggers(u.id);
      } catch (e) {
        console.error('[notif] trigger ล้มเหลว user', u.id, (e as Error).message);
      }
    }

    cursor = users[users.length - 1].id;
    if (users.length < BATCH_SIZE) break;
  }
}

let timer: NodeJS.Timeout | null = null;

/** เริ่ม scheduled job (เปิดด้วย env NOTIF_CRON=on) — ตรวจงบทุก N ชม. ด้วย setInterval (ไม่ต้องพึ่ง lib) */
export function startNotificationScheduler() {
  if (process.env.NOTIF_CRON !== 'on') {
    console.log('[notif] scheduler ปิดอยู่ (ตั้ง NOTIF_CRON=on เพื่อเปิด)');
    return;
  }
  const rawMs = Number(process.env.NOTIF_CRON_MS ?? 6 * 60 * 60 * 1000); // default 6 ชม.
  const everyMs = Math.max(60000, isNaN(rawMs) ? 6 * 60 * 60 * 1000 : rawMs);
  if (timer) clearInterval(timer);
  timer = setInterval(() => {
    runAllUsersBudgetTriggers().catch(() => {});
    runAllUsersSubscriptionReminders().catch(() => {}); // เตือน subscription ที่ใกล้ตัดเงิน
    runAllUsersPredictionTriggers().catch(() => {}); // 🔮 พยากรณ์ AI เบื้องหลัง → แจ้งเตือนเงินตึง/ผิดปกติ
  }, everyMs);
  console.log(`[notif] scheduler เปิด (ทุก ~${Math.round(everyMs / 60000)} นาที)`);
}
