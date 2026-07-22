import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

// หมวดหมู่ครบทุกด้าน — ครอบคลุมตั้งแต่วัยรุ่น (ค่าขนม/คาเฟ่/เรียน/เกม) ถึงคนทำงาน (ค่าเช่า/ประกัน/ผ่อน/ลงทุน)
// upsert ด้วย name_type → รันซ้ำได้ ของเดิมไม่เปลี่ยน (ห้ามแก้ name เดิม เพราะ autoCategorize อ้างถึง)
const categories = [
  // ── รายจ่าย ──────────────────────────────────────────────
  { name: 'Food', nameTh: 'อาหาร', icon: '🍜', color: '#FF6B6B', type: 'expense' },
  { name: 'Cafe', nameTh: 'คาเฟ่/เครื่องดื่ม', icon: '☕', color: '#C08457', type: 'expense' },
  { name: 'Groceries', nameTh: 'ของใช้/ซูเปอร์', icon: '🛒', color: '#F59F00', type: 'expense' },
  { name: 'Shopping', nameTh: 'ช้อปปิ้ง', icon: '🛍️', color: '#845EF7', type: 'expense' },
  { name: 'Transport', nameTh: 'เดินทาง', icon: '🚗', color: '#4DABF7', type: 'expense' },
  { name: 'Fuel', nameTh: 'น้ำมันรถ', icon: '⛽', color: '#495057', type: 'expense' },
  { name: 'Bills', nameTh: 'บิล/ค่าบริการ', icon: '🧾', color: '#FFA94D', type: 'expense' },
  { name: 'MobileInternet', nameTh: 'มือถือ/เน็ต', icon: '📱', color: '#3BC9DB', type: 'expense' },
  { name: 'Housing', nameTh: 'ที่พัก/ค่าเช่า', icon: '🏠', color: '#F76707', type: 'expense' },
  { name: 'Entertainment', nameTh: 'บันเทิง/เกม', icon: '🎮', color: '#F783AC', type: 'expense' },
  { name: 'Subscription', nameTh: 'ค่าสมาชิก/แอป', icon: '💳', color: '#E64980', type: 'expense' },
  { name: 'Education', nameTh: 'การศึกษา/เรียน', icon: '📚', color: '#4C6EF5', type: 'expense' },
  { name: 'Health', nameTh: 'สุขภาพ', icon: '💊', color: '#69DB7C', type: 'expense' },
  { name: 'Fitness', nameTh: 'ออกกำลังกาย/กีฬา', icon: '🏋️', color: '#40C057', type: 'expense' },
  { name: 'Beauty', nameTh: 'ความงาม/เสริมสวย', icon: '💅', color: '#FAA2C1', type: 'expense' },
  { name: 'Travel', nameTh: 'ท่องเที่ยว', icon: '✈️', color: '#22B8CF', type: 'expense' },
  { name: 'Family', nameTh: 'ครอบครัว/พ่อแม่', icon: '👨‍👩‍👧', color: '#FF922B', type: 'expense' },
  { name: 'Pet', nameTh: 'สัตว์เลี้ยง', icon: '🐾', color: '#94D82D', type: 'expense' },
  { name: 'Gift', nameTh: 'ของขวัญ/บริจาค', icon: '🎁', color: '#FF8787', type: 'expense' },
  { name: 'Insurance', nameTh: 'ประกัน', icon: '🛡️', color: '#748FFC', type: 'expense' },
  { name: 'Savings', nameTh: 'ออมเงิน/ลงทุน', icon: '🏦', color: '#12B886', type: 'expense' },
  { name: 'Debt', nameTh: 'ผ่อน/หนี้', icon: '💸', color: '#FA5252', type: 'expense' },
  { name: 'OtherExpense', nameTh: 'อื่น ๆ', icon: '📌', color: '#868E96', type: 'expense' },
  // ── รายรับ ───────────────────────────────────────────────
  { name: 'Salary', nameTh: 'เงินเดือน', icon: '💰', color: '#37B24D', type: 'income' },
  { name: 'Freelance', nameTh: 'ฟรีแลนซ์/รับจ้าง', icon: '💻', color: '#4DABF7', type: 'income' },
  { name: 'PartTime', nameTh: 'งานพาร์ทไทม์', icon: '⏰', color: '#7950F2', type: 'income' },
  { name: 'Bonus', nameTh: 'โบนัส', icon: '🎉', color: '#F59F00', type: 'income' },
  { name: 'Business', nameTh: 'ค้าขาย/ธุรกิจ', icon: '🏪', color: '#E8590C', type: 'income' },
  { name: 'Investment', nameTh: 'ผลตอบแทน/ดอกเบี้ย', icon: '📈', color: '#0CA678', type: 'income' },
  { name: 'Allowance', nameTh: 'ค่าขนม/ครอบครัวให้', icon: '🧧', color: '#FF6B6B', type: 'income' },
  { name: 'Refund', nameTh: 'เงินคืน/เงินทอน', icon: '↩️', color: '#15AABF', type: 'income' },
  { name: 'OtherIncome', nameTh: 'รายได้อื่น', icon: '✨', color: '#20C997', type: 'income' },
];

async function main() {
  for (const c of categories) {
    await prisma.category.upsert({
      where: { name_type: { name: c.name, type: c.type } },
      update: {},
      create: c,
    });
  }

  const email = 'demo@bestimove.ai';
  const user = await prisma.user.upsert({
    where: { email },
    update: {},
    create: {
      email,
      passwordHash: await bcrypt.hash('demo1234', 10),
      displayName: 'สมชาย (Demo)',
      monthlyIncome: 2_500_000, // 25,000 ฿
    },
  });

  const existing = await prisma.transaction.count({ where: { userId: user.id } });
  if (existing === 0) {
    const cat = async (name: string) =>
      (await prisma.category.findFirst({ where: { name, type: 'expense' } }))?.id;
    const samples = [
      { type: 'income', amount: 2_500_000, note: 'เงินเดือน', source: 'manual', categoryId: undefined },
      { type: 'expense', amount: 650_000, note: 'ข้าวเที่ยง + กาแฟ', source: 'manual', categoryId: await cat('Food') },
      { type: 'expense', amount: 420_000, note: 'Shopee', source: 'ocr', categoryId: await cat('Shopping') },
      { type: 'expense', amount: 350_000, note: 'BTS + วิน', source: 'manual', categoryId: await cat('Transport') },
    ];
    for (const s of samples) {
      await prisma.transaction.create({ data: { userId: user.id, ...s } });
    }
  }

  console.log(`✅ Seed complete: ${categories.length} categories · demo user ${email} / demo1234`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
