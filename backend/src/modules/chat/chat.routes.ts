import { Router } from 'express';
import { z } from 'zod';
import { asyncHandler, HttpError } from '../../lib/http';
import { requireAuth } from '../../lib/auth';
import { prisma } from '../../lib/prisma';
import { cache } from '../../lib/cache';
import { buildContext } from './context_builder';
import { generateReply, ChatTurn, ocrImage } from './coach';
import {
  detectExportRequest,
  buildExportReply,
  buildDynamicExportReply,
  ChatAttachment,
} from './export_intent';
import { checkFinanceScope, OUT_OF_SCOPE_REPLY } from './finance_scope';

export const chatRouter = Router();
chatRouter.use(requireAuth);

// เผื่อข้อความยาวจาก OCR (สลิป/ตาราง) — ปกติผู้ใช้พิมพ์สั้น แต่แนบรูปแล้ววิเคราะห์อาจยาว
const sendSchema = z.object({
  message: z.string().min(1).max(8000),
  imageBase64: z.string().optional(), // ➕ รองรับการส่งรูปแบบ Base64
});

// GET /api/v1/chat -> ประวัติแชท
chatRouter.get(
  '/',
  asyncHandler(async (req, res) => {
    const messages = await prisma.chatMessage.findMany({
      where: { userId: req.userId! },
      orderBy: { createdAt: 'asc' },
      take: 100,
    });
    res.json({ messages });
  }),
);

// POST /api/v1/chat -> ส่งข้อความ + รับคำตอบจากพี่เงิน
chatRouter.post(
  '/',
  asyncHandler(async (req, res) => {
    const { message, imageBase64 } = sendSchema.parse(req.body);
    const userId = req.userId!;

    // rate limit ง่ายๆ: 20 ข้อความ/นาที/คน
    const rlKey = `chat_rl:${userId}`;
    const count = (await cache.get<number>(rlKey)) ?? 0;
    if (count >= 20) throw new HttpError(429, 'ส่งข้อความถี่เกินไป ลองใหม่อีกครั้งใน 1 นาที');
    await cache.set(rlKey, count + 1, 60);

    // ทำ OCR ถ้าผู้ใช้ส่งรูปภาพมาด้วย
    let ocrText: string | undefined;
    if (imageBase64) {
      try {
        ocrText = await ocrImage(imageBase64);
      } catch (e) {
        console.error('[chat] OCR failed for message image attachment:', e);
      }
    }

    // ตรวจขอบเขตก่อนเรียก LLM และก่อนสร้างไฟล์ เพื่อให้พี่เงินตอบเฉพาะเรื่องการเงิน
    const priorMessagesDesc = await prisma.chatMessage.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 16,
    });
    const history: ChatTurn[] = [...priorMessagesDesc].reverse().filter((m) => {
      if (m.role !== 'assistant' || !m.context) return true;
      try {
        const source = JSON.parse(m.context).source;
        return source !== 'finance-scope-guard' && source !== 'export-format-unsupported';
      } catch (_) {
        return true;
      }
    }).map((m) => {
      let content = m.content;
      if (m.role === 'user' && m.context) {
        try {
          const parsed = JSON.parse(m.context);
          if (parsed.ocrText) {
            content = `${m.content}\n\n[ข้อมูลที่แอปตรวจพบในรูปภาพที่ผู้ใช้แนบ: ${parsed.ocrText}]`;
          }
        } catch (_) {}
      }
      return { role: m.role === 'assistant' ? 'assistant' : 'user', content };
    });
    const scope = checkFinanceScope(message, history, ocrText);

    // เก็บข้อความผู้ใช้ โดยเก็บ ocrText และ flag ว่ามีรูปไว้ใน context
    await prisma.chatMessage.create({
      data: {
        userId,
        role: 'user',
        content: message,
        context: ocrText ? JSON.stringify({ hasImage: true, ocrText }) : null,
      },
    });

    if (!scope.allowed) {
      const saved = await prisma.chatMessage.create({
        data: {
          userId,
          role: 'assistant',
          content: OUT_OF_SCOPE_REPLY,
          context: JSON.stringify({ source: 'finance-scope-guard', reason: scope.reason }),
        },
      });
      res.status(201).json({ message: saved, source: 'finance-scope-guard' });
      return;
    }

    // ── ถ้าเป็นคำขอ "ไฟล์การเงิน" → พี่เงินสร้างไฟล์ + แนบปุ่มดาวน์โหลด ──
    const exp = detectExportRequest(message);
    if (exp) {
      let reply: string;
      let attachment: ChatAttachment | null;
      if (exp.kind === 'custom') {
        // ข้อมูลจากบทสนทนา → ให้ LLM จัดเป็นตาราง
        const ctx = await buildContext(userId);
        ({ reply, attachment } = await buildDynamicExportReply(userId, exp.format, ctx, message, history));
      } else {
        ({ reply, attachment } = buildExportReply(userId, exp.kind, exp.format));
      }
      const saved = await prisma.chatMessage.create({
        data: { userId, role: 'assistant', content: reply, context: JSON.stringify({ source: 'export', attachment }) },
      });
      res.status(201).json({ message: saved, source: 'export', attachment });
      return;
    }

    // ประกอบ context จริง โดยใช้เฉพาะบทสนทนาก่อนข้อความปัจจุบัน (ไม่ส่งคำถามซ้ำ)
    const context = await buildContext(userId);

    // ส่งข้อความปัจจุบันพร้อมแนบข้อมูล OCR ล่าสุดเข้าไปคุยกับ LLM
    let currentQuestion = message;
    if (ocrText) {
      currentQuestion = `${message}\n\n[ข้อมูลที่แอปตรวจพบในรูปภาพที่ส่งมาในข้อความนี้: ${ocrText}]`;
    }

    const { reply, source } = await generateReply(context, currentQuestion, history);

    // เก็บคำตอบ (แนบ snapshot ว่า source อะไร)
    const saved = await prisma.chatMessage.create({
      data: { userId, role: 'assistant', content: reply, context: JSON.stringify({ source }) },
    });

    res.status(201).json({ message: saved, source });
  }),
);

// POST /api/v1/chat/ocr -> อ่านข้อความจากรูป (สลิป/เอกสาร) ด้วย Typhoon OCR
chatRouter.post(
  '/ocr',
  asyncHandler(async (req, res) => {
    const { imageBase64 } = req.body as { imageBase64?: string };
    if (!imageBase64) throw new HttpError(400, 'ต้องแนบรูป (imageBase64 เป็น data URL)');
    try {
      const text = await ocrImage(imageBase64);
      res.json({ text });
    } catch (e) {
      console.error('[chat/ocr] failed:', (e as Error).message);
      throw new HttpError(503, 'อ่านรูปไม่สำเร็จ — ตรวจว่าตั้ง TYPHOON_API_KEY และรุ่น OCR ถูกต้อง');
    }
  }),
);
