# OCR Slip Parser Spike

## รัน
```bash
python ocr_spike.py --demo               # parser บนสลิปตัวอย่าง (ควรได้ 4/4 ฟิลด์)
python ocr_spike.py --image samples/slip1.jpg   # OCR รูปจริง (ต้องลง tesseract+tha)
```

## วัด accuracy (งานที่เหลือของ Sprint 1)
1. รวบรวมสลิปจริง 20–30 ใบ (PromptPay/ธนาคารต่าง ๆ/ใบเสร็จร้าน) วางใน `samples/`
2. รันทีละใบ เทียบค่าที่ parse ได้กับค่าจริง → บันทึกเป็นตาราง accuracy ต่อฟิลด์
3. สรุปเป็น "OCR accuracy report" (DoD ของ P3 ใน Sprint 1)

## หมายเหตุ
- โปรดักชันใช้ **Google ML Kit Text Recognition (on-device)** ใน Flutter — รองรับภาษาไทย, ไม่ส่งรูปขึ้น server (ดีต่อ PDPA)
- สคริปต์นี้โฟกัส "ตรรกะ parse" ที่ใช้ซ้ำได้ไม่ว่า OCR engine ไหน
- สลิป PromptPay มีโครงสร้างค่อนข้างคงที่ → template matching ได้ผลดี; ใบเสร็จร้านหลากหลายกว่า → ต้องพึ่ง heuristic + ให้ user ยืนยันก่อน save เสมอ
