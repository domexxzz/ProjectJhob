#!/usr/bin/env python3
"""OCR slip parser spike (Sprint 1, P3).

เป้า: พิสูจน์ว่า parse ฟิลด์สำคัญ (จำนวนเงิน/วันที่/เลขอ้างอิง/ร้าน) จากข้อความสลิปได้แม่นแค่ไหน.
ส่วนที่ยากจริง = "ตรรกะ parse" ไม่ใช่ตัว OCR.

โปรดักชัน OCR = Google ML Kit (on-device, ใน Flutter). สคริปต์นี้เสียบ OCR engine อะไรก็ได้.
  --demo       : รัน parser บนข้อความสลิปตัวอย่าง (PromptPay) — stdlib ล้วน ไม่ต้องลงอะไร
  --image PATH : OCR รูปจริงด้วย pytesseract (ต้องลง tesseract + ภาษาไทย 'tha') แล้ว parse
"""
import argparse
import json
import re
import sys
from datetime import datetime

SAMPLE_SLIP = """
ธนาคารกสิกรไทย
โอนเงินสำเร็จ
20 มิ.ย. 67 14:32 น.
จาก นาย ก. xxx-x-x1234-x
ไปยัง ร้านอาหารตามสั่ง
จำนวน 120.00 บาท
ค่าธรรมเนียม 0.00 บาท
รหัสอ้างอิง 015220062714320012345
"""

THAI_MONTHS = {
    "ม.ค.": 1, "ก.พ.": 2, "มี.ค.": 3, "เม.ย.": 4, "พ.ค.": 5, "มิ.ย.": 6,
    "ก.ค.": 7, "ส.ค.": 8, "ก.ย.": 9, "ต.ค.": 10, "พ.ย.": 11, "ธ.ค.": 12,
}


def parse_amount(text: str):
    m = re.search(r"จำนวน(?:เงิน)?\s*(?::|：)?\s*([\d,]+\.\d{2})", text)
    if m:
        return float(m.group(1).replace(",", ""))
    amts = [float(a.replace(",", "")) for a in re.findall(r"([\d,]+\.\d{2})\s*บาท", text)]
    return max(amts) if amts else None


def parse_date(text: str):
    months = "|".join(re.escape(k) for k in THAI_MONTHS)
    m = re.search(rf"(\d{{1,2}})\s*({months})\s*(\d{{2,4}})", text)
    if not m:
        m2 = re.search(r"(\d{1,2})[/\-](\d{1,2})[/\-](\d{2,4})", text)
        if m2:
            day, mon, year = int(m2.group(1)), int(m2.group(2)), int(m2.group(3))
        else:
            return None
    else:
        day, mon, year = int(m.group(1)), THAI_MONTHS[m.group(2)], int(m.group(3))
    
    if year < 100:
        year += 2500          # พ.ศ. 2 หลัก -> 25xx
    if year > 2400:
        year -= 543           # พ.ศ. -> ค.ศ.
    try:
        return datetime(year, mon, day).date().isoformat()
    except ValueError:
        return None


def parse_ref(text: str):
    m = re.search(r"(?:รหัสอ้างอิง|อ้างอิง|Ref\.?|เลขที่อ้างอิง|เลขที่รายการ|Transaction\s*(?:No\.?|ID)?)\s*(?::|：)?\s*([0-9A-Za-z]+)", text, re.IGNORECASE)
    if m:
        ref_val = m.group(1).strip()
        if len(ref_val) >= 6:
            return ref_val
    tokens = re.findall(r"\b([0-9A-Za-z]{12,30})\b", text)
    if tokens:
        return tokens[0]
    return None


def parse_merchant(text: str):
    m = re.search(r"(?:ไปยัง|โอนไปยัง|เข้าบัญชี|โอนเข้าบัญชี|ร้านค้า|บริษัท)\s*(?::|：)?\s*(.+)", text)
    if m:
        val = m.group(1).strip()
        val = re.split(r"\s+(?:xxx-|[0-9]{3}-|จำนวน|บาท|โอนเงิน|ธนาคาร|เข้าบัญชี|ไปยัง)", val)[0]
        return val.strip()
    return None


CATEGORY_KEYWORDS = {
    "Food": ["ร้านอาหาร", "ส้มตำ", "ชาบู", "กะเพรา", "กาแฟ", "cafe", "coffee", "7-Eleven", "เซเว่น", "food", "ก๋วยเตี๋ยว", "ชาไข่มุก", "sushi", "หมูกระทะ", "อร่อย"],
    "Shopping": ["Shopee", "Lazada", "TikTok Shop", "เสื้อผ้า", "ห้าง", "Mall", "fashion", "gadget", "Uniqlo", "Zara", "H&M"],
    "Transport": ["BTS", "MRT", "วินมอเตอร์ไซค์", "แท็กซี่", "taxi", "Grab", "Bolt", "น้ำมัน", "ปตท", "shell", "caltex", "ทางด่วน", "ตั๋วเครื่องบิน"],
    "Bills": ["การไฟฟ้า", "การประปา", "อินเทอร์เน็ต", "AIS", "True", "DTAC", "Netflix", "Spotify", "บัตรเครดิต"],
    "Entertainment": ["โรงหนัง", "Major", "SF Cinema", "คาราโอเกะ", "เหล้า", "เบียร์", "ผับ", "บาร์", "concert", "เกม", "Steam", "PlayStation"],
    "Health": ["โรงพยาบาล", "คลินิก", "ยา", "pharmacy", "Watson", "Boots", "ฟิตเนส", "gym"],
    "Salary": ["เงินเดือน", "salary", "paycheck"],
}


def auto_categorize(text: str, merchant: str) -> str:
    # Clean bank names to prevent false positives (e.g., 'อยุธยา' matching 'ยา' under Health)
    clean_text = text.replace("อยุธยา", "").replace("ธนาคาร", "")
    query = f"{clean_text} {merchant}".lower()
    for cat, keywords in CATEGORY_KEYWORDS.items():
        for kw in keywords:
            if kw.lower() in query:
                return cat
    return "Food"


def parse_slip(text: str) -> dict:
    merchant = parse_merchant(text)
    return {
        "amount_baht": parse_amount(text),
        "date": parse_date(text),
        "ref": parse_ref(text),
        "merchant": merchant,
        "category": auto_categorize(text, merchant or ""),
    }


def ocr_image(path: str) -> str:
    try:
        import pytesseract
        from PIL import Image
    except ImportError:
        sys.exit("ต้องลง: pip install pytesseract pillow + ติดตั้ง tesseract (ภาษาไทย: tha)")
    return pytesseract.image_to_string(Image.open(path), lang="tha+eng")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--demo", action="store_true")
    ap.add_argument("--image")
    args = ap.parse_args()

    if args.image:
        text = ocr_image(args.image)
    elif args.demo:
        text = SAMPLE_SLIP
    else:
        ap.error("ใช้ --demo หรือ --image PATH")

    print("--- OCR TEXT ---")
    print(text.strip())
    print("\n--- PARSED ---")
    result = parse_slip(text)
    print(json.dumps(result, ensure_ascii=False, indent=2))

    if args.demo:
        expected = {
            "amount_baht": 120.0,
            "date": "2024-06-20",
            "ref": "015220062714320012345",
            "merchant": "ร้านอาหารตามสั่ง",
        }
        hits = sum(1 for k in expected if result.get(k) == expected[k])
        print(f"\n[demo] parse ถูก {hits}/{len(expected)} ฟิลด์ (amount/date/ref/merchant)")


if __name__ == "__main__":
    main()
