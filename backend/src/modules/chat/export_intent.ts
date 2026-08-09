import { randomUUID } from 'crypto';
import {
  DynamicDocument,
  DynamicExportPayload,
  DynamicTable,
  ExportFormat,
  ExportKind,
  formatLabel,
  isDocumentFormat,
  labelFor,
  signExportToken,
} from '../export/export.service';
import { chatComplete, ChatTurn, LlmMessage } from './coach';
import { buildContextBlock } from './persona';
import { CoachContext } from './context_builder';
import { cache } from '../../lib/cache';

export interface ChatAttachment {
  kind: string;
  format: ExportFormat;
  filename: string;
  label: string;
  token: string;
  /** เก็บไว้กู้ไฟล์ตอน cache หมดอายุ (เฉพาะไฟล์ที่ LLM จัดจากแชท) */
  cacheId?: string;
  payload?: DynamicExportPayload;
}

const STRUCTURED_FORMATS: ExportFormat[] = ['xlsx', 'xml', 'csv', 'json'];

function requestedFormat(message: string): ExportFormat | null {
  const m = message.toLowerCase();
  if (/\bpdf\b/.test(m)) return 'pdf';
  if (/google\s*doc|\bdocx?\b|\bword\b|เวิร์ด/.test(m)) return 'docx';
  if (/\bhtml?\b|เว็บเพจ/.test(m)) return 'html';
  if (/\bcsv\b/.test(m)) return 'csv';
  if (/\bjson\b/.test(m)) return 'json';
  if (/\bxml\b/.test(m)) return 'xml';
  if (/\btxt\b|text\s*file|ไฟล์ข้อความ/.test(m)) return 'txt';
  if (/excel|xlsx|สเปรดชีต|spreadsheet/.test(m)) return 'xlsx';
  return null;
}

/** ตรวจคำขอส่งออก แล้วเลือกรูปแบบที่เหมาะกับข้อมูลเมื่อผู้ใช้ไม่ได้ระบุนามสกุล */
export function detectExportRequest(message: string): { kind: ExportKind | 'custom'; format: ExportFormat } | null {
  const m = message.toLowerCase();
  const format = requestedFormat(message);
  const wantsFile = format !== null || /ไฟล์|export|ส่งออก|ดาวน์โหลด|ดาวโหลด|ขอไฟล|โหลดไฟล|ทำตาราง|เป็นตาราง/.test(m);
  if (!wantsFile) return null;

  let kind: ExportKind | 'custom' = 'custom';
  if (/subscription|สมัครสมาชิก|ค่าบริการ|สมาชิกรายเดือน/.test(m)) kind = 'subscriptions';
  else if (/เดินบัญชี|statement|ธุรกรรมทั้งหมด|รายการทั้งหมด|รายการเดือนนี้/.test(m)) kind = 'transactions';
  else if (/งบประมาณ|งบราย|budget/.test(m)) kind = 'budget';
  else if (/สรุปการเงิน|สรุปบัญชี|ภาพรวมการเงิน/.test(m)) kind = 'summary';

  // ข้อมูลจากฐานข้อมูลเหมาะกับ Excel; เนื้อหาคำแนะนำ/บทสนทนาเหมาะกับ PDF
  // แต่ถ้าผู้ใช้พูดถึง "ตาราง" ชัดเจน ให้เป็น Excel (เอาไปกรอกต่อได้จริง)
  const asksForTable = /ทำตาราง|เป็นตาราง|คอลัมน์|แถว/.test(m);
  const fallbackFormat: ExportFormat = kind === 'custom' && !asksForTable ? 'pdf' : 'xlsx';
  return { kind, format: format ?? fallbackFormat };
}

export function buildExportReply(userId: string, kind: ExportKind, format: ExportFormat): { reply: string; attachment: ChatAttachment } {
  const label = labelFor(kind);
  const stamp = new Date().toISOString().split('T')[0];
  const filename = `${kind}-${stamp}.${format}`;
  const token = signExportToken(userId);
  const reply = `ได้เลยครับ 📄 พี่เงินสร้างไฟล์ **${label}** (${formatLabel(format)}) จากข้อมูลจริงของคุณให้แล้ว — กดปุ่มด้านล่างเพื่อดาวน์โหลดได้เลย 📥`;
  return { reply, attachment: { kind, format, filename, label, token } };
}

export async function buildDynamicExportReply(
  userId: string,
  format: ExportFormat,
  ctx: CoachContext,
  message: string,
  history: ChatTurn[],
): Promise<{ reply: string; attachment: ChatAttachment | null }> {
  let payload: DynamicExportPayload | null;
  let itemCount: number | null = null;
  const wantsTable = STRUCTURED_FORMATS.includes(format) || /ตาราง|คอลัมน์|แถว|spreadsheet|สเปรดชีต/i.test(message);

  if (isDocumentFormat(format) && !wantsTable) {
    payload = documentFromHistory(history) ?? fallbackTableFromContext(ctx);
  } else {
    const generated = await generateTable(ctx, message, history);
    // LLM จัดตารางไม่ได้ → ใช้ตารางสรุปจากข้อมูลจริงแทน ผู้ใช้จะได้ไฟล์เสมอ
    const table = generated
      ? normalizeSavingsPlanDates(generated, message)
      : fallbackTableFromContext(ctx);
    payload = table;
    itemCount = table?.rows.length ?? null;
  }

  if (!payload) {
    return {
      reply: STRUCTURED_FORMATS.includes(format)
        ? 'พี่เงินยังจัดข้อมูลเป็นตารางไม่ได้ครับ 🙏 ลองบอกคอลัมน์ที่ต้องการ เช่น “ทำตารางแผนออม 6 เดือน: เดือน, ยอดออม, ยอดสะสม”'
        : 'พี่เงินยังไม่พบเนื้อหาก่อนหน้าที่จะนำไปสร้างไฟล์ครับ ลองขอคำแนะนำหรือให้พี่เงินร่างเนื้อหาก่อน แล้วพิมพ์ “ส่งออกเป็นไฟล์” ได้เลย',
      attachment: null,
    };
  }

  const cacheId = randomUUID();
  await cache.set(`export:${cacheId}`, payload, 900);
  const token = signExportToken(userId, cacheId);
  const label = ('content' in payload ? payload.title : (payload.title || 'ข้อมูลจากแชท')).slice(0, 40);
  const stamp = new Date().toISOString().split('T')[0];
  const safe = label.replace(/[\\/:*?"<>|]/g, '_');
  const filename = `${safe}-${stamp}.${format}`;
  const countText = itemCount === null ? '' : ` (${itemCount} แถว)`;
  const reply = `ได้เลยครับ 📄 พี่เงินจัด **${label}** จากที่คุยกันเป็นไฟล์ ${formatLabel(format)} ให้แล้ว${countText} — กดปุ่มด้านล่างเพื่อดาวน์โหลด 📥`;
  // แนบ payload ไปกับข้อความด้วย → ถูกบันทึกลง DB ทำให้โหลดซ้ำได้แม้ cache หมดอายุ/เซิร์ฟเวอร์รีสตาร์ต
  return {
    reply,
    attachment: { kind: 'custom', format, filename, label, token, cacheId, payload },
  };
}

function documentFromHistory(history: ChatTurn[]): DynamicDocument | null {
  const assistantTurns = history.filter((turn) => turn.role === 'assistant').reverse();
  for (const turn of assistantTurns) {
    const content = turn.content
      .replace(/หากต้องการ[^\n]*(?:PDF|Google Doc|Word|ไฟล์)[^\n]*/gi, '')
      .replace(/[^\n]*(?:พี่เงินสร้างไฟล์|กดปุ่มด้านล่างเพื่อดาวน์โหลด)[^\n]*/gi, '')
      .trim();
    if (!content) continue;
    const firstMeaningful = content.split(/\r?\n/).map((line) => line.replace(/^[#>*\-\s]+/, '').replace(/\*\*/g, '').trim()).find(Boolean);
    const title = (firstMeaningful && firstMeaningful.length <= 60 ? firstMeaningful : 'เอกสารคำแนะนำจากพี่เงิน').slice(0, 60);
    return { title, content };
  }
  return null;
}

async function generateTable(ctx: CoachContext, question: string, history: ChatTurn[]): Promise<DynamicTable | null> {
  const today = bangkokDateParts();
  const currentDate = `${today.day}/${today.month}/${today.year + 543}`;
  const system =
    'คุณเป็นตัวช่วยจัดข้อมูลการเงินเป็น “ตาราง” สำหรับส่งออกเป็นไฟล์\n' +
    'ให้ดู "บทสนทนาก่อนหน้า" เป็นหลัก แล้วแปลงสิ่งที่คุยกันไว้ให้เป็นตาราง เช่น ถ้าเพิ่งคุยเรื่อง\n' +
    'แผนออมเงิน ให้ทำตารางแผนออม (งวด/วันที่/ยอดออม/ยอดสะสม/คงเหลือ) ถ้าคุยเรื่องสรุปรายจ่าย\n' +
    'ให้ทำตารางรายจ่ายตามหมวด — ยึดตัวเลขที่ปรากฏในบทสนทนาเป็นหลัก\n' +
    'ตอบเป็น JSON เท่านั้น ห้ามมีข้อความอื่นหรือ code fence\n' +
    'รูปแบบ: {"title":"ชื่อสั้นๆ","sheet":"ชื่อชีต","headers":["คอลัมน์1","คอลัมน์2"],"rows":[["ค่า","ค่า"]]}\n' +
    `วันนี้ตามเวลาไทยคือ ${currentDate} ถ้าเป็นแผนรายเดือนต้องเริ่มจากวัน/เดือน/ปีนี้ ห้ามเริ่มจากมกราคมโดยอัตโนมัติ ` +
    'แต่ละงวดเป็นหนึ่งเดือนเต็ม: เริ่มวันเดียวกันของเดือนถัดไป และสิ้นสุดหนึ่งวันก่อนงวดถัดไป\n' +
    'เงินเป็นบาท\n' +
    '⚠️ สำคัญ: ห้ามคืน rows เป็น [] เด็ดขาด ต้องมีอย่างน้อย 1 แถวเสมอ\n' +
    'ถ้าบทสนทนาไม่มีตัวเลขให้ใช้ ให้สร้างตารางสรุปจาก "ข้อมูลผู้ใช้จริง" ด้านล่างแทน\n\n' +
    '## ข้อมูลผู้ใช้ (context จริง)\n' +
    buildContextBlock(ctx);
  const messages: LlmMessage[] = [{ role: 'system', content: system }, ...history.slice(-12), { role: 'user', content: question }];

  const output = await chatComplete(messages, { temperature: 0.2, maxTokens: 1200 });
  const first = output ? parseTable(output.text) : null;
  if (first) return first;

  // ลองอีกครั้งแบบบังคับให้ตอบ JSON ล้วน (บางครั้งโมเดลเผลอเขียนคำอธิบายนำ)
  const retry = await chatComplete(
    [
      ...messages,
      {
        role: 'user',
        content:
          'ตอบใหม่เป็น JSON ล้วน ๆ อย่างเดียว ขึ้นต้นด้วย { และจบด้วย } '
          + 'ห้ามมีคำอธิบาย ห้ามมี ``` และ rows ต้องมีอย่างน้อย 1 แถว',
      },
    ],
    { temperature: 0, maxTokens: 1200 },
  );
  return retry ? parseTable(retry.text) : null;
}

/**
 * ตารางสำรอง — สร้างจากข้อมูลจริงของผู้ใช้ เมื่อ LLM จัดตารางไม่สำเร็จ
 * เพื่อให้ผู้ใช้ "ได้ไฟล์เสมอ" แทนที่จะเจอทางตัน
 */
function fallbackTableFromContext(ctx: CoachContext): DynamicTable | null {
  const baht = (satang: number) => Math.round(satang / 100);
  const rows: (string | number)[][] = [];

  rows.push(['รายได้ต่อเดือน', baht(ctx.monthlyIncome)]);
  rows.push(['ใช้ไปเดือนนี้', baht(ctx.thisMonthSpent)]);
  rows.push(['คงเหลือเดือนนี้', baht(ctx.monthlyIncome - ctx.thisMonthSpent)]);

  for (const b of ctx.budgetRemaining ?? []) {
    rows.push([`งบ: ${b.category}`, baht(b.remaining)]);
  }
  for (const t of ctx.topExpenses ?? []) {
    rows.push([`ใช้จ่าย: ${t.category}`, baht(t.amount)]);
  }
  for (const g of ctx.goals ?? []) {
    rows.push([`เป้าหมาย: ${g.name}`, `${g.progressPct}%`]);
  }

  if (rows.length === 0) return null;
  return {
    title: 'สรุปการเงินของฉัน',
    sheet: 'สรุป',
    headers: ['รายการ', 'จำนวน (บาท)'],
    rows,
  };
}

function parseTable(text: string): DynamicTable | null {
  const start = text.indexOf('{');
  const end = text.lastIndexOf('}');
  if (start < 0 || end <= start) return null;
  try {
    const object = JSON.parse(text.slice(start, end + 1)) as { title?: unknown; sheet?: unknown; headers?: unknown; rows?: unknown };
    if (!Array.isArray(object.headers) || !Array.isArray(object.rows) || object.headers.length === 0 || object.rows.length === 0) return null;
    return {
      title: typeof object.title === 'string' ? object.title : undefined,
      sheet: typeof object.sheet === 'string' ? object.sheet : undefined,
      headers: object.headers.map((header) => String(header)),
      rows: (object.rows as unknown[])
        .filter((row): row is unknown[] => Array.isArray(row))
        .map((row) => row.map((cell) => (typeof cell === 'number' ? cell : String(cell)))),
    };
  } catch {
    return null;
  }
}

function bangkokDateParts(now = new Date()): { year: number; month: number; day: number } {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Bangkok',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(now);
  const value = (type: string) => Number(parts.find((part) => part.type === type)?.value ?? 0);
  return { year: value('year'), month: value('month'), day: value('day') };
}

function isoDate(year: number, month: number, day: number): string {
  return `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
}

function anchoredMonthDate(year: number, month: number, anchorDay: number, offset: number): Date {
  const first = new Date(Date.UTC(year, month - 1 + offset, 1));
  const targetYear = first.getUTCFullYear();
  const targetMonth = first.getUTCMonth();
  const lastDay = new Date(Date.UTC(targetYear, targetMonth + 1, 0)).getUTCDate();
  return new Date(Date.UTC(targetYear, targetMonth, Math.min(anchorDay, lastDay)));
}

/** บังคับแกนเวลาของแผนออมให้สัมพันธ์กับวันที่จริง แม้ LLM จะคืน ม.ค.-มิ.ย. มา */
export function normalizeSavingsPlanDates(table: DynamicTable, message: string, now = new Date()): DynamicTable {
  const isSavingsPlan = /แผน.*ออม|ออม.*เดือน|saving\s*plan/i.test(`${message} ${table.title ?? ''}`);
  if (!isSavingsPlan) return table;

  const durationFromMessage = message.match(/(\d{1,2})\s*เดือน/);
  const duration = Math.min(Math.max(Number(durationFromMessage?.[1] ?? table.rows.length ?? 1), 1), 120);
  const today = bangkokDateParts(now);
  const rows: (string | number)[][] = [];
  const amountColumn = table.headers.findIndex((header) => /ยอดออม|เงินออม|ออม.*บาท/.test(header));
  let cumulative = 0;

  for (let index = 0; index < duration; index += 1) {
    const startDate = anchoredMonthDate(today.year, today.month, today.day, index);
    const nextStartDate = anchoredMonthDate(today.year, today.month, today.day, index + 1);
    const endDate = new Date(nextStartDate.getTime() - 24 * 60 * 60 * 1000);
    const sourceRow = table.rows[index] ?? table.rows[table.rows.length - 1] ?? [];
    const numericValues = sourceRow.filter((cell): cell is number => typeof cell === 'number' && Number.isFinite(cell));
    const amountAtColumn = amountColumn >= 0 ? sourceRow[amountColumn] : undefined;
    const parsedAmount = typeof amountAtColumn === 'string' ? Number(amountAtColumn.replace(/,/g, '')) : NaN;
    const amount = typeof amountAtColumn === 'number' ? amountAtColumn : (Number.isFinite(parsedAmount) ? parsedAmount : (numericValues[0] ?? 0));
    cumulative += amount;
    rows.push([
      index + 1,
      isoDate(startDate.getUTCFullYear(), startDate.getUTCMonth() + 1, startDate.getUTCDate()),
      isoDate(endDate.getUTCFullYear(), endDate.getUTCMonth() + 1, endDate.getUTCDate()),
      amount,
      cumulative,
    ]);
  }

  const last = rows[rows.length - 1];
  const start = rows[0][1] as string;
  const end = last[2] as string;
  return {
    ...table,
    title: `แผนออมเงิน ${duration} เดือน`,
    sheet: 'แผนออมเงิน',
    meta: { asOf: isoDate(today.year, today.month, today.day), startDate: start, endDate: end, currency: 'THB' },
    headers: ['งวด', 'วันที่เริ่ม', 'วันที่สิ้นสุด', 'ยอดออม (บาท)', 'ยอดสะสม (บาท)'],
    rows,
  };
}
