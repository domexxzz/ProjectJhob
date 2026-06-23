import OpenAI from 'openai';
import { CoachContext } from './context_builder';
import { buildSystemPrompt, baht } from './persona';
import { env } from '../../config/env';

export interface ChatTurn {
  role: 'user' | 'assistant';
  content: string;
}
export interface CoachReply {
  reply: string;
  source: string; // ชื่อ model หรือ 'fallback'
}

interface LlmProvider {
  name: string;
  apiKey: string;
  model: string;
  baseURL?: string;
}

/** ลำดับการลอง: Typhoon (ไทยดีสุด) → Groq (เร็ว) → OpenAI. ใส่ key ตัวไหน ตัวนั้นถูกใช้ */
function configuredProviders(): LlmProvider[] {
  const list: LlmProvider[] = [];
  if (env.typhoonApiKey)
    list.push({ name: 'typhoon', apiKey: env.typhoonApiKey, model: env.typhoonModel, baseURL: 'https://api.opentyphoon.ai/v1' });
  if (env.groqApiKey)
    list.push({ name: 'groq', apiKey: env.groqApiKey, model: env.groqModel, baseURL: 'https://api.groq.com/openai/v1' });
  if (env.openaiApiKey)
    list.push({ name: 'openai', apiKey: env.openaiApiKey, model: env.openaiModel, baseURL: env.openaiBaseUrl });
  return list;
}

/** เรียก LLM ตามลำดับ provider ที่ตั้ง key ไว้; ถ้าไม่มี key หรือทุกตัวล้มเหลว → fallback rule-based */
export async function generateReply(
  context: CoachContext,
  question: string,
  history: ChatTurn[],
): Promise<CoachReply> {
  const messages = [
    { role: 'system' as const, content: buildSystemPrompt(context) },
    ...history.slice(-6),
    { role: 'user' as const, content: question },
  ];

  for (const p of configuredProviders()) {
    try {
      const client = new OpenAI({ apiKey: p.apiKey, baseURL: p.baseURL });
      const resp = await client.chat.completions.create({
        model: p.model,
        temperature: 0.6,
        max_tokens: 1500, // ไทยกินโทเค็นเยอะ — เผื่อให้ตอบจบไม่ขาด (persona คุมความยาว ~200 คำ)
        messages,
      });
      const reply = resp.choices[0]?.message?.content?.trim();
      if (reply) return { reply, source: `${p.name}:${p.model}` };
    } catch (e) {
      console.error(`[coach] ${p.name} ล้มเหลว, ลอง provider ถัดไป:`, (e as Error).message);
    }
  }
  return { reply: fallbackReply(context, question), source: 'fallback' };
}

/** OCR รูป (สลิป/เอกสาร) ด้วย Typhoon OCR — รับ data URL ("data:image/...;base64,xxx") คืนข้อความ */
export async function ocrImage(imageDataUrl: string): Promise<string> {
  if (!env.typhoonApiKey) throw new Error('no TYPHOON_API_KEY for OCR');
  const client = new OpenAI({ apiKey: env.typhoonApiKey, baseURL: 'https://api.opentyphoon.ai/v1' });
  const resp = await client.chat.completions.create({
    model: env.typhoonOcrModel,
    max_tokens: 1000,
    messages: [
      {
        role: 'user',
        content: [
          {
            type: 'text',
            text: 'อ่านข้อความทั้งหมดในรูปนี้ออกมาเป็นข้อความล้วน เน้น จำนวนเงิน วันที่ ร้านค้า/ผู้รับ และเลขอ้างอิง',
          },
          { type: 'image_url', image_url: { url: imageDataUrl } },
        ] as never,
      },
    ],
  });
  return resp.choices[0]?.message?.content?.trim() ?? '';
}

/** โค้ชแบบ rule-based — ตอบ grounded จาก context จริง (ใช้ตอนยังไม่ใส่ API key) */
function fallbackReply(c: CoachContext, question: string): string {
  const remaining = c.monthlyIncome - c.thisMonthSpent;
  const over = c.budgetRemaining.filter((b) => b.remaining < 0);
  const top = c.topExpenses[0];

  if (/ออม|เก็บเงิน|save|saving/i.test(question)) {
    const save20 = Math.max(0, Math.round(remaining * 0.2));
    const goal = c.goals[0];
    return (
      `อยากออมใช่มั้ย เยี่ยมเลย! 👏 เดือนนี้เหลือ ${baht(remaining)} ` +
      `ลองกันไว้สัก 20% = ${baht(save20)} ก่อนใช้จ่ายอย่างอื่นนะ` +
      (goal
        ? ` เป้า "${goal.name}" ตอนนี้ ${goal.progressPct}% แล้ว สู้ๆ! 🎯`
        : ` แล้วลองตั้งเป้าหมายออมในแอปดู จะได้เห็นความคืบหน้า 💪`)
    );
  }

  if (/เกินงบ|งบประมาณ|งบเดือน|เหลืองบ|budget/i.test(question)) {
    if (over.length) {
      return (
        `ตอนนี้ ${over.map((o) => `${o.category} เกินงบ ${baht(-o.remaining)}`).join(', ')} 😅 ` +
        `ลองคุมหมวดนี้สักหน่อยในสัปดาห์นี้นะ เดี๋ยวก็กลับมาอยู่ในงบได้!`
      );
    }
    return `งบยังโอเคทุกหมวดเลย เก่งมาก! 🎉 เดือนนี้ใช้ไป ${baht(c.thisMonthSpent)} เหลืออีก ${baht(remaining)}`;
  }

  return (
    `เดือนนี้ใช้ไป ${baht(c.thisMonthSpent)} จาก ${baht(c.monthlyIncome)} เหลืออีก ${baht(remaining)} นะ 💰` +
    (top ? ` หมวดที่ใช้เยอะสุดคือ ${top.category} (${baht(top.amount)})` : '') +
    (over.length
      ? ` ⚠️ ระวัง ${over.map((o) => o.category).join(', ')} เกินงบแล้ว ลองคุมอีกนิดนะ!`
      : ` ยังอยู่ในงบ ทำได้ดีมาก! 🎉`)
  );
}
