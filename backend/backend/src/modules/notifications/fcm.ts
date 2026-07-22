import { prisma } from '../../lib/prisma';

// 🔔 FCM push แบบ "เปิดได้ทีหลัง" — ถ้ายังไม่ลง firebase-admin หรือไม่มี creds
// ทุกอย่างจะ no-op เงียบ ๆ (in-app notification center ยังทำงานปกติ)
// เปิดใช้จริง: `npm i firebase-admin` + ตั้ง env FIREBASE_SERVICE_ACCOUNT = JSON ของ service account

let fcmReady: boolean | null = null;
let messaging: any = null;

async function ensureFcm(): Promise<boolean> {
  if (fcmReady !== null) return fcmReady;
  const creds = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (!creds) {
    fcmReady = false;
    return false;
  }
  try {
    const mod: any = await import('firebase-admin' as any); // dynamic → ไม่พังตอน build ถ้ายังไม่ลง lib
    const admin = mod.default ?? mod;
    const serviceAccount = JSON.parse(creds); // ใส่เป็น JSON string ใน env
    if (!admin.apps?.length) {
      admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
    }
    messaging = admin.messaging();
    fcmReady = true;
  } catch (e) {
    console.warn('[fcm] push ปิดอยู่ (ยังไม่ลง firebase-admin หรือ creds ไม่ถูก):', (e as Error).message);
    fcmReady = false;
  }
  return fcmReady;
}

/** ส่ง push ไป device ของ user (ถ้าตั้งค่า FCM ไว้) — ไม่พังถ้ายังไม่ได้ตั้ง */
export async function sendPush(userId: string, title: string, body: string): Promise<void> {
  if (!(await ensureFcm())) return;
  const user = await prisma.user.findUnique({ where: { id: userId }, select: { deviceToken: true } });
  if (!user?.deviceToken) return;
  try {
    await messaging.send({ token: user.deviceToken, notification: { title, body } });
  } catch (e) {
    console.error('[fcm] ส่ง push ล้มเหลว:', (e as Error).message);
  }
}
