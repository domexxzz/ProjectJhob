import { readFileSync } from 'fs';
import { prisma } from '../../lib/prisma';
import { env } from '../../config/env';

// 🔔 FCM push แบบ "เปิดได้ทีหลัง" — ถ้ายังไม่ลง firebase-admin หรือไม่มี creds
// ทุกอย่างจะ no-op เงียบ ๆ (in-app notification center ยังทำงานปกติ)
// เปิดใช้จริง: `npm i firebase-admin` + ตั้ง env FIREBASE_SERVICE_ACCOUNT
//   = JSON string ของ service account  หรือ  path ไปยังไฟล์ .json ก็ได้ (เช่น ./service-account.json)

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
    // firebase-admin v13+ เป็น modular API — import submodule (dynamic → build ผ่านแม้ยังไม่ลง lib)
    const appMod: any = await import('firebase-admin/app' as any);
    const msgMod: any = await import('firebase-admin/messaging' as any);
    // รับได้ทั้ง JSON string ตรง ๆ หรือ path ไปยังไฟล์ .json (สะดวกกว่าเวลา key ยาว)
    const trimmed = creds.trim();
    const json = trimmed.startsWith('{') ? trimmed : readFileSync(trimmed, 'utf8');
    const serviceAccount = JSON.parse(json);
    if (!appMod.getApps().length) {
      appMod.initializeApp({ credential: appMod.cert(serviceAccount) });
    }
    messaging = msgMod.getMessaging();
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
    await messaging.send({
      token: user.deviceToken,
      notification: { title, body },
      // ใช้ channel IMPORTANCE_HIGH (สร้างใน MainActivity ฝั่งแอป) → เด้ง heads-up + มีเสียง
      android: { priority: 'high', notification: { channelId: 'high_importance_channel' } },
      // เว็บ/PWA (รวม iPhone ที่เพิ่มลงหน้าจอโฮม) — ใส่ไอคอนและให้แตะแล้วเปิดแอป
      webpush: {
        notification: { icon: '/icons/Icon-192.png', badge: '/icons/Icon-192.png' },
        fcmOptions: { link: env.webAppUrl || '/' },
      },
    });
  } catch (e) {
    console.error('[fcm] ส่ง push ล้มเหลว:', (e as Error).message);
  }
}
