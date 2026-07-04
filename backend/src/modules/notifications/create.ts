import { prisma } from '../../lib/prisma';
import { sendPush } from './fcm';

/**
 * สร้าง notification (บันทึก DB + ยิง push) แบบกันซ้ำ — type+title เดิมภายใน ~20 ชม. จะไม่สร้างซ้ำ
 * แยกออกมาเป็น module กลาง เพื่อให้ทั้ง budget triggers และ subscription reminders reuse ได้ (กัน circular import)
 */
export async function createNotification(
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
