import { prisma } from '../../lib/prisma';
import { baht } from '../chat/persona';
import { createNotification } from '../notifications/create';

/** เตือน subscription ที่จะตัดเงินภายใน 2 วัน (reuse createNotification → กันซ้ำ + ยิง push) */
export async function runSubscriptionReminders(userId: string) {
  const now = new Date();
  const soon = new Date(now.getTime() + 2 * 24 * 60 * 60 * 1000);
  const subs = await prisma.subscription.findMany({
    where: { userId, nextBilling: { gte: now, lte: soon } },
  });

  const created = [];
  for (const s of subs) {
    const days = Math.max(0, Math.ceil((new Date(s.nextBilling).getTime() - now.getTime()) / (24 * 60 * 60 * 1000)));
    const when = days <= 1 ? 'พรุ่งนี้' : `อีก ${days} วัน`;
    const n = await createNotification(
      userId,
      'subscription',
      `${s.name} จะตัดเงิน${days <= 1 ? 'พรุ่งนี้' : ''}`,
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
