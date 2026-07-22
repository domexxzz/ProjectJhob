import { Router } from 'express';
import { z } from 'zod';
import { asyncHandler } from '../../lib/http';
import { requireAuth } from '../../lib/auth';
import { registerSchema, loginSchema } from '../../lib/validate';
import { registerUser, loginUser } from './auth.service';
import { verifyGoogleIdToken, verifyGoogleAccessToken, verifyFacebookToken, oauthLogin } from './oauth.service';
import { prisma } from '../../lib/prisma';

export const authRouter = Router();

// รับได้ทั้ง idToken (มือถือ) และ accessToken (เว็บ) — อย่างน้อย 1 อย่าง
const googleSchema = z
  .object({ idToken: z.string().min(10).optional(), accessToken: z.string().min(10).optional() })
  .refine((d) => d.idToken || d.accessToken, { message: 'ต้องมี idToken หรือ accessToken' });
const facebookSchema = z.object({ accessToken: z.string().min(10) });

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

authRouter.get(
  '/me',
  requireAuth,
  asyncHandler(async (req, res) => {
    const user = await prisma.user.findUnique({
      where: { id: req.userId! },
      select: {
        id: true,
        email: true,
        displayName: true,
        monthlyIncome: true,
        level: true,
        streak: true,
        avatarUrl: true,
        provider: true,
      },
    });
    res.json({ user });
  }),
);
