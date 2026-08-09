import { Router } from 'express';
import { asyncHandler, HttpError } from '../../lib/http';
import { cache } from '../../lib/cache';
import { buildExportFile, buildDynamicFile, verifyExportToken, DynamicExportPayload, ExportKind, ExportFormat } from './export.service';
import { prisma } from '../../lib/prisma';

export const exportRouter = Router();

const KINDS: ExportKind[] = ['budget', 'transactions', 'summary', 'subscriptions'];

// GET /api/v1/export/:kind?format=xlsx|xml|pdf|docx|csv|json|txt|html&dt=<download token>
// auth ผ่าน dt (short-lived token). ถ้า token มี cacheId → dynamic (ตารางจากแชท), ไม่งั้น → export จาก DB

/**
 * กู้ payload ของไฟล์จากข้อความในแชทที่บันทึกไว้ใน DB
 * ใช้ตอน cache หาย (หมดอายุ 15 นาที หรือเซิร์ฟเวอร์รีสตาร์ต) — ทำให้ไฟล์เก่าโหลดซ้ำได้
 */
async function payloadFromChatHistory(
  userId: string,
  cacheId: string,
): Promise<DynamicExportPayload | null> {
  const row = await prisma.chatMessage.findFirst({
    where: { userId, role: 'assistant', context: { contains: cacheId } },
    orderBy: { createdAt: 'desc' },
    select: { context: true },
  });
  if (!row?.context) return null;
  try {
    const att = JSON.parse(row.context).attachment;
    return att?.payload ?? null;
  } catch {
    return null; // context พัง — ถือว่าไม่มี
  }
}

exportRouter.get(
  '/:kind',
  asyncHandler(async (req, res) => {
    const dt = req.query.dt as string | undefined;
    if (!dt) throw new HttpError(401, 'ต้องมี download token (dt)');

    let userId: string;
    let cacheId: string | undefined;
    try {
      ({ userId, cacheId } = verifyExportToken(dt));
    } catch {
      throw new HttpError(401, 'download token ไม่ถูกต้องหรือหมดอายุ');
    }

    const requested = String(req.query.format ?? 'xlsx').toLowerCase();
    const formats: ExportFormat[] = ['xlsx', 'xml', 'pdf', 'docx', 'csv', 'json', 'txt', 'html'];
    if (!formats.includes(requested as ExportFormat)) throw new HttpError(400, 'รูปแบบไฟล์ไม่ถูกต้อง');
    const format = requested as ExportFormat;

    let file;
    if (cacheId) {
      // dynamic — ตารางที่ LLM จัดจากแชท (เก็บใน cache 15 นาที)
      let payload = await cache.get<DynamicExportPayload>(`export:${cacheId}`);
      if (!payload) {
        // cache หาย (หมดอายุ/เซิร์ฟเวอร์รีสตาร์ต) → กู้จากข้อความในแชทที่บันทึกไว้
        payload = await payloadFromChatHistory(userId, cacheId);
        if (payload) await cache.set(`export:${cacheId}`, payload, 900); // เก็บกลับเข้า cache
      }
      if (!payload) {
        throw new HttpError(410, 'ไม่พบข้อมูลของไฟล์นี้แล้ว — ขอพี่เงินสร้างใหม่อีกครั้งได้เลยครับ');
      }
      file = await buildDynamicFile(payload, format);
    } else {
      const kind = req.params.kind as ExportKind;
      if (!KINDS.includes(kind)) throw new HttpError(400, 'ชนิดไฟล์ไม่ถูกต้อง');
      file = await buildExportFile(userId, kind, format);
    }

    res.setHeader('Content-Type', file.contentType);
    res.setHeader('Content-Disposition', `attachment; filename="${encodeURIComponent(file.filename)}"`);
    res.send(file.body);
  }),
);
