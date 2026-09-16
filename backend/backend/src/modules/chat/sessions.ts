/**
 * จัดการ "ห้องแชท" (ChatSession) — ผู้ใช้สร้างบทสนทนาใหม่ได้เรื่อย ๆ
 * ข้อความเก่าที่ยังไม่มีห้อง (sessionId = null) จะถูกย้ายเข้าห้องให้อัตโนมัติครั้งแรกที่เปิดรายการห้อง
 */
import { prisma } from '../../lib/prisma';
import { chatComplete } from './coach';

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
    select: { title: true, titleLocked: true },
  });
  // ตั้งชื่อชั่วคราวจากข้อความแรกก่อน (จะได้มีชื่อทันที) — เดี๋ยว AI มาตั้งให้ดีกว่าทีหลัง
  const shouldRename = !session?.titleLocked && (!session?.title || session.title === 'แชทใหม่');
  await prisma.chatSession.update({
    where: { id: sessionId },
    data: shouldRename ? { title: titleFromMessage(userMessage) } : { updatedAt: new Date() },
  });
}

/**
 * ให้ AI อ่านบทสนทนาทั้งห้องแล้วตั้งชื่อที่สื่อความหมาย
 * เรียกแบบ fire-and-forget หลังตอบผู้ใช้ไปแล้ว (ไม่ให้ผู้ใช้รอ)
 * ทำเฉพาะตอนบทสนทนาเริ่มมีเนื้อหาพอ (4 ข้อความ) และซ้ำอีกครั้งตอนยาวขึ้น (12)
 */
export async function autoTitleSession(sessionId: string): Promise<void> {
  try {
    const session = await prisma.chatSession.findUnique({
      where: { id: sessionId },
      select: { titleLocked: true, _count: { select: { messages: true } } },
    });
    if (!session || session.titleLocked) return;

    const count = session._count.messages;
    if (count !== 4 && count !== 12) return; // ตั้งชื่อเฉพาะจังหวะที่กำหนด กันเรียก LLM ถี่เกิน

    const messages = await prisma.chatMessage.findMany({
      where: { sessionId },
      orderBy: { createdAt: 'asc' },
      take: 12,
      select: { role: true, content: true },
    });
    if (messages.length < 2) return;

    const transcript = messages
      .map((m) => `${m.role === 'user' ? 'ผู้ใช้' : 'พี่เงิน'}: ${m.content.slice(0, 300)}`)
      .join('\n');

    const out = await chatComplete(
      [
        {
          role: 'system',
          content:
            'ตั้งชื่อหัวข้อบทสนทนาให้สั้นกระชับเป็นภาษาไทย บอกว่าคุยเรื่องอะไร\n' +
            'กติกา: ยาวไม่เกิน 6 คำ · ห้ามใส่เครื่องหมายคำพูด · ห้ามขึ้นต้นว่า "บทสนทนาเรื่อง"\n' +
            'ตอบมาเฉพาะชื่อหัวข้อเท่านั้น ห้ามมีข้อความอื่น\n' +
            'ตัวอย่าง: วางแผนออมเงินซื้อโน้ตบุ๊ก / บันทึกค่ากาแฟรายวัน / สรุปรายจ่ายเดือนนี้',
        },
        { role: 'user', content: transcript.slice(0, 4000) },
      ],
      { temperature: 0.3, maxTokens: 60 },
    );
    if (!out?.text) return;

    // เก็บกวาดคำตอบ: ตัดอัญประกาศ/บรรทัดเกิน แล้วจำกัดความยาว
    const title = out.text
      .split('\n')[0]
      .replace(/^["'“”‘’\s]+|["'“”‘’\s.]+$/g, '')
      .slice(0, 60)
      .trim();
    if (title.length < 2) return;

    await prisma.chatSession.update({ where: { id: sessionId }, data: { title } });
  } catch (e) {
    // ตั้งชื่อไม่สำเร็จไม่ใช่เรื่องคอขาดบาดตาย — ใช้ชื่อจากข้อความแรกต่อไป
    console.warn('[sessions] ตั้งชื่อห้องอัตโนมัติไม่สำเร็จ:', (e as Error).message);
  }
}
