import { prisma } from '../../lib/prisma';
import { hashPassword, verifyPassword, signToken } from '../../lib/auth';
import { HttpError } from '../../lib/http';

type UserRow = {
  id: string;
  email: string;
  displayName: string | null;
  monthlyIncome: number;
  level: number;
  streak: number;
  avatarUrl?: string | null;
};

export function publicUser(u: UserRow) {
  return {
    id: u.id,
    email: u.email,
    displayName: u.displayName,
    monthlyIncome: u.monthlyIncome,
    level: u.level,
    streak: u.streak,
    avatarUrl: u.avatarUrl ?? null,
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
