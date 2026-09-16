import { Router } from 'express';
import { asyncHandler } from '../../lib/http';
import { requireAuth } from '../../lib/auth';
import { prisma } from '../../lib/prisma';

export const categoriesRouter = Router();
categoriesRouter.use(requireAuth);

categoriesRouter.get(
  '/',
  asyncHandler(async (_req, res) => {
    const categories = await prisma.category.findMany({ orderBy: [{ type: 'asc' }, { name: 'asc' }] });
    res.json({ categories });
  }),
);

categoriesRouter.post(
  '/',
  asyncHandler(async (req, res) => {
    const { nameTh, icon, color, type } = req.body;
    if (!nameTh || typeof nameTh !== 'string' || !nameTh.trim()) {
      res.status(400).json({ error: 'กรุณาระบุชื่อหมวดหมู่' });
      return;
    }

    const trimmedNameTh = nameTh.trim();
    const categoryName = `custom_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    const categoryType = type === 'income' ? 'income' : 'expense';
    const categoryIcon = icon && typeof icon === 'string' ? icon.trim() : '📁';
    const categoryColor = color && typeof color === 'string' ? color.trim() : '#4CD97B';

    const category = await prisma.category.create({
      data: {
        name: categoryName,
        nameTh: trimmedNameTh,
        icon: categoryIcon,
        color: categoryColor,
        type: categoryType,
        isDefault: false,
      },
    });

    res.status(201).json({ category });
  }),
);
