# 📊 Sprint Status — AI Finance Coach "พี่เงิน"

> อัปเดต: 23 มิ.ย. 2569 · branch `feature/sprint4-ai-coach` (commit 0512591) · master = 524d277

**ภาพรวม:** Sprint 1–4 เสร็จครบ ✅ + ทำเกินแผนหลายอย่าง (multimodal coach, UI redesign, profile/budget). เหลือ Sprint 5–8

---

## ✅ Sprint 1 — Foundation + Walking Skeleton  (DONE)
- [x] Backend: Auth (JWT+bcrypt), Transaction CRUD, Prisma schema 7 ตาราง, `/health`
- [x] DB: SQLite (dev) — สลับ Postgres ได้
- [x] Mobile: auth (login/register), dashboard, add-transaction (3-tap), Hive
- [x] AI spike: OCR slip parser, โค้ช hello-world
- [ ] CI (GitHub Actions), deploy staging, OCR accuracy report บนสลิปจริง 20–30 ใบ

## ✅ Sprint 2 — Transaction Core + OCR  (DONE)
- [x] OCR slip parser + auto-categorize (`POST /transactions/analyze-text`)
- [x] UI สแกนสลิป (mock OCR templates → กรอกฟอร์มอัตโนมัติ + ให้ user ยืนยัน)
- [x] Categories API, Budgets CRUD, transaction edit/delete
- [x] Offline-first sync (Hive — cache + pending queue)
- [ ] กล้องจริง + ML Kit on-device (ต้องเทสบนมือถือจริง)

## ✅ Sprint 3 — Smart Dashboard + Budget  (DONE)
- [x] Pie chart (fl_chart) + spending by category + toggle วัน/สัปดาห์/เดือน
- [x] Budget engine + `/budgets/status` (spent/remaining/%/เกินงบ)
- [x] Aggregate endpoint (`/transactions/aggregate?by=category|time`)
- [x] Anomaly detection (เตือนเมื่อใช้เกินเฉลี่ยหมวด ≥40%)
- [x] Cache layer (Redis + in-memory fallback)

## ✅ Sprint 4 — AI Coach "พี่เงิน"  (DONE + เกินเป้า)
- [x] Chat UI + history + context-builder (ข้อมูลจริงตามสไลด์ 5)
- [x] Persona = **ที่ปรึกษาการเงินมืออาชีพ** (ออม/ลงทุน/หนี้ แบบหลักการ, ไม่ตัดสิน, มี disclaimer, ไม่ชี้หุ้นรายตัว)
- [x] **Multi-provider LLM**: Typhoon (live) → Groq → OpenAI → rule-based fallback
- [x] 🎁 BONUS: avatar อนิเมชัน (idle/listening/thinking), รับ**เสียง** (speech_to_text), รับ**รูป/สลิป** (Typhoon OCR `/chat/ocr`)
- [x] 🎁 Markdown rendering ในฟองแชท + แก้คำตอบโดนตัด (max_tokens 1500)

## 🎁 นอกแผน (Bonus) — DONE
- [x] **UI redesign สไตล์ fintech (Dime)**: gradient header เต็มจอ + ภาพประกอบ (เหรียญ฿+กราฟ) + quick actions เลื่อนแนวนอน + bottom nav + center FAB + การ์ดเงานุ่ม + pill toggle
- [x] หน้า **Budget** (`/budgets`) + **Profile** (`/profile`, มี logout)
- [x] Web release build + static deploy (`:5599`) · GitHub repo (private) + feature-branch workflow

---

## 🔲 เหลือทำ (Sprint 5–8)

### Sprint 5 — Goals + Smart Notifications
- [ ] หน้า Goals (ตั้งเป้าออม + progress + celebrate) — schema `Goal` มีแล้ว
- [ ] AI สร้างแผนออม (target+deadline+income → แผนรายเดือน)
- [ ] Push notifications (FCM) — ใกล้งบ/เกินงบ/สรุปรายวัน

### Sprint 6 — Predictions + Gamification + Beta
- [ ] AI Predictions (Python + Prophet) ทำนายรายจ่ายเดือนหน้า + anomaly
- [ ] Gamification (streak logic, badges, level, weekly challenge) — schema `Achievement` มีแล้ว
- [ ] 🚀 Beta release 30+ users + analytics

### Sprint 7 — Hardening (Security · PDPA · Polish)
- [ ] Security pass (rate limit ทั่ว, validation, secrets), biometric lock
- [ ] PDPA: consent, ลบบัญชี, export CSV/PDF, privacy policy
- [ ] AI safety: ตัด PII ก่อนส่ง LLM, กัน prompt injection

### Sprint 8 — Launch
- [ ] Store assets + release build (TestFlight/Play), production deploy + monitoring
- [ ] เอกสารโปรเจกต์ + demo video + รายงานฉบับสมบูรณ์

---

## 🔧 Cross-cutting ที่ค้าง
- [ ] รันบนมือถือจริง — เทส permission เสียง/กล้อง (Expo/Flutter device)
- [ ] CI/CD + deploy staging (Railway/Render)
- [ ] เปิด PR `feature/sprint4-ai-coach` → `master`
- [ ] 🔑 rotate Typhoon key (เคยโผล่ใน log ระหว่าง dev)
- [ ] ลง Redis จริง (ตอนนี้ใช้ in-memory fallback) ตอนขึ้น prod
