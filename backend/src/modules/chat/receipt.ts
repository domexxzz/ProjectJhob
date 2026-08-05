/**
 * แยกรายการสินค้าจากใบเสร็จ (OCR แล้ว) → สร้างหลาย transaction + การ์ดหลายใบ
 * ใบเสร็จมีรูปแบบหลากหลายมาก จึงใช้ LLM แตกเป็น JSON แทน regex (ทนกว่า)
 */
import { chatComplete } from './coach';
import { quickCreate, TxnCard } from './tools';

export interface ReceiptItem {
  name: string;
  priceBaht: number;
}

const SYSTEM_PROMPT = `คุณคือตัวแยกรายการสินค้าจากใบเสร็จ/สลิปที่ผ่าน OCR มา
งานของคุณ: ดึง "รายการสินค้าแต่ละชิ้น" พร้อมราคา (บาท) ออกมาเป็น JSON เท่านั้น
รูปแบบผลลัพธ์: {"items":[{"name":"ชื่อสินค้า","price":ราคาบาทเป็นตัวเลข}, ...]}
กฎสำคัญ:
- เอาเฉพาะ "รายการสินค้าจริง" — ตัดบรรทัดพวก ยอดรวม, รวมทั้งสิ้น, total, subtotal, ภาษีมูลค่าเพิ่ม, vat, เงินสด, รับเงิน, เงินทอน, change, ส่วนลด, discount ทิ้งทั้งหมด
- price = ราคาต่อรายการหน่วยบาท เป็นตัวเลขล้วน (ถ้ามีจำนวน x ราคา ให้ใช้ราคารวมของรายการนั้น)
- ถ้าอ่านชื่อไม่ชัดให้เดาที่ใกล้เคียงสุด แต่ราคาต้องมาจากตัวเลขจริงในใบเสร็จ
- ถ้าไม่ใช่ใบเสร็จที่มีหลายรายการ (เช่นเป็นสลิปโอนเงินยอดเดียว) ให้คืน {"items":[]}
- ตอบ JSON อย่างเดียว ห้ามมีข้อความอื่น ห้ามมี markdown`;

/** แตก OCR text ของใบเสร็จเป็นรายการสินค้า — คืน [] ถ้าไม่ใช่ใบเสร็จหลายรายการ */
export async function extractReceiptItems(ocrText: string): Promise<ReceiptItem[]> {
  if (!ocrText || ocrText.trim().length < 10) return [];
  const out = await chatComplete(
    [
      { role: 'system', content: SYSTEM_PROMPT },
      { role: 'user', content: ocrText.slice(0, 6000) },
    ],
    { temperature: 0.1, maxTokens: 1200 },
  );
  if (!out) return [];
  return parseItems(out.text);
}

/** ดึง JSON ออกจากคำตอบ LLM แบบทนทาน (รอดจาก code fence / ข้อความปน) */
function parseItems(text: string): ReceiptItem[] {
  const start = text.indexOf('{');
  const end = text.lastIndexOf('}');
  if (start < 0 || end <= start) return [];
  try {
    const obj = JSON.parse(text.slice(start, end + 1));
    const arr = Array.isArray(obj.items) ? obj.items : [];
    return arr
      .map((it: { name?: unknown; price?: unknown }) => ({
        name: String(it.name ?? '').trim().slice(0, 60),
        priceBaht:
          typeof it.price === 'number'
            ? it.price
            : Number(String(it.price ?? '').replace(/,/g, '')),
      }))
      .filter((it: ReceiptItem) => it.name.length > 0 && Number.isFinite(it.priceBaht) && it.priceBaht > 0)
      .slice(0, 40); // กันใบเสร็จยาวผิดปกติ
  } catch {
    return [];
  }
}

// ── ตัวตรวจ "เอกสารสัญญา/ซื้อรถ/เช่าซื้อ" — ไม่ใช่ใบเสร็จซื้อของ ห้ามแตกรายการ ──
const CONTRACT_HINT =
  /สัญญา|เช่าซื้อ|ใบซื้อขาย|ใบรับรถ|เงินดาวน์|ดาวน์|ยอดคงเหลือ|ราคาเต็ม|เลขตัวรถ|เลขเครื่อง|ผู้เช่าซื้อ|ผู้ค้ำประกัน|งวดละ|ผ่อน.*งวด|ทะเบียนรถ/;

export interface ContractInfo {
  isContract: boolean;
  downPaymentBaht: number | null; // เงินที่จ่ายวันนี้/เงินดาวน์ (อ่านคร่าว ๆ อาจเพี้ยน)
  vehicle: string | null;
}

const CONTRACT_SYSTEM = `คุณคือตัวช่วยอ่านเอกสารการเงินที่ผ่าน OCR มา
ถ้าข้อความเป็น "เอกสารสัญญา/ใบซื้อขาย/เช่าซื้อ ยานพาหนะหรือทรัพย์สิน" (มีราคาเต็ม เงินดาวน์ ยอดคงเหลือ หรือการผ่อนงวด) ให้คืน JSON:
{"isContract":true,"downPaymentBaht":ตัวเลขเงินดาวน์หรือเงินที่จ่ายวันนี้ (หน่วยบาท ถ้าหาไม่เจอใส่ null),"vehicle":"ยี่ห้อ/ประเภทรถ ถ้ามี ไม่มีใส่ null"}
ถ้าเป็นใบเสร็จซื้อของทั่วไปหรือเอกสารอื่น คืน {"isContract":false,"downPaymentBaht":null,"vehicle":null}
ตอบ JSON อย่างเดียว ห้ามมีข้อความอื่น`;

/** ตรวจว่า OCR เป็นเอกสารสัญญา/ซื้อรถหรือไม่ — regex gate ก่อน (ไม่เข้าเงื่อนไข = ไม่เรียก LLM) */
export async function analyzeContract(ocrText: string): Promise<ContractInfo> {
  const none: ContractInfo = { isContract: false, downPaymentBaht: null, vehicle: null };
  if (!ocrText || !CONTRACT_HINT.test(ocrText)) return none;

  const out = await chatComplete(
    [
      { role: 'system', content: CONTRACT_SYSTEM },
      { role: 'user', content: ocrText.slice(0, 6000) },
    ],
    { temperature: 0.1, maxTokens: 300 },
  );
  if (!out) return { ...none, isContract: true }; // เจอ keyword แต่ LLM ล่ม → ยังถือว่าเป็นสัญญา (กันแตกรายการ)

  const start = out.text.indexOf('{');
  const end = out.text.lastIndexOf('}');
  if (start < 0 || end <= start) return { ...none, isContract: true };
  try {
    const obj = JSON.parse(out.text.slice(start, end + 1));
    if (!obj.isContract) return none;
    const amt = typeof obj.downPaymentBaht === 'number'
      ? obj.downPaymentBaht
      : Number(String(obj.downPaymentBaht ?? '').replace(/,/g, ''));
    return {
      isContract: true,
      downPaymentBaht: Number.isFinite(amt) && amt > 0 ? amt : null,
      vehicle: obj.vehicle ? String(obj.vehicle).slice(0, 40) : null,
    };
  } catch {
    return { ...none, isContract: true };
  }
}

/** สร้าง transaction ต่อ 1 รายการสินค้า (เป็นรายจ่าย) → คืนการ์ดที่สร้างสำเร็จ */
export async function logReceiptItems(userId: string, items: ReceiptItem[]): Promise<TxnCard[]> {
  const cards: TxnCard[] = [];
  for (const it of items) {
    // สินค้าจากใบเสร็จร้านค้า: ถ้า keyword ไม่แมตช์ ให้ตกเป็น "ของใช้/ซูเปอร์" แทน "อื่นๆ"
    const card = await quickCreate(userId, {
      type: 'expense',
      amountBaht: it.priceBaht,
      note: it.name,
      fallbackCategory: 'Groceries',
    });
    if (card) cards.push(card);
  }
  return cards;
}
