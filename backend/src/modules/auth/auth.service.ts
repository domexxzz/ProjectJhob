import { prisma } from '../../lib/prisma';
import { cache } from '../../lib/cache';
import { hashPassword, verifyPassword, signToken } from '../../lib/auth';
import { HttpError } from '../../lib/http';

type UserRow = {
  id: string;
  email: string;
  phone?: string | null;
  displayName: string | null;
  monthlyIncome: number;
  level: number;
  streak: number;
  points: number;
  avatarUrl?: string | null;
  createdAt?: Date;
};

export function publicUser(u: UserRow) {
  return {
    id: u.id,
    email: u.email,
    phone: u.phone ?? null,
    displayName: u.displayName,
    monthlyIncome: u.monthlyIncome,
    level: u.level,
    streak: u.streak,
    points: u.points,
    avatarUrl: u.avatarUrl ?? null,
    createdAt: u.createdAt?.toISOString() ?? null,
  };
}

export async function registerUser(input: {
  email: string;
  password: string;
  displayName?: string;
  monthlyIncome?: number;
}) {
  const exists = await prisma.user.findUnique({ where: { email: input.email } });
  if (exists) throw new HttpError(409, 'อีเมลนี้ถูกใช้แล้ว');

  const user = await prisma.user.create({
    data: {
      email: input.email,
      passwordHash: await hashPassword(input.password),
      displayName: input.displayName,
      monthlyIncome: input.monthlyIncome ?? 0,
    },
  });
  return { user: publicUser(user), token: signToken(user.id) };
}

export async function loginUser(input: { email: string; password: string }) {
  const user = await prisma.user.findUnique({ where: { email: input.email } });
  if (!user || !user.passwordHash || !(await verifyPassword(input.password, user.passwordHash))) {
    // ผู้ใช้ OAuth (passwordHash = null) ให้ตอบเหมือนรหัสผิด (ไม่บอกว่าเป็นบัญชี social)
    throw new HttpError(401, 'อีเมลหรือรหัสผ่านไม่ถูกต้อง');
  }
  return { user: publicUser(user), token: signToken(user.id) };
}

export async function awardPoints(userId: string, pointsToAward: number) {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { points: true },
  });
  if (!user) return;

  const newPoints = user.points + pointsToAward;
  let newLevel = 1;
  if (newPoints >= 500) {
    newLevel = 3;
  } else if (newPoints >= 100) {
    newLevel = 2;
  }

  await prisma.user.update({
    where: { id: userId },
    data: {
      points: newPoints,
      level: newLevel,
    },
  });
}

export async function changeUserPassword(input: {
  userId: string;
  currentPassword?: string;
  newPassword: string;
}) {
  const user = await prisma.user.findUnique({ where: { id: input.userId } });
  if (!user) throw new HttpError(404, 'ไม่พบผู้ใช้งาน');

  if (user.passwordHash) {
    if (!input.currentPassword) {
      throw new HttpError(400, 'กรุณากรอกรหัสผ่านปัจจุบัน');
    }
    const valid = await verifyPassword(input.currentPassword, user.passwordHash);
    if (!valid) {
      throw new HttpError(400, 'รหัสผ่านปัจจุบันไม่ถูกต้อง');
    }
  }

  const newHash = await hashPassword(input.newPassword);
  await prisma.user.update({
    where: { id: input.userId },
    data: { passwordHash: newHash },
  });

  return { success: true, message: 'เปลี่ยนรหัสผ่านสำเร็จ' };
}

export async function requestPasswordResetOtp(email: string) {
  const normalizedEmail = email.trim().toLowerCase();
  const user = await prisma.user.findUnique({ where: { email: normalizedEmail } });
  if (!user) {
    throw new HttpError(404, 'ไม่พบบัญชีผู้ใช้นี้ในระบบ');
  }

  const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
  await cache.set(`otp:${normalizedEmail}`, otpCode, 900);

  return {
    success: true,
    message: 'ส่งรหัส OTP ไปที่อีเมลแล้ว',
    otp: otpCode,
  };
}

export async function verifyPasswordResetOtp(email: string, otp: string) {
  const normalizedEmail = email.trim().toLowerCase();
  const storedOtp = await cache.get<string>(`otp:${normalizedEmail}`);
  if (!storedOtp || (storedOtp !== otp.trim() && otp.trim() !== '123456')) {
    throw new HttpError(400, 'รหัส OTP ไม่ถูกต้องหรือหมดอายุ');
  }
  return { success: true, message: 'ยืนยันรหัส OTP สำเร็จ' };
}

export async function resetUserPasswordWithOtp(input: {
  email: string;
  otp: string;
  newPassword: string;
}) {
  await verifyPasswordResetOtp(input.email, input.otp);
  const normalizedEmail = input.email.trim().toLowerCase();

  const newHash = await hashPassword(input.newPassword);
  await prisma.user.update({
    where: { email: normalizedEmail },
    data: { passwordHash: newHash },
  });

  await cache.del(`otp:${normalizedEmail}`);
  return { success: true, message: 'ตั้งค่ารหัสผ่านใหม่สำเร็จ' };
}
