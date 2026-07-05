import { Router } from 'express';
import { prisma } from '../../lib/prisma';
import { asyncHandler, HttpError } from '../../lib/http';
import { requireAuth } from '../../lib/auth';
import { z } from 'zod';
import { cache } from '../../lib/cache';
import type { Subscription } from '@prisma/client';
import { runSubscriptionReminders } from './reminders';
import { importSubscriptionsFromGmail } from './gmail_import';
import { buildGmailAuthUrl } from './gmail_oauth';

// 💡 DM-5 — Subscription Tracker (Netflix/Spotify/YouTube รายเดือน) · จำนวนเงินเป็นสตางค์

export const subscriptionsRouter = Router();
subscriptionsRouter.use(requireAuth);

const createSchema = z.object({
  name: z.string().trim().min(1, 'ชื่อห้ามว่าง').max(100),
  amount: z.number().int().positive('amount ต้องมากกว่า 0'),
  cycle: z.enum(['monthly', 'yearly']).default('monthly'),
  nextBilling: z.coerce.date(),
  logo: z.string().max(200).optional(),
});
const updateSchema = createSchema.partial();

/** แปลงเป็นยอด "ต่อเดือน" (รายปี ÷ 12) เพื่อรวมยอด */
function monthlyEquivalent(s: Subscription): number {
  return s.cycle === 'yearly' ? Math.round(s.amount / 12) : s.amount;
}

// GET /api/v1/subscriptions — รายการ + ยอดรวมต่อเดือน
subscriptionsRouter.get(
  '/',
  asyncHandler(async (req, res) => {
    const userId = req.userId!;
    const cacheKey = `user:${userId}:subs`;
    const cached = await cache.get<{ subscriptions: Subscription[]; totalMonthly: number }>(cacheKey);
    if (cached) return res.json(cached);

    const subscriptions = await prisma.subscription.findMany({
      where: { userId },
      orderBy: { nextBilling: 'asc' },
    });
    const totalMonthly = subscriptions.reduce((sum, s) => sum + monthlyEquivalent(s), 0);

    const result = { subscriptions, totalMonthly };
    await cache.set(cacheKey, result, 300);
    res.json(result);
  }),
);

// POST /api/v1/subscriptions
subscriptionsRouter.post(
  '/',
  asyncHandler(async (req, res) => {
    const data = createSchema.parse(req.body);
    const subscription = await prisma.subscription.create({
      data: { userId: req.userId!, ...data },
    });
    await cache.delPattern(`user:${req.userId!}:*`);
    res.status(201).json({ subscription });
  }),
);

// PATCH /api/v1/subscriptions/:id
subscriptionsRouter.patch(
  '/:id',
  asyncHandler(async (req, res) => {
    const data = updateSchema.parse(req.body);
    const existing = await prisma.subscription.findFirst({ where: { id: req.params.id, userId: req.userId! } });
    if (!existing) throw new HttpError(404, 'ไม่พบรายการ subscription');

    const subscription = await prisma.subscription.update({ where: { id: req.params.id }, data });
    await cache.delPattern(`user:${req.userId!}:*`);
    res.json({ subscription });
  }),
);

// DELETE /api/v1/subscriptions/:id
subscriptionsRouter.delete(
  '/:id',
  asyncHandler(async (req, res) => {
    const existing = await prisma.subscription.findFirst({ where: { id: req.params.id, userId: req.userId! } });
    if (!existing) throw new HttpError(404, 'ไม่พบรายการ subscription');

    await prisma.subscription.delete({ where: { id: req.params.id } });
    await cache.delPattern(`user:${req.userId!}:*`);
    res.json({ ok: true });
  }),
);

// POST /api/v1/subscriptions/run-reminders — เตือน subscription ที่ใกล้ตัดเงิน (ทดสอบ/เดโม)
subscriptionsRouter.post(
  '/run-reminders',
  asyncHandler(async (req, res) => {
    const created = await runSubscriptionReminders(req.userId!);
    res.json({ created: created.length, notifications: created });
  }),
);

// GET /api/v1/subscriptions/gmail/auth-url — คืน URL ให้ผู้ใช้ไปยินยอมที่ Google (server-side OAuth, robust)
subscriptionsRouter.get(
  '/gmail/auth-url',
  asyncHandler(async (req, res) => {
    const url = buildGmailAuthUrl(req.userId!);
    res.json({ url });
  }),
);

// POST /api/v1/subscriptions/import-gmail — นำเข้า subscription จาก Gmail (ต้องมี Google access token + scope gmail.readonly)
const gmailImportSchema = z.object({ accessToken: z.string().min(10) });
subscriptionsRouter.post(
  '/import-gmail',
  asyncHandler(async (req, res) => {
    const { accessToken } = gmailImportSchema.parse(req.body);
    const result = await importSubscriptionsFromGmail(req.userId!, accessToken);
    await cache.delPattern(`user:${req.userId!}:*`);
    res.json(result);
  }),
);
