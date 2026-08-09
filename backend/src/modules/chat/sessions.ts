/**
 * จัดการ "ห้องแชท" (ChatSession) — ผู้ใช้สร้างบทสนทนาใหม่ได้เรื่อย ๆ
 * ข้อความเก่าที่ยังไม่มีห้อง (sessionId = null) จะถูกย้ายเข้าห้องให้อัตโนมัติครั้งแรกที่เปิดรายการห้อง
 */
import { prisma } from '../../lib/prisma';

/** ตัดข้อความแรกมาเป็นชื่อห้อง เช่น "กาแฟ 50 บาท" */
export function titleFromMessage(message: string): string {
  const clean = message.replace(/\s+/g, ' ').trim();
  if (!clean) return 'แชทใหม่';
  return clean.length > 40 ? `${clean.slice(0, 40)}…` : clean;
}

/**
 * ย้ายข้อความเก่า (ยังไม่มีห้อง) เข้าห้องเดียวให้เรียบร้อย — รันครั้งเดียวต่อผู้ใช้
 * ทำแบบขี้เกียจ (lazy) จะได้ไม่ต้องเขียน migration script แยก
 */
export async function migrateLegacyMessages(userId: string): Promise<void> {
  const legacyCount = await prisma.chatMessage.count({
    where: { userId, sessionId: null },
  });
  if (legacyCount === 0) return;

  const oldest = await prisma.chatMessage.findFirst({
    where: { userId, sessionId: null },
    orderBy: { createdAt: 'asc' },
    select: { createdAt: true },
  });

  const session = await prisma.chatSession.create({
    data: {
      userId,
      title: 'บทสนทนาก่อนหน้า',
      createdAt: oldest?.createdAt ?? new Date(),
    },
  });
  await prisma.chatMessage.updateMany({
    where: { userId, sessionId: null },
    data: { sessionId: session.id },
  });
}

/** หาห้องล่าสุด ถ้ายังไม่มีเลยให้สร้างใหม่ — ใช้ตอนผู้ใช้ส่งข้อความโดยไม่ระบุห้อง */
export async function ensureSession(userId: string, firstMessage?: string): Promise<string> {
  const latest = await prisma.chatSession.findFirst({
    where: { userId },
    orderBy: { updatedAt: 'desc' },
    select: { id: true },
  });
  if (latest) return latest.id;

  const created = await prisma.chatSession.create({
    data: { userId, title: firstMessage ? titleFromMessage(firstMessage) : 'แชทใหม่' },
  });
  return created.id;
}

/** ตรวจว่าห้องนี้เป็นของผู้ใช้จริง (กันดูข้ามบัญชี) */
export async function assertOwnedSession(userId: string, sessionId: string): Promise<boolean> {
  const found = await prisma.chatSession.findFirst({
    where: { id: sessionId, userId },
    select: { id: true },
  });
  return !!found;
}

/**
 * อัปเดตห้องหลังมีข้อความใหม่ — เลื่อน updatedAt ขึ้นบนสุด
 * และตั้งชื่อห้องจากข้อความแรกถ้ายังเป็นชื่อเริ่มต้น
 */
export async function touchSession(sessionId: string, userMessage: string): Promise<void> {
  const session = await prisma.chatSession.findUnique({
    where: { id: sessionId },
    select: { title: true },
  });
  const shouldRename = !session?.title || session.title === 'แชทใหม่';
  await prisma.chatSession.update({
    where: { id: sessionId },
    data: shouldRename ? { title: titleFromMessage(userMessage) } : { updatedAt: new Date() },
  });
}
