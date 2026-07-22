import { Router } from 'express';
import { asyncHandler } from '../../lib/http';
import { cache } from '../../lib/cache';
import { env } from '../../config/env';
import { handleGmailCallback } from '../subscriptions/gmail_oauth';

export const integrationsRouter = Router();

// GET /api/v1/integrations/gmail/callback — Google redirect กลับมาที่นี่ (auth ผ่าน state ไม่ใช้ Bearer)
integrationsRouter.get(
  '/gmail/callback',
  asyncHandler(async (req, res) => {
    const { code, state, error } = req.query as { code?: string; state?: string; error?: string };
    if (error || !code || !state) {
      return res.status(400).send(page('❌ ยกเลิก/ไม่สำเร็จ', String(error ?? 'ไม่มี code หรือ state')));
    }
    try {
      const result = await handleGmailCallback(code, state);
      await cache.delPattern(`user:${result.userId}:*`);
      res.send(page(`✅ นำเข้า ${result.imported} รายการจาก Gmail`, `สแกน ${result.scanned} อีเมล · ปิดหน้านี้ แล้วกลับไปที่แอป ลากรีเฟรชรายการ`));
    } catch (e) {
      res.status(500).send(page('❌ นำเข้าไม่สำเร็จ', (e as Error).message));
    }
  }),
);

function page(title: string, sub: string): string {
  const app = env.webAppUrl;
  return (
    `<!doctype html><html lang="th"><head><meta charset="utf-8">` +
    `<meta name="viewport" content="width=device-width,initial-scale=1"><title>Gmail import</title><style>` +
    `body{font-family:system-ui,sans-serif;background:#0D1117;color:#fff;margin:0;height:100vh;` +
    `display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center;padding:24px}` +
    `h2{margin:0 0 8px;font-size:22px}p{color:#8A9BB0;margin:0 0 22px;max-width:340px}` +
    `a{background:#00C850;color:#0D1117;text-decoration:none;padding:12px 26px;border-radius:12px;font-weight:700}` +
    `</style></head><body><h2>${title}</h2><p>${sub}</p><a href="${app}">เปิดแอป →</a></body></html>`
  );
}
