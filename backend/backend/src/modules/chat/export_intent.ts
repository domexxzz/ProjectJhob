import { randomUUID } from 'crypto';
import { ExportKind, ExportFormat, labelFor, signExportToken, DynamicTable } from '../export/export.service';
import { chatComplete, LlmMessage, ChatTurn } from './coach';
import { buildContextBlock } from './persona';
import { CoachContext } from './context_builder';
import { cache } from '../../lib/cache';

export interface ChatAttachment {
  kind: string; // budget | transactions | summary | subscriptions | custom
  format: ExportFormat;
  filename: string;
  label: string;
  token: string;
}

/**
 * ตรวจว่าผู้ใช้ขอ "ไฟล์การเงิน" ไหม
 * - ชนิดชัดเจน (งบประมาณ/รายการ/สรุป/subscription) → export จาก DB จริง
 * - อื่น ๆ (ตาราง/แผน/ข้อมูลจากบทสนทนา) → 'custom' = ให้ LLM จัดเป็นตาราง
 */
export function detectExportRequest(message: string): { kind: ExportKind | 'custom'; format: ExportFormat } | null {
  const m = message.toLowerCase();
  const wantsFile = /ไฟล์|excel|xlsx|xml|export|ส่งออก|ดาวน์โหลด|ดาวโหลด|ขอไฟล|โหลดไฟล|ทำตาราง|เป็นตาราง|สเปรดชีต|spreadsheet/.test(m);
  if (!wantsFile) return null;

  const format: ExportFormat = /xml/.test(m) ? 'xml' : 'xlsx';

  if (/subscription|สมัครสมาชิก|ค่าบริการ|สมาชิกรายเดือน/.test(m)) return { kind: 'subscriptions', format };
  if (/เดินบัญชี|statement|ธุรกรรมทั้งหมด|รายการทั้งหมด|รายการเดือนนี้/.test(m)) return { kind: 'transactions', format };
  if (/งบประมาณ|งบราย|budget/.test(m)) return { kind: 'budget', format };
  if (/สรุปการเงิน|สรุปบัญชี|ภาพรวมการเงิน/.test(m)) return { kind: 'summary', format };

  return { kind: 'custom', format }; // ข้อมูลจากบทสนทนา
}

/** ── ชนิดชัดเจน: สร้าง attachment (token ชี้ข้อมูล DB) + ข้อความตอบ ── */
export function buildExportReply(userId: string, kind: ExportKind, format: ExportFormat): { reply: string; attachment: ChatAttachment } {
  const label = labelFor(kind);
  const stamp = new Date().toISOString().split('T')[0];
  const filename = `${kind}-${stamp}.${format}`;
  const token = signExportToken(userId);
  const ext = format === 'xlsx' ? 'Excel' : 'XML';
  const reply = `ได้เลยครับ 📄 พี่เงินสร้างไฟล์**${label}** (${ext}) จากข้อมูลจริงของคุณให้แล้ว — กดปุ่มด้านล่างเพื่อดาวน์โหลดได้เลย 📥`;
  return { reply, attachment: { kind, format, filename, label, token } };
}

/** ── custom: ให้ LLM จัดข้อมูลจากบทสนทนาเป็นตาราง แล้วสร้างไฟล์ ── */
export async function buildDynamicExportReply(
  userId: string,
  format: ExportFormat,
  ctx: CoachContext,
  message: string,
  history: ChatTurn[],
): Promise<{ reply: string; attachment: ChatAttachment | null }> {
  const table = await generateTable(ctx, message, history);
  if (!table || table.headers.length === 0 || table.rows.length === 0) {
    return {
      reply:
        'พี่เงินยังจัดข้อมูลนี้เป็นตารางไม่ได้ครับ 🙏 ลองบอกให้ชัดว่าต้องการคอลัมน์อะไรบ้าง เช่น ' +
        '"ทำตารางแผนออม 6 เดือน คอลัมน์: เดือน, ยอดออม, ยอดสะสม"',
      attachment: null,
    };
  }

  const cacheId = randomUUID();
  await cache.set(`export:${cacheId}`, table, 900); // เก็บตาราง 15 นาที
  const token = signExportToken(userId, cacheId);

  const label = (table.title || 'ข้อมูลจากแชท').slice(0, 40);
  const stamp = new Date().toISOString().split('T')[0];
  const safe = label.replace(/[\\/:*?"<>|]/g, '_');
  const filename = `${safe}-${stamp}.${format}`;
  const ext = format === 'xlsx' ? 'Excel' : 'XML';
  const reply = `ได้เลยครับ 📄 พี่เงินจัด **${label}** จากที่คุยกันเป็นไฟล์ ${ext} ให้แล้ว (${table.rows.length} แถว) — กดปุ่มด้านล่างเพื่อดาวน์โหลด 📥`;
  return { reply, attachment: { kind: 'custom', format, filename, label, token } };
}

/** เรียก LLM ให้ดึงข้อมูลจากบทสนทนาเป็นตาราง JSON */
async function generateTable(ctx: CoachContext, question: string, history: ChatTurn[]): Promise<DynamicTable | null> {
  const sys =
    'คุณเป็นตัวช่วยจัดข้อมูลการเงินเป็น "ตาราง" สำหรับ export เป็นไฟล์\n' +
    'จากบทสนทนาและคำขอล่าสุด ให้ดึง/จัดข้อมูลที่ผู้ใช้ต้องการเป็นตาราง แล้ว **ตอบเป็น JSON เท่านั้น** ห้ามมีข้อความอื่นหรือ code fence\n' +
    'รูปแบบ: {"title":"ชื่อสั้นๆ","sheet":"ชื่อชีต","headers":["คอลัมน์1","คอลัมน์2"],"rows":[["ค่า","ค่า"]]}\n' +
    'เงินเป็นบาท · อ้างอิงข้อมูลจริงของผู้ใช้ด้านล่างถ้าเกี่ยวข้อง · ถ้าข้อมูลไม่พอให้ headers และ rows เป็น []\n\n' +
    '## ข้อมูลผู้ใช้ (context จริง)\n' +
    buildContextBlock(ctx);
  const messages: LlmMessage[] = [{ role: 'system', content: sys }, ...history.slice(-6), { role: 'user', content: question }];
  const out = await chatComplete(messages, { temperature: 0.2, maxTokens: 1200 });
  if (!out) return null;
  return parseTable(out.text);
}

function parseTable(text: string): DynamicTable | null {
  const s = text.indexOf('{');
  const e = text.lastIndexOf('}');
  if (s < 0 || e <= s) return null;
  try {
    const obj = JSON.parse(text.slice(s, e + 1)) as { title?: unknown; sheet?: unknown; headers?: unknown; rows?: unknown };
    if (!Array.isArray(obj.headers) || !Array.isArray(obj.rows)) return null;
    return {
      title: typeof obj.title === 'string' ? obj.title : undefined,
      sheet: typeof obj.sheet === 'string' ? obj.sheet : undefined,
      headers: obj.headers.map((h) => String(h)),
      rows: (obj.rows as unknown[])
        .filter((r): r is unknown[] => Array.isArray(r))
        .map((r) => r.map((c) => (typeof c === 'number' ? c : String(c)))),
    };
  } catch {
    return null;
  }
}
