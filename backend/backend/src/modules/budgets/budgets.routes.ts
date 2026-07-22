import { Router } from 'express';
import { prisma } from '../../lib/prisma';
import { asyncHandler, HttpError } from '../../lib/http';
import { requireAuth } from '../../lib/auth';
import { z } from 'zod';
import { cache } from '../../lib/cache';

export const budgetsRouter = Router();
budgetsRouter.use(requireAuth);

const createBudgetSchema = z.object({
  categoryId: z.string().nullable().optional(),
  amount: z.number().int().positive('amount ต้องมากกว่า 0'),
  period: z.enum(['monthly', 'weekly']).default('monthly'),
});

const updateBudgetSchema = createBudgetSchema.partial();

// GET /api/v1/budgets
budgetsRouter.get(
  '/',
  asyncHandler(async (req, res) => {
    const cacheKey = `user:${req.userId}:budgets`;
    const cached = await cache.get<{ budgets: any[] }>(cacheKey);
    if (cached) return res.json(cached);

    const budgets = await prisma.budget.findMany({
      where: { userId: req.userId! },
      include: { category: true },
    });
    
    const result = { budgets };
    await cache.set(cacheKey, result, 300);
    res.json(result);
  }),
);

// GET /api/v1/budgets/status
budgetsRouter.get(
  '/status',
  asyncHandler(async (req, res) => {
    const userId = req.userId!;
    const { period } = req.query as { period?: string };

    const cacheKey = `user:${userId}:budgets_status:${period || 'all'}`;
    const cached = await cache.get<{ budgetsStatus: any[] }>(cacheKey);
    if (cached) return res.json(cached);

    const budgets = await prisma.budget.findMany({
      where: {
        userId,
        ...(period ? { period } : {}),
      },
      include: { category: true },
    });

    const now = new Date();
    const budgetsStatus = [];

    for (const b of budgets) {
      let startDate: Date;
      let endDate: Date;

      if (b.period === 'weekly') {
        const startOfWeek = new Date(now);
        const day = startOfWeek.getDay();
        const diff = startOfWeek.getDate() - day + (day === 0 ? -6 : 1);
        startOfWeek.setDate(diff);
        startOfWeek.setHours(0, 0, 0, 0);

        const endOfWeek = new Date(startOfWeek);
        endOfWeek.setDate(startOfWeek.getDate() + 7);

        startDate = startOfWeek;
        endDate = endOfWeek;
      } else {
        // default to monthly
        const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
        const endOfMonth = new Date(now.getFullYear(), now.getMonth() + 1, 1);

        startDate = startOfMonth;
        endDate = endOfMonth;
      }

      // Calculate total expense spent in this budget's range
      const agg = await prisma.transaction.aggregate({
        _sum: { amount: true },
        where: {
          userId,
          type: 'expense',
          categoryId: b.categoryId || null,
          occurredAt: {
            gte: startDate,
            lt: endDate,
          },
        },
      });

      const spent = agg._sum.amount || 0;

      budgetsStatus.push({
        id: b.id,
        categoryId: b.categoryId,
        category: b.category ? {
          id: b.category.id,
          name: b.category.name,
          nameTh: b.category.nameTh,
          icon: b.category.icon,
          color: b.category.color,
          type: b.category.type,
        } : null,
        amount: b.amount,
        spent,
        remaining: b.amount - spent,
        percentage: b.amount > 0 ? parseFloat((spent / b.amount).toFixed(2)) : 0,
        isExceeded: spent > b.amount,
        period: b.period,
      });
    }

    const result = { budgetsStatus };
    await cache.set(cacheKey, result, 300);
    res.json(result);
  }),
);

// POST /api/v1/budgets
budgetsRouter.post(
  '/',
  asyncHandler(async (req, res) => {
    const data = createBudgetSchema.parse(req.body);
    
    // Check if budget for this category and period already exists
    const existing = await prisma.budget.findFirst({
      where: {
        userId: req.userId!,
        categoryId: data.categoryId || null,
        period: data.period,
      },
    });
    if (existing) {
      throw new HttpError(400, 'งบสำหรับหมวดหมู่นี้ถูกตั้งไว้แล้ว');
    }

    const budget = await prisma.budget.create({
      data: {
        userId: req.userId!,
        categoryId: data.categoryId,
        amount: data.amount,
        period: data.period,
      },
      include: { category: true },
    });

    await cache.delPattern(`user:${req.userId!}:*`);
    res.status(201).json({ budget });
  }),
);

// PATCH /api/v1/budgets/:id
budgetsRouter.patch(
  '/:id',
  asyncHandler(async (req, res) => {
    const data = updateBudgetSchema.parse(req.body);
    const existing = await prisma.budget.findFirst({
      where: { id: req.params.id, userId: req.userId! },
    });
    if (!existing) throw new HttpError(404, 'ไม่พบงบประมาณ');

    const budget = await prisma.budget.update({
      where: { id: req.params.id },
      data: {
        categoryId: data.categoryId,
        amount: data.amount,
        period: data.period,
      },
      include: { category: true },
    });

    await cache.delPattern(`user:${req.userId!}:*`);
    res.json({ budget });
  }),
);

// DELETE /api/v1/budgets/:id
budgetsRouter.delete(
  '/:id',
  asyncHandler(async (req, res) => {
    const existing = await prisma.budget.findFirst({
      where: { id: req.params.id, userId: req.userId! },
    });
    if (!existing) throw new HttpError(404, 'ไม่พบงบประมาณ');

    await prisma.budget.delete({ where: { id: req.params.id } });

    await cache.delPattern(`user:${req.userId!}:*`);
    res.json({ ok: true });
  }),
);
