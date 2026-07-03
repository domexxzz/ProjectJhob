## 🛠️ TASK — โดม (Developer · Full-stack/AI)

> **โฟกัสรอบนี้:** เป็นเจ้าของฟีเจอร์ที่ **ลึกทางเทคนิค** แบบ end-to-end — สร้างทั้ง **API (Node/Express) + AI + หน้าจอ Flutter** ของ Goals, Notifications และ AI Savings Plan
> Stack: **Node + Express + Prisma** (backend) · **Typhoon/LangChain** (AI) · **Flutter + Riverpod** (screen) · theme กลางที่ `lib/app/theme.dart`

> 🆕 รอบนี้โดมเริ่มลงมือ dev เต็มตัว (รอบก่อนยังไม่มี task) — จับงาน full-stack เพราะได้คะแนน **"เทคนิคการพัฒนา"** สูงและครบทุกช่อง rubric

> 🎨 **Mockup อ้างอิง (Canva "AI Personal" — [design](https://www.canva.com/design/DAHNlIeU6mc/edit)):**
>
> | หน้า Canva | จอ | งานของโดม |
> |---|---|---|
> | P8–9 | เป้าหมาย (Goals) — list / สร้าง / แก้+ลบ / **เติมเงินเข้าเป้า (ชิป 500–6,000)** / **ปฏิทินเดดไลน์** / **แผน AI 25-50-75%** | DM-1 + DM-3 |
> | P14 | แจ้งเตือน (Notification Center) + badge | DM-2 |
> | P14 | **Subscription** (Netflix/Spotify/YouTube รายเดือน + เตือนก่อนตัดเงิน) | **DM-5 🆕** |
> | ทุกหน้า | การ์ด **"แนะนำสำหรับคุณ"** (Goals/Budget/Dashboard) | **DM-6 🆕** |
>
> *(Chat Bot ใน P14 ทำแล้ว → ใช้ mockup ปรับ polish · ธีมทั้งหมด = **dark + green** ตาม TA-0 ของต้า — ทำหน้าจอบนธีมนี้)*

---

### 🎯 ทำไมงานนี้ = คะแนนของโดม (rubric: Developer/IOT, เต็ม 70)

**CLO5 (55)**
| # | เกณฑ์ในใบให้คะแนน | คะแนน | ทำยังไงให้ได้ |
|---|---|:--:|---|
| 1 | **จำนวน Screen** (auto) | 10 | ส่ง Goals + Notification Center + Subscription (3+ หน้า ผูกข้อมูลจริง) |
| 2 | **จำนวน Component/Feature/Function** (auto) | 15 | API endpoint + service function + widget → นับได้เยอะ |
| 3 | ประสิทธิผล — **Flow ครบถ้วนถูกต้อง** | 10 | ตั้งเป้า→AI แผน→progress + แจ้งเตือนเด้งจริง |
| 4 | ประสิทธิผล — **โปรแกรมทำงานได้ ไม่มี Bug** | 10 | typecheck ผ่าน + `flutter analyze` 0 error + handle error |
| 5 | ประสิทธิภาพ — **เทคนิคการพัฒนา** ⭐ | 5 | full-stack + AI + scheduled job + cache → จุดแข็งของโดม |
| 6 | **ความพึงพอใจ/สวยงาม/ใช้ง่าย** | 5 | ใช้ design system (widget จาก TA-1 ของต้า) |

**CLO6 (15):** ใช้ **Typhoon (Thai LLM)** สร้างแผนออมเฉพาะบุคคล + AI generate ข้อความแจ้งเตือน = นวัตกรรม/สร้างสรรค์โดยตรง

> 💡 โดมได้เปรียบช่อง #5 (เทคนิคการพัฒนา) เพราะทำ full-stack + AI — เขียนในเอกสาร/ตอนพรีเซนต์ให้ชัดว่าใช้เทคนิคอะไร (scheduled trigger, LLM integration, cache invalidation)

---

## 📍 สถานะจริงในโปรเจกต์ (ฐานที่ต่อยอด)
- **DB มีตารางแล้ว** (Prisma): `Goal { name, target, current, deadline }` และ `Achievement { type, unlockedAt }` — **แต่ยังไม่มี API/route**
- Backend modules ที่มี: `auth, transactions, budgets, categories, chat, health` → เพิ่มโมดูลใหม่ที่ `backend/src/modules/`
- Pattern อ้างอิง: ดู `modules/budgets/budgets.routes.ts` (มี zod validation + `requireAuth` + cache pattern `cache.delPattern`) — ก็อป pattern นี้
- AI coach pattern: ดู `modules/chat/coach.ts` + `context_builder.ts` (multi-provider: Typhoon→Groq→OpenAI→rule-based)

---

## งานย่อย (เรียงตามลำดับแนะนำ)

### DM-1 · Goals end-to-end (API + Screen) ⭐ทำก่อน — ปลดบล็อกทีม
**Backend** — สร้าง `backend/src/modules/goals/goals.routes.ts` (ก็อป pattern budgets):
- `GET /api/v1/goals` → list + คำนวณ `percentage = current/target`
- `POST /api/v1/goals` `{ name, target, deadline? }` (zod: name ห้ามว่าง, target > 0 สตางค์)
- `PATCH /api/v1/goals/:id` (แก้ชื่อ/เป้า/current/deadline)
- `POST /api/v1/goals/:id/deposit` `{ amount }` → `current += amount` (จอเติมเงินเข้าเป้า P8)
- `DELETE /api/v1/goals/:id`
- ลงทะเบียน router ใน `backend/src/app.ts` + อัปเดต API contract ใน `README.md`

**Mobile** — `lib/features/goals/goals_screen.dart` + route `/goals` — 🎨 **ตาม mockup P8–9** (หลายจอ):
- **จอ list "เป้าหมายของฉัน"**: header + มาสคอต + การ์ดเป้าหมาย (progress bar % + ยอด `current/target`) + ปุ่ม "+ เพิ่มเป้าหมาย" + การ์ด "แนะนำสำหรับคุณ" (DM-6)
- **จอสร้างเป้า "เพิ่มเป้าหมาย"**: รูป/ไอคอน + ชื่อ + ยอดเป้า + เดดไลน์
- **จอแก้ไขเป้า "แก้ไขเป้าหมาย"**: เหมือนสร้าง + ปุ่ม **ลบ (แดง)** + บันทึกการแก้ไข
- **จอเติมเงินเข้าเป้า "กำหนดเงินเข้าเป้าหมาย"**: ช่อง ฿ + **ชิปจำนวนเร็ว 500/1,000/1,500/2,000/2,500/3,000/4,000/5,000/6,000** + ปุ่ม เก็บ → เรียก `/deposit`
- **จอเดดไลน์**: ปฏิทินเลือกช่วงวัน + เลือกเดือน (ป้อน DM-3 คำนวณแผน)
- **celebrate**: animation เมื่อถึงเป้า (CLO6 — ให้ต้าช่วยเรื่อง animation)
- ปุ่ม "เป้าหมาย" ใน quick action ของ dashboard ชี้มาที่นี่
- ✅ DoD: สร้าง/แก้/ลบ/เติมเงินเข้าเป้า → progress วิ่งจากข้อมูลจริง + หน้าตาตรง mockup (dark+green)

### DM-2 · Notifications (FCM + Trigger + Screen)
**Backend** — โมดูล `notifications`:
- เก็บ device token · trigger 3 แบบ: **ใกล้งบ (≥80%) / เกินงบ / สรุปรายวัน** (อ่านจาก `/budgets/status` ที่มีอยู่)
- **Scheduled job** (เช่น `node-cron`) ยิงสรุปรายวัน + ตรวจงบ
- ส่งผ่าน **FCM** (Firebase Cloud — ตาม P01)
- `GET /api/v1/notifications` (history) + mark-as-read

**Mobile** — `lib/features/notifications/notifications_screen.dart` + route `/notifications` — 🎨 **ตาม mockup P14** (Notification Center):
- ขอ permission + Notification Center (รายการแจ้งเตือน + badge ยังไม่อ่าน + แตะเพื่ออ่าน/ลบ)
- ✅ DoD: ใช้เกินงบหมวดอาหาร → ได้ push "ใช้เกินงบอาหารแล้วนะ!" + เห็นใน center (ตรง mockup P01)

### DM-3 · AI Savings Plan (Typhoon/LangChain) — CLO6
- Endpoint `POST /api/v1/goals/:id/plan` (หรือ `/goals/plan`): รับ `target + deadline + monthlyIncome` → คืน **แผนออมรายเดือน** (ต้องออมเดือนละเท่าไร, ตัดค่าใช้จ่ายหมวดไหน)
- ใช้ **Typhoon** (ก็อป multi-provider pattern จาก `chat/coach.ts`) + **heuristic fallback** (คำนวณตรง ๆ เมื่อ LLM ล่ม): `ต่อเดือน = (target - current) / เดือนที่เหลือ`
- ⚠️ **ตัด PII ก่อนส่ง LLM** (ส่งตัวเลข/หมวด ไม่ส่งชื่อ-เลขบัญชี) — ตาม PDPA ใน SPRINT_PLAN
- แสดงผลในหน้า Goals (การ์ด "พี่เงินแนะนำ")
- ✅ DoD: ตั้งเป้า "เที่ยวญี่ปุ่น 50,000 ใน 10 เดือน" → พี่เงินตอบ "ออมเดือนละ ~5,000, ลองลดหมวด..." + มี fallback

### DM-4 · (Stretch → เริ่ม Sprint 6) Achievements engine
- Service คำนวณ streak/badge/XP จาก transaction (table `Achievement` + `User.streak/level` มีแล้ว) → เตรียมต่อ Gamification UI ใน Sprint 6

### DM-5 · Subscription Tracker 🆕 — 🎨 mockup P14 (Subscription)
> ฟีเจอร์ใหม่จาก mockup: ติดตามค่าบริการรายเดือน (Netflix/Spotify/YouTube ฯลฯ) + เตือนก่อนตัดเงิน
**Backend** — โมดูล `subscriptions` (+ ตาราง Prisma `Subscription { name, amount, cycle, nextBilling, logo? }` — migrate เพิ่ม):
- `GET/POST/PATCH/DELETE /api/v1/subscriptions` (ก็อป pattern budgets)
- ต่อ **DM-2**: scheduled job เตือน "พรุ่งนี้ Netflix ตัด 149฿"
**Mobile** — `lib/features/subscriptions/subscriptions_screen.dart` (เข้าจากเมนู P15):
- ลิสต์ (โลโก้ + ชื่อ + ยอด/เดือน + วันตัดถัดไป) + เพิ่ม/แก้/ลบ + สรุปยอดรวมต่อเดือน
- ✅ DoD: เพิ่ม subscription → เห็นในลิสต์ + ยอดรวมถูก + เตือนก่อนตัด

### DM-6 · AI Recommendation Engine "แนะนำสำหรับคุณ" 🆕 — CLO6
> mockup มีการ์ด "แนะนำสำหรับคุณ" ทั้งหน้า Goals/Budget/Dashboard → ทำ engine เดียวป้อนทุกหน้า
- `GET /api/v1/recommendations?context=goal|budget|dashboard` → คำแนะนำสั้น (เช่น "ลดค่าอาหาร 10% จะถึงเป้าเร็วขึ้น 1 เดือน")
- ใช้ **Typhoon** + context-builder (income/spent/budget/goal) + **heuristic fallback** · **ตัด PII ก่อนส่ง LLM**
- ✅ DoD: การ์ด "แนะนำสำหรับคุณ" ทุกหน้าโชว์ข้อความจริงจาก AI (มี fallback)

---

## 📐 กติกา (คุณภาพ = ช่อง 10+10 คะแนน)
- **Backend:** zod validate ทุก input · `requireAuth` ทุก route · `cache.delPattern('user:<id>:*')` หลังเขียน · คืน error ภาษาไทย
- **เงินเป็นสตางค์** (Int) เสมอ — อย่าใช้ float
- **Mobile:** ใช้ widget กลางจาก TA-1 (คุยกับต้า) · `Money.formatBaht()` · มี empty/loading/error
- รัน backend typecheck + `flutter analyze` ให้ผ่านก่อนเปิด PR

## 🤝 ทำงานคู่กับทีม
- **แตงกวา (SE):** ขอ field/flow ของ Goals & Notification จาก `requirements.md` + ให้เธอวาด Sequence diagram ของ AI savings plan → คุณ implement ตาม
- **ต้า:** ใช้ `lib/app/widgets/` (TA-1) ร่วมกัน — อย่าสร้าง widget ซ้ำ · ตกลง API response shape ก่อนต้าผูกหน้าจอ
- API ไหนเสร็จ **อัปเดต `README.md` (API Contract)** ทันที เพื่อให้ทีมเห็น

## 🔄 การส่งงาน
- แตก branch ต่อ 1 งาน: `feature/dome-<ชื่องาน>` (เช่น `feature/dome-goals-api`)
- Backend + Mobile ของฟีเจอร์เดียวกัน ทำใน branch เดียวได้ (vertical slice) → เปิด PR → รีวิว → merge `main`
- 📖 ขั้นตอน Git ละเอียด: [../GIT_WORKFLOW_GUIDE.md](../GIT_WORKFLOW_GUIDE.md)

## ✅ Definition of Done (รวม)
- [ ] `/goals` (+deposit) · `/notifications` · `/subscriptions` · `/recommendations` API ผ่าน typecheck + ลงทะเบียนใน `app.ts` + เขียนใน README
- [ ] Goals (list/สร้าง/แก้/ลบ/เติมเงิน/ปฏิทิน) + Notification Center + Subscription screen ผูกข้อมูลจริง (ไม่ mock) — **ธีม dark+green**
- [ ] AI เสนอแผนออม (25/50/75%) + การ์ด "แนะนำสำหรับคุณ" ทำงาน + มี heuristic fallback + ตัด PII
- [ ] Push แจ้งเตือนเกินงบ/ก่อนตัด subscription เด้งจริง (ทดสอบบนมือถือ)
- [ ] `flutter analyze` 0 error + backend typecheck ผ่าน
