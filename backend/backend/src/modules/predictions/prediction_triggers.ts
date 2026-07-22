import { prisma } from '../../lib/prisma';
import { createNotification } from '../notifications/create';
import { fetchPrediction } from './predictions.service';

/**
 * พยากรณ์ให้ user (เบื้องหลัง) แล้วยิงเข้า Notification เฉพาะเรื่องสำคัญ:
 * - alert ระดับ warning/danger (เงินตึง, burn-out, จะหมดเร็ว)
 * - anomaly รายจ่ายผิดปกติเด่นสุด 1 รายการ
 * createNotification กันซ้ำ (type+title ภายใน ~20 ชม.) อยู่แล้ว
 */
export async function runPredictionTriggers(userId: string) {
  const result = await fetchPrediction(userId);
  if (!result) return []; // FastAPI ปิด/ไม่พร้อม → ข้ามเงียบ ๆ

  const created = [];

  for (const a of result.alerts) {
    if (a.type === 'danger' || a.type === 'warning') {
      const n = await createNotification(userId, 'prediction', `🔮 ${a.title}`, a.body, { alertType: a.type });
      if (n) created.push(n);
    }
  }

  const topAnom = result.anomalies[0];
  if (topAnom) {
    const n = await createNotification(userId, 'prediction', '🔮 ตรวจพบรายจ่ายผิดปกติ', topAnom.description, {
      anomalyId: topAnom.id,
    });
    if (n) created.push(n);
  }

  return created;
}

/** รันพยากรณ์ให้ทุก user (ใช้ใน scheduled job) */
export async function runAllUsersPredictionTriggers() {
  const users = await prisma.user.findMany({ select: { id: true } });
  for (const u of users) {
    try {
      await runPredictionTriggers(u.id);
    } catch (e) {
      console.error('[predictions] trigger ล้มเหลว user', u.id, (e as Error).message);
    }
  }
}
