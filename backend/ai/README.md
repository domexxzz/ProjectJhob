# 🤖 AI Spikes (Sprint 1, P3)

เป้าหมาย Sprint 1 = **de-risk** 2 ส่วนที่ยากที่สุดก่อน: OCR สลิป + โค้ช AI

## 1) โค้ช "พี่เงิน" — `coach/`
hello-world ของ AI Coach: ประกอบ system prompt จาก **persona** + **context injection** (ข้อมูลจริงของผู้ใช้) แล้วถาม LLM

```bash
python coach/coach.py --dry-run     # ดู prompt ที่ประกอบได้ (ไม่ต้องมี API key)
# ทดสอบจริง:
cp .env.example .env && echo "ใส่ OPENAI_API_KEY ใน .env"
pip install -r requirements.txt
python coach/coach.py --question "เดือนนี้ใช้เงินเป็นยังไงบ้าง?"
```
- `persona.md` — บุคลิก/กฎ/ข้อห้ามของพี่เงิน (≤150 คำ, ไม่แนะนำหุ้นเจาะจง, ตัด PII)
- `context_schema.json` — สัญญาของข้อมูลที่ฉีดเข้า prompt (ตรงกับ context injection สไลด์ 5)
- `sample_context.json` — ตัวอย่างข้อมูล (income 25k, ใช้ 18.5k, อาหารเกินงบ, เป้าญี่ปุ่น 45%, streak 12)
- default model = `gpt-3.5-turbo` (ถูก) → prod fallback `gpt-4` + cache (ตาม risk plan)

## 2) OCR slip parser — `ocr_spike/`
พิสูจน์ว่า parse จำนวนเงิน/วันที่/เลขอ้างอิง/ร้าน จากข้อความสลิปได้ — ส่วนที่ยากจริงคือ "ตรรกะ parse" ไม่ใช่ตัว OCR

```bash
python ocr_spike/ocr_spike.py --demo            # รัน parser บนสลิปตัวอย่าง (stdlib ล้วน)
python ocr_spike/ocr_spike.py --image slip.jpg  # OCR รูปจริง (ต้องลง tesseract + ภาษาไทย)
```
> โปรดักชัน OCR = **Google ML Kit on-device** (ใน Flutter). สคริปต์นี้ทดสอบ parser + วัด accuracy บนสลิปจริง (วางรูปใน `ocr_spike/samples/`)

## ติดตั้ง
```bash
python -m venv .venv && . .venv/Scripts/activate   # Windows (Mac/Linux: source .venv/bin/activate)
pip install -r requirements.txt
```
