import jwt from 'jsonwebtoken';
import { env } from '../../config/env';
import { HttpError } from '../../lib/http';
import { importSubscriptionsFromGmail } from './gmail_import';

// 🔐 Server-side OAuth (authorization code flow) สำหรับ Gmail import
// robust กว่า google_sign_in บนเว็บ (redirect เต็มหน้า ไม่ใช้ popup) · ต้องมี GOOGLE_CLIENT_SECRET

const GMAIL_SCOPE = 'https://www.googleapis.com/auth/gmail.readonly';

function webClientId(): string {
  if (!env.googleClientId) throw new HttpError(503, 'backend ยังไม่ได้ตั้ง GOOGLE_CLIENT_ID');
  return env.googleClientId.split(',')[0].trim(); // ใช้ตัวแรก (web client)
}

/** สร้าง URL ให้ผู้ใช้ไปยินยอมที่ Google (เต็มหน้า) — state = JWT ผูก userId (อายุ 10 นาที) */
export function buildGmailAuthUrl(userId: string): string {
  if (!env.googleClientSecret) {
    throw new HttpError(503, 'backend ยังไม่ได้ตั้ง GOOGLE_CLIENT_SECRET (ต้องใช้สำหรับ Gmail import แบบ server-side)');
  }
  const state = jwt.sign({ sub: userId, purpose: 'gmail' }, env.jwtSecret, { expiresIn: '10m' });
  const params = new URLSearchParams({
    client_id: webClientId(),
    redirect_uri: env.gmailRedirectUri,
    response_type: 'code',
    scope: GMAIL_SCOPE,
    access_type: 'offline',
    include_granted_scopes: 'true',
    prompt: 'consent',
    state,
  });
  return `https://accounts.google.com/o/oauth2/v2/auth?${params.toString()}`;
}

/** callback: verify state → แลก code เป็น access token → import → คืนผล */
export async function handleGmailCallback(code: string, state: string) {
  let userId: string;
  try {
    const payload = jwt.verify(state, env.jwtSecret) as { sub: string; purpose?: string };
    if (payload.purpose !== 'gmail') throw new Error('bad purpose');
    userId = payload.sub;
  } catch {
    throw new HttpError(400, 'state ไม่ถูกต้องหรือหมดอายุ');
  }

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      code,
      client_id: webClientId(),
      client_secret: env.googleClientSecret!,
      redirect_uri: env.gmailRedirectUri,
      grant_type: 'authorization_code',
    }).toString(),
  });
  if (!res.ok) {
    const b = await res.text().catch(() => '');
    console.error('[gmail-oauth] token exchange ล้มเหลว:', res.status, b.slice(0, 400));
    throw new HttpError(502, 'แลก token กับ Google ไม่สำเร็จ (เช็ค client secret / redirect URI)');
  }
  const tok = (await res.json()) as { access_token?: string };
  if (!tok.access_token) throw new HttpError(502, 'ไม่ได้รับ access token จาก Google');

  const result = await importSubscriptionsFromGmail(userId, tok.access_token);
  return { userId, ...result };
}
