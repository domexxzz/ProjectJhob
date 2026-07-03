# 🗓️ แผนการทำงาน — โดม (Sprint 5, 2 สัปดาห์)

> อ้างอิง: [TASK_Dome_Developer.md](TASK_Dome_Developer.md) · [SPRINT_5_PLAN.md](../SPRINT_5_PLAN.md) · ช่วง **3–16 ก.ค. 2569**
> บทบาท: **Developer (Full-stack/AI)** — ทำ end-to-end ทั้ง API + AI + หน้าจอ Flutter

## 🎯 หลักการวางแผน
1. **Vertical slice ทีละฟีเจอร์** (backend → mobile จบเป็นเรื่อง ๆ) — ได้ทั้ง screen + API ครบ (ตอบ rubric #1, #2)
2. **Risk/value-first** — ทำ **Goals ก่อน** (ค่าสูง + ปลดบล็อกทีม), เก็บ **FCM (เสี่ยงสุด)** ไว้ต้นสัปดาห์ 2 พร้อม buffer
3. **Reuse ของเดิม** — `buildContext()` + coach multi-provider (Typhoon ใช้ได้แล้ว) → DM-3/DM-6 ประหยัดเวลา
4. **Logic ก่อน สไตล์ทีหลัง** — ต้ากำลังทำ TA-0 (ธีม dark+green) + TA-1 (widget กลาง) → โดมเขียน logic/โครงหน้าจอไปก่อน แล้วค่อยจับธีม/widget วันท้าย ๆ

---

## 🧭 ภาพรวม 4 เฟส

| เฟส | วัน | งาน | ส่งมอบ |
|---|---|---|---|
| **1 · Goals** | D1–3 | DM-1 (API + 4 จอ) | สร้าง/แก้/ลบ/เติมเงินเข้าเป้า ทำงานจริง |
| **2 · AI layer** | D4–5 | DM-3 แผนออม + DM-6 rec engine | "พี่เงินแนะนำ" ทุกหน้า |
| **3 · Notifications** | D6–8 | DM-2 (FCM + trigger + Notif Center) | push เกินงบเด้งจริง |
| **4 · Subscription + ปิดงาน** | D9–10 | DM-5 + DM-4(stretch) + จับธีม + analyze | Subscription + demo พร้อม |

---

## 🔗 ลำดับ dependency
```
DM-1 Goals API (D1) ──► DM-1 Goals screen (D2-3) ──► DM-3 แผนออม (D4)
       │                                                   │
       └──► buildContext() (มีแล้ว) ──► DM-6 rec engine (D5) ──► การ์ด "แนะนำ" ป้อนให้ ต้า (Budget/Dashboard)
DM-2 FCM setup (D6, เสี่ยง) ──► trigger+cron (D7) ──► Notif Center (D8) ──► DM-5 reminder (D9)
ต้า TA-0 ธีม + TA-1 widget ──(พร้อมเมื่อไร)──► โดมจับธีม/widget หน้าจอ (D10)
```

---

## 📋 รายละเอียดรายงาน (เรียงตามลำดับทำ)

### เฟส 1 — DM-1 Goals (D1–3) ⭐ทำก่อน — ปลดบล็อกทีม
**D1 · Backend** — `backend/src/modules/goals/goals.routes.ts` (ก็อป pattern `budgets.routes.ts`)
- [ ] `GET /api/v1/goals` (list + `percentage`)
- [ ] `POST /api/v1/goals` `{name, target, deadline?}` (zod: name ไม่ว่าง, target>0 สตางค์)
- [ ] `PATCH /api/v1/goals/:id`
- [ ] `POST /api/v1/goals/:id/deposit` `{amount}` → `current += amount`
- [ ] `DELETE /api/v1/goals/:id`
- [ ] register ใน `app.ts` + เขียน API contract ใน `README.md` + `cache.delPattern` หลังเขียน
- [ ] เทส curl: create → deposit → list (ตาราง `Goal` มีอยู่แล้ว ไม่ต้อง migrate)

**D2–3 · Mobile** — `lib/features/goals/` (route `/goals`, quick action dashboard ชี้มา)
- [ ] `goals_repository.dart` (Dio) + Riverpod providers
- [ ] จอ list "เป้าหมายของฉัน" (การ์ด + progress %)
- [ ] จอสร้าง/แก้ (ชื่อ/ยอด/เดดไลน์) + ปุ่มลบ (แดง)
- [ ] จอเติมเงินเข้าเป้า — **ชิปจำนวนเร็ว 500–6,000** → เรียก `/deposit`
- [ ] จอเดดไลน์ (ปฏิทินช่วงวัน) — ป้อน DM-3
- ✅ **DoD:** สร้าง/แก้/ลบ/เติมเงิน → progress วิ่งจากข้อมูลจริง

### เฟส 2 — AI layer (D4–5)
**D4 · DM-3 แผนออม AI** — `POST /api/v1/goals/:id/plan`
- [ ] reuse `buildContext(userId)` (ไม่มี PII อยู่แล้ว) + coach multi-provider (Typhoon)
- [ ] คำนวณ heuristic: `ต่อเดือน = (target-current)/เดือนที่เหลือ` + milestone **25/50/75%**
- [ ] LLM เรียบเรียงเป็นข้อความ + **fallback heuristic** เมื่อ LLM ล่ม
- [ ] แสดงการ์ด "พี่เงินแนะนำ" ในจอ Goals
- ✅ **DoD:** เป้า 50,000 ใน 10 เดือน → "ออมเดือนละ ~5,000…" + มี fallback

**D5 · DM-6 Recommendation engine** — `GET /api/v1/recommendations?context=goal|budget|dashboard`
- [ ] reuse `buildContext()` → คำแนะนำสั้น (Typhoon + heuristic fallback, ตัด PII)
- [ ] ป้อนการ์ด "แนะนำสำหรับคุณ" (Goals ของเรา + **ส่ง shape ให้ ต้า** ใช้ใน Budget/Dashboard)
- ✅ **DoD:** การ์ดโชว์ข้อความจริงจาก AI ทุกหน้า (มี fallback)

### เฟส 3 — DM-2 Notifications (D6–8) 🔴 เสี่ยงสุด
**D6 · Setup (เผื่อเวลา)**
- [ ] `npm i firebase-admin node-cron` + `npm i -D @types/node-cron`
- [ ] Firebase project + service account → env `FIREBASE_*` (อย่า commit)
- [ ] `POST /notifications/token` เก็บ device token + mobile ขอ permission + ลงทะเบียน token
- [ ] ตาราง `Notification { type, title, body, read, createdAt }` (migrate)

**D7 · Trigger + scheduled job**
- [ ] อ่าน `/budgets/status` (มีแล้ว) → trigger: ใกล้งบ ≥80% / เกินงบ / สรุปรายวัน
- [ ] `node-cron` ยิงสรุปรายวัน + ตรวจงบ → ส่ง FCM + บันทึกลง DB
- [ ] เทส push บน **Android device จริง** ก่อน (iOS ไว้ทีหลัง)

**D8 · Mobile Notification Center** — `lib/features/notifications/` (route `/notifications`)
- [ ] `GET /notifications` + `PATCH /:id/read` · จอลิสต์ + badge ยังไม่อ่าน
- ✅ **DoD:** ใช้เกินงบอาหาร → push "ใช้เกินงบอาหารแล้วนะ!" + เห็นใน center

### เฟส 4 — Subscription + ปิดงาน (D9–10)
**D9 · DM-5 Subscription Tracker** — `mockup P14`
- [ ] ตาราง `Subscription { name, amount, cycle, nextBilling, logo? }` (migrate)
- [ ] `GET/POST/PATCH/DELETE /api/v1/subscriptions`
- [ ] mobile `subscriptions_screen.dart` (โลโก้+ยอด/เดือน+วันตัด, สรุปยอดรวม, เพิ่ม/แก้/ลบ) เข้าจากเมนู P15
- [ ] reminder ผ่าน cron ของ DM-2 (เตือนก่อนตัด)
- ✅ **DoD:** เพิ่ม sub → ลิสต์ + ยอดรวมถูก + เตือนก่อนตัด

**D10 · ปิดงาน**
- [ ] DM-4 (stretch) achievements engine — service streak/badge/XP (เตรียม Sprint 6)
- [ ] **จับธีม dark+green + widget กลางของต้า** ให้ทุกหน้าของโดม (หลัง TA-0/TA-1 เสร็จ)
- [ ] `flutter analyze` = 0 error + backend `npm run typecheck` ผ่าน
- [ ] เปิด/เคลียร์ PR ที่เหลือ + ซ้อม demo

---

## ⚠️ ความเสี่ยง + ทางแก้
| ความเสี่ยง | ทางแก้ |
|---|---|
| **FCM/Firebase setup** ยุ่ง (credential, iOS APNs) | เริ่ม D6 มี buffer · เทส Android ก่อน · **บันทึก notif ลง DB** ให้ center ทำงานได้แม้ push ยังไม่นิ่ง |
| Typhoon quota/ล่ม | มี **heuristic fallback** ทุกจุด (DM-3/DM-6) — ไม่พังถ้า LLM หลุด |
| ต้ายังทำธีม/widget ไม่เสร็จ | โดมทำ logic + โครงหน้าจอก่อน → จับธีม/widget วัน D10 |
| migrate ตารางใหม่ (Subscription/Notification) | dev = `npm run db:push` (SQLite) · prod ค่อย migrate Postgres |
| แก้ `.env` แล้วไม่มีผล | **restart backend เสมอ** (`tsx watch` ไม่จับ `.env`) — เพิ่งเจอกับ Typhoon key |

## 🌿 Git branches (1 งาน = 1 branch)
`feature/dome-goals-api` · `feature/dome-goals-screen` · `feature/dome-ai-plan` · `feature/dome-recommendations` · `feature/dome-notifications` · `feature/dome-subscriptions`
→ เปิด PR → แตงกวา/ต้ารีวิว → merge `main` (ดู [GIT_WORKFLOW_GUIDE.md](../GIT_WORKFLOW_GUIDE.md))

## ✅ เช็ค rubric (Developer/IOT 70)
- **Screen (10):** Goals list / form / deposit / Notif Center / Subscription = **5+ จอ** ✓
- **Component/Function (15):** endpoint + service + widget เยอะ ✓
- **Flow (10):** ตั้งเป้า→แผน AI→เติมเงิน→progress + เกินงบ→push ✓
- **ไม่มี Bug (10):** analyze 0 error + typecheck + handle error/fallback ✓
- **เทคนิค (5) ⭐:** full-stack + FCM + node-cron + LLM + cache = จุดแข็งโดม (เขียนในเอกสาร/พรีเซนต์)
- **CLO6 (15):** Typhoon แผนออม + rec engine = นวัตกรรม ✓

---

## 🚀 เริ่มวันนี้ (3 step แรก)
1. `git checkout -b feature/dome-goals-api`
2. ก็อป `budgets.routes.ts` → `goals/goals.routes.ts` → ใส่ 5 endpoint (มี `/deposit`) → register ใน `app.ts`
3. เทส: `curl -X POST .../api/v1/goals -d '{"name":"เที่ยวญี่ปุ่น","target":5000000}'` → `/deposit` → `GET /goals` (ยืนยัน `percentage` วิ่ง)
