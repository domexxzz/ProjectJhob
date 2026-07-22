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
