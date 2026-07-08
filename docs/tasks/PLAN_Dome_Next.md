# 🗺️ แผนงานต่อ — โดม (หลัง DM-1/2/3)

> ต่อจาก [PLAN_Dome_Sprint5.md](PLAN_Dome_Sprint5.md) · อัปเดต 3 ก.ค. 2569 · branch ปัจจุบัน `feature/dome-notifications`

## ✅ เสร็จแล้ว (ทดสอบ + push + เปิด PR)
| งาน | สถานะ | อ้างอิง |
|---|---|---|
| DM-1 Goals API (CRUD + deposit) | ✅ | commit `9546fbf` · [PR #7](https://github.com/Domezzxx/Project-JhobSAMNOR/pull/7) |
| DM-3 AI Savings Plan (`/goals/:id/plan`) | ✅ | commit `5297521` · PR #7 |
| DM-2 Notifications (center + triggers + FCM guarded) | ✅ | commit `4c81df4` · [PR #8](https://github.com/Domezzxx/Project-JhobSAMNOR/pull/8) |
| Merge main (mobile ต้า) + docs + handoff | ✅ | commit `35f570b`, `9f41448` |

---

## 🎯 เหลือปิดใน Sprint 5

### N1 · DM-6 · AI Recommendation Engine ⭐ทำก่อน (เร็วสุด — reuse ของเดิม)
> การ์ด "แนะนำสำหรับคุณ" ใน mockup Goals/Budget/Dashboard → engine เดียวป้อนทุกหน้า
- `GET /api/v1/recommendations?context=goal|budget|dashboard`
- **reuse ที่มีแล้ว:** `buildContext()` (ไม่มี PII) + `chatComplete()` (ที่ refactor ไว้ตอน DM-3) → เหลือแค่เขียน prompt + heuristic fallback
- ส่ง shape ให้ **ต้า** ผูกการ์ด rec ใน Budget/Dashboard
- branch `feature/dome-recommendations` (base: `feature/dome-notifications`)
- ✅ DoD: การ์ด rec ทุก context โชว์ข้อความจริงจาก AI (มี fallback) + `source` = `typhoon:...`

### N2 · DM-5 · Subscription Tracker
> ฟีเจอร์ใหม่จาก mockup P14 (Netflix/Spotify/YouTube รายเดือน)
- **Backend:** ตาราง `Subscription { name, amount, cycle, nextBilling, logo? }` (migrate เหมือน Notification) + `GET/POST/PATCH/DELETE /api/v1/subscriptions`
- ต่อ **DM-2:** trigger เตือนก่อนตัดเงิน (reuse `createNotification` + cron)
- **Mobile:** `lib/features/subscriptions/subscriptions_screen.dart` (โลโก้+ยอด/เดือน+วันตัด + สรุปยอดรวม + เพิ่ม/แก้/ลบ) เข้าจากเมนู
- branch `feature/dome-subscriptions`
- ✅ DoD: เพิ่ม sub → ลิสต์ + ยอดรวมถูก + เตือนก่อนตัด · เทสผ่าน

### N3 · Mobile wiring — จอของโดม (ผูกข้อมูลจริง)
- **Notification Center** (`lib/features/notifications/`): ผูก `GET /notifications` (+badge) · `PATCH /:id/read` · ปุ่มรีเฟรช = `POST /run-triggers`
- **Goals — การ์ด "พี่เงินแนะนำ"**: ผูก `POST /goals/:id/plan` (คุยกับต้าว่าใครทำจอ list/detail — ต้ามี goals screen อยู่แล้ว)
- ✅ DoD: 2 จอนี้ผูกข้อมูลจริง (ไม่ mock) + empty/loading/error + ธีม dark+green

### N4 · FCM push (เปิดของจริง) — 🟡 ต้องมี Firebase creds
- `cd backend && npm i firebase-admin`
- สร้าง Firebase project → service account JSON → env `FIREBASE_SERVICE_ACCOUNT`
- ทดสอบ push บน **Android จริง** (iOS ต้องตั้ง APNs เพิ่ม)
- (โค้ด `fcm.ts` เขียน guarded ไว้แล้ว — ใส่ creds แล้วทำงานทันที)

### N5 · ปิด Sprint 5
- [ ] `flutter analyze` = 0 error + backend `npm run typecheck` ผ่าน
- [ ] merge **PR #7 → main** ก่อน แล้ว **PR #8**
- [ ] อัปเดต `SPRINT_STATUS.md` (Goals/Notif/Plan/Rec/Subscription = done)
- [ ] เปิด `NOTIF_CRON=on` บน staging

---

## 🔭 บริดจ์เข้า Sprint 6 (งานโดม)

### S6-1 · DM-4 · Achievements Engine → Gamification
- service คำนวณ **streak / badge / XP / level** (ตาราง `Achievement` + `User.streak/level` มีแล้ว)
- `GET /api/v1/achievements` · `GET /api/v1/gamification/status`
- feed UI (streak "🔥 12 วัน", badge, level, weekly challenge)

### S6-2 · AI Predictions (Python + Prophet) 🔴 stack ใหม่ (เสี่ยง)
- **FastAPI** service ทำนายรายจ่ายเดือนหน้าต่อหมวด + anomaly
- Node proxy `GET /api/v1/predictions` + **heuristic fallback** (ตอนข้อมูล < 2 เดือน)
- การ์ด prediction บน dashboard
- ⚠️ Prophet ต้องข้อมูล 2+ เดือน → เริ่ม heuristic ก่อน, เก็บข้อมูล beta ไปด้วย

### S6-3 · Beta support (30+ users)
- event logging + crash/analytics wiring
- deploy staging (Railway/Render) + Redis จริง (ตอนนี้ in-memory fallback)

---

## 🔗 ลำดับ + ความเสี่ยง
```
N1 DM-6 rec (เร็ว, reuse) ──► ปลดการ์ด "แนะนำ" ให้ ต้า ทุกหน้า
        ▼
N2 DM-5 subscription (migrate + CRUD + screen)
        ▼
N3 wiring จอ notif/goals ──► N5 ปิด sprint (analyze + merge PR)
N4 FCM ⟶ รอ Firebase creds (ทำคู่ขนานได้)
        ▼
S6 Gamification → Predictions (Prophet) → Beta
```
- **ทำ N1 ก่อน** เพราะ reuse `buildContext`+`chatComplete` → เสร็จเร็ว + ปลดบล็อกการ์ด rec ของ ต้า
- **S6-2 (Prophet)** เสี่ยงสุด (stack Python ใหม่) → เผื่อเวลา + มี heuristic fallback

## 🌿 Git branches
`feature/dome-recommendations` · `feature/dome-subscriptions` · `feature/dome-gamification` · `feature/dome-predictions`
(แตกจาก `feature/dome-notifications` หรือ `main` หลัง PR #7/#8 merge)

## ✅ เช็ค rubric (Developer/IOT — ต่อยอดคะแนน)
- **Screen เพิ่ม:** Subscription + Notif Center + (gamification/prediction cards) → ช่อง #1
- **เทคนิค (#5) ⭐:** rec/prediction AI + FCM + cron + FastAPI = จุดแข็งโดม
- **CLO6:** DM-6 rec + Prophet prediction = นวัตกรรมเพิ่ม

---

## 🚀 เริ่มวันนี้ (3 step — DM-6)
1. `git switch -c feature/dome-recommendations` (จาก `feature/dome-notifications`)
2. สร้าง `backend/src/modules/recommendations/recommendations.routes.ts` → `GET /?context=` → เรียก `buildContext()` + `chatComplete()` (prompt สั้น) + heuristic fallback
3. `curl "/api/v1/recommendations?context=budget"` (Bearer) → เช็ค `source` = `typhoon:...` แล้ว commit
