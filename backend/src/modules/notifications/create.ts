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
  if (dup) {
    // หากมีแจ้งเตือนหัวข้อเดิมอยู่แล้วภายใน 20 ชม. ให้ปรับข้อมูลให้ล่าสุด (เช่น จำนวนวันที่เหลือลดลง)
    // และดันขึ้นมาด้านบนสุดพร้อมแจ้งเตือนใหม่อีกครั้ง
    const updated = await prisma.notification.update({
      where: { id: dup.id },
      data: {
        body,
        read: false,
        createdAt: new Date(),
        data: data ? JSON.stringify(data) : null,
      },
    });
    await sendPush(userId, title, body);
    return updated;
  }

  const n = await prisma.notification.create({
    data: { userId, type, title, body, data: data ? JSON.stringify(data) : null },
  });
  await sendPush(userId, title, body); // no-op ถ้ายังไม่ตั้ง FCM
  return n;
}
