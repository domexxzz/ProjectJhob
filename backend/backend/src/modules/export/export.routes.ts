import { Router } from 'express';
import { asyncHandler, HttpError } from '../../lib/http';
import { cache } from '../../lib/cache';
import { buildExportFile, buildDynamicFile, verifyExportToken, DynamicTable, ExportKind, ExportFormat } from './export.service';

export const exportRouter = Router();

const KINDS: ExportKind[] = ['budget', 'transactions', 'summary', 'subscriptions'];

// GET /api/v1/export/:kind?format=xlsx|xml&dt=<download token>
// auth ผ่าน dt (short-lived token). ถ้า token มี cacheId → dynamic (ตารางจากแชท), ไม่งั้น → export จาก DB
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

    const format: ExportFormat = req.query.format === 'xml' ? 'xml' : 'xlsx';

    let file;
    if (cacheId) {
      // dynamic — ตารางที่ LLM จัดจากแชท (เก็บใน cache 15 นาที)
      const table = await cache.get<DynamicTable>(`export:${cacheId}`);
      if (!table) throw new HttpError(410, 'ไฟล์หมดอายุแล้ว (เกิน 15 นาที) — ขอพี่เงินสร้างใหม่อีกครั้งได้เลย');
      file = buildDynamicFile(table, format);
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
