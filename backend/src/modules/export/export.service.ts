import * as XLSX from 'xlsx';
import ExcelJS from 'exceljs';
import jwt from 'jsonwebtoken';
import PDFDocument from 'pdfkit';
import path from 'path';
import { readFileSync } from 'fs';
import {
  AlignmentType,
  BorderStyle,
  Document,
  HeadingLevel,
  LevelFormat,
  Packer,
  PageOrientation,
  Paragraph,
  Table,
  TableCell,
  TableLayoutType,
  TableRow,
  TextRun,
  WidthType,
} from 'docx';
import { prisma } from '../../lib/prisma';
import { env } from '../../config/env';

export type ExportKind = 'budget' | 'transactions' | 'summary' | 'subscriptions';
export type ExportFormat = 'xlsx' | 'xml' | 'pdf' | 'docx' | 'csv' | 'json' | 'txt' | 'html';

const KIND_LABEL: Record<ExportKind, string> = {
  budget: 'งบประมาณ',
  transactions: 'รายการเดินบัญชี',
  summary: 'สรุปการเงิน',
  subscriptions: 'Subscription',
};

const FORMAT_LABEL: Record<ExportFormat, string> = {
  xlsx: 'Excel',
  xml: 'XML',
  pdf: 'PDF',
  docx: 'Word',
  csv: 'CSV',
  json: 'JSON',
  txt: 'ข้อความ',
  html: 'HTML',
};

const MIME: Record<ExportFormat, string> = {
  xlsx: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  xml: 'application/xml; charset=utf-8',
  pdf: 'application/pdf',
  docx: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  csv: 'text/csv; charset=utf-8',
  json: 'application/json; charset=utf-8',
  txt: 'text/plain; charset=utf-8',
  html: 'text/html; charset=utf-8',
};

const baht = (satang: number) => Math.round(satang) / 100;
const xmlEscape = (s: string) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
const htmlEscape = (s: string) => xmlEscape(s).replace(/'/g, '&#39;');

export interface ExportFile {
  filename: string;
  contentType: string;
  body: Buffer | string;
}

export interface DynamicTable {
  title?: string;
  sheet?: string;
  meta?: {
    asOf?: string;
    startDate?: string;
    endDate?: string;
    currency?: string;
  };
  headers: string[];
  rows: (string | number)[][];
}

export interface DynamicDocument {
  title: string;
  content: string;
}

export type DynamicExportPayload = DynamicTable | DynamicDocument;

export const isDocumentFormat = (format: ExportFormat): boolean =>
  format === 'pdf' || format === 'docx' || format === 'txt' || format === 'html';

export function formatLabel(format: ExportFormat): string {
  return FORMAT_LABEL[format];
}

async function buildRows(userId: string, kind: ExportKind): Promise<{ sheet: string; rows: (string | number)[][] }> {
  const now = new Date();
  const start = new Date(now.getFullYear(), now.getMonth(), 1);
  const end = new Date(now.getFullYear(), now.getMonth() + 1, 1);

  if (kind === 'budget') {
    const budgets = await prisma.budget.findMany({ where: { userId, period: 'monthly' }, include: { category: true } });
    const rows: (string | number)[][] = [['หมวดหมู่', 'งบ (บาท)', 'ใช้ไป (บาท)', 'คงเหลือ (บาท)', 'สถานะ']];
    let limit = 0;
    let spentTotal = 0;
    for (const budget of budgets) {
      const agg = await prisma.transaction.aggregate({
        _sum: { amount: true },
        where: { userId, type: 'expense', categoryId: budget.categoryId ?? null, occurredAt: { gte: start, lt: end } },
      });
      const spent = agg._sum.amount ?? 0;
      limit += budget.amount;
      spentTotal += spent;
      rows.push([
        budget.category?.nameTh ?? 'งบรวม',
        baht(budget.amount),
        baht(spent),
        baht(budget.amount - spent),
        spent > budget.amount ? 'เกินงบ' : 'ปกติ',
      ]);
    }
    rows.push(['รวม', baht(limit), baht(spentTotal), baht(limit - spentTotal), '']);
    return { sheet: 'งบประมาณ', rows };
  }

  if (kind === 'transactions') {
    const transactions = await prisma.transaction.findMany({
      where: { userId, occurredAt: { gte: start, lt: end } },
      orderBy: { occurredAt: 'desc' },
      include: { category: true },
    });
    const rows: (string | number)[][] = [['วันที่', 'ประเภท', 'จำนวน (บาท)', 'หมวดหมู่', 'ที่มา', 'โน้ต']];
    let income = 0;
    let expense = 0;
    for (const transaction of transactions) {
      if (transaction.type === 'income') income += transaction.amount;
      else expense += transaction.amount;
      rows.push([
        transaction.occurredAt.toISOString().split('T')[0],
        transaction.type === 'income' ? 'รายรับ' : 'รายจ่าย',
        baht(transaction.amount),
        transaction.category?.nameTh ?? 'อื่นๆ',
        transaction.source ?? 'manual',
        transaction.note ?? '',
      ]);
    }
    rows.push(['รวม', '', '', '', '', '']);
    rows.push(['รายรับ', baht(income), 'รายจ่าย', baht(expense), 'คงเหลือ', baht(income - expense)]);
    return { sheet: 'รายการเดินบัญชี', rows };
  }

  if (kind === 'subscriptions') {
    const subscriptions = await prisma.subscription.findMany({ where: { userId }, orderBy: { nextBilling: 'asc' } });
    const rows: (string | number)[][] = [['บริการ', 'ราคา/รอบ (บาท)', 'รอบบิล', 'ตัดเงินถัดไป', 'ต่อเดือน (บาท)']];
    let monthly = 0;
    for (const subscription of subscriptions) {
      const perMonth = subscription.cycle === 'yearly' ? Math.round(subscription.amount / 12) : subscription.amount;
      monthly += perMonth;
      rows.push([
        subscription.name,
        baht(subscription.amount),
        subscription.cycle === 'yearly' ? 'รายปี' : 'รายเดือน',
        subscription.nextBilling.toISOString().split('T')[0],
        baht(perMonth),
      ]);
    }
    rows.push(['รวมต่อเดือน', '', '', '', baht(monthly)]);
    return { sheet: 'Subscription', rows };
  }

  const grouped = await prisma.transaction.groupBy({
    by: ['type'],
    _sum: { amount: true },
    where: { userId, occurredAt: { gte: start, lt: end } },
  });
  const income = grouped.find((group) => group.type === 'income')?._sum.amount ?? 0;
  const expense = grouped.find((group) => group.type === 'expense')?._sum.amount ?? 0;
  const goals = await prisma.goal.findMany({ where: { userId } });
  const rows: (string | number)[][] = [
    ['รายการ', 'ค่า (บาท)', 'ปัจจุบัน (บาท)', 'คืบหน้า (%)'],
    ['รายรับ', baht(income), '', ''],
    ['รายจ่าย', baht(expense), '', ''],
    ['คงเหลือสุทธิ', baht(income - expense), '', ''],
    ...goals.map((goal) => [goal.name, baht(goal.target), baht(goal.current), goal.target > 0 ? Math.round((goal.current / goal.target) * 100) : 0]),
  ];
  return { sheet: 'สรุปการเงิน', rows };
}

function rowsToXml(root: string, sheet: string, rows: (string | number)[][]): string {
  const headers = rows[0] ?? [];
  const body = rows.slice(1).map((row) => {
    const cells = row.map((value, index) => `    <cell name="${xmlEscape(String(headers[index] ?? `col${index + 1}`))}">${xmlEscape(String(value))}</cell>`).join('\n');
    return `  <row>\n${cells}\n  </row>`;
  }).join('\n');
  return `<?xml version="1.0" encoding="UTF-8"?>\n<${root} currency="THB" sheet="${xmlEscape(sheet)}">\n${body}\n</${root}>\n`;
}

function rowsToJson(rows: (string | number)[][]): string {
  const headers = rows[0] ?? [];
  const records = rows.slice(1).map((row) => Object.fromEntries(headers.map((header, index) => [String(header || `column_${index + 1}`), row[index] ?? ''])));
  return JSON.stringify(records, null, 2);
}

function rowsToCsv(rows: (string | number)[][]): string {
  const sheet = XLSX.utils.aoa_to_sheet(rows);
  return `\uFEFF${XLSX.utils.sheet_to_csv(sheet)}`;
}

function rowsToText(title: string, rows: (string | number)[][]): string {
  return `${title}\n${'='.repeat(Math.min(title.length + 4, 60))}\n\n${rows.map((row) => row.join('\t')).join('\n')}\n`;
}

function documentToText(document: DynamicDocument): string {
  return `${document.title}\n${'='.repeat(Math.min(document.title.length + 4, 60))}\n\n${document.content.trim()}\n`;
}

function cleanMarkdown(text: string): string {
  return text
    .replace(/```[\s\S]*?```/g, (block) => block.replace(/```\w*/g, '').replace(/```/g, ''))
    .replace(/\*\*(.*?)\*\*/g, '$1')
    .replace(/__(.*?)__/g, '$1')
    .replace(/`([^`]+)`/g, '$1')
    .replace(/^#{1,6}\s+/gm, '')
    .trim();
}

function tableToDocument(title: string, rows: (string | number)[][]): DynamicDocument {
  return { title, content: rows.map((row) => row.join(' | ')).join('\n') };
}

function resolvePdfFont(): string {
  return path.resolve(__dirname, '../../../assets/fonts/Sarabun-Regular.ttf');
}

const THAI_MONTHS_SHORT = ['ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.', 'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'];

function parseIsoDate(value: unknown): { year: number; month: number; day: number } | null {
  if (typeof value !== 'string') return null;
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  if (!match) return null;
  return { year: Number(match[1]), month: Number(match[2]), day: Number(match[3]) };
}

function displayDate(value: unknown): string {
  const date = parseIsoDate(value);
  return date ? `${date.day} ${THAI_MONTHS_SHORT[date.month - 1]} ${date.year + 543}` : String(value ?? '');
}

function displayTableRows(rows: (string | number)[][]): (string | number)[][] {
  return rows.map((row, rowIndex) => row.map((value) => rowIndex === 0 ? value : (parseIsoDate(value) ? displayDate(value) : value)));
}

function formatAmount(value: unknown): string {
  return typeof value === 'number' ? value.toLocaleString('th-TH', { maximumFractionDigits: 2 }) : String(value ?? '');
}

function summaryFromRows(rows: (string | number)[][], meta?: DynamicTable['meta']): { total: number; count: number; start: string; end: string } {
  const headers = rows[0]?.map(String) ?? [];
  const body = rows.slice(1);
  const cumulativeIndex = headers.findIndex((header) => /ยอดสะสม|คงเหลือสุทธิ|รวม/.test(header));
  const amountIndex = headers.findIndex((header) => /ยอดออม|จำนวน.*บาท|ค่า.*บาท/.test(header));
  const total = cumulativeIndex >= 0 && body.length && typeof body[body.length - 1][cumulativeIndex] === 'number'
    ? Number(body[body.length - 1][cumulativeIndex])
    : body.reduce((sum, row) => sum + (amountIndex >= 0 && typeof row[amountIndex] === 'number' ? Number(row[amountIndex]) : 0), 0);
  return {
    total,
    count: body.length,
    start: meta?.startDate ? displayDate(meta.startDate) : '-',
    end: meta?.endDate ? displayDate(meta.endDate) : '-',
  };
}

async function createStyledXlsx(title: string, rows: (string | number)[][], meta?: DynamicTable['meta']): Promise<Buffer> {
  const workbook = new ExcelJS.Workbook();
  workbook.creator = 'พี่เงิน';
  workbook.created = new Date();
  const worksheet = workbook.addWorksheet(title.slice(0, 28), {
    views: [{ state: 'frozen', ySplit: 6, showGridLines: false }],
    pageSetup: { orientation: 'landscape', fitToPage: true, fitToWidth: 1, fitToHeight: 0, margins: { left: 0.35, right: 0.35, top: 0.6, bottom: 0.6, header: 0.25, footer: 0.25 } },
  });
  const headers = rows[0]?.map(String) ?? [];
  const body = rows.slice(1);
  const columnCount = Math.max(headers.length, 1);
  const lastColumn = worksheet.getColumn(columnCount).letter;
  const summary = summaryFromRows(rows, meta);

  worksheet.mergeCells(`A1:${lastColumn}1`);
  const titleCell = worksheet.getCell('A1');
  titleCell.value = title;
  titleCell.font = { name: 'Tahoma', size: 20, bold: true, color: { argb: 'FFFFFFFF' } };
  titleCell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF075E45' } };
  titleCell.alignment = { vertical: 'middle', horizontal: 'left' };
  worksheet.getRow(1).height = 38;

  worksheet.mergeCells(`A2:${lastColumn}2`);
  const subtitle = meta?.startDate && meta?.endDate
    ? `ช่วงแผน ${displayDate(meta.startDate)} - ${displayDate(meta.endDate)}  |  ข้อมูล ณ ${displayDate(meta.asOf)}`
    : `สร้างโดยพี่เงิน  |  ข้อมูล ณ ${new Date().toLocaleDateString('th-TH')}`;
  worksheet.getCell('A2').value = subtitle;
  worksheet.getCell('A2').font = { name: 'Tahoma', size: 10, color: { argb: 'FF667085' } };
  worksheet.getCell('A2').alignment = { vertical: 'middle', horizontal: 'left' };
  worksheet.getRow(2).height = 23;

  const summaryValues: (string | number | null)[] = ['เป้าหมายรวม', summary.total, `จำนวน ${summary.count} งวด`];
  worksheet.getRow(4).values = summaryValues;
  if (columnCount > 3) worksheet.mergeCells(`C4:${lastColumn}4`);
  worksheet.getRow(4).height = 30;
  for (let column = 1; column <= columnCount; column += 1) {
    const cell = worksheet.getRow(4).getCell(column);
    cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFEAF8F0' } };
    cell.font = { name: 'Tahoma', size: 11, bold: true, color: { argb: 'FF075E45' } };
    cell.alignment = { vertical: 'middle', horizontal: column === 2 ? 'right' : (column >= 3 ? 'center' : 'left') };
  }
  if (columnCount >= 2) worksheet.getCell('B4').numFmt = '#,##0;[Red](#,##0);-';

  const headerRow = worksheet.getRow(6);
  headerRow.values = headers;
  headerRow.height = 30;
  headerRow.eachCell((cell) => {
    cell.font = { name: 'Tahoma', size: 11, bold: true, color: { argb: 'FFFFFFFF' } };
    cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF0B7A58' } };
    cell.alignment = { vertical: 'middle', horizontal: 'center', wrapText: true };
    cell.border = { bottom: { style: 'medium', color: { argb: 'FF075E45' } } };
  });

  const amountIndex = headers.findIndex((header) => /ยอดออม.*บาท|จำนวน.*บาท/.test(header));
  const cumulativeIndex = headers.findIndex((header) => /ยอดสะสม/.test(header));
  body.forEach((sourceRow, rowIndex) => {
    const excelRow = worksheet.getRow(7 + rowIndex);
    sourceRow.forEach((value, columnIndex) => {
      const cell = excelRow.getCell(columnIndex + 1);
      const parsed = parseIsoDate(value);
      cell.value = parsed ? new Date(Date.UTC(parsed.year, parsed.month - 1, parsed.day, 12)) : value;
      cell.font = { name: 'Tahoma', size: 10.5, color: { argb: 'FF1D2939' } };
      cell.alignment = { vertical: 'middle', horizontal: typeof value === 'number' ? 'right' : (parsed ? 'center' : 'left') };
      cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: rowIndex % 2 ? 'FFF7FAF8' : 'FFFFFFFF' } };
      cell.border = { bottom: { style: 'thin', color: { argb: 'FFE4E7EC' } } };
      if (parsed) cell.numFmt = '[$-th-TH]d mmmm yyyy';
      else if (typeof value === 'number' && columnIndex > 0) cell.numFmt = '#,##0;[Red](#,##0);-';
    });
    if (amountIndex >= 0 && cumulativeIndex >= 0) {
      const amountLetter = worksheet.getColumn(amountIndex + 1).letter;
      const cumulativeCell = excelRow.getCell(cumulativeIndex + 1);
      cumulativeCell.value = { formula: `SUM($${amountLetter}$7:${amountLetter}${7 + rowIndex})`, result: sourceRow[cumulativeIndex] as number };
      cumulativeCell.numFmt = '#,##0;[Red](#,##0);-';
      cumulativeCell.font = { name: 'Tahoma', size: 10.5, bold: true, color: { argb: 'FF075E45' } };
    }
    excelRow.height = 26;
  });

  headers.forEach((header, index) => {
    const values = body.slice(0, 50).map((row) => String(row[index] ?? ''));
    const width = /วันที่/.test(header) ? 19 : /บาท|ยอด/.test(header) ? 18 : Math.min(Math.max(header.length + 4, ...values.map((value) => value.length + 2), 10), 28);
    worksheet.getColumn(index + 1).width = width;
  });
  worksheet.autoFilter = { from: { row: 6, column: 1 }, to: { row: 6, column: columnCount } };
  worksheet.headerFooter.oddFooter = '&Lพี่เงิน - แผนการเงินส่วนบุคคล&Cหน้า &P / &N&Rข้อมูล ณ วันที่ ' + (meta?.asOf ? displayDate(meta.asOf) : new Date().toLocaleDateString('th-TH'));
  const output = await workbook.xlsx.writeBuffer();
  return Buffer.from(output as ArrayBuffer);
}

async function createPdf(document: DynamicDocument): Promise<Buffer> {
  return new Promise<Buffer>((resolve, reject) => {
    const pdf = new PDFDocument({ size: 'A4', margins: { top: 54, right: 54, bottom: 54, left: 54 }, info: { Title: document.title, Author: 'พี่เงิน' } });
    const chunks: Buffer[] = [];
    pdf.on('data', (chunk: Buffer) => chunks.push(chunk));
    pdf.on('end', () => resolve(Buffer.concat(chunks)));
    pdf.on('error', reject);
    // ใช้ Buffer ใหม่ทุกครั้งเพื่อไม่ให้ fontkit นำ subset จาก PDF ก่อนหน้ามาใช้ซ้ำ
    const font = Buffer.from(readFileSync(resolvePdfFont()));
    pdf.registerFont('Thai', font);
    pdf.font('Thai').fontSize(20).fillColor('#0F5132').text(document.title, { lineGap: 4 });
    pdf.moveDown(0.4);
    pdf.font('Thai').fontSize(9).fillColor('#667085').text(`สร้างโดยพี่เงิน • ${new Date().toLocaleDateString('th-TH')}`);
    pdf.moveDown(1.1);

    const pdfContent = document.content.replace(/\p{Extended_Pictographic}/gu, '');
    for (const rawLine of pdfContent.split(/\r?\n/)) {
      const line = rawLine.trimEnd();
      if (!line.trim()) {
        pdf.moveDown(0.55);
        continue;
      }
      const heading = /^#{1,6}\s+/.test(rawLine);
      const boldLine = /^\*\*(.+)\*\*$/.exec(line);
      const bullet = /^[-*•]\s+/.test(line);
      const numbered = /^\d+[.)]\s+/.test(line);
      if (heading) {
        pdf.font('Thai').fontSize(14).fillColor('#173B2A').text(line.replace(/^#{1,6}\s+/, ''), { lineGap: 3 });
        pdf.moveDown(0.25);
      } else if (boldLine) {
        pdf.font('Thai').fontSize(13).fillColor('#173B2A').text(boldLine[1], { lineGap: 3 });
        pdf.moveDown(0.2);
      } else if (bullet || numbered) {
        pdf.font('Thai').fontSize(11).fillColor('#1D2939').text(bullet ? `• ${line.replace(/^[-*•]\s+/, '')}` : line, { indent: 12, lineGap: 4 });
      } else {
        pdf.font('Thai').fontSize(11).fillColor('#1D2939').text(cleanMarkdown(line), { lineGap: 4 });
      }
    }
    pdf.end();
  });
}

async function createTablePdf(title: string, rows: (string | number)[][], meta?: DynamicTable['meta']): Promise<Buffer> {
  return new Promise<Buffer>((resolve, reject) => {
    const pdf = new PDFDocument({ size: 'A4', margins: { top: 0, right: 0, bottom: 0, left: 0 }, info: { Title: title, Author: 'พี่เงิน' } });
    const chunks: Buffer[] = [];
    pdf.on('data', (chunk: Buffer) => chunks.push(chunk));
    pdf.on('end', () => resolve(Buffer.concat(chunks)));
    pdf.on('error', reject);
    pdf.registerFont('Thai', Buffer.from(readFileSync(resolvePdfFont())));

    const pageWidth = 595.28;
    const pageHeight = 841.89;
    const margin = 42;
    const availableWidth = pageWidth - margin * 2;
    const headers = rows[0]?.map(String) ?? [];
    const body = rows.slice(1);
    const summary = summaryFromRows(rows, meta);
    let pageNumber = 1;
    let y = 0;

    const drawBrandHeader = (compact = false) => {
      const height = compact ? 78 : 122;
      pdf.rect(0, 0, pageWidth, height).fill('#075E45');
      pdf.circle(margin + 18, compact ? 30 : 42, 17).fill('#00D477');
      pdf.font('Thai').fontSize(17).fillColor('#064E3B').text('฿', margin + 11, compact ? 19 : 31, { width: 14, align: 'center' });
      pdf.font('Thai').fontSize(compact ? 17 : 23).fillColor('#FFFFFF').text(title, margin + 48, compact ? 18 : 28, { width: availableWidth - 48, lineGap: 2 });
      pdf.font('Thai').fontSize(9.5).fillColor('#B9E9D3').text(
        compact ? 'ตารางแผนการเงิน (ต่อ)' : 'แผนที่อ้างอิงวัน เดือน และปีปัจจุบันตามเวลาไทย',
        margin + 48,
        compact ? 47 : 68,
        { width: availableWidth - 48 },
      );
      y = height + (compact ? 22 : 20);
    };

    const drawFooter = () => {
      pdf.moveTo(margin, pageHeight - 35).lineTo(pageWidth - margin, pageHeight - 35).lineWidth(0.5).strokeColor('#D0D5DD').stroke();
      pdf.font('Thai').fontSize(8).fillColor('#667085').text('พี่เงิน • เอกสารเพื่อการวางแผนการเงินส่วนบุคคล', margin, pageHeight - 27, { width: 330 });
      pdf.text(`หน้า ${pageNumber}`, pageWidth - margin - 80, pageHeight - 27, { width: 80, align: 'right' });
    };

    drawBrandHeader();
    const cardGap = 10;
    const cardWidth = (availableWidth - cardGap * 2) / 3;
    const cards = [
      ['เป้าหมายรวม', `${formatAmount(summary.total)} บาท`],
      ['จำนวนงวด', `${summary.count} งวด`],
      ['ช่วงแผน', meta?.startDate && meta?.endDate ? `${displayDate(meta.startDate)} - ${displayDate(meta.endDate)}` : 'ตามข้อมูลในตาราง'],
    ];
    cards.forEach(([label, value], index) => {
      const x = margin + index * (cardWidth + cardGap);
      pdf.roundedRect(x, y, cardWidth, 70, 8).fill('#EAF8F0');
      pdf.font('Thai').fontSize(8.5).fillColor('#667085').text(label, x + 12, y + 11, { width: cardWidth - 24 });
      pdf.font('Thai').fontSize(index === 2 ? 9.5 : 15).fillColor('#075E45').text(value, x + 12, y + 32, { width: cardWidth - 24, lineGap: 1 });
    });
    y += 92;

    let columnWidths: number[];
    if (headers.length === 5 && headers.some((header) => /วันที่เริ่ม/.test(header))) {
      columnWidths = [42, 112, 112, 112, availableWidth - 378];
    } else {
      const weights = headers.map((header, index) => Math.min(Math.max(header.length, ...body.slice(0, 20).map((row) => String(row[index] ?? '').length), 6), 22));
      const totalWeight = weights.reduce((sum, weight) => sum + weight, 0) || 1;
      columnWidths = weights.map((weight) => (availableWidth * weight) / totalWeight);
    }

    const drawTableHeader = () => {
      let x = margin;
      headers.forEach((header, index) => {
        const width = columnWidths[index];
        pdf.rect(x, y, width, 36).fill('#0B7A58');
        pdf.font('Thai').fontSize(9).fillColor('#FFFFFF').text(header, x + 6, y + 9, { width: width - 12, align: index === 0 ? 'center' : (/บาท|ยอด/.test(header) ? 'right' : 'center'), lineGap: 1 });
        x += width;
      });
      y += 36;
    };

    drawTableHeader();
    body.forEach((row, rowIndex) => {
      const rowHeight = 36;
      if (y + rowHeight > pageHeight - 48) {
        drawFooter();
        pdf.addPage();
        pageNumber += 1;
        drawBrandHeader(true);
        drawTableHeader();
      }
      let x = margin;
      row.forEach((rawValue, columnIndex) => {
        const width = columnWidths[columnIndex] ?? 60;
        const value = parseIsoDate(rawValue) ? displayDate(rawValue) : formatAmount(rawValue);
        pdf.rect(x, y, width, rowHeight).fill(rowIndex % 2 ? '#F7FAF8' : '#FFFFFF');
        pdf.moveTo(x, y + rowHeight).lineTo(x + width, y + rowHeight).lineWidth(0.45).strokeColor('#DDE5E0').stroke();
        pdf.font('Thai').fontSize(9.7).fillColor(columnIndex === row.length - 1 ? '#075E45' : '#1D2939').text(value, x + 6, y + 11, {
          width: width - 12,
          align: typeof rawValue === 'number' && columnIndex > 0 ? 'right' : (parseIsoDate(rawValue) ? 'center' : 'left'),
          lineGap: 1,
        });
        x += width;
      });
      y += rowHeight;
    });
    drawFooter();
    pdf.end();
  });
}

function paragraphForLine(rawLine: string): Paragraph {
  const line = rawLine.trimEnd();
  if (/^#{1,3}\s+/.test(line)) {
    const level = (line.match(/^#+/)?.[0].length ?? 1) === 1 ? HeadingLevel.HEADING_1 : HeadingLevel.HEADING_2;
    return new Paragraph({ text: line.replace(/^#{1,6}\s+/, ''), heading: level });
  }
  if (/^[-*•]\s+/.test(line)) {
    return new Paragraph({ text: line.replace(/^[-*•]\s+/, ''), numbering: { reference: 'finance-bullets', level: 0 } });
  }
  if (/^\d+[.)]\s+/.test(line)) {
    return new Paragraph({ text: line.replace(/^\d+[.)]\s+/, ''), numbering: { reference: 'finance-numbers', level: 0 } });
  }
  return new Paragraph({ children: [new TextRun(cleanMarkdown(line))], spacing: { after: line ? 120 : 60, line: 264 } });
}

function computeColumnWidths(rows: (string | number)[][]): number[] {
  const columnCount = Math.max(...rows.map((row) => row.length), 1);
  const weights = Array.from({ length: columnCount }, (_, column) => {
    const longest = Math.max(...rows.slice(0, 25).map((row) => String(row[column] ?? '').length), 4);
    return Math.min(Math.max(longest, 6), 28);
  });
  const total = weights.reduce((sum, value) => sum + value, 0);
  const widths = weights.map((weight) => Math.floor((9360 * weight) / total));
  widths[widths.length - 1] += 9360 - widths.reduce((sum, value) => sum + value, 0);
  return widths;
}

async function createDocx(document: DynamicDocument, tableRows?: (string | number)[][]): Promise<Buffer> {
  const children: (Paragraph | Table)[] = [
    new Paragraph({
      children: [new TextRun({ text: document.title, bold: true, size: 46, color: '0F5132', font: 'Arial' })],
      spacing: { before: 0, after: 80 },
    }),
    new Paragraph({
      children: [new TextRun({ text: `สร้างโดยพี่เงิน • ${new Date().toLocaleDateString('th-TH')}`, size: 18, color: '667085', font: 'Arial' })],
      spacing: { after: 320 },
    }),
  ];

  if (tableRows?.length) {
    const widths = computeColumnWidths(tableRows);
    children.push(new Table({
      width: { size: 9360, type: WidthType.DXA },
      indent: { size: 120, type: WidthType.DXA },
      layout: TableLayoutType.FIXED,
      columnWidths: widths,
      borders: {
        top: { style: BorderStyle.SINGLE, size: 1, color: 'D0D5DD' },
        bottom: { style: BorderStyle.SINGLE, size: 1, color: 'D0D5DD' },
        left: { style: BorderStyle.SINGLE, size: 1, color: 'D0D5DD' },
        right: { style: BorderStyle.SINGLE, size: 1, color: 'D0D5DD' },
        insideHorizontal: { style: BorderStyle.SINGLE, size: 1, color: 'EAECF0' },
        insideVertical: { style: BorderStyle.SINGLE, size: 1, color: 'EAECF0' },
      },
      rows: tableRows.map((row, rowIndex) => new TableRow({
        tableHeader: rowIndex === 0,
        children: widths.map((width, columnIndex) => new TableCell({
          width: { size: width, type: WidthType.DXA },
          margins: { top: 100, bottom: 100, left: 120, right: 120 },
          shading: rowIndex === 0 ? { fill: 'E8F5EE' } : undefined,
          children: [new Paragraph({
            alignment: typeof row[columnIndex] === 'number' ? AlignmentType.RIGHT : AlignmentType.LEFT,
            children: [new TextRun({ text: String(row[columnIndex] ?? ''), bold: rowIndex === 0, size: 20, font: 'Arial' })],
            spacing: { before: 0, after: 0, line: 240 },
          })],
        })),
      })),
    }));
  } else {
    children.push(...document.content.split(/\r?\n/).map(paragraphForLine));
  }

  const file = new Document({
    creator: 'พี่เงิน',
    title: document.title,
    styles: {
      default: { document: { run: { font: 'Arial', size: 22, color: '1D2939' }, paragraph: { spacing: { after: 120, line: 264 } } } },
      paragraphStyles: [
        { id: 'Heading1', name: 'Heading 1', basedOn: 'Normal', next: 'Normal', quickFormat: true, run: { font: 'Arial', size: 32, bold: true, color: '0F5132' }, paragraph: { spacing: { before: 320, after: 160 }, outlineLevel: 0 } },
        { id: 'Heading2', name: 'Heading 2', basedOn: 'Normal', next: 'Normal', quickFormat: true, run: { font: 'Arial', size: 26, bold: true, color: '173B2A' }, paragraph: { spacing: { before: 240, after: 120 }, outlineLevel: 1 } },
      ],
    },
    numbering: {
      config: [
        { reference: 'finance-bullets', levels: [{ level: 0, format: LevelFormat.BULLET, text: '•', alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 720, hanging: 360 }, spacing: { after: 80, line: 264 } } } }] },
        { reference: 'finance-numbers', levels: [{ level: 0, format: LevelFormat.DECIMAL, text: '%1.', alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 720, hanging: 360 }, spacing: { after: 80, line: 264 } } } }] },
      ],
    },
    sections: [{
      properties: {
        page: { size: { width: 12240, height: 15840, orientation: PageOrientation.PORTRAIT }, margin: { top: 1440, right: 1440, bottom: 1440, left: 1440, header: 708, footer: 708 } },
      },
      children,
    }],
  });
  return Packer.toBuffer(file);
}

function rowsToHtml(title: string, rows: (string | number)[][]): string {
  const head = rows[0] ?? [];
  const body = rows.slice(1);
  return `<!doctype html><html lang="th"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${htmlEscape(title)}</title><style>body{font-family:"Noto Sans Thai",Tahoma,sans-serif;max-width:980px;margin:40px auto;padding:0 20px;color:#1d2939}h1{color:#0f5132}table{width:100%;border-collapse:collapse}th,td{border:1px solid #d0d5dd;padding:10px;text-align:left}th{background:#e8f5ee}tr:nth-child(even){background:#f9fafb}</style></head><body><h1>${htmlEscape(title)}</h1><table><thead><tr>${head.map((cell) => `<th>${htmlEscape(String(cell))}</th>`).join('')}</tr></thead><tbody>${body.map((row) => `<tr>${row.map((cell) => `<td>${htmlEscape(String(cell))}</td>`).join('')}</tr>`).join('')}</tbody></table></body></html>`;
}

function documentToHtml(document: DynamicDocument): string {
  const paragraphs = cleanMarkdown(document.content).split(/\r?\n/).map((line) => line.trim() ? `<p>${htmlEscape(line)}</p>` : '<br>');
  return `<!doctype html><html lang="th"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${htmlEscape(document.title)}</title><style>body{font-family:"Noto Sans Thai",Tahoma,sans-serif;max-width:760px;margin:40px auto;padding:0 20px;line-height:1.75;color:#1d2939}h1{color:#0f5132}p{margin:.45em 0}</style></head><body><h1>${htmlEscape(document.title)}</h1>${paragraphs.join('')}</body></html>`;
}

async function fileFromRows(
  title: string,
  base: string,
  root: string,
  rows: (string | number)[][],
  format: ExportFormat,
  meta?: DynamicTable['meta'],
): Promise<ExportFile> {
  if (format === 'xlsx') {
    return { filename: `${base}.xlsx`, contentType: MIME.xlsx, body: await createStyledXlsx(title, rows, meta) };
  }
  if (format === 'xml') return { filename: `${base}.xml`, contentType: MIME.xml, body: rowsToXml(root, title, rows) };
  if (format === 'csv') return { filename: `${base}.csv`, contentType: MIME.csv, body: rowsToCsv(rows) };
  if (format === 'json') return { filename: `${base}.json`, contentType: MIME.json, body: rowsToJson(rows) };
  if (format === 'txt') return { filename: `${base}.txt`, contentType: MIME.txt, body: rowsToText(title, rows) };
  if (format === 'html') return { filename: `${base}.html`, contentType: MIME.html, body: rowsToHtml(title, rows) };
  if (format === 'pdf') return { filename: `${base}.pdf`, contentType: MIME.pdf, body: await createTablePdf(title, rows, meta) };
  const presentableRows = displayTableRows(rows);
  return { filename: `${base}.docx`, contentType: MIME.docx, body: await createDocx(tableToDocument(title, presentableRows), presentableRows) };
}

async function fileFromDocument(document: DynamicDocument, base: string, format: ExportFormat): Promise<ExportFile> {
  if (format === 'pdf') return { filename: `${base}.pdf`, contentType: MIME.pdf, body: await createPdf(document) };
  if (format === 'docx') return { filename: `${base}.docx`, contentType: MIME.docx, body: await createDocx(document) };
  if (format === 'html') return { filename: `${base}.html`, contentType: MIME.html, body: documentToHtml(document) };
  if (format === 'txt') return { filename: `${base}.txt`, contentType: MIME.txt, body: documentToText(document) };
  const rows: (string | number)[][] = [['เนื้อหา'], ...cleanMarkdown(document.content).split(/\r?\n/).filter(Boolean).map((line) => [line])];
  return fileFromRows(document.title, base, 'document', rows, format);
}

export async function buildExportFile(userId: string, kind: ExportKind, format: ExportFormat): Promise<ExportFile> {
  const { sheet, rows } = await buildRows(userId, kind);
  const stamp = new Date().toISOString().split('T')[0];
  return fileFromRows(sheet, `${kind}-${stamp}`, kind, rows, format);
}

export async function buildDynamicFile(payload: DynamicExportPayload, format: ExportFormat): Promise<ExportFile> {
  const title = 'content' in payload ? payload.title : (payload.title || 'ข้อมูลจากแชท');
  const safe = title.replace(/[\\/:*?"<>|]/g, '_').slice(0, 40) || 'chat-data';
  const base = `${safe}-${new Date().toISOString().split('T')[0]}`;
  if ('content' in payload) return fileFromDocument(payload, base, format);
  const rows: (string | number)[][] = [payload.headers, ...payload.rows];
  return fileFromRows(title, base, 'summary', rows, format, payload.meta);
}

export function labelFor(kind: ExportKind): string {
  return KIND_LABEL[kind];
}

export function signExportToken(userId: string, cacheId?: string): string {
  return jwt.sign({ sub: userId, purpose: 'export', cid: cacheId }, env.jwtSecret, { expiresIn: '15m' });
}

export function verifyExportToken(token: string): { userId: string; cacheId?: string } {
  const payload = jwt.verify(token, env.jwtSecret) as { sub: string; purpose?: string; cid?: string };
  if (payload.purpose !== 'export') throw new Error('bad purpose');
  return { userId: payload.sub, cacheId: payload.cid };
}
