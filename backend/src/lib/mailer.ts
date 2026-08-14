/**
 * ตัวส่งอีเมล — เลือกผู้ให้บริการตาม env ที่ตั้งไว้
 *
 * ใช้รูปแบบเดียวกับที่ระบบเลือก LLM provider อยู่แล้ว คือ "ตั้ง key ตัวไหน ใช้ตัวนั้น"
 * เพื่อให้เพื่อนในทีมเลือกได้ตามสะดวก โดยไม่ต้องแก้โค้ด
 *
 *   RESEND_API_KEY      → Resend (เรียกผ่าน HTTP API ไม่ต้องลงไลบรารีเพิ่ม)
 *   SMTP_HOST/USER/PASS → SMTP ทั่วไป เช่น Gmail (ต้องใช้ App Password ไม่ใช่รหัสผ่านปกติ)
 *   ไม่ตั้งอะไรเลย       → โหมดพัฒนา: พิมพ์รหัสลง console แทนการส่งจริง
 *
 * ⚠️ โหมดพัฒนาใช้ได้เฉพาะตอนรันในเครื่อง — ถ้าไม่ได้ตั้งค่าใด ๆ บนเซิร์ฟเวอร์จริง
 * ฟังก์ชันจะคืน ok:false เพื่อให้ผู้เรียกรู้ว่าส่งไม่สำเร็จ ไม่ใช่แกล้งทำเป็นสำเร็จ
 */
import { env } from '../config/env';

export interface MailResult {
  ok: boolean;
  /** ชื่อผู้ให้บริการที่ใช้จริง หรือเหตุผลที่ส่งไม่ได้ */
  detail: string;
}

const FROM = process.env.MAIL_FROM ?? 'พี่เงิน <onboarding@resend.dev>';
const isProduction = process.env.NODE_ENV === 'production';

async function sendViaResend(to: string, subject: string, html: string): Promise<MailResult> {
  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${process.env.RESEND_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ from: FROM, to, subject, html }),
  });
  if (!res.ok) {
    const body = await res.text().catch(() => '');
    return { ok: false, detail: `resend ตอบ ${res.status}: ${body.slice(0, 200)}` };
  }
  return { ok: true, detail: 'resend' };
}

async function sendViaSmtp(to: string, subject: string, html: string): Promise<MailResult> {
  // import แบบ dynamic — คนที่ใช้ Resend ไม่จำเป็นต้องติดตั้ง nodemailer
  const nodemailer = await import('nodemailer').catch(() => null);
  if (!nodemailer) {
    return { ok: false, detail: 'ตั้ง SMTP_* ไว้แต่ยังไม่ได้ติดตั้ง nodemailer (npm i nodemailer)' };
  }
  const port = Number(process.env.SMTP_PORT ?? 587);
  const transport = nodemailer.default.createTransport({
    host: process.env.SMTP_HOST,
    port,
    secure: port === 465,
    auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS },
    // ตั้ง timeout ไว้ทุกจังหวะ — วัดจริงแล้วเคยค้างถึง 120 วินาที
    // ถ้าปล่อยไม่จำกัด เวลามีปัญหาจะไม่มีทางรู้ว่าติดตรงไหน
    connectionTimeout: 15_000, // ต่อไม่ติดใน 15 วิ = พอร์ตน่าจะถูกบล็อก
    greetingTimeout: 10_000, // ต่อติดแต่เซิร์ฟเวอร์ไม่ทัก
    socketTimeout: 20_000, // คุยกันอยู่แล้วเงียบไป
  });
  await transport.sendMail({ from: FROM, to, subject, html });
  return { ok: true, detail: `smtp:${process.env.SMTP_HOST}` };
}

/**
 * ผลการส่งครั้งล่าสุด — ไว้วินิจฉัยตอนผู้ใช้บอกว่า "ไม่ได้รับอีเมล"
 *
 * จำเป็นเพราะการส่งทำแบบไม่รอผล (ดูเหตุผลใน otp.service.ts) ข้อผิดพลาดจึงไม่
 * ไปโผล่ที่คำตอบของ API และคนที่ไม่มีสิทธิ์เข้า dashboard ก็อ่าน log ไม่ได้
 */
let lastResult: (MailResult & { at: string }) | null = null;

export function lastMailResult(): (MailResult & { at: string }) | null {
  return lastResult;
}

/** ส่งอีเมล — ไม่เคย throw ผู้เรียกดูค่า ok เอง */
export async function sendEmail(to: string, subject: string, html: string): Promise<MailResult> {
  const result = await _send(to, subject, html);
  lastResult = { ...result, at: new Date().toISOString() };
  return result;
}

async function _send(to: string, subject: string, html: string): Promise<MailResult> {
  try {
    if (process.env.RESEND_API_KEY) return await sendViaResend(to, subject, html);
    if (process.env.SMTP_HOST && process.env.SMTP_USER && process.env.SMTP_PASS) {
      return await sendViaSmtp(to, subject, html);
    }
    if (isProduction) {
      return {
        ok: false,
        detail: 'ยังไม่ได้ตั้งค่าการส่งอีเมลบนเซิร์ฟเวอร์ (ต้องตั้ง RESEND_API_KEY หรือ SMTP_*)',
      };
    }
    // โหมดพัฒนา — ให้เห็นเนื้อหาใน console จะได้ทดสอบได้โดยไม่ต้องมีบัญชีผู้ให้บริการ
    console.log(`\n📧 [dev] ส่งถึง ${to}\n   หัวข้อ: ${subject}\n   ${html.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim()}\n`);
    return { ok: true, detail: 'dev-console' };
  } catch (e) {
    return { ok: false, detail: (e as Error).message.slice(0, 200) };
  }
}

/** เทมเพลตอีเมล OTP — ข้อความเปลี่ยนตามว่าใช้ทำอะไร */
export function otpEmailTemplate(
  code: string,
  purpose: 'reset' | 'verify' | 'login',
): { subject: string; html: string } {
  const label = {
    reset: { subject: 'รหัสยืนยันสำหรับตั้งรหัสผ่านใหม่ — พี่เงิน', lead: 'ใช้รหัสนี้เพื่อตั้งรหัสผ่านใหม่' },
    verify: { subject: 'ยืนยันอีเมลของคุณ — พี่เงิน', lead: 'ใช้รหัสนี้เพื่อยืนยันอีเมลของคุณ' },
    login: { subject: 'รหัสเข้าสู่ระบบ — พี่เงิน', lead: 'ใช้รหัสนี้เพื่อเข้าสู่ระบบ' },
  }[purpose];

  const html = `
<div style="font-family:system-ui,-apple-system,'Segoe UI',sans-serif;max-width:420px;margin:0 auto;padding:24px">
  <h2 style="margin:0 0 4px;color:#111">พี่เงิน</h2>
  <p style="margin:0 0 20px;color:#666;font-size:14px">${label.lead}</p>
  <div style="background:#f4f6f8;border-radius:12px;padding:20px;text-align:center">
    <div style="font-size:32px;font-weight:700;letter-spacing:8px;color:#111">${code}</div>
  </div>
  <p style="margin:20px 0 0;color:#666;font-size:13px">
    รหัสนี้ใช้ได้ 10 นาที และใช้ได้ครั้งเดียว<br>
    ถ้าคุณไม่ได้เป็นคนขอ ไม่ต้องทำอะไร บัญชีของคุณยังปลอดภัยดี
  </p>
</div>`.trim();

  return { subject: label.subject, html };
}

/** ไว้ตรวจว่าระบบส่งอีเมลพร้อมใช้งานไหม (ไม่เปิดเผยค่า key) */
export function mailerStatus(): string {
  if (process.env.RESEND_API_KEY) return 'resend';
  if (process.env.SMTP_HOST) return `smtp:${process.env.SMTP_HOST}`;
  return isProduction ? 'ยังไม่ได้ตั้งค่า' : 'dev-console';
}

// import env ไว้เพื่อบังคับให้ config ถูกโหลดก่อนใช้งาน (ลำดับเดียวกับโมดูลอื่น)
void env;
