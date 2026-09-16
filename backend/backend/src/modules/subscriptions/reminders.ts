import { prisma } from '../../lib/prisma';
import { baht } from '../chat/persona';
import { createNotification } from '../notifications/create';

/** เตือน subscription ที่จะตัดเงินภายใน 2 วัน (reuse createNotification → กันซ้ำ + ยิง push) */
export async function runSubscriptionReminders(userId: string) {
  const now = new Date();
  const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const soon = new Date(startOfToday.getTime() + 2 * 24 * 60 * 60 * 1000);
  const subs = await prisma.subscription.findMany({
    where: { userId, nextBilling: { gte: startOfToday, lte: soon } },
  });

  const created = [];
  for (const s of subs) {
    const nextBillingDate = new Date(s.nextBilling);
    const diffTime = nextBillingDate.getTime() - startOfToday.getTime();
    const days = Math.max(0, Math.round(diffTime / (24 * 60 * 60 * 1000)));

    let when = '';
    let titleWhen = '';
    if (days === 0) {
      when = 'วันนี้';
      titleWhen = 'วันนี้';
    } else if (days === 1) {
      when = 'พรุ่งนี้';
      titleWhen = 'พรุ่งนี้';
    } else {
      when = `อีก ${days} วัน`;
      titleWhen = `ใน ${days} วัน`;
    }

    const n = await createNotification(
      userId,
      'subscription',
      `${s.name} จะตัดเงิน${titleWhen}`,
      `${when} ${s.name} จะตัด ${baht(s.amount)} เตรียมเงินไว้นะ 💳`,
      { subscriptionId: s.id },
    );
    if (n) created.push(n);
  }
  return created;
}

/** รัน reminder ให้ทุก user (ใช้ใน scheduled job) */
export async function runAllUsersSubscriptionReminders() {
  const users = await prisma.user.findMany({ select: { id: true } });
  for (const u of users) {
    try {
      await runSubscriptionReminders(u.id);
    } catch (e) {
      console.error('[notif] subscription reminder ล้มเหลว user', u.id, (e as Error).message);
    }
  }
}
