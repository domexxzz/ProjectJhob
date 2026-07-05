import { OAuth2Client } from 'google-auth-library';
import { prisma } from '../../lib/prisma';
import { signToken } from '../../lib/auth';
import { HttpError } from '../../lib/http';
import { env } from '../../config/env';
import { publicUser } from './auth.service';

const googleClient = new OAuth2Client();

export interface OAuthProfile {
  provider: 'google' | 'facebook';
  providerId: string;
  email: string;
  displayName?: string | null;
  avatarUrl?: string | null;
}

/** verify Google ID token (จาก google_sign_in) → profile */
export async function verifyGoogleIdToken(idToken: string): Promise<OAuthProfile> {
  if (!env.googleClientId) throw new HttpError(503, 'backend ยังไม่ได้ตั้ง GOOGLE_CLIENT_ID');
  let payload;
  try {
    const ticket = await googleClient.verifyIdToken({
      idToken,
      audience: env.googleClientId.split(',').map((s) => s.trim()),
    });
    payload = ticket.getPayload();
  } catch {
    throw new HttpError(401, 'Google token ไม่ถูกต้องหรือหมดอายุ');
  }
  if (!payload?.email) throw new HttpError(401, 'Google token ไม่มีอีเมล');
  return {
    provider: 'google',
    providerId: payload.sub,
    email: payload.email,
    displayName: payload.name,
    avatarUrl: payload.picture,
  };
}

/** verify Google access token (เว็บให้ access token แทน idToken) → profile ผ่าน userinfo endpoint */
export async function verifyGoogleAccessToken(accessToken: string): Promise<OAuthProfile> {
  const res = await fetch('https://www.googleapis.com/oauth2/v3/userinfo', {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  if (!res.ok) throw new HttpError(401, 'Google access token ไม่ถูกต้องหรือหมดอายุ');
  const d = (await res.json()) as { sub?: string; email?: string; name?: string; picture?: string };
  if (!d.sub || !d.email) throw new HttpError(401, 'Google token ไม่มีข้อมูลผู้ใช้');
  return { provider: 'google', providerId: d.sub, email: d.email, displayName: d.name, avatarUrl: d.picture };
}

/** verify Facebook access token ผ่าน Graph API → profile */
export async function verifyFacebookToken(accessToken: string): Promise<OAuthProfile> {
  const url = `https://graph.facebook.com/me?fields=id,name,email,picture.type(large)&access_token=${encodeURIComponent(accessToken)}`;
  const res = await fetch(url);
  if (!res.ok) throw new HttpError(401, 'Facebook token ไม่ถูกต้อง');
  const d = (await res.json()) as { id?: string; name?: string; email?: string; picture?: { data?: { url?: string } } };
  if (!d.id) throw new HttpError(401, 'Facebook token ไม่ถูกต้อง');
  if (!d.email) throw new HttpError(400, 'บัญชี Facebook นี้ไม่มีอีเมล — ลองล็อกอินด้วย Google หรืออีเมลแทน');
  return {
    provider: 'facebook',
    providerId: d.id,
    email: d.email,
    displayName: d.name,
    avatarUrl: d.picture?.data?.url,
  };
}

/** หา/สร้าง/ผูก user จาก OAuth profile → คืน { user, token } (shape เดียวกับ login) */
export async function oauthLogin(profile: OAuthProfile) {
  // 1) หาโดย provider + providerId
  let user = await prisma.user.findFirst({
    where: { provider: profile.provider, providerId: profile.providerId },
  });

  // 2) ไม่เจอ → หาโดยอีเมล (ผูกกับบัญชีเดิม เช่น เคยสมัครด้วย email/password)
  if (!user) {
    const byEmail = await prisma.user.findUnique({ where: { email: profile.email } });
    if (byEmail) {
      user = await prisma.user.update({
        where: { id: byEmail.id },
        data: {
          provider: profile.provider,
          providerId: profile.providerId,
          avatarUrl: profile.avatarUrl ?? byEmail.avatarUrl,
        },
      });
    }
  }

  // 3) ยังไม่มี → สร้างใหม่ (ไม่มี passwordHash)
  if (!user) {
    user = await prisma.user.create({
      data: {
        email: profile.email,
        provider: profile.provider,
        providerId: profile.providerId,
        displayName: profile.displayName,
        avatarUrl: profile.avatarUrl,
      },
    });
  }

  return { user: publicUser(user), token: signToken(user.id) };
}
