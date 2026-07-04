# 💰 AI Finance Coach — "พี่เงิน"

ผู้ช่วยการเงินส่วนตัว AI สำหรับคนรุ่นใหม่ (นักศึกษา/วัยทำงาน 18–30) — สแกนสลิป, จัดหมวดอัตโนมัติ, โค้ช AI "พี่เงิน", ตั้งเป้าออม, และ gamification.

> Senior Project · Bestimove Academy · ทีม 3 คน · 16 สัปดาห์ · Flutter (iOS & Android)

---

## 📂 โครงสร้าง Monorepo

```
ai-finance-coach/
├── docs/                 แผนงาน
│   ├── SPRINT_PLAN.md       แผน 8 sprints (16 สัปดาห์) ฉบับเต็ม
│   └── SPRINT_1_TASKS.md    เช็คลิสต์ Sprint 1 + วิธีรัน
├── backend/              Node.js + Express + Prisma + TypeScript  (✅ รันได้เลย)
├── mobile/               Flutter (Dart + Riverpod)               (สแกฟโฟลด์ — ต้องมี Flutter SDK)
└── ai/                   Python spikes: OCR slip parser + โค้ช "พี่เงิน" (LangChain/OpenAI)
```

## 🚀 Quickstart

### 1) Backend (พร้อมรัน — ไม่ต้องลง Postgres/Docker)
```bash
cd backend
cp .env.example .env          # dev ใช้ SQLite อัตโนมัติ
npm install
npm run db:push               # สร้างตาราง (SQLite: dev.db)
npm run db:seed               # ใส่หมวดหมู่ + demo user (demo@bestimove.ai / demo1234)
npm run dev                   # http://localhost:4000  (GET /health)
```

### 2) Mobile (ต้องมี Flutter SDK ก่อน)
```bash
cd mobile
flutter pub get
# Android emulator วิ่งหา host ผ่าน 10.0.2.2 ; iOS sim ใช้ localhost
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000
```

### 3) AI spikes (Python)
```bash
cd ai
python -m venv .venv && . .venv/Scripts/activate   # Windows
pip install -r requirements.txt
python coach/coach.py --dry-run                     # ดู prompt ที่ประกอบจาก context (ไม่ต้องมี API key)
python ocr_spike/ocr_spike.py --demo                # ทดสอบ parser สลิปบนข้อความตัวอย่าง
```

## 🔌 API Contract (v1)
Base: `http://localhost:4000` · auth = `Authorization: Bearer <token>` · **จำนวนเงินเป็นสตางค์ (int, 1 บาท = 100)**

| Method | Path | Auth | คำอธิบาย |
|---|---|:--:|---|
| GET  | `/health` | | สถานะ + เช็ค DB |
| POST | `/api/v1/auth/register` | | `{ email, password, displayName?, monthlyIncome? }` → `{ user, token }` |
| POST | `/api/v1/auth/login` | | `{ email, password }` → `{ user, token }` |
| GET  | `/api/v1/auth/me` | ✓ | โปรไฟล์ผู้ใช้ปัจจุบัน |
| GET  | `/api/v1/categories` | ✓ | หมวดหมู่ทั้งหมด |
| GET  | `/api/v1/transactions?month=YYYY-MM&type=expense` | ✓ | รายการ + `summary {income,expense,balance}` |
| POST | `/api/v1/transactions` | ✓ | `{ type, amount, categoryId?, note?, source? }` |
| GET/PATCH/DELETE | `/api/v1/transactions/:id` | ✓ | อ่าน/แก้/ลบ |
| GET  | `/api/v1/goals` | ✓ | รายการเป้าหมายออม + `percentage` (0–100) |
| POST | `/api/v1/goals` | ✓ | `{ name, target, deadline?, current? }` (เงินเป็นสตางค์) |
| PATCH | `/api/v1/goals/:id` | ✓ | แก้ชื่อ/เป้า/current/เดดไลน์ |
| POST | `/api/v1/goals/:id/deposit` | ✓ | `{ amount }` → `current += amount` (เติมเงินเข้าเป้า) |
| POST | `/api/v1/goals/:id/plan` | ✓ | แผนออม AI (ออม/เดือน + ไมล์สโตน 25/50/75% + คำแนะนำพี่เงิน) |
| DELETE | `/api/v1/goals/:id` | ✓ | ลบเป้าหมาย |
| GET  | `/api/v1/notifications` | ✓ | รายการแจ้งเตือน + `unreadCount` |
| PATCH | `/api/v1/notifications/:id/read` | ✓ | ทำเป็นอ่านแล้ว |
| POST | `/api/v1/notifications/read-all` | ✓ | อ่านทั้งหมด |
| POST | `/api/v1/notifications/token` | ✓ | `{ token }` ลงทะเบียน FCM device token |
| POST | `/api/v1/notifications/run-triggers` | ✓ | ตรวจงบเดี๋ยวนี้ → สร้างแจ้งเตือน (ใกล้/เกินงบ) |
| GET  | `/api/v1/recommendations?context=goal\|budget\|dashboard` | ✓ | การ์ด "แนะนำสำหรับคุณ" (AI + heuristic fallback) |

## 🧭 Tech Decisions (Sprint 1)
- **เงินเก็บเป็นสตางค์ (Int)** ไม่ใช่ float — กัน floating-point error (มาตรฐานแอปการเงิน). UI หารด้วย 100 ตอนแสดงผล.
- **Dev = SQLite, Prod = PostgreSQL** — Sprint 1 ใช้ SQLite เพื่อให้ทุกคนรันได้ทันทีไม่ต้องลง service. สลับเป็น Postgres: เปลี่ยน `provider` ใน `prisma/schema.prisma` เป็น `postgresql` + ตั้ง `DATABASE_URL` (ดู `.env.example`) แล้ว `npx prisma migrate dev`.
- **⚠️ "อ่าน SMS ธนาคาร" มีข้อจำกัดจริง** — iOS อ่านกล่อง SMS ไม่ได้, Android โดน Google Play จำกัด `READ_SMS` → ออกแบบให้ **OCR + กรอกเร็ว** เป็นทางหลัก, SMS เป็น Android-only/best-effort. (ดู docs/SPRINT_PLAN.md)

ดูแผนเต็ม → [docs/SPRINT_PLAN.md](docs/SPRINT_PLAN.md) · งาน Sprint 1 → [docs/SPRINT_1_TASKS.md](docs/SPRINT_1_TASKS.md)
