import OpenAI from 'openai';
import { CoachContext } from './context_builder';
import { buildSystemPrompt, baht } from './persona';
import { env } from '../../config/env';
import { TOOLS, runTool, TxnCard } from './tools';

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

export interface LlmMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

/**
 * เรียก LLM ระดับล่าง (low-level) ตามลำดับ provider ที่ตั้ง key ไว้.
 * คืน null ถ้าไม่มี key เลย หรือทุกตัวล้มเหลว — ผู้เรียกไปตัดสินใจ fallback เอง.
 * ใช้ร่วมกันทั้ง chat (generateReply) และ savings plan (goals/plan.ts)
 */
export async function chatComplete(
  messages: LlmMessage[],
  opts: { temperature?: number; maxTokens?: number } = {},
): Promise<{ text: string; source: string } | null> {
  for (const p of configuredProviders()) {
    try {
      const client = new OpenAI({ apiKey: p.apiKey, baseURL: p.baseURL });
      const resp = await client.chat.completions.create({
        model: p.model,
        temperature: opts.temperature ?? 0.6,
        max_tokens: opts.maxTokens ?? 1500, // ไทยกินโทเค็นเยอะ
        messages: messages as never,
      });
      const text = resp.choices[0]?.message?.content?.trim();
      if (text) return { text, source: `${p.name}:${p.model}` };
    } catch (e) {
      console.error(`[coach] ${p.name} ล้มเหลว, ลอง provider ถัดไป:`, (e as Error).message);
    }
  }
  return null;
}

/** โค้ชตอบแชท; ถ้าไม่มี key หรือทุกตัวล้มเหลว → fallback rule-based */
export async function generateReply(
  context: CoachContext,
  question: string,
  history: ChatTurn[],
): Promise<CoachReply> {
  const messages: LlmMessage[] = [
    { role: 'system', content: buildSystemPrompt(context) },
    ...history.slice(-12),
    { role: 'user', content: question },
  ];
  const out = await chatComplete(messages);
  if (out) return { reply: out.text, source: out.source };
  return { reply: fallbackReply(context, question, history), source: 'fallback' };
}

/** คำแนะนำการใช้ tool — ต่อท้าย system prompt เฉพาะเส้นทางที่เปิด function calling */
const TOOLS_HINT = `## เครื่องมือที่ใช้ได้ (สำคัญ — ใช้ข้อมูลจริงเสมอ)
- คุณเข้าถึงข้อมูลจริงของผู้ใช้ผ่านเครื่องมือได้ ห้ามเดา/แต่งตัวเลขรายการ ยอดใช้จ่าย งบ หรือเป้าออมเอง
- ผู้ใช้ถามยอด/รายการ/สรุปการใช้จ่าย (เช่น "เดือนนี้จ่ายค่าอาหารเท่าไหร่", "จ่ายอะไรไปบ้างสัปดาห์นี้") → เรียก query_transactions ก่อนตอบ แล้วสรุปด้วยตัวเลขจริง
- ผู้ใช้บอกว่าเพิ่งจ่าย/ได้รับเงินอย่างชัดเจน (เช่น "จ่ายค่ากาแฟ 50 บาท", "ได้เงินเดือน 25000") → เรียก create_transaction บันทึกให้ แล้วยืนยันสั้น ๆ ว่าบันทึก "อะไร กี่บาท หมวดไหน" และบอกว่าถ้าผิดสามารถแก้/ลบในแอปได้
- ข้อความสั้นรูปแบบ "<ชื่อรายการ> <จำนวน>" เช่น "อาหารตุนหลายวัน 535", "กาแฟ 50", "เงินเดือน 30000" = ผู้ใช้ต้องการบันทึกรายการ → เรียก create_transaction ทันที ไม่ต้องถามซ้ำ (amountBaht=จำนวน, note=ชื่อรายการ) โดยเลือกประเภทให้ถูก:
  · ชื่อบ่งบอก "รายได้" (เงินเดือน, โบนัส, ค่าจ้าง, ฟรีแลนซ์, พาร์ทไทม์, รับเงิน, ได้เงิน, เงินคืน, ขายของ, ดอกเบี้ย, ค่าขนม) → type=income
  · นอกนั้น (ค่าอาหาร ของใช้ ช้อปปิ้ง เดินทาง ฯลฯ) → type=expense
- ถามเรื่องงบ → get_budget_status; ถามเรื่องเป้าออม → list_goals
- ผลลัพธ์จากเครื่องมือเป็นหน่วย "บาท" อยู่แล้ว นำมาเรียบเรียงเป็นภาษาคนได้เลย
- ถ้าข้อมูลไม่พอจะบันทึก (เช่นไม่บอกจำนวนเงิน) ให้ถามผู้ใช้ก่อน ห้ามสมมติจำนวน`;

/**
 * โค้ชตอบแชทแบบเปิด function calling — ให้ LLM query/บันทึกข้อมูลจริงได้
 * วน tool loop ต่อ provider; provider ไหนไม่รองรับ tools แล้ว throw → ลองตัวถัดไป; หมด → fallback
 */
export async function generateReplyWithTools(
  context: CoachContext,
  question: string,
  history: ChatTurn[],
  userId: string,
): Promise<CoachReply & { cards: TxnCard[] }> {
  // เรียง provider สำหรับ tool path ต่างจาก chat ปกติ: Groq/OpenAI เรียก tool ได้แม่นกว่า Typhoon มาก
  // (Typhoon เก่งไทยแต่ tool-calling ไม่นิ่ง — มักหลอนว่า "บันทึกแล้ว" โดยไม่เรียก tool จริง)
  const TOOL_RANK: Record<string, number> = { groq: 0, openai: 1, typhoon: 2 };
  const providers = [...configuredProviders()].sort(
    (a, b) => (TOOL_RANK[a.name] ?? 9) - (TOOL_RANK[b.name] ?? 9),
  );
  if (providers.length === 0) {
    return { reply: fallbackReply(context, question, history), source: 'fallback', cards: [] };
  }

  // วันนี้ตามเวลาไทย — ให้ LLM อ้างวันที่ถูกต้อง (โมเดลไม่รู้วันปัจจุบันเอง มักหลอนวันที่)
  const todayTh = new Intl.DateTimeFormat('th-TH', {
    timeZone: 'Asia/Bangkok', dateStyle: 'long',
  }).format(new Date());
  const baseMessages: unknown[] = [
    { role: 'system', content: `${buildSystemPrompt(context)}\n\n${TOOLS_HINT}\n- วันนี้คือ ${todayTh} (เวลาไทย) ใช้อ้างอิงเมื่อพูดถึงวันที่` },
    ...history.slice(-12),
    { role: 'user', content: question },
  ];
  const MAX_STEPS = 5; // กัน loop ไม่รู้จบ (query → สรุป โดยปกติ 1-2 รอบ)

  for (const p of providers) {
    // เก็บ card ต่อการลอง provider หนึ่งครั้ง — ให้ตรงกับคำตอบที่ผู้ใช้เห็นจริง (provider ที่สำเร็จ)
    const cards: TxnCard[] = [];
    try {
      const client = new OpenAI({ apiKey: p.apiKey, baseURL: p.baseURL });
      const messages = [...baseMessages];

      for (let step = 0; step < MAX_STEPS; step++) {
        const resp = await client.chat.completions.create({
          model: p.model,
          temperature: 0.4, // ต่ำ = เรียก tool แม่นขึ้น
          max_tokens: 1500,
          messages: messages as never,
          tools: TOOLS as never,
          tool_choice: 'auto',
        });
        const msg = resp.choices[0]?.message;
        if (!msg) break;

        const toolCalls = msg.tool_calls;
        if (toolCalls && toolCalls.length) {
          messages.push(msg as never); // ต้องใส่ assistant turn ที่มี tool_calls ก่อน
          for (const tc of toolCalls) {
            let args: unknown = {};
            try {
              args = JSON.parse(tc.function.arguments || '{}');
            } catch {
              args = {};
            }
            const result = await runTool(tc.function.name, args, userId);
            // จดรายการที่สร้างสำเร็จไว้ทำการ์ด "จดสำเร็จ" ให้ mobile
            if (tc.function.name === 'create_transaction' && (result as { ok?: boolean }).ok) {
              const r = result as unknown as TxnCard;
              cards.push({ id: r.id, type: r.type, amountBaht: r.amountBaht, category: r.category, categoryId: r.categoryId, note: r.note, date: r.date });
            }
            messages.push({
              role: 'tool',
              tool_call_id: tc.id,
              content: JSON.stringify(result),
            } as never);
          }
          continue; // วนอีกรอบให้ LLM ใช้ผลลัพธ์
        }

        const text = msg.content?.trim();
        if (text) return { reply: text, source: `${p.name}:${p.model}`, cards };
        break; // ไม่มีทั้ง content และ tool call → ลอง provider ถัดไป
      }
    } catch (e) {
      console.error(`[coach:tools] ${p.name} ล้มเหลว, ลอง provider ถัดไป:`, (e as Error).message);
      // ถ้าสร้างรายการสำเร็จแล้ว แต่ provider ล่มตอนสรุป (เช่น 429) → ยืนยันจากการ์ดเลย
      // ห้าม retry provider อื่นเพราะจะรันบทสนทนาซ้ำ = สร้างรายการซ้ำ
      if (cards.length) return { reply: confirmFromCards(cards), source: `${p.name}:partial`, cards };
    }
  }
  return { reply: fallbackReply(context, question, history), source: 'fallback', cards: [] };
}

/** ข้อความยืนยันสำรอง เมื่อบันทึกสำเร็จแต่ LLM ล่มก่อนเรียบเรียงคำตอบ */
function confirmFromCards(cards: TxnCard[]): string {
  const lines = cards.map((c) => {
    const kind = c.type === 'income' ? 'รายรับ' : 'รายจ่าย';
    const label = c.note?.trim() || c.category;
    return `จดให้แล้วครับ ✅ ${kind}: ${label} ${c.amountBaht.toLocaleString('en-US')} บาท (หมวด${c.category})`;
  });
  return `${lines.join('\n')}\n\nถ้าผิดสามารถกดแก้หรือลบที่การ์ดด้านล่างได้เลยครับ`;
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
function fallbackReply(c: CoachContext, question: string, history: ChatTurn[]): string {
  const remaining = c.monthlyIncome - c.thisMonthSpent;
  const over = c.budgetRemaining.filter((b) => b.remaining < 0);
  const top = c.topExpenses[0];
  const recentConversation = history.slice(-8).map((turn) => turn.content).join('\n');

  if (
    /ข้อความเปิดใจ|ร่างข้อความ|ประโยคเริ่มคุย|พูดยังไงดี/i.test(question) &&
    /แฟน|คู่รัก|ครอบครัว/i.test(recentConversation) &&
    /เงิน|ใช้จ่าย|ค่าใช้จ่าย|เกินตัว/i.test(recentConversation)
  ) {
    return (
      'ลองเปิดใจแบบไม่กล่าวโทษประมาณนี้นะครับ 💬\n\n' +
      '> “เราอยากคุยเรื่องการใช้เงินด้วยกัน เพราะเราเป็นห่วงอนาคตของเราสองคน ไม่ได้อยากควบคุมเธอนะ เราลองมาดูรายรับ–รายจ่ายและตั้งข้อตกลงที่สบายใจทั้งคู่ได้ไหม”\n\n' +
      'เลือกคุยตอนที่ทั้งคู่ใจเย็น แล้วเริ่มจากเป้าหมายร่วมกันก่อนตัวเลขครับ'
    );
  }

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
