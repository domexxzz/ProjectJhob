import type { ChatTurn } from './coach';

export type FinanceScopeReason = 'finance' | 'financial_follow_up' | 'social' | 'out_of_scope';

export interface FinanceScopeDecision {
  allowed: boolean;
  reason: FinanceScopeReason;
}

/** คำตอบคงที่จาก server เพื่อไม่ให้โมเดลถูกชักจูงให้ออกนอกขอบเขต */
export const OUT_OF_SCOPE_REPLY =
  'ขอโทษนะครับ พี่เงินให้คำปรึกษาเฉพาะเรื่องการเงินส่วนบุคคลแบบครบวงจร เช่น รายรับ–รายจ่าย การออม งบประมาณ หนี้ ภาษี ประกัน การลงทุน และการวางแผนเกษียณ 💰\n\nลองเล่าเป้าหมายหรือปัญหาการเงินที่อยากจัดการได้เลยครับ';

const FINANCE_PATTERNS: RegExp[] = [
  // "เงิน" เป็นภาษาธรรมชาติที่ผู้ใช้ใช้ปรึกษาปัญหาชีวิต ไม่ควรบังคับให้ใช้ศัพท์การเงิน
  /เงิน|การเงิน|วางแผนเงิน|บริหารเงิน|สุขภาพทางการเงิน|financial|personal finance/i,
  /เงินเดือน|รายได้|รายรับ|รายจ่าย|ใช้จ่าย|ค่าใช้จ่าย|ค่าครองชีพ|เกินตัว|ฟุ่มเฟือย|ช้อปเพลิน|กระแสเงินสด|cash\s*flow|income|expense|spending/i,
  /แบ่งค่าใช้จ่าย|หารค่าใช้จ่าย|ค่าใช้จ่าย.*(?:แฟน|คู่รัก|ครอบครัว)|(?:แฟน|คู่รัก|ครอบครัว).*ค่าใช้จ่าย/i,
  /งบประมาณ|ตั้งงบ|เกินงบ|budget/i,
  /ออม|เก็บเงิน|เงินสำรอง|เงินฉุกเฉิน|บัญชีออมทรัพย์|saving|emergency fund/i,
  /ลงทุน|หุ้น|กองทุน|พันธบัตร|ตราสารหนี้|คริปโต|ทองคำ|พอร์ต|dca|ผลตอบแทน|ปันผล|ความเสี่ยง|investment|stock|fund|portfolio|return/i,
  /หนี้|เจ้าหนี้|ลูกหนี้|ดอกเบี้ย|กู้|สินเชื่อ|ผ่อน|รีไฟแนนซ์|บัตรเครดิต|เครดิตบูโร|snowball|avalanche|debt|loan|interest|credit card/i,
  /ภาษี|ลดหย่อน|สรรพากร|tax/i,
  /ประกัน|เบี้ยประกัน|ความคุ้มครอง|insurance/i,
  /เกษียณ|บำนาญ|กองทุนสำรองเลี้ยงชีพ|ประกันสังคม|retire|pension/i,
  /ซื้อบ้าน|ผ่อนบ้าน|ซื้อรถ|ผ่อนรถ|ดาวน์บ้าน|ดาวน์รถ|ค่าเช่า|mortgage/i,
  /บัญชี|ธนาคาร|ธุรกรรม|โอนเงิน|ชำระเงิน|สลิป|ใบเสร็จ|statement|transaction|bank|receipt/i,
  /เป้าหมายการเงิน|เป้าหมายออม|goal.*(?:money|saving|finance)/i,
  /สมาชิก|ค่าสมาชิก|subscription/i,
  /มรดก|พินัยกรรม|วางแผนทรัพย์สิน|estate planning/i,
  /เงินเฟ้อ|อัตราแลกเปลี่ยน|สกุลเงิน|inflation|exchange rate|currency/i,
  /มิจฉาชีพ.*เงิน|หลอกโอน|โกงเงิน|บัญชีม้า|financial fraud|scam/i,
  /กำไร|ขาดทุน|ต้นทุน|คุ้มทุน|profit|loss|cost|break.?even/i,
  /50\s*\/\s*30\s*\/\s*20|fire movement|net worth|สินทรัพย์|หนี้สิน|ความมั่งคั่ง|wealth|roi|cagr/i,
];

const EXPLICIT_NON_FINANCE_PATTERNS: RegExp[] = [
  /สูตรอาหาร|ทำอาหาร|เมนูอาหาร|recipe/i,
  /เขียนเกม|เล่นเกม|game walkthrough/i,
  /การบ้าน(?:คณิต|ฟิสิกส์|เคมี|ชีวะ|ประวัติศาสตร์)|โจทย์ฟิสิกส์|โจทย์เคมี/i,
  /ดูดวง|ทำนายดวง|horoscope|astrology/i,
  /แต่งเพลง|เนื้อเพลง|รีวิวหนัง|เรื่องย่อหนัง/i,
  /แปลภาษา|translate/i,
  /พยากรณ์อากาศ|อากาศวันนี้|weather/i,
  /วางแผนเที่ยว|สถานที่ท่องเที่ยว|ร้านอาหารแนะนำ|travel itinerary/i,
  /เขียนโค้ด|แก้บั๊ก|สร้างเว็บไซต์|สร้างแอป|programming/i,
];

const SOCIAL_OR_CAPABILITY =
  /^(?:สวัสดี(?:ครับ|ค่ะ)?|หวัดดี|ดีครับ|ดีค่ะ|hello|hi|hey|ขอบคุณ(?:ครับ|ค่ะ)?|โอเค|ตกลง|ได้เลย|คุณคือใคร|พี่เงินคือใคร|(?:คุณ|พี่เงิน)?ช่วยอะไรได้บ้าง|(?:คุณ|พี่เงิน)?ทำอะไรได้บ้าง)[\s!?.ๆ]*$/i;

const FOLLOW_UP =
  /(?:อธิบายเพิ่ม|ขอรายละเอียด|ขอตัวอย่าง|ช่วยคำนวณ|คำนวณให้|เปรียบเทียบ|ทำไม|ยังไง|ต่อเลย|แล้วต่อ|แบบไหนดี|เท่าไหร่|หมายความว่า|ถ้าอย่างนั้น|กรณีนี้|ข้อความเปิดใจ|ร่างข้อความ|ประโยคเริ่มคุย|พูดยังไงดี|ตอบยังไงดี|ตามที่บอก|ที่แนะนำ|ที่เสนอ|เมื่อกี้|ก่อนหน้า|เรื่องนี้|อันนี้|ขอแบบ|เอาแบบ|ไฟล์|pdf|google\s*doc|word|docx|excel|xlsx|xml|ส่งออก|ดาวน์โหลด)/i;

export function hasFinanceIntent(text: string): boolean {
  const normalized = text.trim();
  return normalized.length > 0 && FINANCE_PATTERNS.some((pattern) => pattern.test(normalized));
}

function hasExplicitNonFinanceIntent(text: string): boolean {
  return EXPLICIT_NON_FINANCE_PATTERNS.some((pattern) => pattern.test(text));
}

function historyHasFinanceContext(history: ChatTurn[]): boolean {
  return history
    .slice(-12)
    .some((turn) => turn.role === 'user' && hasFinanceIntent(turn.content));
}

/**
 * ประตูก่อนเรียก LLM: อนุญาตเรื่องการเงิน, บทสนทนาสังคมสั้น ๆ และคำถามต่อเนื่อง
 * ที่มีบริบทการเงินเท่านั้น ส่วนคำถามทั่วไปให้ server ปฏิเสธทันที
 */
export function checkFinanceScope(
  message: string,
  history: ChatTurn[] = [],
  ocrText?: string,
): FinanceScopeDecision {
  const combined = `${message}\n${ocrText ?? ''}`.trim();

  if (hasFinanceIntent(combined)) return { allowed: true, reason: 'finance' };

  // รูปที่ไม่มีร่องรอยข้อมูลการเงินไม่ควรถูกส่งต่อให้โมเดลวิเคราะห์เรื่องทั่วไป
  if (ocrText) return { allowed: false, reason: 'out_of_scope' };

  if (SOCIAL_OR_CAPABILITY.test(message.trim())) return { allowed: true, reason: 'social' };

  if (
    message.length <= 160 &&
    !hasExplicitNonFinanceIntent(message) &&
    FOLLOW_UP.test(message) &&
    historyHasFinanceContext(history)
  ) {
    return { allowed: true, reason: 'financial_follow_up' };
  }

  return { allowed: false, reason: 'out_of_scope' };
}
