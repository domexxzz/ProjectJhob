import { Router } from 'express';
import { prisma } from '../../lib/prisma';
import { asyncHandler, HttpError } from '../../lib/http';
import { requireAuth } from '../../lib/auth';
import { z } from 'zod';
import { runBudgetTriggers } from './triggers';
import { runPredictionTriggers } from '../predictions/prediction_triggers';

export const notificationsRouter = Router();
notificationsRouter.use(requireAuth);

// GET /api/v1/notifications — รายการ + จำนวนยังไม่อ่าน
notificationsRouter.get(
  '/',
  asyncHandler(async (req, res) => {
    const userId = req.userId!;
    const [notifications, unreadCount] = await Promise.all([
      prisma.notification.findMany({ where: { userId }, orderBy: { createdAt: 'desc' }, take: 100 }),
      prisma.notification.count({ where: { userId, read: false } }),
    ]);
    res.json({ notifications, unreadCount });
  }),
);

// PATCH /api/v1/notifications/:id/read — ทำเป็นอ่านแล้ว
notificationsRouter.patch(
  '/:id/read',
  asyncHandler(async (req, res) => {
    const existing = await prisma.notification.findFirst({ where: { id: req.params.id, userId: req.userId! } });
    if (!existing) throw new HttpError(404, 'ไม่พบการแจ้งเตือน');
    const notification = await prisma.notification.update({ where: { id: req.params.id }, data: { read: true } });
    res.json({ notification });
  }),
);

// POST /api/v1/notifications/read-all — อ่านทั้งหมด
notificationsRouter.post(
  '/read-all',
  asyncHandler(async (req, res) => {
    await prisma.notification.updateMany({ where: { userId: req.userId!, read: false }, data: { read: true } });
    res.json({ ok: true });
  }),
);

// POST /api/v1/notifications/token — ลงทะเบียน FCM device token
const tokenSchema = z.object({ token: z.string().min(1) });
notificationsRouter.post(
  '/token',
  asyncHandler(async (req, res) => {
    const { token } = tokenSchema.parse(req.body);
    await prisma.user.update({ where: { id: req.userId! }, data: { deviceToken: token } });
    res.json({ ok: true });
  }),
);

// POST /api/v1/notifications/run-triggers — ตรวจงบเดี๋ยวนี้ → สร้างแจ้งเตือน (ใช้ทดสอบ/เดโม)
notificationsRouter.post(
  '/run-triggers',
  asyncHandler(async (req, res) => {
    const [budget, prediction] = await Promise.all([
      runBudgetTriggers(req.userId!),
      runPredictionTriggers(req.userId!), // 🔮 พยากรณ์ AI → แจ้งเตือน (ข้ามเงียบถ้า FastAPI ปิด)
    ]);
    const created = [...budget, ...prediction];
    res.json({ created: created.length, notifications: created });
  }),
);
