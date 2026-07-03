import { Router } from 'express';
import { prisma } from '../../lib/prisma';
import { asyncHandler, HttpError } from '../../lib/http';
import { requireAuth } from '../../lib/auth';
import { z } from 'zod';
import { cache } from '../../lib/cache';
import type { Goal } from '@prisma/client';
import { buildContext } from '../chat/context_builder';
import { generateSavingsPlan } from './plan';

export const goalsRouter = Router();
goalsRouter.use(requireAuth);

// 💡 จำนวนเงิน (target/current) เป็น "สตางค์" (Int) เหมือนทั้งระบบ
const createGoalSchema = z.object({
  name: z.string().trim().min(1, 'ชื่อเป้าหมายห้ามว่าง').max(100),
  target: z.number().int().positive('target ต้องมากกว่า 0'),
  current: z.number().int().min(0).optional(),
  deadline: z.coerce.date().optional(), // รับ ISO string ("2026-12-31") ได้
});

const updateGoalSchema = createGoalSchema.partial();

const depositSchema = z.object({
  amount: z.number().int().positive('amount ต้องมากกว่า 0'),
});

/** แนบ percentage (0–100, ปัดเลขจำนวนเต็ม) ให้ client เอาไปโชว์ progress ได้เลย */
function withProgress(g: Goal) {
  return {
    ...g,
    percentage: g.target > 0 ? Math.round((g.current / g.target) * 100) : 0,
  };
}

// GET /api/v1/goals — รายการเป้าหมายทั้งหมด + progress
goalsRouter.get(
  '/',
  asyncHandler(async (req, res) => {
    const userId = req.userId!;
    const cacheKey = `user:${userId}:goals`;
    const cached = await cache.get<{ goals: ReturnType<typeof withProgress>[] }>(cacheKey);
    if (cached) return res.json(cached);

    const goals = await prisma.goal.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });

    const result = { goals: goals.map(withProgress) };
    await cache.set(cacheKey, result, 300);
    res.json(result);
  }),
);

// POST /api/v1/goals — สร้างเป้าหมายใหม่
goalsRouter.post(
  '/',
  asyncHandler(async (req, res) => {
    const data = createGoalSchema.parse(req.body);

    const goal = await prisma.goal.create({
      data: {
        userId: req.userId!,
        name: data.name,
        target: data.target,
        current: data.current ?? 0,
        deadline: data.deadline,
      },
    });

    await cache.delPattern(`user:${req.userId!}:*`);
    res.status(201).json({ goal: withProgress(goal) });
  }),
);

// PATCH /api/v1/goals/:id — แก้ชื่อ/เป้า/current/เดดไลน์
goalsRouter.patch(
  '/:id',
  asyncHandler(async (req, res) => {
    const data = updateGoalSchema.parse(req.body);

    const existing = await prisma.goal.findFirst({
      where: { id: req.params.id, userId: req.userId! },
    });
    if (!existing) throw new HttpError(404, 'ไม่พบเป้าหมาย');

    const goal = await prisma.goal.update({
      where: { id: req.params.id },
      data: {
        name: data.name,
        target: data.target,
        current: data.current,
        deadline: data.deadline,
      },
    });

    await cache.delPattern(`user:${req.userId!}:*`);
    res.json({ goal: withProgress(goal) });
  }),
);

// POST /api/v1/goals/:id/deposit — เติมเงินเข้าเป้า (current += amount)
goalsRouter.post(
  '/:id/deposit',
  asyncHandler(async (req, res) => {
    const { amount } = depositSchema.parse(req.body);

    const existing = await prisma.goal.findFirst({
      where: { id: req.params.id, userId: req.userId! },
    });
    if (!existing) throw new HttpError(404, 'ไม่พบเป้าหมาย');

    const goal = await prisma.goal.update({
      where: { id: req.params.id },
      data: { current: { increment: amount } }, // atomic
    });

    await cache.delPattern(`user:${req.userId!}:*`);
    res.json({ goal: withProgress(goal) });
  }),
);

// POST /api/v1/goals/:id/plan — แผนออม AI (DM-3): คำนวณตัวเลข + พี่เงิน (Typhoon) เรียบเรียง + heuristic fallback
goalsRouter.post(
  '/:id/plan',
  asyncHandler(async (req, res) => {
    const goal = await prisma.goal.findFirst({
      where: { id: req.params.id, userId: req.userId! },
    });
    if (!goal) throw new HttpError(404, 'ไม่พบเป้าหมาย');

    const ctx = await buildContext(req.userId!);
    const plan = await generateSavingsPlan(goal, ctx);
    res.json({ plan });
  }),
);

// DELETE /api/v1/goals/:id
goalsRouter.delete(
  '/:id',
  asyncHandler(async (req, res) => {
    const existing = await prisma.goal.findFirst({
      where: { id: req.params.id, userId: req.userId! },
    });
    if (!existing) throw new HttpError(404, 'ไม่พบเป้าหมาย');

    await prisma.goal.delete({ where: { id: req.params.id } });

    await cache.delPattern(`user:${req.userId!}:*`);
    res.json({ ok: true });
  }),
);
