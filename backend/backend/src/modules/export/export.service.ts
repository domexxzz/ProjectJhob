import * as XLSX from 'xlsx';
import jwt from 'jsonwebtoken';
import { prisma } from '../../lib/prisma';
import { env } from '../../config/env';

// สร้างไฟล์การเงินจากข้อมูลจริงของผู้ใช้ (Excel .xlsx หรือ XML) — เงินเก็บเป็นสตางค์ แปลงเป็นบาท (÷100)
export type ExportKind = 'budget' | 'transactions' | 'summary' | 'subscriptions';
export type ExportFormat = 'xlsx' | 'xml';

const KIND_LABEL: Record<ExportKind, string> = {
  budget: 'งบประมาณ',
  transactions: 'รายการเดินบัญชี',
  summary: 'สรุปการเงิน',
  subscriptions: 'Subscription',
};

const baht = (satang: number) => Math.round(satang) / 100;
const esc = (s: string) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

interface ExportFile {
  filename: string;
  contentType: string;
  body: Buffer | string;
}

/** ดึงข้อมูลตามชนิด → คืนเป็น "แถวตาราง" (AOA) + ชื่อ sheet */
async function buildRows(userId: string, kind: ExportKind): Promise<{ sheet: string; rows: (string | number)[][] }> {
  const now = new Date();
  const start = new Date(now.getFullYear(), now.getMonth(), 1);
  const end = new Date(now.getFullYear(), now.getMonth() + 1, 1);

  if (kind === 'budget') {
    const budgets = await prisma.budget.findMany({ where: { userId, period: 'monthly' }, include: { category: true } });
    const rows: (string | number)[][] = [['หมวดหมู่', 'งบ (บาท)', 'ใช้ไป (บาท)', 'คงเหลือ (บาท)', 'สถานะ']];
    let tl = 0, ts = 0;
    for (const b of budgets) {
      const agg = await prisma.transaction.aggregate({
        _sum: { amount: true },
        where: { userId, type: 'expense', categoryId: b.categoryId ?? null, occurredAt: { gte: start, lt: end } },
      });
      const spent = agg._sum.amount ?? 0;
      tl += b.amount; ts += spent;
      rows.push([b.category?.nameTh ?? 'งบรวม', baht(b.amount), baht(spent), baht(b.amount - spent), spent > b.amount ? 'เกินงบ' : 'ปกติ']);
    }
    rows.push(['รวม', baht(tl), baht(ts), baht(tl - ts), '']);
    return { sheet: 'งบประมาณ', rows };
  }

  if (kind === 'transactions') {
    const txns = await prisma.transaction.findMany({ where: { userId, occurredAt: { gte: start, lt: end } }, orderBy: { occurredAt: 'desc' }, include: { category: true } });
    const rows: (string | number)[][] = [['วันที่', 'ประเภท', 'จำนวน (บาท)', 'หมวดหมู่', 'ที่มา', 'โน้ต']];
    let inc = 0, exp = 0;
    for (const t of txns) {
      if (t.type === 'income') inc += t.amount; else exp += t.amount;
      rows.push([t.occurredAt.toISOString().split('T')[0], t.type === 'income' ? 'รายรับ' : 'รายจ่าย', baht(t.amount), t.category?.nameTh ?? 'อื่นๆ', t.source ?? 'manual', t.note ?? '']);
    }
    rows.push(['รวม', '', '', '', '', '']);
    rows.push(['รายรับ', baht(inc), 'รายจ่าย', baht(exp), 'คงเหลือ', baht(inc - exp)]);
    return { sheet: 'รายการเดินบัญชี', rows };
  }

  if (kind === 'subscriptions') {
    const subs = await prisma.subscription.findMany({ where: { userId }, orderBy: { nextBilling: 'asc' } });
    const rows: (string | number)[][] = [['บริการ', 'ราคา/รอบ (บาท)', 'รอบบิล', 'ตัดเงินถัดไป', 'ต่อเดือน (บาท)']];
    let monthly = 0;
    for (const s of subs) {
      const perMonth = s.cycle === 'yearly' ? Math.round(s.amount / 12) : s.amount;
      monthly += perMonth;
      rows.push([s.name, baht(s.amount), s.cycle === 'yearly' ? 'รายปี' : 'รายเดือน', s.nextBilling.toISOString().split('T')[0], baht(perMonth)]);
    }
    rows.push(['รวมต่อเดือน', '', '', '', baht(monthly)]);
    return { sheet: 'Subscription', rows };
  }

  // summary
  const grouped = await prisma.transaction.groupBy({ by: ['type'], _sum: { amount: true }, where: { userId, occurredAt: { gte: start, lt: end } } });
  const income = grouped.find((g) => g.type === 'income')?._sum.amount ?? 0;
  const expense = grouped.find((g) => g.type === 'expense')?._sum.amount ?? 0;
  const goals = await prisma.goal.findMany({ where: { userId } });
  const rows: (string | number)[][] = [
    ['รายการ', 'ค่า (บาท)'],
    ['รายรับ', baht(income)],
    ['รายจ่าย', baht(expense)],
    ['คงเหลือสุทธิ', baht(income - expense)],
    ['', ''],
    ['เป้าหมาย', 'เป้า (บาท)', 'ปัจจุบัน (บาท)', 'คืบหน้า (%)'],
    ...goals.map((g) => [g.name, baht(g.target), baht(g.current), g.target > 0 ? Math.round((g.current / g.target) * 100) : 0]),
  ];
  return { sheet: 'สรุปการเงิน', rows };
}

function rowsToXml(kind: ExportKind, sheet: string, rows: (string | number)[][]): string {
  const header = rows[0] as string[];
  const body = rows.slice(1).map((r) => {
    const cells = r.map((v, i) => `    <cell name="${esc(header[i] ?? `col${i}`)}">${esc(String(v))}</cell>`).join('\n');
    return `  <row>\n${cells}\n  </row>`;
  }).join('\n');
  return `<?xml version="1.0" encoding="UTF-8"?>\n<${kind} currency="THB" sheet="${esc(sheet)}">\n${body}\n</${kind}>\n`;
}

/** สร้างไฟล์ export พร้อมส่ง (buffer สำหรับ xlsx, string สำหรับ xml) */
export async function buildExportFile(userId: string, kind: ExportKind, format: ExportFormat): Promise<ExportFile> {
  const { sheet, rows } = await buildRows(userId, kind);
  const stamp = new Date().toISOString().split('T')[0];
  const base = `${kind}-${stamp}`;

  if (format === 'xml') {
    return { filename: `${base}.xml`, contentType: 'application/xml; charset=utf-8', body: rowsToXml(kind, sheet, rows) };
  }

  const ws = XLSX.utils.aoa_to_sheet(rows);
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, sheet);
  const buf = XLSX.write(wb, { type: 'buffer', bookType: 'xlsx' }) as Buffer;
  return { filename: `${base}.xlsx`, contentType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', body: buf };
}

export function labelFor(kind: ExportKind): string {
  return KIND_LABEL[kind];
}

/** download token อายุสั้น (auth การดาวน์โหลดผ่าน browser โดยไม่ต้องแนบ header)
 *  cacheId = ใช้กับ dynamic export (ตารางที่ LLM สร้างจากแชท เก็บใน cache) */
export function signExportToken(userId: string, cacheId?: string): string {
  return jwt.sign({ sub: userId, purpose: 'export', cid: cacheId }, env.jwtSecret, { expiresIn: '15m' });
}

export function verifyExportToken(token: string): { userId: string; cacheId?: string } {
  const p = jwt.verify(token, env.jwtSecret) as { sub: string; purpose?: string; cid?: string };
  if (p.purpose !== 'export') throw new Error('bad purpose');
  return { userId: p.sub, cacheId: p.cid };
}

// ── Dynamic export: สร้างไฟล์จาก "ตาราง" ที่ LLM จัดจากบทสนทนา ──
export interface DynamicTable {
  title?: string;
  sheet?: string;
  headers: string[];
  rows: (string | number)[][];
}

export function buildDynamicFile(table: DynamicTable, format: ExportFormat): ExportFile {
  const sheet = (table.sheet || table.title || 'ข้อมูล').slice(0, 28);
  const rows: (string | number)[][] = [table.headers, ...table.rows];
  const stamp = new Date().toISOString().split('T')[0];
  const safe = (table.title || 'chat-data').replace(/[\\/:*?"<>|]/g, '_').slice(0, 40);
  const base = `${safe}-${stamp}`;

  if (format === 'xml') {
    return { filename: `${base}.xml`, contentType: 'application/xml; charset=utf-8', body: rowsToXml('summary', sheet, rows) };
  }
  const ws = XLSX.utils.aoa_to_sheet(rows);
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, sheet);
  const buf = XLSX.write(wb, { type: 'buffer', bookType: 'xlsx' }) as Buffer;
  return { filename: `${base}.xlsx`, contentType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', body: buf };
}
