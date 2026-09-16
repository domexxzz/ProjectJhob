# ✅ Sprint 1 — Foundation + Walking Skeleton

**เป้า:** ผู้ใช้ register/login → กรอก transaction → เห็นบน dashboard ครบทั้ง 3 layer (พิสูจน์ว่าระบบต่อกันติด)

## สถานะใน scaffold นี้

### P2 — Backend (✅ รันได้จริง, ตรวจสอบแล้ว)
- [x] Repo + TypeScript + Express setup
- [x] Prisma schema ครบ 7 ตาราง (users, transactions, categories, budgets, goals, chat_messages, achievements)
- [x] Auth: register/login + bcrypt + JWT + middleware `requireAuth`
- [x] Transaction CRUD API + summary (income/expense/balance) + filter `month`/`type`
- [x] Categories API + seed หมวดหมู่ไทย + demo user
- [x] `/health` (เช็ค DB) + error/validation handler (zod)
- [ ] CI (GitHub Actions) — ⬜ เพิ่มตอนมี repo remote
- [ ] Deploy staging (Railway/Render) — ⬜ ทำเมื่อสมัคร service

### P1 — Mobile (Flutter scaffold — ต้องมี Flutter SDK เพื่อรัน)
- [x] โครง lib/ + Riverpod + go_router + Dio API client + secure token store
- [x] Design system / theme (`lib/app/theme.dart`)
- [x] Login + Register screens (ต่อ backend จริง)
- [x] Dashboard (greeting + การ์ดคงเหลือ + summary + รายการล่าสุด)
- [x] Add Transaction (3-tap: จำนวน → รายรับ/จ่าย → หมวด → save)
- [x] Hive init (local cache)
- [ ] รัน `flutter pub get` + `flutter run` — ⬜ ต้องลง Flutter SDK ในเครื่อง dev ก่อน

### P3 — AI Spikes (Python — รัน dry-run/demo ได้)
- [x] OCR slip parser spike (`ai/ocr_spike/`) — parse จำนวน/วันที่/ref จากข้อความสลิป + โครงเสียบ OCR engine
- [x] โค้ช "พี่เงิน" hello-world (`ai/coach/`) — persona + context injection + `--dry-run`
- [x] Context injection schema (`ai/coach/context_schema.json`) + ตัวอย่าง (สไลด์ 5)
- [ ] วัด OCR accuracy บนสลิปจริง 20–30 ใบ — ⬜ ใส่รูปใน `ai/ocr_spike/samples/` แล้วรันด้วย OCR engine

## ▶️ วิธีรัน (walking skeleton)
```bash
cd backend
cp .env.example .env
npm install
npm run db:push && npm run db:seed
npm run dev
# ทดสอบ flow:
curl http://localhost:4000/health
curl -X POST http://localhost:4000/api/v1/auth/login -H "Content-Type: application/json" \
  -d '{"email":"demo@bestimove.ai","password":"demo1234"}'
# เอา token ไปเรียก GET /api/v1/transactions (Bearer)
```

## 🎯 Definition of Done (Sprint 1)
- [x] register/login จริง คืน JWT
- [x] เพิ่ม transaction แล้ว persist + ดึงกลับมาเห็น (summary ถูกต้อง)
- [x] backend ผ่าน typecheck + boot + health ok
- [ ] mobile รันบน emulator (ต้องมี Flutter SDK)
- [ ] OCR accuracy report บนสลิปจริง
- [ ] CI เขียว + deploy staging
