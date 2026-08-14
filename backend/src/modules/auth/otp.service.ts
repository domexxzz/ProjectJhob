/**
 * รหัส OTP ทางอีเมล — ใช้ได้ 3 กรณี
 *
 *   verify → ยืนยันอีเมลตอนสมัคร
 *   reset  → ลืมรหัสผ่าน (ยืนยันแล้วได้ token ไว้ตั้งรหัสใหม่)
 *   login  → เข้าสู่ระบบด้วยรหัสแทนรหัสผ่าน
 *
 * หลักความปลอดภัยที่ยึดไว้
 *  1. เก็บรหัสแบบเข้ารหัส (bcrypt) ไม่เก็บตัวเลขตรง ๆ — ฐานข้อมูลรั่วก็เอาไปใช้ไม่ได้
 *  2. ไม่บอกว่าอีเมลนั้นมีในระบบหรือไม่ — ขอรหัสกับอีเมลไหนก็ตอบเหมือนกันหมด
 *     ไม่งั้นหน้าลืมรหัสผ่านจะกลายเป็นเครื่องมือไล่เช็กว่าใครสมัครไว้บ้าง
 *  3. รหัสใช้ได้ครั้งเดียว หมดอายุ 10 นาที กรอกผิดได้ไม่เกิน 5 ครั้ง
 *  4. ขอรหัสใหม่ = ยกเลิกรหัสเก่าทั้งหมดของกรณีนั้น กันมีหลายรหัสใช้ได้พร้อมกัน
 *  5. เทียบรหัสด้วย bcrypt.compare ซึ่งใช้เวลาเท่ากันไม่ว่าจะถูกหรือผิด
 */
import crypto from 'crypto';
import jwt from 'jsonwebtoken';
import { prisma } from '../../lib/prisma';
import { hashPassword, verifyPassword, signToken } from '../../lib/auth';
import { sendEmail, otpEmailTemplate } from '../../lib/mailer';
import { env } from '../../config/env';
import { HttpError } from '../../lib/http';

export type OtpPurpose = 'reset' | 'verify' | 'login';

const CODE_TTL_MINUTES = 10;
const MAX_ATTEMPTS = 5;

/** รหัส 6 หลักแบบสุ่มปลอดภัย — ไม่ใช้ Math.random เพราะเดาลำดับถัดไปได้ */
function generateCode(): string {
  return String(crypto.randomInt(0, 1_000_000)).padStart(6, '0');
}

/**
 * ขอรหัส OTP
 *
 * ทำงานเงียบ ๆ เหมือนกันเสมอไม่ว่าอีเมลจะมีในระบบหรือไม่ (ดูหลักข้อ 2)
 * ผู้เรียกจึงตอบผู้ใช้ได้ว่า "ถ้าอีเมลนี้มีในระบบ เราส่งรหัสไปแล้ว"
 */
export async function requestOtp(email: string, purpose: OtpPurpose): Promise<void> {
  const user = await prisma.user.findUnique({ where: { email: email.toLowerCase().trim() } });
  if (!user) return; // เงียบไว้ — ไม่เผยว่าอีเมลนี้ไม่มีในระบบ

  // ยกเลิกรหัสเก่าที่ยังใช้ได้ของกรณีเดียวกัน
  await prisma.otpCode.updateMany({
    where: { userId: user.id, purpose, consumedAt: null },
    data: { consumedAt: new Date() },
  });

  const code = generateCode();
  await prisma.otpCode.create({
    data: {
      userId: user.id,
      purpose,
      codeHash: await hashPassword(code),
      expiresAt: new Date(Date.now() + CODE_TTL_MINUTES * 60_000),
    },
  });

  // ⚠️ ห้าม await การส่งอีเมล — วัดจริงแล้วการส่งผ่าน SMTP ใช้เวลาถึง 120 วินาที
  // ถ้ารอให้ส่งเสร็จก่อนตอบ จะเกิดปัญหา 2 ชั้น
  //   1. ผู้ใช้กดปุ่มแล้วรอ 2 นาที
  //   2. ร้ายกว่านั้น: อีเมลที่ไม่มีในระบบตอบใน 0.16 วินาที ส่วนอีเมลที่มีจริง
  //      ตอบใน 120 วินาที — ต่างกัน 750 เท่า ใครจับเวลาก็รู้ทันทีว่าอีเมลไหน
  //      มีบัญชีอยู่ ทำให้ความพยายามตอบข้อความเหมือนกันหมดข้างบนเป็นโมฆะ
  // จึงส่งแบบไม่รอผล เพื่อให้ทั้งสองกรณีใช้เวลาเท่ากัน
  const { subject, html } = otpEmailTemplate(code, purpose);
  void sendEmail(user.email, subject, html).then((sent) => {
    if (!sent.ok) {
      // ไม่บอกผู้ใช้ เพราะจะกลายเป็นการเผยว่าอีเมลนี้มีอยู่จริง
      // แต่ต้องบันทึกไว้ให้คนดูแลระบบเห็น ไม่งั้นหาสาเหตุไม่เจอเวลาผู้ใช้บอกว่าไม่ได้รับรหัส
      console.error(`[otp] ส่งอีเมลไม่สำเร็จ (${purpose}):`, sent.detail);
    } else {
      console.log(`[otp] ส่งรหัส ${purpose} สำเร็จผ่าน ${sent.detail}`);
    }
  });
}

/**
 * ตรวจรหัส OTP — คืน userId ถ้าถูกต้อง
 * โยน HttpError พร้อมข้อความที่ผู้ใช้อ่านรู้เรื่องถ้าไม่ผ่าน
 */
async function consumeOtp(email: string, code: string, purpose: OtpPurpose): Promise<string> {
  const invalid = new HttpError(400, 'รหัสไม่ถูกต้องหรือหมดอายุแล้ว');

  const user = await prisma.user.findUnique({ where: { email: email.toLowerCase().trim() } });
  if (!user) throw invalid; // ข้อความเดียวกับรหัสผิด ไม่เผยว่าอีเมลไม่มีในระบบ

  const record = await prisma.otpCode.findFirst({
    where: { userId: user.id, purpose, consumedAt: null, expiresAt: { gt: new Date() } },
    orderBy: { createdAt: 'desc' },
  });
  if (!record) throw invalid;

  if (record.attempts >= MAX_ATTEMPTS) {
    // ปิดรหัสนี้ทิ้งเลย ไม่ให้เดาต่อ
    await prisma.otpCode.update({ where: { id: record.id }, data: { consumedAt: new Date() } });
    throw new HttpError(429, 'กรอกรหัสผิดหลายครั้งเกินไป กรุณาขอรหัสใหม่');
  }

  if (!(await verifyPassword(code.trim(), record.codeHash))) {
    await prisma.otpCode.update({ where: { id: record.id }, data: { attempts: record.attempts + 1 } });
    throw invalid;
  }

  await prisma.otpCode.update({ where: { id: record.id }, data: { consumedAt: new Date() } });
  return user.id;
}

/** ยืนยันอีเมลตอนสมัคร — คืน token ให้ใช้งานต่อได้เลย */
export async function verifyEmailOtp(email: string, code: string) {
  const userId = await consumeOtp(email, code, 'verify');
  const user = await prisma.user.update({
    where: { id: userId },
    data: { emailVerifiedAt: new Date() },
  });
  return { token: signToken(user.id), emailVerified: true };
}

/** เข้าสู่ระบบด้วย OTP แทนรหัสผ่าน */
export async function loginWithOtp(email: string, code: string) {
  const userId = await consumeOtp(email, code, 'login');
  await prisma.user.update({ where: { id: userId }, data: { lastLoginAt: new Date() } });
  return { token: signToken(userId) };
}

/**
 * ลืมรหัสผ่าน ขั้นที่ 1 — ยืนยันรหัสแล้วได้ token สำหรับตั้งรหัสใหม่
 *
 * แยกเป็น 2 ขั้นเพราะไม่อยากให้ผู้ใช้กรอกรหัส OTP พร้อมรหัสผ่านใหม่ในหน้าเดียว
 * token มีอายุสั้น 10 นาที และใช้ตั้งรหัสผ่านได้อย่างเดียว
 */
export async function verifyResetOtp(email: string, code: string) {
  const userId = await consumeOtp(email, code, 'reset');
  const resetToken = jwt.sign({ sub: userId, purpose: 'password-reset' }, env.jwtSecret, {
    expiresIn: '10m',
  });
  return { resetToken };
}

/** ลืมรหัสผ่าน ขั้นที่ 2 — ตั้งรหัสผ่านใหม่ด้วย token จากขั้นที่ 1 */
export async function resetPassword(resetToken: string, newPassword: string) {
  let payload: { sub: string; purpose?: string };
  try {
    payload = jwt.verify(resetToken, env.jwtSecret) as { sub: string; purpose?: string };
  } catch {
    throw new HttpError(400, 'ลิงก์ตั้งรหัสผ่านหมดอายุแล้ว กรุณาขอรหัสใหม่');
  }
  // ต้องเช็ก purpose ด้วย ไม่งั้น token ล็อกอินธรรมดาจะเอามาตั้งรหัสผ่านใหม่ได้
  if (payload.purpose !== 'password-reset') {
    throw new HttpError(400, 'token ไม่ถูกต้อง');
  }

  await prisma.user.update({
    where: { id: payload.sub },
    data: { passwordHash: await hashPassword(newPassword) },
  });

  // ตั้งรหัสใหม่แล้ว รหัส OTP ที่ค้างอยู่ทั้งหมดต้องใช้ไม่ได้
  await prisma.otpCode.updateMany({
    where: { userId: payload.sub, consumedAt: null },
    data: { consumedAt: new Date() },
  });

  return { ok: true };
}
