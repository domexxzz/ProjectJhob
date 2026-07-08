# 🤝 Handoff → ต้า (Mobile Developer)

> จาก: โดม (backend) · วันที่ 3 ก.ค. 2569
> **สรุป:** backend ของ Goals / แผนออม AI / Notifications เสร็จ + push แล้ว → ต้า pull ไป **ผูกข้อมูลจริงแทน mock** ได้เลย

---

## ✅ พร้อมให้ต่อแล้ว
- ธีม **dark + green** + จอ onboarding / dashboard / budget ของต้า → อยู่บน `main` แล้ว
- **Backend ใหม่** (branch `feature/dome-notifications`): Goals CRUD + เติมเงินเข้าเป้า + แผนออม AI + Notification center + budget triggers — ทดสอบผ่านกับ backend จริงทุกตัว
- PR รอ merge: [#7 goals](https://github.com/Domezzxx/Project-JhobSAMNOR/pull/7) · [#8 notifications](https://github.com/Domezzxx/Project-JhobSAMNOR/pull/8)

---

## 1️⃣ ดึงโค้ดล่าสุด
```bash
git fetch origin
# แตก branch ใหม่ต่อยอดจาก integration (มี app ตัวเอง + backend โดม)
git switch -c feature/ta4-wire-api origin/feature/dome-notifications
```
> แค่ดูเฉย ๆ: `git switch feature/dome-notifications`
> พอ PR #7/#8 merge เข้า main แล้ว เปลี่ยนมาใช้ main ได้: `git switch main && git pull`

## 2️⃣ รัน Backend (endpoint ใหม่พร้อมใช้)
```bash
cd backend
cp .env.example .env      # ถ้ายังไม่มี .env — ใส่ TYPHOON_API_KEY ให้ AI ตอบจริง (ไม่ใส่ = fallback rule-based)
npm install
npm run db:push          # สร้าง/อัปเดตตาราง (รวม Goal, Notification)
npm run db:seed          # demo user + หมวดหมู่
npm run dev              # → http://localhost:4000   (เช็ค /health)
```
> ⚠️ **แก้ `.env` ทุกครั้งต้อง restart** (`Ctrl+C` แล้ว `npm run dev`) — dev server ไม่ reload `.env` อัตโนมัติ

## 3️⃣ รัน Flutter app ต่อ backend
```bash
cd ../mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000   # Android emulator
# เว็บ:  flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:4000
```
demo login: **demo@bestimove.ai** / **demo1234**

---

## 4️⃣ Endpoint ผูกหน้าจอได้เลย (แทน mock)

### 🎯 Goals (จอ P8–9)
| Method | Path | Body | ใช้ที่ |
|---|---|---|---|
| GET | `/api/v1/goals` | — | จอ list (คืน `percentage` 0–100) |
| POST | `/api/v1/goals` | `{name, target, deadline?}` | จอสร้างเป้า |
| PATCH | `/api/v1/goals/:id` | `{name?, target?, deadline?}` | จอแก้เป้า |
| POST | `/api/v1/goals/:id/deposit` | `{amount}` | จอเติมเงิน (ชิป 500–6,000) |
| POST | `/api/v1/goals/:id/plan` | — | การ์ด "พี่เงินแนะนำ" (แผนออม AI) |
| DELETE | `/api/v1/goals/:id` | — | ปุ่มลบ |

### 🔔 Notifications (จอ P14 — Notification Center)
| Method | Path | ใช้ที่ |
|---|---|---|
| GET | `/api/v1/notifications` | จอ center → `{notifications[], unreadCount}` |
| PATCH | `/api/v1/notifications/:id/read` | แตะอ่าน |
| POST | `/api/v1/notifications/read-all` | อ่านทั้งหมด |
| POST | `/api/v1/notifications/run-triggers` | ปุ่ม "รีเฟรช" → สร้างแจ้งเตือนใกล้/เกินงบ |

**กติกาข้อมูล:** เงินทุกช่อง = **สตางค์** (÷100 ตอนแสดง, ใช้ `Money.formatBaht()`) · แนบ token: `Authorization: Bearer <token>`

### ตัวอย่างผลจริง (แผนออม AI)
```
POST /goals/<id>/plan →
{ "plan": { "monthlyAmount": 750000, "monthsLeft": 6, "incomePct": 30,
  "milestones": [{pct:25,...},{pct:50,...},{pct:75,...}],
  "message": "ออมเดือนละ 7,500 บาท (~30% ของรายได้)...", "source": "typhoon:..." } }
```

---

## 🩹 ติดปัญหาบ่อย
| อาการ | แก้ |
|---|---|
| แอปต่อ API ไม่ได้ / connection refused | 1) backend รันอยู่ไหม  2) emulator ใช้ **`10.0.2.2`** ไม่ใช่ `localhost`  3) เครื่องจริงใช้ IP ของ PC |
| AI ตอบเป็นสรุปงบซ้ำ ๆ (ไม่ตรงคำถาม) | ยังไม่ใส่ `TYPHOON_API_KEY` ใน `.env` (หรือใส่แล้วไม่ได้ restart) |
| `prisma` error เรื่อง Notification/Goal | รัน `npx prisma generate` แล้ว restart |

## 📌 งานถัดไปของต้า
ดู [tasks/TASK_Ta_Developer.md](tasks/TASK_Ta_Developer.md) — ตอนนี้เหลือ **ผูกข้อมูลจริง** เข้าจอ goals/budget/notif + empty/loading/error ทุกหน้า
คู่มือลง Flutter (ถ้าเครื่องใหม่): [FLUTTER_SETUP_TA.md](FLUTTER_SETUP_TA.md) · Git flow: [GIT_WORKFLOW_GUIDE.md](GIT_WORKFLOW_GUIDE.md)

มีอะไรติดทักโดม/เบสได้เลย 🙌
