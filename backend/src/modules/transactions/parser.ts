import { prisma } from '../../lib/prisma';

const THAI_MONTHS: Record<string, number> = {
  "ม.ค.": 1, "ก.พ.": 2, "มี.ค.": 3, "เม.ย.": 4, "พ.ค.": 5, "มิ.ย.": 6,
  "ก.ค.": 7, "ส.ค.": 8, "ก.ย.": 9, "ต.ค.": 10, "พ.ย.": 11, "ธ.ค.": 12,
};

export function parseAmount(text: string): number | null {
  // 1) ยอดที่มีป้ายกำกับชัดเจน เช่น "จำนวนเงิน: 440.00"
  const labeled = text.match(/จำนวน(?:เงิน)?\s*(?::|：)?\s*([\d,]+\.\d{2})/);
  if (labeled) {
    return Math.round(parseFloat(labeled[1].replace(/,/g, "")) * 100);
  }
  // 2) รูปแบบ "440.00 บาท"
  const withBaht: number[] = [];
  for (const match of text.matchAll(/([\d,]+\.\d{2})\s*บาท/g)) {
    withBaht.push(Math.round(parseFloat(match[1].replace(/,/g, "")) * 100));
  }
  if (withBaht.length > 0) return Math.max(...withBaht);

  // 3) สำรอง — สลิปจ่ายบิล (ttb/ธนาคาร) โชว์ยอดลอย ๆ "440.00" ไม่มีคำว่า "บาท"/"จำนวนเงิน"
  //    เก็บทุกจำนวนรูปแบบ N.NN แล้วตัดค่าที่นำหน้าด้วย ค่าธรรมเนียม/ยอดคงเหลือ/ส่วนลด ออก → เอาค่ามากสุด
  const EXCLUDE = /(ค่าธรรมเนียม|ธรรมเนียม|ค่าบริการ|ยอดคงเหลือ|คงเหลือ|ส่วนลด|fee|balance|discount)[\s:：]*$/i;
  const candidates: number[] = [];
  for (const match of text.matchAll(/([\d,]+\.\d{2})/g)) {
    const idx = match.index ?? 0;
    const before = text.slice(Math.max(0, idx - 24), idx);
    if (EXCLUDE.test(before)) continue; // ข้ามค่าธรรมเนียม/ยอดคงเหลือ
    candidates.push(Math.round(parseFloat(match[1].replace(/,/g, "")) * 100));
  }
  return candidates.length > 0 ? Math.max(...candidates) : null;
}

export function parseDate(text: string): Date | null {
  const monthsPattern = Object.keys(THAI_MONTHS).map(k => k.replace(/\./g, "\\.")).join("|");
  const m1 = text.match(new RegExp(`(\\d{1,2})\\s*(${monthsPattern})\\s*(\\d{2,4})`));
  if (m1) {
    const day = parseInt(m1[1]);
    const month = THAI_MONTHS[m1[2]];
    let year = parseInt(m1[3]);
    if (year < 100) year += 2500;
    if (year > 2400) year -= 543;
    try {
      return new Date(Date.UTC(year, month - 1, day, 12, 0, 0));
    } catch {
      return null;
    }
  }
  const m2 = text.match(/(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})/);
  if (m2) {
    const day = parseInt(m2[1]);
    const month = parseInt(m2[2]);
    let year = parseInt(m2[3]);
    if (year < 100) year += 2500;
    if (year > 2400) year -= 543;
    try {
      return new Date(Date.UTC(year, month - 1, day, 12, 0, 0));
    } catch {
      return null;
    }
  }
  return null;
}

export function parseRef(text: string): string | null {
  const m = text.match(/(?:รหัสอ้างอิง|อ้างอิง|Ref\.?|เลขที่อ้างอิง|เลขที่รายการ|Transaction\s*(?:No\.?|ID)?)\s*(?::|：)?\s*([0-9A-Za-z]+)/i);
  if (m && m[1].length >= 6) {
    return m[1];
  }
  const tokens = text.match(/\b([0-9A-Za-z]{12,30})\b/g);
  if (tokens && tokens.length > 0) {
    return tokens[0];
  }
  return null;
}

/** ทำความสะอาดชื่อ: ตัดคำต่อท้ายที่ไม่ใช่ชื่อ + ปฏิเสธถ้าเป็นเลขบัญชี/รหัสล้วน */
function cleanName(raw: string): string | null {
  let v = raw
    // ตัดตรงจุดที่ขึ้นต้นด้วยเลขบัญชี/จำนวน/คีย์เวิร์ดอื่น
    .split(/\s+(?:x{2,}|X{2,}|\*{2,}|[0-9]{3,}|[0-9]-|จำนวน|บาท|เลขที่|รหัส|อ้างอิง|Ref|โอนเงิน|ธนาคาร|บันทึกช่วยจำ|วันที่|เวลา)/)[0]
    .trim();
  // ตัดเลขบัญชีแบบปิดบัง x-xxxx-x หรือเลขยาว ๆ ที่ติดมา
  v = v.replace(/[xX*]{1,}[-\dxX*]*/g, '').replace(/\b\d{4,}\b/g, '').replace(/\s{2,}/g, ' ').trim();
  if (v.length < 2) return null;
  const nonSpace = v.replace(/\s/g, '');
  const digits = (nonSpace.match(/\d/g) || []).length;
  if (digits >= nonSpace.length * 0.5) return null; // ส่วนใหญ่เป็นตัวเลข = น่าจะเป็นรหัส/เลขบัญชี ไม่เอา
  return v;
}

/**
 * ชื่อสำหรับโน้ต — เรียงความสำคัญ: บันทึกช่วยจำ (ผู้ใช้พิมพ์เอง) → ชื่อผู้รับเงิน → ชื่อบัญชีปลายทาง
 * ไม่เอารหัสใบเสร็จ/เลขอ้างอิง/เลขบัญชี
 */
export function parseMerchant(text: string): string | null {
  const patterns = [
    /(?:บันทึกช่วยจำ|memo|note)\s*(?::|：)?\s*(.+)/i,
    /(?:ชื่อผู้รับเงิน|ผู้รับเงิน|ชื่อผู้รับ|ผู้รับ|ไปยัง|โอนไปยัง|ถึง)\s*(?::|：)?\s*(.+)/,
    /(?:เข้าบัญชี|โอนเข้าบัญชี|ร้านค้า|บริษัท)\s*(?::|：)?\s*(.+)/,
  ];
  for (const re of patterns) {
    const m = text.match(re);
    if (m) {
      const name = cleanName(m[1]);
      if (name) return name;
    }
  }
  // สลิปจ่ายบิล (ttb/ธนาคาร): ชื่อผู้รับบิลมักอยู่หน้าเลข biller/ผู้เสียภาษีในวงเล็บ
  // เช่น "Banyabaramee (010753600031508)" / "TikTokShop Seller (010555609115221)"
  const biller = text.match(/([^\n()]{2,60}?)\s*\(\s*\d{10,17}\s*\)/);
  if (biller) {
    const name = cleanName(biller[1]);
    if (name) return name;
  }
  return null;
}

// ⚠️ ชื่อหมวด (key) ต้องตรงกับ Category.name ใน DB เป๊ะ ๆ (ดู prisma/seed.ts)
// เรียงหมวด "เฉพาะเจาะจง/ดักง่าย" ไว้ก่อน (Cafe/Fuel/Debt/Housing) กันชนกับหมวดกว้าง (Food/Transport/Shopping)
// autoCategorize เลือกเฉพาะหมวดที่ type ตรงกัน → keyword รายรับ/รายจ่ายอยู่รวมกันได้
const CATEGORY_KEYWORDS: Record<string, string[]> = {
  // ── รายจ่าย: เฉพาะเจาะจงก่อน ──
  "Debt": ["ค่างวด", "งวดรถ", "งวดบ้าน", "งวดมือถือ", "งวดโทรศัพท์", "ผ่อนรถ", "ผ่อนบ้าน", "ผ่อน", "หนี้", "กยศ", "สินเชื่อ", "กู้", "ดอกเบี้ย"],
  "Housing": ["ค่าเช่า", "ค่าห้อง", "ค่าหอ", "หอพัก", "ค่าคอนโด", "ค่าบ้าน", "ที่พักรายเดือน"],
  "MobileInternet": ["ค่าเน็ต", "ค่าไวไฟ", "wifi", "ค่าโทรศัพท์", "ค่าโทร", "ค่ามือถือ", "แพ็กเกจเน็ต", "เติมเงินมือถือ", "ais", "dtac", "ทรูมูฟ", "truemove"],
  "Subscription": ["netflix", "spotify", "youtube premium", "disney", "icloud", "prime video", "ค่าสมาชิก", "สมาชิกรายเดือน", "subscription"],
  "Bills": ["ค่าไฟ", "ค่าไฟฟ้า", "ค่าน้ำ", "ค่าประปา", "การไฟฟ้า", "การประปา", "ค่าส่วนกลาง", "ค่าขยะ"],
  "Fuel": ["น้ำมัน", "เติมน้ำมัน", "ปตท", "ptt", "shell", "esso", "เอสโซ่", "caltex", "บางจาก", "เบนซิน", "ดีเซล", "แก๊สรถ"],
  "Cafe": ["กาแฟ", "coffee", "คาเฟ่", "cafe", "ชาไข่มุก", "ชานม", "อเมซอน", "amazon coffee", "starbucks", "สตาร์บัค", "เครื่องดื่ม", "ชาเขียว", "โกโก้", "น้ำผลไม้"],
  "Groceries": ["ของใช้", "ซูเปอร์", "supermarket", "บิ๊กซี", "โลตัส", "แม็คโคร", "makro", "tops", "villa", "ยาสีฟัน", "สบู่", "แชมพู", "ทิชชู", "ผงซักฟอก", "ของเข้าบ้าน"],
  "Fitness": ["ฟิตเนส", "gym", "ยิม", "ออกกำลังกาย", "โยคะ", "yoga", "ว่ายน้ำ", "แบดมินตัน", "ตีแบด", "ฟุตบอล"],
  "Beauty": ["ทำผม", "ตัดผม", "ทำเล็บ", "สปา", "spa", "เสริมสวย", "เครื่องสำอาง", "สกินแคร์", "ครีมบำรุง", "นวดหน้า"],
  "Health": ["โรงพยาบาล", "รพ.", "คลินิก", "หาหมอ", "ค่ายา", "ซื้อยา", "pharmacy", "ร้านยา", "watson", "วัตสัน", "boots", "ตรวจสุขภาพ", "ทำฟัน", "หมอฟัน"],
  "Education": ["ค่าเทอม", "ค่าหน่วยกิต", "หนังสือเรียน", "คอร์สเรียน", "เรียนพิเศษ", "ติว", "ค่าอบรม", "สอบ"],
  "Insurance": ["ประกันชีวิต", "ประกันรถ", "ประกันสุขภาพ", "เบี้ยประกัน", "ค่าประกัน"],
  "Pet": ["สัตว์เลี้ยง", "อาหารหมา", "อาหารแมว", "ค่าหมอสัตว์", "โรงพยาบาลสัตว์", "ทรายแมว"],
  "Gift": ["ของขวัญ", "บริจาค", "ทำบุญ", "ซองงาน", "ของฝาก", "ใส่ซอง"],
  "Family": ["ให้พ่อ", "ให้แม่", "ให้ที่บ้าน", "ค่าเลี้ยงดู", "ส่งเงินให้พ่อแม่"],
  "Savings": ["ออมเงิน", "เงินออม", "ลงทุน", "ซื้อหุ้น", "กองทุน", "ฝากประจำ", "dca"],
  "Travel": ["ท่องเที่ยว", "ไปเที่ยว", "ทริป", "ตั๋วเครื่องบิน", "โรงแรม", "ที่พักต่างจังหวัด", "รีสอร์ท"],
  "Transport": ["bts", "mrt", "วินมอเตอร์ไซค์", "แท็กซี่", "taxi", "grab", "แกร็บ", "bolt", "ทางด่วน", "ค่ารถ", "ค่าเดินทาง", "ค่าโดยสาร", "รถเมล์", "รถไฟฟ้า", "ค่าทางด่วน"],
  "Entertainment": ["โรงหนัง", "ดูหนัง", "major", "sf cinema", "คาราโอเกะ", "เหล้า", "เบียร์", "ผับ", "บาร์", "คอนเสิร์ต", "เกม", "steam", "playstation"],
  "Shopping": ["shopee", "ชอปปี้", "ช้อปปี้", "lazada", "ลาซาด้า", "tiktok shop", "เสื้อผ้า", "รองเท้า", "กระเป๋า", "ห้าง", "central", "uniqlo", "zara", "h&m", "gadget"],
  "Food": ["ข้าว", "ก๋วยเตี๋ยว", "ก๋วยจั๊บ", "ส้มตำ", "ชาบู", "หมูกระทะ", "กะเพรา", "ข้าวมันไก่", "sushi", "ซูชิ", "ร้านอาหาร", "อาหาร", "kfc", "แมค", "mcdonald", "พิซซ่า", "ข้าวเที่ยง", "ข้าวเย็น", "ข้าวเช้า", "โจ๊ก", "ส่งข้าว"],
  // ── รายรับ ──
  "Salary": ["เงินเดือน", "salary", "paycheck"],
  "Bonus": ["โบนัส", "bonus"],
  "Freelance": ["ฟรีแลนซ์", "freelance", "รับจ้าง", "รับงาน", "งานนอก"],
  "PartTime": ["พาร์ทไทม์", "part-time", "parttime", "งานพิเศษ"],
  "Business": ["ค้าขาย", "ขายของ", "ขายได้", "ยอดขาย", "กำไรร้าน"],
  "Investment": ["ดอกเบี้ย", "ปันผล", "dividend", "ผลตอบแทน", "กำไรหุ้น", "ขายหุ้น"],
  "Allowance": ["ค่าขนม", "ครอบครัวให้", "เงินจากพ่อแม่", "พ่อแม่ให้"],
  "Refund": ["เงินคืน", "เงินทอน", "refund", "คืนเงิน", "cashback", "แคชแบ็ก"],
};

export async function autoCategorize(
  text: string,
  merchant: string,
  type: 'income' | 'expense',
  userId?: string,
  customFallback?: string, // หมวดสำรองเฉพาะกรณี เช่น ใบเสร็จร้านค้า → Groceries
): Promise<string | null> {
  // User Correction Learning: check past transactions for this user with same merchant
  if (userId && merchant) {
    const cleanMerchant = merchant.trim();
    if (cleanMerchant) {
      const lastTxn = await prisma.transaction.findFirst({
        where: {
          userId,
          type,
          note: {
            contains: cleanMerchant,
          },
          categoryId: { not: null },
        },
        orderBy: { occurredAt: 'desc' },
        select: { categoryId: true },
      });
      if (lastTxn && lastTxn.categoryId) {
        return lastTxn.categoryId;
      }
    }
  }

  const cleanText = text.replace(/อยุธยา/g, "").replace(/ธนาคาร/g, "");
  const queryText = `${cleanText} ${merchant}`.toLowerCase();
  
  for (const [catName, keywords] of Object.entries(CATEGORY_KEYWORDS)) {
    for (const kw of keywords) {
      if (queryText.includes(kw.toLowerCase())) {
        const cat = await prisma.category.findFirst({ where: { name: catName, type } });
        if (cat) return cat.id;
      }
    }
  }
  
  // ⭐ ไม่แมตช์ keyword → หมวด "อื่นๆ" (ไม่ใช่ 'Food') เพื่อไม่ให้เดาผิดเป็นอาหารทุกอย่าง
  // (customFallback ใช้กับใบเสร็จร้านค้า → Groceries แทน)
  const fallbackName = customFallback ?? (type === 'income' ? 'OtherIncome' : 'OtherExpense');
  const defaultCat = await prisma.category.findFirst({ where: { name: fallbackName, type } });
  return defaultCat ? defaultCat.id : null;
}
