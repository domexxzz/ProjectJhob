import { Router } from 'express';
import { prisma } from '../../lib/prisma';
import { asyncHandler, HttpError } from '../../lib/http';
import { requireAuth } from '../../lib/auth';
import { z } from 'zod';
import { cache } from '../../lib/cache';

export const budgetsRouter = Router();
budgetsRouter.use(requireAuth);

const createBudgetSchema = z.object({
  name: z.string().min(1, 'กรุณาใส่ชื่อหัวข้องบประมาณ').optional(),
  categoryId: z.string().nullable().optional(),
  amount: z.number().int().positive('amount ต้องมากกว่า 0'),
  showOnDashboard: z.boolean().default(true).optional(),
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

    const cacheKey = `user:${userId}:budgets_status`;
    const cached = await cache.get<{ budgetsStatus: any[] }>(cacheKey);
    if (cached) return res.json(cached);

    const budgets = await prisma.budget.findMany({
      where: {
        userId,
      },
      include: { category: true },
    });

    const budgetsStatus = [];

    for (const b of budgets) {
      // Calculate total expense spent for this budget's category
      const agg = await prisma.transaction.aggregate({
        _sum: { amount: true },
        where: {
          userId,
          type: 'expense',
          OR: [
            { budgetId: b.id },
            ...(b.categoryId ? [{ categoryId: b.categoryId }] : []),
          ],
        },
      });

      const spent = agg._sum.amount || 0;
      const actualRatio = b.amount > 0 ? spent / b.amount : 0;
      const riskLevel = actualRatio >= 0.8
        ? 'danger'
        : actualRatio >= 0.5
          ? 'warning'
          : 'safe';

      budgetsStatus.push({
        id: b.id,
        name: (b as any).name ?? null,
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
        showOnDashboard: (b as any).showOnDashboard ?? true,
        riskLevel,
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
    
    // Check duplicates:
    // - ถ้ามี categoryId → ห้ามซ้ำ category+period
    // - ถ้าไม่มี categoryId (custom name) → ห้ามซ้ำ name+period
    let existing = null;
    if (data.categoryId) {
      existing = await prisma.budget.findFirst({
        where: {
          userId: req.userId!,
          categoryId: data.categoryId,
          period: data.period,
        },
      });
      if (existing) throw new HttpError(400, 'งบสำหรับหมวดหมู่นี้ถูกตั้งไว้แล้ว');
    } else if (data.name) {
      existing = await prisma.budget.findFirst({
        where: {
          userId: req.userId!,
          name: data.name,
          period: data.period,
        },
      });
      if (existing) throw new HttpError(400, `งบ "${data.name}" สำหรับช่วงเวลานี้ถูกตั้งไว้แล้ว`);
    }

    const budget = await prisma.budget.create({
      data: {
        userId: req.userId!,
        name: data.name ?? null,
        categoryId: data.categoryId,
        amount: data.amount,
        period: data.period,
        startDate: data.startDate ? new Date(data.startDate) : undefined,
        endDate: data.endDate ? new Date(data.endDate) : undefined,
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
        ...(data.name !== undefined ? { name: data.name } : {}),
        categoryId: data.categoryId,
        amount: data.amount,
        period: data.period,
        startDate: data.startDate !== undefined ? (data.startDate ? new Date(data.startDate) : null) : undefined,
        endDate: data.endDate !== undefined ? (data.endDate ? new Date(data.endDate) : null) : undefined,
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
