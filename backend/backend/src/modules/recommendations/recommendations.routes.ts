import { Router } from 'express';
import { asyncHandler } from '../../lib/http';
import { requireAuth } from '../../lib/auth';
import { cache } from '../../lib/cache';
import { buildContext, CoachContext } from '../chat/context_builder';
import { buildContextBlock, baht } from '../chat/persona';
import { chatComplete } from '../chat/coach';

// 💡 DM-6 — การ์ด "แนะนำสำหรับคุณ" (Goals / Budget / Dashboard)
// reuse buildContext() (ไม่มี PII) + chatComplete() (multi-provider LLM) → เหลือแค่ prompt + fallback

export const recommendationsRouter = Router();
recommendationsRouter.use(requireAuth);

const CONTEXTS = ['goal', 'budget', 'dashboard'] as const;
type RecContext = (typeof CONTEXTS)[number];

const ASKS: Record<RecContext, string> = {
  budget: 'ดูงบรายหมวดเดือนนี้จากข้อมูลจริง แล้วแนะนำ 1 อย่างที่ทำได้จริงเรื่องคุมงบหรือหมวดที่ควรลด',
  goal: 'ดูเป้าหมายออมของผู้ใช้ แล้วแนะนำ 1 อย่างที่ช่วยให้ออมถึงเป้าเร็วขึ้น',
  dashboard: 'สรุปภาพรวมการเงินเดือนนี้สั้น ๆ พร้อม 1 คำแนะนำ',
};

/** fallback แบบ grounded (ใช้เมื่อไม่มี LLM key หรือ LLM ล่ม) */
function heuristic(ctx: RecContext, c: CoachContext): string {
  const remaining = c.monthlyIncome - c.thisMonthSpent;
  const over = c.budgetRemaining.filter((b) => b.remaining < 0);
  const top = c.topExpenses[0];

  if (ctx === 'budget') {
    if (over.length) return `หมวด ${over.map((o) => o.category).join(', ')} เกินงบแล้ว ลองคุมสัปดาห์นี้สักหน่อยนะ 😅`;
    if (top) return `หมวดที่ใช้เยอะสุดคือ ${top.category} (${baht(top.amount)}) ลองตั้งงบคุมไว้ดูนะ 👀`;
    return `เดือนนี้คุมงบได้ดี เหลือ ${baht(remaining)} เก่งมาก! 🎉`;
  }
  if (ctx === 'goal') {
    const g = c.goals[0];
    if (g) return `เป้า "${g.name}" ไป ${g.progressPct}% แล้ว ออมเพิ่มอีกนิดเดือนนี้ก็ใกล้ถึง สู้ ๆ! 🎯`;
    const save20 = Math.max(0, Math.round(remaining * 0.2));
    return `ลองตั้งเป้าออมในแอปดูนะ เดือนนี้เหลือ ${baht(remaining)} เก็บ 20% = ${baht(save20)} ก็เริ่มได้ 💪`;
  }
  // dashboard
  return `เดือนนี้ใช้ไป ${baht(c.thisMonthSpent)} เหลือ ${baht(remaining)}${top ? ` · ${top.category} เยอะสุด` : ''} 💰`;
}

// GET /api/v1/recommendations?context=goal|budget|dashboard
recommendationsRouter.get(
  '/',
  asyncHandler(async (req, res) => {
    const userId = req.userId!;
    const raw = req.query.context;
    const ctx: RecContext = typeof raw === 'string' && (CONTEXTS as readonly string[]).includes(raw) ? (raw as RecContext) : 'dashboard';

    const cacheKey = `user:${userId}:rec:${ctx}`;
    const cached = await cache.get<{ recommendation: unknown }>(cacheKey);
    if (cached) return res.json(cached);

    const context = await buildContext(userId);
    const system =
      `คุณคือ "พี่เงิน" ผู้ช่วยการเงิน AI ตอบ "สั้นมาก" 1–2 ประโยค (≤ 40 คำ) เป็นกันเอง อ้างตัวเลขจริงเสมอ แทรก emoji ได้ ` +
      `ห้ามใช้ตาราง/หัวข้อ/bullet และห้ามแนะนำหุ้น/กองทุนรายตัว\n\n## ข้อมูลผู้ใช้ (real-time, ไม่มี PII)\n${buildContextBlock(context)}`;

    const out = await chatComplete(
      [
        { role: 'system', content: system },
        { role: 'user', content: ASKS[ctx] },
      ],
      { temperature: 0.6, maxTokens: 120 },
    );

    const recommendation = {
      context: ctx,
      text: out ? out.text : heuristic(ctx, context),
      source: out ? out.source : 'fallback',
    };

    const result = { recommendation };
    await cache.set(cacheKey, result, 600); // cache 10 นาที (ประหยัด token) — ถูก invalidate เมื่อมีธุรกรรม/งบ/เป้าใหม่
    res.json(result);
  }),
);
