import { Router } from 'express';
import { Prisma } from '@prisma/client';
import { asyncHandler, HttpError } from '../../lib/http';
import { requireAuth } from '../../lib/auth';
import { createTransactionSchema, updateTransactionSchema } from '../../lib/validate';
import { prisma } from '../../lib/prisma';
import { parseAmount, parseDate, parseRef, parseMerchant, autoCategorize } from './parser';
import { cache } from '../../lib/cache';
import { ocrImage } from '../chat/coach';

export const transactionsRouter = Router();
transactionsRouter.use(requireAuth);

/**
 * Historical anomaly check helper
 * Flags if an expense is 40% or more above the average of the last 10 expenses in the same category
 */
async function checkAnomaly(
  userId: string,
  type: string,
  categoryId: string | null,
  amount: number
): Promise<string | null> {
  if (type !== 'expense' || !categoryId) return null;

  const pastTxns = await prisma.transaction.findMany({
    where: {
      userId,
      type: 'expense',
      categoryId,
    },
    orderBy: { occurredAt: 'desc' },
    take: 10,
    select: { amount: true },
  });

  if (pastTxns.length >= 3) {
    const sum = pastTxns.reduce((acc, t) => acc + t.amount, 0);
    const avg = sum / pastTxns.length;

    if (amount >= 1.4 * avg) {
      const category = await prisma.category.findUnique({
        where: { id: categoryId },
      });
      const catName = category?.nameTh || 'หมวดหมู่นี้';
      const pct = Math.round(((amount - avg) / avg) * 100);
      return `คุณใช้จ่ายในหมวด ${catName} สูงกว่าค่าเฉลี่ยปกติ ${pct}% ⚠️`;
    }
  }

  return null;
}

// GET /api/v1/transactions?month=YYYY-MM&type=expense
transactionsRouter.get(
  '/',
  asyncHandler(async (req, res) => {
    const { month, type } = req.query as { month?: string; type?: string };
    const cacheKey = `user:${req.userId!}:transactions:${month || 'all'}:${type || 'all'}`;

    const cached = await cache.get<any>(cacheKey);
    if (cached) return res.json(cached);

    const where: Prisma.TransactionWhereInput = { userId: req.userId! };
    if (type === 'income' || type === 'expense') where.type = type;
    if (month && /^\d{4}-\d{2}$/.test(month)) {
      const [y, m] = month.split('-').map(Number);
      where.occurredAt = { gte: new Date(y, m - 1, 1), lt: new Date(y, m, 1) };
    }

    const transactions = await prisma.transaction.findMany({
      where,
      orderBy: { occurredAt: 'desc' },
      include: { category: true },
    });

    const summary = transactions.reduce(
      (acc, t) => {
        if (t.type === 'income') acc.income += t.amount;
        else acc.expense += t.amount;
        return acc;
      },
      { income: 0, expense: 0 },
    );

    const result = {
      transactions,
      summary: { ...summary, balance: summary.income - summary.expense },
    };

    await cache.set(cacheKey, result, 300);
    res.json(result);
  }),
);

// POST /api/v1/transactions
transactionsRouter.post(
  '/',
  asyncHandler(async (req, res) => {
    const data = createTransactionSchema.parse(req.body);

    const anomalyAlert = await checkAnomaly(
      req.userId!,
      data.type,
      data.categoryId || null,
      data.amount
    );

    const transaction = await prisma.transaction.create({
      data: {
        userId: req.userId!,
        type: data.type,
        amount: data.amount,
        note: data.note,
        source: data.source,
        categoryId: data.categoryId,
        occurredAt: data.occurredAt ? new Date(data.occurredAt) : undefined,
      },
      include: { category: true },
    });

    await cache.delPattern(`user:${req.userId!}:*`);

    res.status(201).json({
      transaction,
      ...(anomalyAlert ? { anomalyAlert } : {}),
    });
  }),
);

// GET /api/v1/transactions/aggregate?by=category|time
transactionsRouter.get(
  '/aggregate',
  asyncHandler(async (req, res) => {
    const { by, period, month } = req.query as { by?: string; period?: string; month?: string };
    const userId = req.userId!;

    const cacheKey = `user:${userId}:transactions_aggregate:${by || 'all'}:${period || 'all'}:${month || 'all'}`;
    const cached = await cache.get<any>(cacheKey);
    if (cached) return res.json(cached);

    const where: Prisma.TransactionWhereInput = { userId };
    if (month && /^\d{4}-\d{2}$/.test(month)) {
      const [y, m] = month.split('-').map(Number);
      where.occurredAt = { gte: new Date(y, m - 1, 1), lt: new Date(y, m, 1) };
    }

    const transactions = await prisma.transaction.findMany({
      where,
      include: { category: true },
    });

    const income = transactions.filter(t => t.type === 'income').reduce((sum, t) => sum + t.amount, 0);
    const expense = transactions.filter(t => t.type === 'expense').reduce((sum, t) => sum + t.amount, 0);
    const balance = income - expense;
    const summary = { income, expense, balance };

    let result: any = { summary };

    if (by === 'category') {
      const expenseTxns = transactions.filter(t => t.type === 'expense');
      const catGroups: Record<string, { categoryId: string | null; nameTh: string; icon: string; color: string; amount: number }> = {};
      
      for (const t of expenseTxns) {
        const catId = t.categoryId || 'other';
        const nameTh = t.category?.nameTh || 'อื่นๆ';
        const icon = t.category?.icon || '💸';
        const color = t.category?.color || '#8E9AA6';
        
        if (!catGroups[catId]) {
          catGroups[catId] = { categoryId: t.categoryId, nameTh, icon, color, amount: 0 };
        }
        catGroups[catId].amount += t.amount;
      }

      const categoriesList = Object.values(catGroups).map(g => ({
        ...g,
        percentage: expense > 0 ? Math.round((g.amount / expense) * 100) : 0,
      })).sort((a, b) => b.amount - a.amount);

      result = { summary, categories: categoriesList };
    } else if (by === 'time') {
      const timeGroups: Record<string, { label: string; income: number; expense: number; amount: number }> = {};
      
      for (const t of transactions) {
        const date = new Date(t.occurredAt);
        let label = '';
        if (period === 'day') {
          label = date.toISOString().split('T')[0];
        } else if (period === 'week') {
          const oneJan = new Date(date.getFullYear(), 0, 1);
          const numberOfDays = Math.floor((date.getTime() - oneJan.getTime()) / (24 * 60 * 60 * 1000));
          const weekNum = Math.ceil((date.getDay() + 1 + numberOfDays) / 7);
          label = `${date.getFullYear()}-W${String(weekNum).padStart(2, '0')}`;
        } else {
          label = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`;
        }

        if (!timeGroups[label]) {
          timeGroups[label] = { label, income: 0, expense: 0, amount: 0 };
        }
        if (t.type === 'income') {
          timeGroups[label].income += t.amount;
        } else {
          timeGroups[label].expense += t.amount;
        }
        timeGroups[label].amount = timeGroups[label].income - timeGroups[label].expense;
      }

      const intervalsList = Object.values(timeGroups).sort((a, b) => a.label.localeCompare(b.label));
      result = { summary, intervals: intervalsList };
    } else {
      result = { summary, transactionsCount: transactions.length };
    }

    await cache.set(cacheKey, result, 300);
    res.json(result);
  }),
);

// POST /api/v1/transactions/parse-slip — อัพสลิป → Typhoon OCR → ดึงยอด/วันที่/ร้าน/หมวด (รวมขั้นตอนให้เรียกครั้งเดียว)
transactionsRouter.post(
  '/parse-slip',
  asyncHandler(async (req, res) => {
    const { imageBase64 } = req.body as { imageBase64?: string };
    if (!imageBase64) throw new HttpError(400, 'ต้องแนบรูปสลิป (imageBase64 เป็น data URL)');

    let text: string;
    try {
      text = await ocrImage(imageBase64);
    } catch (e) {
      console.error('[parse-slip] OCR ล้มเหลว:', (e as Error).message);
      throw new HttpError(503, 'อ่านสลิปไม่สำเร็จ — ตรวจว่าตั้ง TYPHOON_API_KEY และรุ่น OCR ถูกต้อง');
    }

    const amountSatang = parseAmount(text);
    const date = parseDate(text);
    const ref = parseRef(text);
    const merchant = parseMerchant(text);
    const categoryId = await autoCategorize(text, merchant || '', 'expense', req.userId);

    res.json({
      amount: amountSatang, // สตางค์ (0 = อ่านยอดไม่เจอ ให้ผู้ใช้กรอกเอง)
      date: date ? date.toISOString().split('T')[0] : null,
      ref,
      merchant,
      categoryId,
      rawText: text,
    });
  }),
);

// POST /api/v1/transactions/analyze-text
transactionsRouter.post(
  '/analyze-text',
  asyncHandler(async (req, res) => {
    const { text } = req.body as { text?: string };
    if (!text) {
      throw new HttpError(400, 'กรุณาส่งข้อความที่สแกนได้');
    }

    const amountSatang = parseAmount(text);
    const date = parseDate(text);
    const ref = parseRef(text);
    const merchant = parseMerchant(text);

    const categoryId = await autoCategorize(text, merchant || '', 'expense', req.userId);

    res.json({
      amount: amountSatang,
      date: date ? date.toISOString().split('T')[0] : null,
      ref,
      merchant,
      categoryId,
    });
  }),
);

transactionsRouter.get(
  '/:id',
  asyncHandler(async (req, res) => {
    const transaction = await prisma.transaction.findFirst({
      where: { id: req.params.id, userId: req.userId! },
      include: { category: true },
    });
    if (!transaction) throw new HttpError(404, 'ไม่พบรายการ');
    res.json({ transaction });
  }),
);

// PATCH /api/v1/transactions/:id
transactionsRouter.patch(
  '/:id',
  asyncHandler(async (req, res) => {
    const data = updateTransactionSchema.parse(req.body);
    const existing = await prisma.transaction.findFirst({
      where: { id: req.params.id, userId: req.userId! },
    });
    if (!existing) throw new HttpError(404, 'ไม่พบรายการ');

    const anomalyAlert = await checkAnomaly(
      req.userId!,
      data.type || existing.type,
      data.categoryId !== undefined ? data.categoryId : existing.categoryId,
      data.amount !== undefined ? data.amount : existing.amount
    );

    const transaction = await prisma.transaction.update({
      where: { id: req.params.id },
      data: {
        type: data.type,
        amount: data.amount,
        note: data.note,
        source: data.source,
        categoryId: data.categoryId,
        occurredAt: data.occurredAt ? new Date(data.occurredAt) : undefined,
      },
      include: { category: true },
    });

    await cache.delPattern(`user:${req.userId!}:*`);

    res.json({
      transaction,
      ...(anomalyAlert ? { anomalyAlert } : {}),
    });
  }),
);

// DELETE /api/v1/transactions/:id
transactionsRouter.delete(
  '/:id',
  asyncHandler(async (req, res) => {
    const existing = await prisma.transaction.findFirst({
      where: { id: req.params.id, userId: req.userId! },
    });
    if (!existing) throw new HttpError(404, 'ไม่พบรายการ');
    
    await prisma.transaction.delete({ where: { id: req.params.id } });

    await cache.delPattern(`user:${req.userId!}:*`);

    res.json({ ok: true });
  }),
);
