## 📱 TASK — ต้า (Developer · Mobile/UI)

> **โฟกัสรอบนี้:** implement หน้าจอ Flutter ให้ **ครบ จำนวนเยอะ ทำงานจริง ไม่มี bug และสวยเหมือนกันทั้งแอป** ตาม spec/wireframe ที่แตงกวา (SE) เตรียมให้
> Stack: **Flutter + Riverpod + go_router** · theme กลางที่ `lib/app/theme.dart` (มี `softCard()`, `kSoftShadow`, `AppColors`, chip/pill theme พร้อมใช้)

> 🎨 **Mockup อ้างอิง (Canva "AI Personal" — [design](https://www.canva.com/design/DAHNlIeU6mc/edit)):** ทุกหน้ามีแบบให้ build ตามแล้ว — เปิดหน้า Canva ที่ระบุก่อนลงมือ
>
> | หน้า Canva | จอ | งานของต้า |
> |---|---|---|
> | P4 | ยินดีต้อนรับ (Onboarding) | TA-2 |
> | P10–11 | งบประมาณ (Budget) — list/เพิ่ม/แก้/ลบ + จอเติมงบ (ชิปจำนวนเร็ว) + สถานะเกินงบแดง 110% | TA-3 |
> | P7 | แก้ไขยอดคงเหลือ | **TA-6 🆕** |
> | P15 | เมนู / การตั้งค่า (บัญชี/แก้โปรไฟล์/ความเป็นส่วนตัว+Face ID) | **TA-7 🆕** |
> | P13 | แดชบอร์ด + จัดการหมวดหมู่ (color-wheel picker) | **TA-8 🆕** |
>
> *(Login P5 · หน้าหลัก P6 · สแกนสลิป P12 = ทำแล้ว → ใช้ mockup ปรับ polish ให้ตรงดีไซน์)*

> 🎨🖤 **มติธีม (สำคัญ):** ยึด mockup = **dark + green** → เริ่มด้วย **TA-0** รื้อ `theme.dart` เป็น dark + accent เขียวก่อน แล้วทุกหน้าค่อยทำต่อบนธีมใหม่ (อย่าเริ่มหน้าจอก่อนธีมเสร็จ — ไม่งั้นแก้สีซ้ำทั้งแอป)

---

### 🎯 ทำไมงานนี้ = คะแนนของต้า (rubric: Developer/IOT, เต็ม 70)

**CLO5 (55)**
| # | เกณฑ์ในใบให้คะแนน | คะแนน | ทำยังไงให้ได้ |
|---|---|:--:|---|
| 1 | **จำนวน Screen** (นับอัตโนมัติ) | 10 | ส่ง 5 หน้าใหม่ (Onboarding, Budget, History, Edit Balance, Settings) ตาม mockup + refactor หน้าเดิม |
| 2 | **จำนวน Component/Feature/Function** (auto) | 15 | แยก widget ใช้ซ้ำใน `lib/app/widgets/` ให้เยอะ (นับเป็น component) |
| 3 | ประสิทธิผล — **Flow ครบถ้วนถูกต้อง** | 10 | ทุกปุ่มไปถูกหน้า, กลับได้, ไม่มีทางตัน |
| 4 | ประสิทธิผล — **โปรแกรมทำงานได้ ไม่มี Bug** | 10 | `flutter analyze` = 0 error + จัดการทุก state |
| 5 | ประสิทธิภาพ — **เทคนิคการพัฒนา** | 5 | Riverpod state, go_router, ไม่ hardcode, reuse |
| 6 | **ความพึงพอใจ/สวยงาม/ใช้ง่าย** | 5 | design system เดียวกันทั้งแอป + polish |

**CLO6 (15):** UI สร้างสรรค์ — celebrate animation, micro-interaction, skeleton loader, empty-state ที่มีคาแรกเตอร์ "พี่เงิน"

> 💡 rubric ของต้านับ **Screen + Component แบบอัตโนมัติ** → ยิ่งหน้าจอ/widget เยอะและทำงานจริง ยิ่งได้คะแนน แต่ **ต้องไม่มี bug** (ช่อง 10 คะแนน) → คุณภาพสำคัญกว่าปริมาณลวก ๆ

---

## 📍 สถานะจริงในโปรเจกต์ตอนนี้ (อย่าทำซ้ำ)
- **หน้าที่มีแล้ว:** Login, Register, Dashboard (`/`), Add/Edit Transaction (`/add`), Chat (`/chat`), Budget view (`/budgets` — อยู่ใน `dashboard_screen.dart`), Profile (`/profile`)
- **ยังไม่มี:** `lib/app/widgets/` (widget กลาง), Onboarding (P4), Budget **Edit** form (P10–11), Transaction History, **หน้าแก้ไขยอดคงเหลือ (P7)**, **เมนู/การตั้งค่า (P15)**, empty/loading/error ที่สม่ำเสมอ
- Route ปัจจุบันอยู่ที่ `lib/app/router.dart` — เพิ่ม route ใหม่ที่นี่

---

## งานย่อย (เรียงตามลำดับแนะนำ)

### TA-0 · Refactor ธีมเป็น dark + green ⭐⭐ทำก่อนสุด (blocker ทั้งทีม)
> มติทีม: ยึด mockup Canva (ดำ + เขียว) — เปลี่ยน `lib/app/theme.dart` จาก ม่วง/สว่าง → **dark + green** ให้ตรง Canva ก่อนแตะหน้าจอใด ๆ
- `AppColors`: `primary` → เขียว (~`#2ECC71`), `bg` → ดำ (~`#0E1512`), `surface`/การ์ด → เทาเข้ม (~`#161D1A`), ข้อความหลักขาว/รองเทาอ่อน · คง `income` เขียว / `expense` แดง
- `ThemeData`: `brightness: Brightness.dark`, `scaffoldBackgroundColor` = bg ดำ, ปุ่ม primary เขียว, chip/pill/input ให้เข้าธีมมืด
- `softCard()` / `kSoftShadow`: ปรับพื้นการ์ดเทาเข้ม + เงาบางลงให้เหมาะ dark
- ✅ DoD: ทุกหน้าเดิม (dashboard/chat/budget/profile) กลายเป็นธีมมืด+เขียวอัตโนมัติ ไม่มีจุดขาวโพลน/ตัวอักษรอ่านไม่ออก · `flutter analyze` 0 error
- 🎯 = ช่อง #6 (สวยงาม/สม่ำเสมอ) และเป็นฐานให้โดมทำหน้าจอบนธีมเดียวกัน

### TA-1 · Design System — แยก component ใช้ซ้ำ ⭐ทำก่อน
สร้าง `lib/app/widgets/` รวม widget กลาง:
- `AppCard` (การ์ดขาว+เงานุ่มจาก `softCard()`), `SectionHeader` (ไอคอน+หัวข้อ+ปุ่ม "ดูทั้งหมด"), `AppChip`, `PrimaryButton`, `EmptyState`, `LoadingState` (skeleton), `ErrorState` (มีปุ่มลองใหม่)
- ✅ DoD: หน้าเดิม (dashboard/chat/budget/profile) refactor มาใช้ widget กลาง — ไม่มีการ์ด/ปุ่ม hardcode ซ้ำ
- 🎯 ตอบช่อง #2 (component count) + #6 (ความสม่ำเสมอ)

### TA-2 · หน้า Onboarding / Welcome — 🎨 mockup P4 (ยินดีต้อนรับ)
- 3 สไลด์แนะนำฟีเจอร์ (สแกนสลิป · โค้ช AI · ตั้งงบ) + avatar พี่เงินทักทาย (ตาม mockup) + ปุ่ม "เริ่มใช้งาน" → `/login`
- ไฟล์: `lib/features/onboarding/onboarding_screen.dart` + route `/onboarding`
- ✅ DoD: เลื่อนสไลด์ได้ (PageView) + dot indicator + ปุ่ม skip → เก็บ flag ว่าเคยดูแล้ว (Hive) ไม่โชว์ซ้ำ

### TA-3 · หน้างบประมาณ (ดู + เพิ่ม/แก้/ลบงบ) — 🎨 mockup P10–11
- ตอนนี้ `/budgets` **ดูได้อย่างเดียว** → ทำหน้า Budget เต็มตาม mockup: การ์ดงบรายหมวด + progress + ปุ่มเพิ่ม/แก้/ลบ (mockup มีหลาย state — ปกติ/ใกล้เต็ม/เกินงบ สีแดง)
- ไฟล์: `lib/features/budgets/budget_edit_screen.dart` (+ แยกส่วนดูออกเป็น widget ถ้าจำเป็น)
- **API พร้อมแล้ว** (ยืนยันจากโค้ด): `POST /api/v1/budgets` `{categoryId?, amount, period}` · `PATCH /api/v1/budgets/:id` · `DELETE /api/v1/budgets/:id`
- ⚠️ validation ตาม spec แตงกวา: `amount > 0` (สตางค์), 1 หมวด/period ตั้งซ้ำไม่ได้ (backend คืน error ไทย — โชว์ให้ผู้ใช้)
- ✅ DoD: เพิ่มงบ → กลับมาเห็นใน progress section จริง (invalidate provider ให้รีเฟรช)

### TA-4 · หน้าประวัติรายการ (Transaction History)
- รายการเต็ม + ฟิลเตอร์ (เดือน/หมวด/ประเภท) + ช่องค้นหา (note)
- ไฟล์: `lib/features/transactions/history_screen.dart`
- **API พร้อม:** `GET /api/v1/transactions?month=YYYY-MM&type=expense` (คืน `summary {income,expense,balance}` ด้วย)
- ✅ DoD: ฟิลเตอร์ทำงาน + แตะรายการ → แก้ไขได้ (reuse `AddTransactionScreen` ผ่าน `/add` + `extra`)

### TA-5 · Empty / Loading / Error states ทุกหน้า
- ใส่ skeleton ตอนโหลด + ภาพ/ข้อความตอนว่าง + ปุ่มลองใหม่ตอน error (ใช้ widget จาก TA-1)
- ✅ DoD: ปิดเน็ตแล้วแอป **ไม่ค้าง/ไม่ขาว** — มี state บอกผู้ใช้เสมอ → ตอบช่อง #4 (ไม่มี bug) โดยตรง

### TA-6 · หน้าแก้ไขยอดคงเหลือ 🆕 — 🎨 mockup P7 (แก้ไขยอดคงเหลือ)
- จอปรับ/แก้ยอดคงเหลือของบัญชี (mockup = จอหลัก + แผงแก้ไขด้านข้าง) → ผู้ใช้แก้ยอดเริ่มต้น/ปรับให้ตรงจริง แล้วระบบบันทึกเป็น adjustment transaction
- ไฟล์: `lib/features/transactions/edit_balance_screen.dart` (หรือ bottom sheet) + route/entry จากหน้าหลัก
- **API:** ใช้ transaction ที่มีอยู่ (`POST /transactions` type adjustment) — เช็คกับโดมถ้าต้องเพิ่ม field
- ✅ DoD: แก้ยอด → dashboard/ยอดคงเหลืออัปเดตจริง (invalidate provider) + validate จำนวน (สตางค์)

### TA-7 · หน้าเมนู / การตั้งค่า 🆕 — 🎨 mockup P15 (เมนู, การตั้งค่า)
- รวมเมนู: โปรไฟล์ · การตั้งค่า (ธีม/ภาษา/แจ้งเตือน) · จัดการหมวดหมู่ · เกี่ยวกับ · ออกจากระบบ (mockup มีลิสต์เมนู + toggle)
- ไฟล์: `lib/features/settings/settings_screen.dart` + route `/settings` (ต่อยอดจาก `/profile` เดิม)
- ✅ DoD: ทุกเมนูลิงก์ไปถูกหน้า/แสดง dialog · toggle การตั้งค่าเก็บใน Hive · logout ทำงาน
- 💡 หน้านี้ = **นับ Screen + Component เพิ่ม** (ตอบช่อง #1, #2 rubric)

### TA-8 · แดชบอร์ด + จัดการหมวดหมู่ 🆕 — 🎨 mockup P13 (แดชบอร์ด)
- Dashboard: **กราฟเส้น** (รายรับ-จ่ายตามเวลา) + **กราฟวงกลม** สัดส่วนหมวด (fl_chart) + รายการสรุปต่อหมวด (เรียง/toggle)
- **จัดการหมวดหมู่**: ลิสต์หมวด + ติ๊กเลือก + **เครื่องมือเลือกสีหมวด (color wheel + ช่อง HEX)** ตาม mockup
- ไฟล์: `lib/features/dashboard/` (แยก widget กราฟ) + `lib/features/categories/category_manage_screen.dart`
- ⚠️ บันทึกสีหมวดต้องมี API — คุยโดมขอ `PATCH /categories/:id` (field `color`) ถ้ายังไม่มี (ตอนนี้ categories เป็น GET อย่างเดียว)
- ✅ DoD: กราฟโชว์ข้อมูลจริง + เปลี่ยนสีหมวด → สีอัปเดตทั้งกราฟ/รายการ

---

## 📐 กติกาหน้าตา (ตาม mockup Canva — ช่อง 5 คะแนน "สวยงาม")
- **ธีม: dark + green** (หลัง TA-0) — พื้นดำ, การ์ดเทาเข้ม, ปุ่ม/ไฮไลต์เขียว · รายรับเขียว `income` · รายจ่าย/เกินงบ แดง `expense`
- **องค์ประกอบซ้ำจาก mockup** (ทำเป็น widget กลางใน TA-1): header เขียวมี avatar + กระดิ่งแจ้งเตือน · **มาสคอต "พี่เงิน"** พร้อมข้อความให้กำลังใจ · การ์ด **"แนะนำสำหรับคุณ"** (ข้อมูลจาก AI ของโดม) · **progress bar** (เขียวปกติ / แดงเมื่อเกิน 100%) · **ชิปจำนวนเร็ว** (500–6,000) ในจอเติมเงิน · **bottom nav 5 ช่อง** (หน้าหลัก / กราฟ / + กลาง / ตั้งค่า / เมนู)
- การ์ด: มุมมน 16–20, เงานุ่ม (`softCard()` เวอร์ชัน dark), เว้นระยะ 16
- ตัวเลขเงิน: ใช้ `Money.formatBaht()` เสมอ (เก็บเป็นสตางค์ หารด้วย 100 ตอนแสดง)
- ปุ่ม/ช่องกรอก: ใช้ theme กลาง — **อย่า hardcode สี/มุม**

## 🔄 การส่งงาน
- แตก branch ต่อ 1 งาน: `feature/ta-<ชื่องาน>` (เช่น `feature/ta-budget-edit`)
- ทำเสร็จ → **รัน `flutter analyze` ให้ 0 error** → เปิด PR → ให้แตงกวา/โดมรีวิว → merge เข้า `main`
- แตงกวารีวิวด้วย test cases (SE-5) → แก้ให้ผ่านก่อน merge
- 📖 ขั้นตอน Git ละเอียด: [../GIT_WORKFLOW_GUIDE.md](../GIT_WORKFLOW_GUIDE.md)

## ✅ Definition of Done (รวม)
- [ ] **TA-0 ธีม dark+green เสร็จก่อน** แล้ว **6 หน้าใหม่** (Onboarding, Budget, History, Edit Balance, Settings, แดชบอร์ด/จัดการหมวด) + widget กลางใช้ทั่วแอป — **หน้าตาตรง mockup Canva**
- [ ] `flutter analyze` = 0 error, ไม่มีหน้าจอค้าง/ขาว (ทดสอบ build/run บน Android emulator ที่ตั้งไว้แล้ว)
- [ ] ทุกหน้ามี empty/loading/error
- [ ] ทุก flow กลับ/ไปต่อได้ ไม่มีทางตัน (ตรวจตาม nav map ของแตงกวา)
