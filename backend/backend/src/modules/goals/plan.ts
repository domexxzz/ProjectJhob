import type { Goal } from '@prisma/client';
import { CoachContext } from '../chat/context_builder';
import { chatComplete } from '../chat/coach';
import { baht, buildSystemPrompt } from '../chat/persona';

// 💡 ทุกจำนวนเงินเป็น "สตางค์" (Int) — client หารด้วย 100 ตอนแสดง

export interface Milestone {
  pct: number; // 25 | 50 | 75 | 100
  amount: number; // satang ที่ต้องมีถึงไมล์สโตนนี้
  monthsFromNow: number; // ประมาณกี่เดือนจะถึง (จากอัตราออม/เดือน)
}

export interface SavingsPlan {
  goalId: string;
  name: string;
  target: number;
  current: number;
  remaining: number;
  monthsLeft: number;
  monthlyAmount: number; // ต้องออม/เดือน (satang)
  incomePct: number | null; // % ของรายได้/เดือน
  milestones: Milestone[];
  message: string; // ข้อความจากพี่เงิน (LLM หรือ heuristic)
  source: string; // ชื่อ model หรือ 'fallback'
}

/** จำนวนเดือน (ทศนิยม) ระหว่าง 2 วันที่ */
function monthsBetween(from: Date, to: Date): number {
  const whole = (to.getFullYear() - from.getFullYear()) * 12 + (to.getMonth() - from.getMonth());
  return whole + (to.getDate() - from.getDate()) / 30;
}

/** คำนวณตัวเลขแผนออม (pure) — ไม่มี PII, ไม่เรียก LLM */
export function computeSavingsPlan(goal: Goal, ctx: CoachContext): Omit<SavingsPlan, 'message' | 'source'> {
  const now = new Date();
  const remaining = Math.max(0, goal.target - goal.current);
  const monthsLeft = goal.deadline
    ? Math.max(1, Math.ceil(monthsBetween(now, new Date(goal.deadline))))
    : 12; // ไม่มีเดดไลน์ → ตั้งต้น 12 เดือน
  const monthlyAmount = Math.ceil(remaining / monthsLeft);
  const incomePct = ctx.monthlyIncome > 0 ? Math.round((monthlyAmount / ctx.monthlyIncome) * 100) : null;

  const milestones: Milestone[] = [25, 50, 75, 100].map((pct) => {
    const amount = Math.round((goal.target * pct) / 100);
    const need = Math.max(0, amount - goal.current);
    return { pct, amount, monthsFromNow: monthlyAmount > 0 ? Math.ceil(need / monthlyAmount) : 0 };
  });

  return {
    goalId: goal.id,
    name: goal.name,
    target: goal.target,
    current: goal.current,
    remaining,
    monthsLeft,
    monthlyAmount,
    incomePct,
    milestones,
  };
}

/** ข้อความ fallback แบบ grounded (ใช้เมื่อไม่มี LLM key หรือ LLM ล่ม) */
function heuristicMessage(p: Omit<SavingsPlan, 'message' | 'source'>, ctx: CoachContext): string {
  const top = ctx.topExpenses[0];
  const lines = [
    `ตั้งเป้า "${p.name}" ${baht(p.target)} 🎯 ตอนนี้เก็บได้ ${baht(p.current)} เหลืออีก ${baht(p.remaining)}`,
    `- ออมเดือนละ ~**${baht(p.monthlyAmount)}**${p.incomePct != null ? ` (~${p.incomePct}% ของรายได้)` : ''} อีก ${p.monthsLeft} เดือนก็ถึง!`,
    `- ไมล์สโตน: 25% ${baht(p.milestones[0].amount)} · 50% ${baht(p.milestones[1].amount)} · 75% ${baht(p.milestones[2].amount)}`,
  ];
  if (top) lines.push(`- ลองลดหมวด **${top.category}** (เดือนนี้ใช้ ${baht(top.amount)}) สักหน่อยนะ 💪`);
  return lines.join('\n');
}

/** สร้างแผนออมเต็ม: คำนวณตัวเลข + ให้พี่เงิน (LLM) เรียบเรียง; ล่ม → heuristic */
export async function generateSavingsPlan(goal: Goal, ctx: CoachContext): Promise<SavingsPlan> {
  const p = computeSavingsPlan(goal, ctx);

  const userPrompt =
    `ช่วยเขียน "แผนออม" สั้น กระชับ เป็นกันเอง จากตัวเลขที่คำนวณมาแล้ว (ห้ามเปลี่ยนตัวเลข):\n` +
    `- เป้าหมาย: ${p.name}\n` +
    `- ยอดเป้า ${baht(p.target)} · เก็บได้แล้ว ${baht(p.current)} · เหลือ ${baht(p.remaining)}\n` +
    `- ระยะเวลา ${p.monthsLeft} เดือน\n` +
    `- ต้องออมเดือนละ ~${baht(p.monthlyAmount)}${p.incomePct != null ? ` (~${p.incomePct}% ของรายได้)` : ''}\n` +
    `- ไมล์สโตน 25% ${baht(p.milestones[0].amount)} · 50% ${baht(p.milestones[1].amount)} · 75% ${baht(p.milestones[2].amount)}\n` +
    `ให้กำลังใจ + แนะนำ 1–2 หมวดที่ควรลดจากข้อมูลจริง + ปิดท้าย disclaimer สั้น ๆ. ห้ามใช้ตาราง/หัวข้อใหญ่ ใช้ bullet สั้น ๆ`;

  // buildSystemPrompt(ctx) ป้อน context จริง (ไม่มี PII) + persona → ได้ disclaimer/สไตล์ครบ
  const out = await chatComplete(
    [
      { role: 'system', content: buildSystemPrompt(ctx) },
      { role: 'user', content: userPrompt },
    ],
    { temperature: 0.5, maxTokens: 700 },
  );

  return out
    ? { ...p, message: out.text, source: out.source }
    : { ...p, message: heuristicMessage(p, ctx), source: 'fallback' };
}
