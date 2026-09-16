#!/usr/bin/env python3
import sys
import io

# Reconfigure stdout to support UTF-8 on Windows
if sys.platform.startswith('win'):
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')

from pathlib import Path

# Add current directory to path to import ocr_spike
sys.path.append(str(Path(__file__).parent))
from ocr_spike import parse_slip

TEST_CASES = [
    {
        "id": 1,
        "bank": "KBank",
        "text": """
ธนาคารกสิกรไทย
โอนเงินสำเร็จ
20 มิ.ย. 67 14:32 น.
จาก นาย ก. xxx-x-x1234-x
ไปยัง ร้านค้า A
จำนวน 120.00 บาท
ค่าธรรมเนียม 0.00 บาท
รหัสอ้างอิง 015220062714320012345
""",
        "expected": {
            "amount_baht": 120.00,
            "date": "2024-06-20",
            "ref": "015220062714320012345",
            "merchant": "ร้านค้า A",
            "category": "Food"
        }
    },
    {
        "id": 2,
        "bank": "SCB",
        "text": """
ไทยพาณิชย์
สแกนจ่ายสำเร็จ
วันที่ 20 มิ.ย. 2567 - 14:32
จาก นาย เอ
เข้าบัญชี Shopee Pay
จำนวนเงิน 250.00 บาท
เลขที่รายการ: 2024062012345
""",
        "expected": {
            "amount_baht": 250.00,
            "date": "2024-06-20",
            "ref": "2024062012345",
            "merchant": "Shopee Pay",
            "category": "Shopping"
        }
    },
    {
        "id": 3,
        "bank": "Bangkok Bank",
        "text": """
ธนาคารกรุงเทพ
รายการโอนเงิน
20/06/2567 14:32
ไปยัง BTS Skytrain
จำนวนเงิน: 50.00 บาท
เลขที่อ้างอิง: BBL123456789
""",
        "expected": {
            "amount_baht": 50.00,
            "date": "2024-06-20",
            "ref": "BBL123456789",
            "merchant": "BTS Skytrain",
            "category": "Transport"
        }
    },
    {
        "id": 4,
        "bank": "Krungthai Bank",
        "text": """
ธนาคารกรุงไทย
โอนเงินสำเร็จ
20 มิ.ย. 67 14:32
โอนไปยัง นาย ดี
จำนวนเงิน 1,500.00 บาท
เลขที่อ้างอิง KTB987654321
""",
        "expected": {
            "amount_baht": 1500.00,
            "date": "2024-06-20",
            "ref": "KTB987654321",
            "merchant": "นาย ดี",
            "category": "Food"
        }
    },
    {
        "id": 5,
        "bank": "GSB",
        "text": """
ธนาคารออมสิน
โอนเงินสำเร็จ
20 มิ.ย. 67
ไปยัง นางสาว อี
จำนวน 300.00 บาท
รหัสอ้างอิง GSB11223344
""",
        "expected": {
            "amount_baht": 300.00,
            "date": "2024-06-20",
            "ref": "GSB11223344",
            "merchant": "นางสาว อี",
            "category": "Food"
        }
    },
    {
        "id": 6,
        "bank": "PromptPay",
        "text": """
พร้อมเพย์
โอนสำเร็จ
20 มิ.ย. 67
โอนเงินไปยัง ร้านอร่อย
จำนวน 45.00 บาท
Ref: PP99887766
""",
        "expected": {
            "amount_baht": 45.00,
            "date": "2024-06-20",
            "ref": "PP99887766",
            "merchant": "ร้านอร่อย",
            "category": "Food"
        }
    },
    {
        "id": 7,
        "bank": "SCB",
        "text": """
โอนเงินสำเร็จ
20/06/67 18:30 น.
เข้าบัญชี การไฟฟ้าส่วนภูมิภาค
จำนวนเงิน: 10,000.00 บาท
เลขที่รายการ: 202406209999
""",
        "expected": {
            "amount_baht": 10000.00,
            "date": "2024-06-20",
            "ref": "202406209999",
            "merchant": "การไฟฟ้าส่วนภูมิภาค",
            "category": "Bills"
        }
    },
    {
        "id": 8,
        "bank": "KBank",
        "text": """
โอนเงินเสร็จสมบูรณ์
20 มิ.ย. 67 10:15 น.
ไปยัง ร้านกาแฟ
จำนวนเงิน 60.00 บาท
รหัสอ้างอิง 0123456789012
""",
        "expected": {
            "amount_baht": 60.00,
            "date": "2024-06-20",
            "ref": "0123456789012",
            "merchant": "ร้านกาแฟ",
            "category": "Food"
        }
    },
    {
        "id": 9,
        "bank": "Bangkok Bank",
        "text": """
โอนเงิน
20-06-2024 12:00
ไปยัง ร้านค้า B
จำนวนเงิน 350.00 บาท
เลขที่อ้างอิง BBL998877
""",
        "expected": {
            "amount_baht": 350.00,
            "date": "2024-06-20",
            "ref": "BBL998877",
            "merchant": "ร้านค้า B",
            "category": "Food"
        }
    },
    {
        "id": 10,
        "bank": "Krungthai Bank",
        "text": """
กรุงไทย
สำเร็จ
20 มิ.ย. 2567 09:30
ไปยัง นาย เจ
จำนวนเงิน 120.00 บาท
เลขที่อ้างอิง 1122334455
""",
        "expected": {
            "amount_baht": 120.00,
            "date": "2024-06-20",
            "ref": "1122334455",
            "merchant": "นาย เจ",
            "category": "Food"
        }
    },
    {
        "id": 11,
        "bank": "GSB",
        "text": """
ธนาคารออมสิน
สำเร็จ
20/06/2567 15:45
ไปยัง บจก. ดีดี
จำนวน 5,000.00 บาท
เลขที่อ้างอิง GSB2024
""",
        "expected": {
            "amount_baht": 5000.00,
            "date": "2024-06-20",
            "ref": "GSB2024",
            "merchant": "บจก. ดีดี",
            "category": "Food"
        }
    },
    {
        "id": 12,
        "bank": "Krungsri",
        "text": """
ธนาคารกรุงศรีอยุธยา
โอนเงินสำเร็จ
20 มิ.ย. 67 14:32
ไปยัง นาย เอส
จำนวนเงิน 99.00 บาท
เลขที่รายการ: BAY776655
""",
        "expected": {
            "amount_baht": 99.00,
            "date": "2024-06-20",
            "ref": "BAY776655",
            "merchant": "นาย เอส",
            "category": "Food"
        }
    },
    {
        "id": 13,
        "bank": "Krungsri",
        "text": """
กรุงศรี
สำเร็จ
20 มิ.ย. 2567 11:11
ไปยัง Major Cineplex
จำนวนเงิน 180.00 บาท
เลขที่อ้างอิง BAY1234
""",
        "expected": {
            "amount_baht": 180.00,
            "date": "2024-06-20",
            "ref": "BAY1234",
            "merchant": "Major Cineplex",
            "category": "Entertainment"
        }
    },
    {
        "id": 14,
        "bank": "TTB",
        "text": """
ทหารไทยธนชาต
โอนเงินสำเร็จ
20 มิ.ย. 67 13:00
ไปยัง ร้านอาหาร
จำนวนเงิน 150.00 บาท
เลขที่อ้างอิง TTB889900
""",
        "expected": {
            "amount_baht": 150.00,
            "date": "2024-06-20",
            "ref": "TTB889900",
            "merchant": "ร้านอาหาร",
            "category": "Food"
        }
    },
    {
        "id": 15,
        "bank": "TTB",
        "text": """
ttb
สำเร็จ
20 มิ.ย. 2567
ไปยัง Watson Pharmacy
จำนวนเงิน 2,000.00 บาท
รหัสอ้างอิง TTB2024
""",
        "expected": {
            "amount_baht": 2000.00,
            "date": "2024-06-20",
            "ref": "TTB2024",
            "merchant": "Watson Pharmacy",
            "category": "Health"
        }
    },
    {
        "id": 16,
        "bank": "PromptPay",
        "text": """
PromptPay
โอนเงินสำเร็จ
20 มิ.ย. 67
ไปยัง นาย เอฟ
จำนวน 1,234.56 บาท
Ref. PP112233
""",
        "expected": {
            "amount_baht": 1234.56,
            "date": "2024-06-20",
            "ref": "PP112233",
            "merchant": "นาย เอฟ",
            "category": "Food"
        }
    },
    {
        "id": 17,
        "bank": "SCB",
        "text": """
SCB
โอนเงินสำเร็จ
20/06/2567
ไปยัง นาย จี
จำนวนเงิน: 80.00 บาท
เลขที่รายการ: SCB888
""",
        "expected": {
            "amount_baht": 80.00,
            "date": "2024-06-20",
            "ref": "SCB888",
            "merchant": "นาย จี",
            "category": "Food"
        }
    },
    {
        "id": 18,
        "bank": "KBank",
        "text": """
K-Plus
โอนเงินสำเร็จ
20 มิ.ย. 67
ไปยัง ร้านค้า D
จำนวนเงิน 75.00 บาท
รหัสอ้างอิง KPLUS555
""",
        "expected": {
            "amount_baht": 75.00,
            "date": "2024-06-20",
            "ref": "KPLUS555",
            "merchant": "ร้านค้า D",
            "category": "Food"
        }
    },
    {
        "id": 19,
        "bank": "Bangkok Bank",
        "text": """
Bualuang mBanking
โอนเงินสำเร็จ
20 มิ.ย. 67
ไปยัง นาย เอช
จำนวน 400.00 บาท
เลขที่อ้างอิง BBL444
""",
        "expected": {
            "amount_baht": 400.00,
            "date": "2024-06-20",
            "ref": "BBL444",
            "merchant": "นาย เอช",
            "category": "Food"
        }
    },
    {
        "id": 20,
        "bank": "Krungthai Bank",
        "text": """
Krungthai NEXT
โอนเงินสำเร็จ
20 มิ.ย. 67
ไปยัง ร้านค้า E
จำนวนเงิน 30.00 บาท
เลขที่อ้างอิง KTB222
""",
        "expected": {
            "amount_baht": 30.00,
            "date": "2024-06-20",
            "ref": "KTB222",
            "merchant": "ร้านค้า E",
            "category": "Food"
        }
    },
    {
        "id": 21,
        "bank": "UOB",
        "text": """
ธนาคารยูโอบี
โอนเงินสำเร็จ
20 มิ.ย. 67
ไปยัง นาย ไอ
จำนวนเงิน 950.00 บาท
เลขที่อ้างอิง UOB111
""",
        "expected": {
            "amount_baht": 950.00,
            "date": "2024-06-20",
            "ref": "UOB111",
            "merchant": "นาย ไอ",
            "category": "Food"
        }
    },
    {
        "id": 22,
        "bank": "UOB",
        "text": """
UOB
สำเร็จ
20 มิ.ย. 2567
ไปยัง ร้านค้า F
จำนวนเงิน 110.00 บาท
เลขที่อ้างอิง UOB222
""",
        "expected": {
            "amount_baht": 110.00,
            "date": "2024-06-20",
            "ref": "UOB222",
            "merchant": "ร้านค้า F",
            "category": "Food"
        }
    },
    {
        "id": 23,
        "bank": "GSB",
        "text": """
MyMo
โอนเงินสำเร็จ
20 มิ.ย. 67
ไปยัง นาย เจ
จำนวน 55.00 บาท
เลขที่อ้างอิง MYMO333
""",
        "expected": {
            "amount_baht": 55.00,
            "date": "2024-06-20",
            "ref": "MYMO333",
            "merchant": "นาย เจ",
            "category": "Food"
        }
    },
    {
        "id": 24,
        "bank": "CIMB",
        "text": """
ธนาคาร ซีไอเอ็มบี ไทย
โอนสำเร็จ
20 มิ.ย. 67
ไปยัง บริษัท แสนสิริ (เงินเดือน)
จำนวนเงิน 700.00 บาท
เลขที่อ้างอิง CIMB555
""",
        "expected": {
            "amount_baht": 700.00,
            "date": "2024-06-20",
            "ref": "CIMB555",
            "merchant": "บริษัท แสนสิริ (เงินเดือน)",
            "category": "Salary"
        }
    },
    {
        "id": 25,
        "bank": "LH Bank",
        "text": """
LH Bank
โอนสำเร็จ
20 มิ.ย. 67
ไปยัง ร้านค้า G
จำนวนเงิน 220.00 บาท
เลขที่อ้างอิง LHB999
""",
        "expected": {
            "amount_baht": 220.00,
            "date": "2024-06-20",
            "ref": "LHB999",
            "merchant": "ร้านค้า G",
            "category": "Food"
        }
    }
]

def main():
    print("=" * 75)
    print("Evaluating OCR Slip Parser + Auto-Categorization on 25 Slips...")
    print("=" * 75)

    correct_counts = {"amount": 0, "date": 0, "ref": 0, "merchant": 0, "category": 0}
    total = len(TEST_CASES)

    print(f"{'ID':<3} | {'Bank':<15} | {'Amount':<6} | {'Date':<6} | {'Ref':<6} | {'Merchant':<8} | {'Category':<8} | {'Overall'}")
    print("-" * 90)

    for case in TEST_CASES:
        result = parse_slip(case["text"])
        expected = case["expected"]

        amt_ok = result.get("amount_baht") == expected["amount_baht"]
        date_ok = result.get("date") == expected["date"]
        ref_ok = result.get("ref") == expected["ref"]
        merchant_ok = result.get("merchant") == expected["merchant"]
        cat_ok = result.get("category") == expected["category"]

        if amt_ok: correct_counts["amount"] += 1
        if date_ok: correct_counts["date"] += 1
        if ref_ok: correct_counts["ref"] += 1
        if merchant_ok: correct_counts["merchant"] += 1
        if cat_ok: correct_counts["category"] += 1

        overall = amt_ok and date_ok and ref_ok and merchant_ok and cat_ok
        status = "✅ PASS" if overall else "❌ FAIL"

        def tick(flag):
            return "✅" if flag else "❌"

        print(f"{case['id']:<3} | {case['bank']:<15} | {tick(amt_ok):<6} | {tick(date_ok):<6} | {tick(ref_ok):<6} | {tick(merchant_ok):<8} | {tick(cat_ok):<8} | {status}")

        if not overall:
            print(f"  ↳ Expected: {expected}")
            print(f"  ↳ Got     : {result}")

    print("=" * 75)
    print("Summary Accuracy Results:")
    print("=" * 75)
    for field, correct in correct_counts.items():
        accuracy = (correct / total) * 100
        print(f"- {field.capitalize():<8} Accuracy: {correct}/{total} ({accuracy:.1f}%)")
    
    total_fields = total * 5
    total_correct = sum(correct_counts.values())
    total_acc = (total_correct / total_fields) * 100
    print(f"- Total Field Accuracy : {total_correct}/{total_fields} ({total_acc:.1f}%)")
    print("=" * 75)

if __name__ == "__main__":
    main()
