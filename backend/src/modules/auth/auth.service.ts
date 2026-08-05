import { prisma } from '../../lib/prisma';
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
