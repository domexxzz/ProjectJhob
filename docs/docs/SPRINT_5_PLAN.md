# 🏃 Sprint 5 Plan — AI Finance Coach "พี่เงิน"

> ช่วงเวลา: **3–16 ก.ค. 2569** (2 สัปดาห์) · ต่อจาก Sprint 1–4 (เสร็จแล้ว ✅)
> อ้างอิง: [SPRINT_STATUS.md](SPRINT_STATUS.md) · [SPRINT_PLAN.md](SPRINT_PLAN.md) · แบบเสนอโครงงาน P01

## 🎯 เป้าหมาย Sprint 5
ปิด backlog หน้าจอที่ค้าง + เปิดฟีเจอร์ **Goals + Smart Notifications** และวางรากฐาน **เอกสารวิศวกรรม (SE) + การทดสอบ** ให้พร้อมป้องกันโครงงาน — โดยงานของทุกคน **แมปตรงกับ rubric ที่ตัวเองถูกให้คะแนน**

**Demo ปลาย sprint:** ผู้ใช้ใหม่ → onboarding → ตั้งเป้าออม → AI เสนอแผนรายเดือน → ได้แจ้งเตือน "ใช้เกินงบอาหารแล้วนะ!" → ดูประวัติ/แก้งบได้

---

## 👥 ทีม & บทบาท (ตาม rubric ใหม่)

| ชื่อเล่น | ชื่อ-สกุล | รหัส | บทบาท (rubric) | โฟกัส |
|---|---|---|---|---|
| **แตงกวา** | ชนิสรา นันสถิตย์ | B6702786 | **Software Engineer** | วางแผน/requirement/diagram/ทดสอบ/เอกสาร |
| **ต้า** | กฤตเมธ เหลาสุพะ | B6702809 | **Developer** (Mobile/UI) | หน้าจอ Flutter + design system + flow |
| **โดม** | จิณณพัฒน์ บุญแพง | B6703158 | **Developer** (Full-stack/AI) | Goals/Notif/AI end-to-end (screen + backend) |

> 📄 งานละเอียดของแต่ละคน: [tasks/TASK_Taengkwa_SoftwareEngineer.md](tasks/TASK_Taengkwa_SoftwareEngineer.md) · [tasks/TASK_Ta_Developer.md](tasks/TASK_Ta_Developer.md) · [tasks/TASK_Dome_Developer.md](tasks/TASK_Dome_Developer.md)

---

## 🧭 หลักการแบ่งงานให้ตรง rubric

- **แตงกวา (SE, rubric Software Eng 70):** ไม่โฟกัส "จำนวนหน้าจอ" แต่โฟกัส **process artifacts** ที่ถูกให้คะแนนโดยตรง — Project Planning & Monitoring (10), Requirement Engineering (6), Design & Implementation/diagram (10), Testing Process (8), จำนวน Component/Feature/Function/Task (15, เป็นเจ้าของ "บัญชีฟีเจอร์" ของทีม), ความเข้าใจในงาน (6)
- **ต้า + โดม (Developer, rubric Dev/IOT 70):** ถูกให้คะแนนจาก **จำนวน Screen (10, auto) + จำนวน Component/Feature/Function (15, auto) + Flow ถูกต้อง (10) + ไม่มี Bug (10) + เทคนิคการพัฒนา (5) + ความสวยงาม/ใช้ง่าย (5)** → ทั้งคู่ต้องมี **หน้าจอที่ทำงานจริง end-to-end** และ **flutter analyze ผ่าน 0 error**
  - **ต้า** = เน้นปริมาณหน้าจอ + UI polish (Design system, Onboarding, Budget Edit, History)
  - **โดม** = เน้นความลึกทางเทคนิค + full-stack (Goals, Notifications, AI savings-plan — ทำทั้ง screen + API/AI) → ได้คะแนน "เทคนิคการพัฒนา" สูง

---

## 🛠️ Environment & CI — พร้อมแล้ว (3 ก.ค.) → หลักฐาน rubric
เครื่อง dev ตั้งค่าครบ ทีมเริ่ม code + build/run ได้ทันที (รายละเอียด: [SPRINT_STATUS.md](SPRINT_STATUS.md))

| พร้อมใช้ | ป้อน rubric ของใคร |
|---|---|
| Android build + emulator `pixel_ai` รันแอปได้ (ต่อ backend `10.0.2.2:4000` จริง) | ต้า+โดม: "รันบน device / Flow ครบ / ไม่มี bug" |
| Windows `.exe` + Web (Edge) build ผ่าน | ต้า+โดม: ความสมบูรณ์/จำนวน platform |
| `codemagic.yaml` (CI cloud: android/ios/macos/web) | แตงกวา: **Testing Process (CI)** + Project Monitoring |
| `flutter analyze` = 0 error + platform guard `speech_to_text` | ต้า+โดม: "ไม่มี bug/เทคนิค" · แตงกวา: test evidence |

→ แตงกวาแปลงเป็นเอกสารให้คะแนนที่ **SE-7** (ตารางด้านล่าง)

---

## 📦 Backlog Sprint 5 (แยกตามเจ้าของ)

### ต้า — Mobile/UI (ทุก API พร้อมแล้ว → บล็อกน้อย) · 🎨 มี mockup ครบทุกจอแล้ว
| ID | งาน | ไฟล์หลัก | Mockup |
|---|---|---|---|
| TA-1 | Design System widgets (ทำก่อน) | `lib/app/widgets/*.dart` | — |
| TA-2 | Onboarding 3 สไลด์ + avatar พี่เงิน | `lib/features/onboarding/` | **P4** |
| TA-3 | Budget (ดู + เพิ่ม/แก้/ลบงบ) | `lib/features/budgets/budget_edit_screen.dart` | **P10–11** |
| TA-4 | Transaction History + filter/search | `lib/features/transactions/history_screen.dart` | — |
| TA-5 | Empty/Loading/Error states ทุกหน้า | (ใช้ widget จาก TA-1) | — |
| TA-6 🆕 | หน้าแก้ไขยอดคงเหลือ | `lib/features/transactions/edit_balance_screen.dart` | **P7** |
| TA-7 🆕 | เมนู / การตั้งค่า | `lib/features/settings/settings_screen.dart` | **P15** |

### โดม — Full-stack/AI (สร้าง API ใหม่ + screen)
| ID | งาน | ไฟล์หลัก | สถานะ / Mockup |
|---|---|---|---|
| DM-1 | Goals end-to-end: `/goals` CRUD + Goals screen (list/สร้าง/รายละเอียด+ring/celebrate) | `backend/.../goals/*` + `lib/features/goals/` | ⚠️ ใหม่ · 🎨 **P8–9** |
| DM-2 | Notifications: FCM + trigger + Notif Center screen | `backend/.../notifications/*` + `lib/features/notifications/` | ⚠️ ใหม่ · 🎨 **P14** |
| DM-3 | AI Savings Plan: target+deadline+income → แผนรายเดือน | `backend/.../goals/plan` (Typhoon/heuristic) | ⚠️ ใหม่ |

### แตงกวา — Software Engineer (เอกสารใน `docs/se/`)
| ID | งาน | ส่งมอบ |
|---|---|---|
| SE-1 | Feature/Function/Task master list + WBS | `docs/se/feature_list.md` |
| SE-2 | Project Plan + Monitoring (Scrum board, Gantt, burndown) | `docs/se/project_plan.md` |
| SE-3 | Requirement Engineering (user story + use case + RTM) | `docs/se/requirements.md` |
| SE-4 | Design diagrams (Architecture, Component, UML, Sequence, ER, Wireframe) | `docs/se/design/*.md` |
| SE-5 | Test Plan + Test Cases + UAT + Test Report | `docs/se/test_plan.md` |
| SE-6 | System understanding / demo-defense + Innovation (CLO6) | `docs/se/innovation.md` |
| SE-7 🆕 | Build & CI/CD Evidence — test environment matrix (android/win/web + Codemagic) | `docs/se/test_environment.md` |

---

## 🔗 ลำดับ dependency (ทำให้ขนานกันได้)

```
แตงกวา SE-1/SE-3 (feature list + requirement)
        │  (นิยาม field/flow)
        ▼
โดม DM-1 (/goals API) ──────► ต้า/โดม ผูก Goals screen
โดม DM-2 (FCM/trigger) ─────► Notif Center
        ▲
แตงกวา SE-4 (ER/Sequence/Wireframe) ← ทำคู่ตอน design
        │
แตงกวา SE-5 (test cases) = เช็คลิสต์ review PR ของ ต้า+โดม
```

- **API ที่ต้องสร้างก่อน (โดม):** `/goals` → ปลดบล็อก Goals screen. เริ่ม DM-1 วันแรก
- **แตงกวา** ส่ง `feature_list.md` + `requirements.md` ภายใน **2–3 วันแรก** เพื่อให้ dev มี field/flow อ้างอิง
- **Wireframe/ER (SE-4)** ทำคู่ขนานตอน dev เริ่ม เพื่อไม่บล็อก

---

## ✅ Definition of Done (Sprint 5)
- [ ] ต้า: 4 หน้าจอใหม่ทำงานจริง + `flutter analyze` = 0 error + ทุกหน้ามี empty/loading/error
- [ ] โดม: `/goals` + `/notifications` API ผ่าน + Goals/Notif screen ผูกข้อมูลจริง + AI เสนอแผนออมได้
- [ ] แตงกวา: `docs/se/` ครบ **7 ไฟล์** (feature list, plan, requirement+RTM, diagram set, test plan, innovation, **test_environment**)
- [ ] ทุกหน้าใหม่ **build + run ผ่านบน Android emulator** (หลักฐานใน SE-7) + Codemagic CI เขียว
- [ ] Demo flow เต็ม: onboarding → ตั้งเป้า → AI แผน → แจ้งเตือนเกินงบ → history/budget edit
- [ ] ทุก PR ผ่าน review (เช็คด้วย Acceptance Criteria ของแตงกวา) → merge เข้า `main`

## 🔭 มองไป Sprint 6–8 (context ให้ SE วางแผนล่วงหน้า)
- **S6:** AI Predictions (Python + Prophet) + Gamification (streak/badge/level) + 🚀 Beta 30+ users
- **S7:** Hardening — Security, PDPA (consent/ลบบัญชี/export), biometric lock, AI safety (ตัด PII)
- **S8:** Launch — store assets, production deploy, เอกสาร + demo video ฉบับสมบูรณ์

---

## 🔁 Ceremonies
- Standup สั้นทุกวัน (เมื่อวาน/วันนี้/ติดอะไร) · Planning ต้นสัปดาห์ · Review+Demo + Retro ปลาย sprint
- Code review ทุก PR (แตงกวารีวิวด้วย Acceptance Criteria ของตัวเอง = ปิด loop SE↔Dev)
- 📖 ขั้นตอน Git: [GIT_WORKFLOW_GUIDE.md](GIT_WORKFLOW_GUIDE.md)
