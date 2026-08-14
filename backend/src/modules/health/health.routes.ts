import { Router } from 'express';
import { prisma } from '../../lib/prisma';
import { asyncHandler } from '../../lib/http';
import { mailerStatus } from '../../lib/mailer';

export const healthRouter = Router();

healthRouter.get(
  '/',
  asyncHandler(async (_req, res) => {
    let db = 'ok';
    try {
      await prisma.$queryRaw`SELECT 1`;
    } catch {
      db = 'error';
    }
    // บอกแค่ว่า "ตั้งค่าการส่งอีเมลแล้วหรือยัง" ไม่บอกว่าใช้บริการอะไรหรือ host ไหน
    // เพราะ /health เรียกได้โดยไม่ต้องล็อกอิน — ยิ่งบอกน้อยยิ่งดี
    const mailer = mailerStatus() === 'ยังไม่ได้ตั้งค่า' ? 'not-configured' : 'ok';
    res.json({ status: 'ok', db, mailer, uptime: Math.round(process.uptime()) });
  }),
);
