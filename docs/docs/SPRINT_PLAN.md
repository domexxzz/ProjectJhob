# 🗺️ แผน Sprint — AI Finance Coach "พี่เงิน"

8 sprints × 2 สัปดาห์ = 16 สัปดาห์ · ทีม 3 คน (P1 Mobile · P2 Backend · P3 AI-ML)
หลักการ: **ทุก sprint ต้อง demo ได้** + **เอาของยาก/เสี่ยงมาทำก่อน**

---

## 📋 ภาพรวมโปรเจกต์

แอปมือถือช่วยคนรุ่นใหม่ (18–30, รายได้ 10–40K) บริหารเงินด้วย AI

| | |
|---|---|
| Platform | Flutter (iOS + Android) |
| 6 ฟีเจอร์หลัก | Smart Transaction (OCR+SMS) · AI Coach "พี่เงิน" · Goal Planning · Dashboard · AI Predictions · Gamification |
| Stack | Flutter+Riverpod+Hive / Node+Express+Prisma / PostgreSQL+Redis / LangChain+GPT / ML Kit OCR / Python+Prophet / FCM |

---

## ⚠️ 4 เรื่องต้องเคลียร์ก่อนเริ่ม (สำคัญกว่าแผน)

1. **🔴 "อ่าน SMS ธนาคาร" ใช้จริงได้แค่ครึ่งเดียว** — iOS อ่านกล่อง SMS ไม่ได้เลย (Apple ไม่เปิด API); Android อ่านได้แต่ Google Play แบนเข้ม (`READ_SMS` ให้เฉพาะ default SMS handler — แอปการเงินมักโดนปฏิเสธตอนรีวิว). → **อย่าให้ฟีเจอร์นี้เป็นทางหลัก** ให้ OCR สลิป + กรอกเร็ว 3-tap เป็นพระเอก, SMS = Android-only/best-effort.
2. **🔴 PDPA ต้องคิดตั้งแต่ Sprint 1** — ข้อมูลการเงิน = sensitive; ส่ง transaction ไป GPT = ส่งข้อมูลส่วนบุคคลออกนอกประเทศ → ต้องมี consent + **ตัด PII ก่อนส่ง LLM** (ส่งตัวเลข/หมวด ไม่ส่งชื่อ-เลขบัญชี) + สิทธิ์ลบ/export ในตัว data model.
3. **🟡 Cold-start ของโค้ช** — ผู้ใช้ใหม่ไม่มีข้อมูล โค้ชแนะนำอะไรไม่ได้ → onboarding ต้องชวนตั้งงบ/รายได้ + เริ่มโหมด "ตั้งงบด้วยกัน".
4. **🟡 Prophet ต้องข้อมูล 2+ เดือน** → ตอน beta ทำนายยังไม่แม่น ต้องมี heuristic fallback.

---

## 🏃 แผน 8 Sprints

### Sprint 1 (W1–2) — Foundation + Walking Skeleton 🦴
**เป้า:** login → กรอก transaction → เห็นบน dashboard ครบ 3 layer

| Role | งาน |
|---|---|
| P1 Mobile | Flutter init, navigation shell, design system/theme, login/register, ฟอร์ม add transaction (3-tap), dashboard list, ตั้ง Hive |
| P2 Backend | repo+CI, schema users/transactions/categories, Prisma migration, Auth (JWT), Transaction CRUD API, deploy staging |
| P3 AI | 🔬 Spike OCR (ML Kit/สลิปไทย — วัด accuracy เป็นตัวเลข) · 🔬 spike LangChain + ออกแบบ context injection + ดราฟต์ persona "พี่เงิน" |

**✅ DoD:** login จริง + add txn ลง DB + dashboard โชว์ + รายงาน OCR accuracy + CI เขียว + Figma design system

### Sprint 2 (W3–4) — Transaction Core + OCR 📸
**เป้า:** สแกนสลิป → review/confirm → save + จัดหมวดอัตโนมัติ *(แก้ HIGH risk "ขี้เกียจกรอก")*

| Role | งาน |
|---|---|
| P1 | กล้อง+OCR UI (scan→confirm→save), category picker, list/edit/delete, offline-first sync (Hive↔API) |
| P2 | Categories API, Budgets CRUD, endpoint aggregate (วัน/สัปดาห์/เดือน/หมวด), seed หมวดเริ่มต้น |
| P3 | OCR post-processing (parse จำนวน/วันที่/ร้าน, template PromptPay), auto-categorize v1 (rule+keyword) |

**✅ DoD:** สแกนสลิป → ยืนยัน → บันทึก+จัดหมวด, ตั้งงบได้ · **บังคับ user confirm ก่อน save เสมอ**

### Sprint 3 (W5–6) — Smart Dashboard + Budget 📊
**เป้า:** layer "เห็นภาพ" — กราฟ + งบ + เตือนเกินงบ (ตรง mockup สไลด์ 1)

| Role | งาน |
|---|---|
| P1 | pie chart (fl_chart), spending by category, budget progress bar, toggle วัน/สัปดาห์/เดือน, การ์ดคงเหลือ |
| P2 | budget engine (spent vs budget), flag เกินงบ, cash-flow summary, Redis cache |
| P3 | auto-categorize v2 (เรียนจาก correction), เตรียม anomaly detection ("Shopee +40%") |

**✅ DoD:** dashboard เหมือน mockup, งบโชว์ progress + เตือนเกินงบ, โหลดไว (cache)

### Sprint 4 (W7–8) — AI Coach "พี่เงิน" v1 🤖 ⭐
**เป้า:** ฟีเจอร์เรือธง — คุยกับพี่เงินด้วยข้อมูลจริงผ่าน context injection *(จบเดือน 2 = core demo ได้)*

| Role | งาน |
|---|---|
| P1 | chat UI (message list, typing, suggestion chips), เก็บ history, entry จาก dashboard |
| P2 | เก็บ chat_messages, context-builder (income/spent/budget_remaining/top_expenses/goals — ตามสไลด์ 5), rate limit, streaming proxy |
| P3 | LangChain chain + prompt persona พี่เงิน (≤150 คำ, actionable, ไม่แนะนำหุ้น), GPT-3.5 default + GPT-4 fallback + cache, disclaimer + ตัด PII |

**✅ DoD:** ถาม "เดือนนี้ใช้เงินเป็นยังไงบ้าง?" → คำตอบ grounded แบบสไลด์ 5

### Sprint 5 (W9–10) — Goals + Smart Notifications 🎯🔔
**เป้า:** ตั้งเป้าออม + AI สร้างแผน + แจ้งเตือนฉลาด

| Role | งาน |
|---|---|
| P1 | หน้า goal (สร้าง/progress "ญี่ปุ่น 45%"), celebrate animation, ขอ permission + notif center |
| P2 | Goals CRUD + คำนวณ progress, FCM, trigger (ใกล้งบ/เกินงบ/สรุปรายวัน), scheduled job |
| P3 | AI สร้างแผนออม (target+deadline+income → แผนรายเดือน), gen ข้อความแจ้งเตือน + คำแนะนำ |

**✅ DoD:** สร้างเป้า → AI เสนอแผน → progress วิ่ง + ได้ push "ใช้เกินงบอาหารแล้วนะ!" (แบบสไลด์ 1)

### Sprint 6 (W11–12) — Predictions + Gamification + 🚀 Beta
**เป้า:** layer ทำนาย + habit loop + ปล่อยให้คนจริงใช้ 30+ คน

| Role | งาน |
|---|---|
| P1 | gamification UI (streak "🔥 12 วัน", badge, level, weekly challenge), แสดง prediction |
| P2 | achievements engine (streak/badge/XP), wiring prediction, event logging สำหรับ beta |
| P3 | Prophet ทำนายรายจ่ายเดือนหน้าต่อหมวด + anomaly alert, deploy FastAPI (+ heuristic fallback ตอนข้อมูลน้อย) |

**✅ DoD:** streak+badge ทำงาน, prediction โชว์ (มี fallback), **Beta ออกถึง 30+ คน**, crash/analytics ไหลเข้า

### Sprint 7 (W13–14) — Hardening: Security · PDPA · Polish 🔒
**เป้า:** ปลอดภัย + ถูกกฎหมาย + ลื่น

| Role | งาน |
|---|---|
| P1 | polish จาก beta, empty/error/loading states, Face ID/Fingerprint lock |
| P2 | security pass (validate/rate limit/secrets), PDPA (consent, ลบบัญชี, export CSV/PDF), privacy policy |
| P3 | AI safety (กัน prompt injection, บังคับ disclaimer, ตัด PII ก่อนส่ง LLM), จูน prediction |

**✅ DoD:** biometric lock, ลบ/export ข้อมูลได้, privacy policy, ไม่มี critical bug

### Sprint 8 (W15–16) — Launch + ส่งงาน 🎉
**เป้า:** ขึ้น store + ปิดงาน senior project

| Role | งาน |
|---|---|
| P1 | store assets (icon/screenshots/listing), release build (TestFlight/Play), fix สุดท้าย |
| P2 | production deploy, monitoring + backup, finalize API docs |
| P3 | deploy model prod, จูน prompt สุดท้าย, dashboard คุมต้นทุน API |
| ทุกคน | เอกสารโปรเจกต์ + demo video + รายงานฉบับสมบูรณ์ |

**✅ DoD:** แอป live ทั้ง 2 store (หรือ TestFlight + Play internal), เอกสารครบ, demo พร้อม

---

## 🔁 ทำทุก Sprint (cross-cutting + ceremonies)
- **Ceremonies:** standup รายวัน · sprint planning + review/demo + retro ทุก 2 สัปดาห์ · sync จันทร์ · code review ทุก PR
- **Tracks ตลอด:** รักษา API contract (P1↔P2 mock ก่อนได้) · test + CI/CD ทุก sprint · analytics ตั้งแต่ Sprint 4
- **ต่างจาก deck:** ดึง OCR + AI spike มาไว้ Sprint 1 (deck ไว้เดือน 2) เพราะเป็น 2 จุดเสี่ยงสูงสุด — รู้เร็วว่าเวิร์คไหมดีกว่าเจอกลางทาง

## 💰 ต้นทุน (จาก deck)
OpenAI 500–1,500฿/ด · Firebase ฟรี · Backend host ฟรี–300฿/ด · DB ฟรี · Apple Dev 3,300฿/ปี · Play 800฿ (ครั้งเดียว) · **รวม ~3,000–8,000฿**
