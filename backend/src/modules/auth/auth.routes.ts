import { Router } from 'express';
import { z } from 'zod';
import { asyncHandler } from '../../lib/http';
import { HttpError } from '../../lib/http';
import { requireAuth } from '../../lib/auth';
import { registerSchema, loginSchema } from '../../lib/validate';
import { registerUser, loginUser } from './auth.service';
import { verifyGoogleIdToken, verifyGoogleAccessToken, verifyFacebookToken, oauthLogin } from './oauth.service';
import { prisma } from '../../lib/prisma';
import { env } from '../../config/env';

export const authRouter = Router();

// รับได้ทั้ง idToken (มือถือ) และ accessToken (เว็บ) — อย่างน้อย 1 อย่าง
const googleSchema = z
  .object({ idToken: z.string().min(10).optional(), accessToken: z.string().min(10).optional() })
  .refine((d) => d.idToken || d.accessToken, { message: 'ต้องมี idToken หรือ accessToken' });
const facebookSchema = z.object({ accessToken: z.string().min(10) });
const updateProfileSchema = z
  .object({
    displayName: z.string().trim().min(1).max(60).optional(),
    email: z.string().trim().email().optional(),
    phone: z.string().trim().max(30).nullable().optional(),
    monthlyIncome: z.number().int().nonnegative().optional(),
    avatarUrl: z.string().max(15_000_000).nullable().optional(),
  })
  .refine((data) => Object.keys(data).length > 0, {
    message: 'ต้องมีข้อมูลที่ต้องการแก้ไขอย่างน้อย 1 รายการ',
  });

const profileSelect = {
  id: true,
  email: true,
  phone: true,
  displayName: true,
  monthlyIncome: true,
  level: true,
  streak: true,
  points: true,
  avatarUrl: true,
  provider: true,
  createdAt: true,
} as const;

authRouter.post(
  '/register',
  asyncHandler(async (req, res) => {
    const data = registerSchema.parse(req.body);
    res.status(201).json(await registerUser(data));
  }),
);

authRouter.post(
  '/login',
  asyncHandler(async (req, res) => {
    const data = loginSchema.parse(req.body);
    res.json(await loginUser(data));
  }),
);

// POST /api/v1/auth/google — ล็อกอินด้วย Google (ส่ง idToken จาก google_sign_in)
authRouter.post(
  '/google',
  asyncHandler(async (req, res) => {
    const { idToken, accessToken } = googleSchema.parse(req.body);
    const profile = idToken ? await verifyGoogleIdToken(idToken) : await verifyGoogleAccessToken(accessToken!);
    res.json(await oauthLogin(profile));
  }),
);

// POST /api/v1/auth/facebook — ล็อกอินด้วย Facebook (ส่ง accessToken จาก flutter_facebook_auth)
authRouter.post(
  '/facebook',
  asyncHandler(async (req, res) => {
    const { accessToken } = facebookSchema.parse(req.body);
    const profile = await verifyFacebookToken(accessToken);
    res.json(await oauthLogin(profile));
  }),
);

// ── Facebook server-side OAuth (สำหรับเว็บ/PWA) ──────────────────────────────
// iOS Safari (ITP) บล็อก connect.facebook.net → FB JS SDK โหลดไม่ได้ ("window.FB is undefined")
// จึงต้อง redirect ไป facebook.com ตรง ๆ แทนการใช้ SDK ฝั่ง client
const fbRedirectUri = () =>
  process.env.FACEBOOK_REDIRECT_URI ??
  `${(env.webAppUrl || '').replace(/\/$/, '')}/api/v1/auth/facebook/callback`;

// GET /api/v1/auth/facebook/start — พาไปหน้า login ของ Facebook
authRouter.get(
  '/facebook/start',
  asyncHandler(async (req, res) => {
    if (!env.facebookAppId) throw new HttpError(503, 'backend ยังไม่ได้ตั้ง FACEBOOK_APP_ID');
    // state: กัน CSRF + จำหน้าที่ผู้ใช้จะกลับไป (ส่งกลับมาใน callback)
    const state = Buffer.from(
      JSON.stringify({ n: Math.random().toString(36).slice(2), t: Date.now() }),
    ).toString('base64url');
    const url =
      'https://www.facebook.com/v21.0/dialog/oauth' +
      `?client_id=${encodeURIComponent(env.facebookAppId)}` +
      `&redirect_uri=${encodeURIComponent(fbRedirectUri())}` +
      `&state=${state}` +
      '&scope=email,public_profile';
    res.redirect(url);
  }),
);

// GET /api/v1/auth/facebook/callback — Facebook ส่ง code กลับมา → แลก token → JWT → กลับเว็บ
authRouter.get(
  '/facebook/callback',
  asyncHandler(async (req, res) => {
    const web = (env.webAppUrl || '').replace(/\/$/, '');
    const fail = (msg: string) =>
      res.redirect(`${web}/#/login?fb_error=${encodeURIComponent(msg)}`);

    const code = typeof req.query.code === 'string' ? req.query.code : '';
    if (!code) return fail(typeof req.query.error_description === 'string' ? req.query.error_description : 'ยกเลิกการล็อกอิน Facebook');
    if (!env.facebookAppId || !env.facebookAppSecret) return fail('backend ยังไม่ได้ตั้ง FACEBOOK_APP_ID/SECRET');

    // แลก code → access token (ต้องใช้ app secret ฝั่ง server เท่านั้น)
    const tokenUrl =
      'https://graph.facebook.com/v21.0/oauth/access_token' +
      `?client_id=${encodeURIComponent(env.facebookAppId)}` +
      `&client_secret=${encodeURIComponent(env.facebookAppSecret)}` +
      `&redirect_uri=${encodeURIComponent(fbRedirectUri())}` +
      `&code=${encodeURIComponent(code)}`;
    const tokenRes = await fetch(tokenUrl);
    const tokenBody = await tokenRes.text();
    if (!tokenRes.ok) {
      // โชว์สาเหตุจริงจาก Facebook (เช่น secret ผิด / redirect_uri ไม่ตรง) แทนข้อความกว้าง ๆ
      let reason = tokenBody.slice(0, 200);
      try {
        const e = JSON.parse(tokenBody) as { error?: { message?: string } };
        if (e.error?.message) reason = e.error.message;
      } catch {
        /* ไม่ใช่ JSON → ใช้ text ดิบ */
      }
      console.error('[fb-oauth] token exchange failed', tokenRes.status, tokenBody.slice(0, 400));
      return fail(`FB: ${reason}`);
    }
    const tokenJson = JSON.parse(tokenBody) as { access_token?: string };
    if (!tokenJson.access_token) return fail('Facebook ไม่ได้ส่ง access token กลับมา');

    try {
      const profile = await verifyFacebookToken(tokenJson.access_token);
      const { token } = await oauthLogin(profile);
      // ส่ง JWT กลับหน้าเว็บผ่าน hash fragment (ไม่ติด log ของ server/proxy)
      res.redirect(`${web}/#/oauth?token=${encodeURIComponent(token)}`);
    } catch (e) {
      return fail(e instanceof HttpError ? e.message : 'ล็อกอิน Facebook ไม่สำเร็จ');
    }
  }),
);

authRouter.get(
  '/me',
  requireAuth,
  asyncHandler(async (req, res) => {
    const user = await prisma.user.findUnique({
      where: { id: req.userId! },
    });
    if (!user) throw new HttpError(404, 'ไม่พบผู้ใช้');

    const now = new Date();
    let pointsAwarded = false;
    let newPoints = user.points;

    if (!user.lastLoginAt) {
      pointsAwarded = true;
      newPoints += 10;
    } else {
      const lastLoginDate = new Date(user.lastLoginAt);
      const diffMs = now.getTime() - lastLoginDate.getTime();
      const hoursDiff = diffMs / (1000 * 60 * 60);

      if (
        now.getUTCFullYear() !== lastLoginDate.getUTCFullYear() ||
        now.getUTCMonth() !== lastLoginDate.getUTCMonth() ||
        now.getUTCDate() !== lastLoginDate.getUTCDate()
      ) {
        pointsAwarded = true;

        if (hoursDiff >= 24) {
          const periodsMissed = Math.floor(hoursDiff / 24);
          const penalty = periodsMissed * 2;
          newPoints = Math.max(0, newPoints - penalty);
        }

        newPoints += 10;
      }
    }

    let updatedUser = user;
    if (pointsAwarded) {
      let newLevel = 1;
      if (newPoints >= 500) newLevel = 3;
      else if (newPoints >= 100) newLevel = 2;

      updatedUser = await prisma.user.update({
        where: { id: req.userId! },
        data: {
          lastLoginAt: now,
          points: newPoints,
          level: newLevel,
        },
      });
    }

    res.json({
      user: {
        id: updatedUser.id,
        email: updatedUser.email,
        phone: updatedUser.phone ?? null,
        displayName: updatedUser.displayName,
        monthlyIncome: updatedUser.monthlyIncome,
        level: updatedUser.level,
        streak: updatedUser.streak,
        points: updatedUser.points,
        avatarUrl: updatedUser.avatarUrl ?? null,
        provider: updatedUser.provider,
        createdAt: updatedUser.createdAt.toISOString(),
      }
    });
  }),
);

authRouter.patch(
  '/me',
  requireAuth,
  asyncHandler(async (req, res) => {
    const data = updateProfileSchema.parse(req.body);

    if (data.email) {
      const duplicate = await prisma.user.findFirst({
        where: { email: data.email, id: { not: req.userId! } },
        select: { id: true },
      });
      if (duplicate) throw new HttpError(409, 'อีเมลนี้ถูกใช้งานแล้ว');
    }

    const user = await prisma.user.update({
      where: { id: req.userId! },
      data: {
        ...data,
        ...(data.phone !== undefined
          ? { phone: data.phone?.trim() || null }
          : {}),
      },
      select: profileSelect,
    });
    res.json({ user });
  }),
);
