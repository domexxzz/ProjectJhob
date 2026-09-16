# 🤝 คู่มือเข้าร่วมพัฒนา — "พี่เงิน" (AI Finance Coach)

คู่มือสำหรับสมาชิกทีมที่เพิ่งเข้ามา — ทำตามนี้แล้วรันได้เองตั้งแต่ต้นจนจบ

> **Production ตอนนี้: https://phee-ngern.onrender.com** (เว็บ/PWA + API อยู่โดเมนเดียวกัน)
> **Repo: `domexxzz/ProjectJhob` · branch หลักที่ deploy: `deploy/cloud`**

---

## 📑 สารบัญ
1. [ต้องลงอะไรก่อน](#1-ต้องลงอะไรก่อน)
2. [ขอไฟล์ลับจากทีม](#2-ขอไฟล์ลับจากทีม-สำคัญ)
3. [Clone + ตั้งค่า](#3-clone--ตั้งค่า)
4. [รัน Backend](#4-รัน-backend)
5. [รัน Mobile (Flutter)](#5-รัน-mobile-flutter)
6. [รัน AI Prophet (ไม่บังคับ)](#6-รัน-ai-prophet-ไม่บังคับ)
7. [กติกาการทำงานร่วมกัน (สำคัญ!)](#7-กติกาการทำงานร่วมกัน-สำคัญ)
8. [ปัญหาที่เจอบ่อย + วิธีแก้](#8-ปัญหาที่เจอบ่อย--วิธีแก้)

---

## 1) ต้องลงอะไรก่อน

| เครื่องมือ | เวอร์ชัน | ใช้ทำอะไร | โหลดที่ |
|---|---|---|---|
| **Node.js** | 20+ (แนะนำ **22.x**) | backend | nodejs.org |
| **Flutter SDK** | 3.19+ (ทีมใช้ 3.44) | แอปมือถือ/เว็บ | flutter.dev |
| **JDK** | 17 หรือ 21 | build Android | มากับ Android Studio |
| **Android Studio** | ล่าสุด | emulator + SDK | developer.android.com |
| **Git** | ล่าสุด | — | git-scm.com |
| **Python** | 3.11 | *(ไม่บังคับ)* ตัวพยากรณ์ Prophet | python.org |

เช็กว่าลงครบ:
```bash
node -v && flutter --version && java -version && git --version
```

---

## 2) ขอไฟล์ลับจากทีม (สำคัญ!)

ไฟล์พวกนี้ **ไม่อยู่ใน git โดยตั้งใจ** (มี API key จริง) — ขอจากทีมทาง **Discord/ไดรฟ์ เท่านั้น**

| ไฟล์ | วางไว้ที่ | มีอะไร |
|---|---|---|
| `.env` | `backend/.env` | คีย์ Typhoon / Groq / JWT / Google |
| `google-services.json` | `mobile/android/app/` | Firebase (แจ้งเตือน + Google login) |

> 🚫 **ห้าม commit ไฟล์พวกนี้เด็ดขาด** — ถ้าเผลอ push ขึ้นไป ต้องเปลี่ยนคีย์ใหม่ทั้งชุดทันที
> 💡 ถ้ายังไม่มีคีย์ AI ก็รันได้ — พี่เงินจะตอบด้วยโหมด rule-based จากข้อมูลจริงแทน

---

## 3) Clone + ตั้งค่า

```bash
git clone https://github.com/domexxzz/ProjectJhob.git
cd ProjectJhob
git checkout deploy/cloud
```

---

## 4) รัน Backend

```bash
cd backend
npm install
```

### ⚠️ เลือกฐานข้อมูลก่อน (จุดที่พลาดกันบ่อยที่สุด)

branch `deploy/cloud` ตั้ง Prisma เป็น **PostgreSQL** (เพราะ production ใช้ Neon)
ถ้าใส่ `DATABASE_URL="file:./dev.db"` แบบ SQLite **จะรันไม่ผ่าน** เลือกทางใดทางหนึ่ง:

**ทาง A — ใช้ Postgres ฟรีของตัวเอง (แนะนำ)**
1. สมัคร [neon.tech](https://neon.tech) (ฟรี) → สร้าง project → copy connection string
2. ใส่ใน `backend/.env`:
   ```
   DATABASE_URL="postgresql://user:pass@host/dbname?sslmode=require"
   ```

**ทาง B — ใช้ SQLite ในเครื่อง (เร็วกว่า แต่ต้องระวัง)**
1. แก้ `backend/prisma/schema.prisma` → `provider = "sqlite"`
2. `DATABASE_URL="file:./dev.db"` ใน `.env`
3. 🚫 **ห้าม commit การแก้ schema.prisma นี้** (จะทำให้ production พัง!)
   ```bash
   git update-index --skip-worktree backend/prisma/schema.prisma   # กันเผลอ commit
   ```

### สร้างตาราง + ข้อมูลตั้งต้น แล้วรัน
```bash
npm run db:push     # สร้างตารางตาม schema
npm run db:seed     # หมวดหมู่ 32 หมวด + demo user
npm run dev         # → http://localhost:4000
```

เช็กว่าใช้ได้:
```bash
curl http://localhost:4000/health
```

**บัญชีทดสอบ:** `demo@bestimove.ai` / `demo1234`

### คำสั่งอื่นที่ใช้บ่อย
| คำสั่ง | ทำอะไร |
|---|---|
| `npm run dev` | รันแบบ auto-reload |
| `npm run typecheck` | เช็ก TypeScript (**ควรรันก่อน commit**) |
| `npm run build` | build เป็น JS |
| `npm run db:studio` | เปิด UI ดู/แก้ฐานข้อมูล |

---

## 5) รัน Mobile (Flutter)

```bash
cd mobile
flutter pub get
```

### รันบน emulator/มือถือ (ต่อ backend ในเครื่อง)
```bash
# Android emulator (10.0.2.2 = localhost ของเครื่องแม่)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000

# มือถือจริงต่อ WiFi เดียวกัน — ใช้ IP เครื่องคุณ (ดูด้วย ipconfig / ifconfig)
flutter run --dart-define=API_BASE_URL=http://192.168.1.xxx:4000
```

### ต่อ production เลย (ไม่ต้องรัน backend เอง)
```bash
flutter run --dart-define=API_BASE_URL=https://phee-ngern.onrender.com
```

### Build แจกจ่าย
```bash
# APK (Android) — ชี้ production
flutter build apk --release \
  --target-platform android-arm,android-arm64,android-x64 \
  --dart-define=API_BASE_URL=https://phee-ngern.onrender.com
# ได้ไฟล์ที่ build/app/outputs/flutter-apk/app-release.apk

# เว็บ/PWA — ไม่ต้องใส่ URL (เรียก API แบบ same-origin เอง)
flutter build web --release
```

> 📱 **iPhone ใช้ APK ไม่ได้** → เข้าเว็บ https://phee-ngern.onrender.com แล้ว "เพิ่มลงหน้าจอโฮม" ใช้เป็นแอปได้เลย

---

## 6) รัน AI Prophet (ไม่บังคับ)

ตัวพยากรณ์การเงิน 30 วัน — backend ทำงานได้ปกติแม้ไม่รันตัวนี้ (จะข้ามส่วนพยากรณ์ไปเงียบ ๆ)

```bash
cd ai/predictions
pip install -r requirements.txt
python app.py                 # → http://127.0.0.1:8000
```
แล้วเพิ่มใน `backend/.env`:
```
PREDICTION_API_URL="http://127.0.0.1:8000/predict"
```

---

## 7) กติกาการทำงานร่วมกัน (สำคัญ!)

### 🚨 `deploy/cloud` = production จริง
Render ตั้ง **Auto-Deploy = On Commit** → **push เข้า `deploy/cloud` เมื่อไหร่ เว็บจริงเปลี่ยนทันที**
ถ้า push โค้ดพัง = แอปที่อาจารย์/เพื่อนใช้อยู่พังทันที

> ⚠️ **push เข้า `main` งานจะไม่ขึ้น production!** เพราะ Render ดูที่ `deploy/cloud` เท่านั้น
> แตก branch จาก `deploy/cloud` และเปิด PR กลับเข้า `deploy/cloud` เสมอ

### 🤖 rebuild web เป็นอัตโนมัติแล้ว (ไม่ต้องทำเอง)
เว็บ/PWA ถูกเสิร์ฟจาก **`backend/public`** ซึ่งเป็นไฟล์ build ที่ commit ไว้ในกิต
เมื่อก่อนถ้าแก้ `mobile/lib/` แล้ว push เฉย ๆ หน้าเว็บจะไม่เปลี่ยน — **ตอนนี้มี GitHub Actions
(`.github/workflows/build-web.yml`) build ให้อัตโนมัติ** ทุกครั้งที่ `mobile/**` ถูก push
เข้า `deploy/cloud` แล้ว commit `backend/public` กลับให้เอง

**สิ่งที่ต้องทำ:** แค่ push โค้ดตามปกติ → รอ ~3-5 นาที (ดูสถานะที่แท็บ **Actions** บน GitHub)

ถ้าอยาก build เองก่อนก็ยังทำได้:
```bash
cd mobile && flutter build web --release && cd ..
rm -rf backend/public && cp -r mobile/build/web backend/public
git add backend/public && git commit -m "chore: rebuild web"
```
> (แอป Android ไม่เกี่ยว — ต้อง build APK ใหม่แยกอยู่แล้ว)

### ✅ วิธีทำงานที่ถูกต้อง
```bash
# 1) แตก branch ของตัวเองก่อนเสมอ
git checkout deploy/cloud
git pull
git checkout -b feature/ชื่องานของคุณ

# 2) เขียนโค้ด แล้วเช็กก่อน commit
cd backend && npm run typecheck     # ต้องไม่มี error
cd ../mobile && flutter analyze     # ต้องไม่มี error (warning ผ่านได้)

# 3) commit + push branch ตัวเอง
git add .
git commit -m "feat: เพิ่มหน้าสรุปรายเดือน"
git push -u origin feature/ชื่องานของคุณ

# 4) เปิด Pull Request บน GitHub → ให้เพื่อนรีวิว → ค่อย merge เข้า deploy/cloud
```

### รูปแบบข้อความ commit
```
feat: เพิ่มฟีเจอร์ใหม่
fix: แก้บั๊ก
refactor: ปรับโครงสร้างโค้ด (พฤติกรรมเหมือนเดิม)
docs: แก้เอกสาร
chore: งานทั่วไป (config, dependency)
```

### เช็กลิสต์ก่อนเปิด PR
- [ ] `npm run typecheck` ผ่าน (backend)
- [ ] `flutter analyze` ไม่มี error (mobile)
- [ ] ไม่มีคีย์/รหัสผ่านหลุดในโค้ด
- [ ] ไม่ได้แก้ `schema.prisma` เป็น sqlite ติดไปด้วย
- [ ] ทดสอบหน้าที่แก้แล้วจริง ๆ

---

## 8) ปัญหาที่เจอบ่อย + วิธีแก้

### ❌ Prisma: provider mismatch / ตารางไม่ถูกสร้าง
ตั้ง `DATABASE_URL` ไม่ตรงกับ provider ใน `schema.prisma` → ดู [ข้อ 4](#4-รัน-backend) เลือกทาง A หรือ B ให้ตรงกัน

### ❌ Android build: `Unable to start the daemon` / `insufficient memory`
RAM ว่างแต่ **Windows commit charge เต็ม** (Docker/WSL กินไว้) — แก้:
```bash
wsl --shutdown          # คืนหน่วยความจำจาก Docker/WSL (เปิดใหม่ได้ทีหลัง)
```
> 🚫 อย่า `taskkill java.exe` ระหว่าง build — จะไปฆ่า Gradle daemon ตัวเอง

### ❌ Android build: `Inconsistent JVM-target` / `compileSdk`
`mobile/android/build.gradle.kts` มีโค้ดบังคับ Kotlin/compileSdk ให้ plugin เก่าอยู่แล้ว
**ห้ามลบออก** (จำเป็นสำหรับ `flutter_facebook_auth` เวอร์ชันเก่า)

### ❌ `flutter run` แล้วต่อ backend ไม่ได้
- emulator ต้องใช้ `10.0.2.2` ไม่ใช่ `localhost`
- มือถือจริงต้องอยู่ **WiFi เดียวกัน** + ใช้ IP จริงของเครื่อง + firewall ต้องไม่บล็อกพอร์ต 4000

### ❌ Login Facebook ไม่ได้
FB App ยังเป็น **Development mode** → login ได้เฉพาะบัญชีที่เป็น admin/tester
ขอให้เจ้าของแอปเพิ่มคุณที่ **Facebook Developer → App Roles → Testers** แล้วกดยอมรับคำเชิญ

### ❌ พี่เงินตอบแบบ rule-based (ไม่ใช่ AI)
ไม่มีคีย์ LLM ใน `.env` หรือคีย์หมดโควตา — ขอคีย์จากทีม หรือสมัครฟรีเองที่ [console.groq.com](https://console.groq.com)

---

## 📚 เอกสารอื่น
| ไฟล์ | เนื้อหา |
|---|---|
| `README.md` | ภาพรวมโปรเจกต์ |
| `docs/ARCHITECTURE.md` | สถาปัตยกรรมระบบฉบับเต็ม |
| `docs/CODE_MAP.md` | แผนที่โค้ด — ไฟล์ไหนทำอะไร |
| `docs/DESIGN_SYSTEM.md` | สี/ฟอนต์/คอมโพเนนต์ UI |

**ติดปัญหาถามในดิสคอร์ดทีมได้เลย** 🙌
