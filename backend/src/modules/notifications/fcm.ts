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
    // ⚠️ กับดัก: ตั้งเป็น path ใช้ได้เฉพาะในเครื่อง — บน cloud ไฟล์ service account
    //    ถูก gitignore ไว้จึงไม่ถูก deploy ไปด้วย ต้องวาง "เนื้อหา JSON" ทั้งก้อนแทน
    const trimmed = creds.trim();
    let json: string;
    if (trimmed.startsWith('{')) {
      json = trimmed;
    } else {
      try {
        json = readFileSync(trimmed, 'utf8');
      } catch {
        throw new Error(
          `FIREBASE_SERVICE_ACCOUNT ตั้งเป็น path "${trimmed}" แต่หาไฟล์ไม่เจอ ` +
            '— บนคลาวด์ต้องวาง "เนื้อหา JSON ทั้งก้อน" แทน path (ไฟล์ถูก gitignore จึงไม่ถูก deploy)',
        );
      }
    }
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

export interface PushResult {
  ok: boolean;
  /** เหตุผลเวลาไม่สำเร็จ — ใช้บอกผู้ใช้/ดีบักได้ว่าติดตรงไหน */
  reason?: 'fcm_not_configured' | 'no_device_token' | 'send_failed';
  detail?: string;
}

/** เช็กว่า backend ตั้งค่า FCM (FIREBASE_SERVICE_ACCOUNT) ไว้แล้วหรือยัง */
export async function isFcmConfigured(): Promise<boolean> {
  return ensureFcm();
}

/** ส่ง push ไป device ของ user (ถ้าตั้งค่า FCM ไว้) — ไม่พังถ้ายังไม่ได้ตั้ง */
export async function sendPush(userId: string, title: string, body: string): Promise<PushResult> {
  if (!(await ensureFcm())) {
    return { ok: false, reason: 'fcm_not_configured' };
  }
  const user = await prisma.user.findUnique({ where: { id: userId }, select: { deviceToken: true } });
  if (!user?.deviceToken) return { ok: false, reason: 'no_device_token' };
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
    return { ok: true };
  } catch (e) {
    const detail = (e as Error).message;
    console.error('[fcm] ส่ง push ล้มเหลว:', detail);
    return { ok: false, reason: 'send_failed', detail };
  }
}
