import { Router } from 'express';
import { z } from 'zod';
import { asyncHandler } from '../../lib/http';
import { HttpError } from '../../lib/http';
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
