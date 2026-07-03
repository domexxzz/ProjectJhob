# 📱 คู่มือติดตั้ง Flutter — สำหรับต้า (Mobile Developer)

> เป้าหมาย: ลง Flutter บนเครื่อง Windows ให้ **รันแอป "พี่เงิน" ได้จริงบน emulator** แล้วเริ่มทำ TA-0..TA-8 ได้เลย
> เวอร์ชันที่ทีมล็อกให้ตรงกัน (จากแตงกวา SE-7): **Flutter 3.44.4 · Dart 3.12.2 · Android SDK 35 · JDK 21 (JBR) · Developer Mode ON**
> ⏱️ ใช้เวลาลงครั้งแรกประมาณ 1–2 ชม. (ส่วนใหญ่รอโหลด Android SDK)

---

## ✅ ทำตามลำดับนี้ (checklist)
1. [ ] เปิด **Developer Mode** ของ Windows
2. [ ] ลง **Git**
3. [ ] ลง **Flutter SDK 3.44.4** + ใส่ PATH
4. [ ] ลง **Android Studio** (มาพร้อม Android SDK + JDK 21)
5. [ ] เปิด Android Studio → ลง **SDK 35 + cmdline-tools + emulator** + `flutter doctor --android-licenses`
6. [ ] ลง **VS Code** + extension Flutter/Dart
7. [ ] `flutter doctor` เขียวครบ
8. [ ] สร้าง **Android Emulator** (Pixel, API 35)
9. [ ] clone repo → `flutter pub get` → `flutter run` ต่อ backend

---

## 1) เปิด Developer Mode (ทำก่อน — กัน error ตอน build)
- กด `Win` → พิมพ์ **"Developer settings"** → เปิด **Developer Mode** = ON
- (Flutter ต้องใช้ symlink ตอน build plugin ถ้าไม่เปิดจะ error)

## 2) ลง Git
- โหลด: https://git-scm.com/download/win → ติดตั้งแบบ Next รัว ๆ (default พอ)
- เช็ค: เปิด **PowerShell** ใหม่ แล้วพิมพ์
```powershell
git --version
```

## 3) ลง Flutter SDK 3.44.4
1. โหลด zip เวอร์ชัน **3.44.4 (stable, Windows)** จาก https://docs.flutter.dev/release/archive
2. แตกไฟล์ไปไว้ที่ **`C:\src\flutter`** หรือ **`C:\flutter`**
   - ⛔ **ห้าม**วางใน `C:\Program Files` (มีช่องว่าง = พัง), ห้ามใน `OneDrive`, ห้ามใน path ที่ต้องใช้สิทธิ์ admin
3. ใส่ **PATH**: `Win` → "Edit the system environment variables" → Environment Variables → เลือก **Path** (ของ User) → New →
```
C:\src\flutter\bin
```
4. **ปิด PowerShell แล้วเปิดใหม่** → เช็ค:
```powershell
flutter --version    # ต้องขึ้น Flutter 3.44.4 • Dart 3.x
```

## 4) ลง Android Studio (ได้ Android SDK + JDK 21 มาด้วย)
- โหลด: https://developer.android.com/studio → ติดตั้ง (ติ๊กให้ลง **Android SDK + Android Virtual Device**)
- เปิด Android Studio ครั้งแรก → ทำตาม Setup Wizard ให้จบ (มันจะโหลด SDK platform + build-tools)

## 5) ตั้งค่า Android SDK ให้ครบ
เปิด Android Studio → **More Actions ▸ SDK Manager**:
- แท็บ **SDK Platforms** → ติ๊ก **Android 15 (API 35)**
- แท็บ **SDK Tools** → ติ๊ก: **Android SDK Command-line Tools (latest)**, **Android SDK Build-Tools**, **Android SDK Platform-Tools**, **Android Emulator**
- Apply → รอโหลด

แล้ว **ยอมรับ license** (สำคัญ — ไม่งั้น build ไม่ได้):
```powershell
flutter doctor --android-licenses    # กด y ทุกอัน
```

> 💡 JDK: Android Studio มี **JBR (JDK 21)** มาให้แล้ว ไม่ต้องลง JDK แยก ถ้า `flutter doctor` ฟ้องเรื่อง Java ให้สั่ง:
> ```powershell
> flutter config --jdk-dir "C:\Program Files\Android\Android Studio\jbr"
> ```

## 6) ลง VS Code + Extension (แนะนำสำหรับเขียนโค้ด)
- โหลด VS Code: https://code.visualstudio.com
- ลง extension: **Flutter** (ของ Dart Code — จะพ่วง Dart extension ให้เอง)
- (จะใช้ Android Studio เขียนก็ได้ แต่ VS Code เบากว่า)

## 7) เช็คว่าพร้อม
```powershell
flutter doctor -v
```
ต้องเขียว ✓ อย่างน้อย: **Flutter**, **Android toolchain**, **VS Code**
- ✗ ตรงไหน → อ่านข้อความมันบอก (ส่วนใหญ่คือ license ยังไม่ยอมรับ / ยังไม่ลง cmdline-tools) → ดูตาราง [แก้ปัญหา](#-แก้ปัญหาที่เจอบ่อย) ล่าง

## 8) สร้าง Android Emulator
Android Studio → **More Actions ▸ Virtual Device Manager** → **Create Device**
- เลือก **Pixel 7** (หรือรุ่นไหนก็ได้) → System Image **API 35** (โหลดถ้ายังไม่มี) → ตั้งชื่อ (เช่น `pixel_ai`) → Finish
- กด ▶️ เปิด emulator ให้ boot จนเห็นหน้า home

เช็คว่า Flutter เห็น device:
```powershell
flutter devices
```

---

## 9) รันโปรเจกต์ "พี่เงิน" 🚀

### 9.1 เอาโค้ดมา (clone)
```powershell
cd C:\Users\<ชื่อคุณ>\Project     # โฟลเดอร์ที่อยากเก็บโปรเจกต์
git clone <URL repo ของทีม> Project-JhobSAMNOR
cd Project-JhobSAMNOR\mobile
```
> ยังไม่รู้ URL/ขั้นตอน git → ถามเบส หรือดู [GIT_WORKFLOW_GUIDE.md](GIT_WORKFLOW_GUIDE.md)

### 9.2 ต้องรัน backend ก่อน (แอปต่อ API จริง)
เปิดอีก terminal:
```powershell
cd ..\backend
npm install
npm run db:push ; npm run db:seed
npm run dev        # ขึ้นที่ http://localhost:4000  (เช็ค: เปิด http://localhost:4000/health)
```
> ล็อกอิน demo: `demo@bestimove.ai` / `demo1234`

### 9.3 รันแอป
```powershell
flutter pub get        # โหลด dependencies (ครั้งแรกนานหน่อย)

# ▶️ Android emulator — ใช้ 10.0.2.2 (= localhost ของ PC เมื่อมองจาก emulator)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000

# ▶️ เว็บ (เทสไว) — ใช้ localhost
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:4000

# ▶️ มือถือจริง (เสียบ USB, เปิด USB debugging) — ใช้ IP ของ PC ที่รัน backend
flutter run --dart-define=API_BASE_URL=http://192.168.x.x:4000
```

> 🖱️ **ทางลัด:** ที่รากโปรเจกต์มี **`run_app.bat`** — ดับเบิลคลิกก็รันบน Chrome (`localhost:4000`) ให้เลย

### 9.4 คำสั่งที่ใช้บ่อยตอน dev
| คำสั่ง | ทำอะไร |
|---|---|
| กด `r` ใน terminal | hot reload (เห็นผลทันที) |
| กด `R` | hot restart (รีสตาร์ท state) |
| `flutter analyze` | เช็ค error/warning — **ต้อง 0 error ก่อนเปิด PR** |
| `flutter pub get` | โหลด/อัปเดต dependency หลังแก้ `pubspec.yaml` |
| `flutter clean` | ล้าง build cache ตอนมันเพี้ยน |
| `flutter devices` | ดู device/emulator ที่ต่ออยู่ |

---

## 🩹 แก้ปัญหาที่เจอบ่อย
| อาการ | สาเหตุ / วิธีแก้ |
|---|---|
| `flutter` ไม่เป็นคำสั่ง | PATH ยังไม่เข้า → ปิด-เปิด terminal ใหม่ / เช็ค `C:\src\flutter\bin` ใน Path |
| `flutter doctor` ฟ้อง Android licenses | รัน `flutter doctor --android-licenses` แล้วกด y ทุกอัน |
| build ค้าง/error เรื่อง symlink | ยังไม่เปิด **Developer Mode** (ข้อ 1) |
| แอปเปิดแต่ **ต่อ API ไม่ได้ / connection refused** | 1) backend ยังไม่รัน  2) emulator ต้องใช้ **`10.0.2.2`** ไม่ใช่ `localhost`  3) เครื่องจริงใช้ IP ของ PC + อยู่ Wi-Fi เดียวกัน |
| Gradle / JDK error | ชี้ JDK ของ Android Studio: `flutter config --jdk-dir "C:\Program Files\Android\Android Studio\jbr"` |
| emulator ไม่ขึ้น / ช้ามาก | เปิด Virtualization (VT-x/AMD-V) ใน BIOS · ปิด Hyper-V ถ้าชน · ให้ RAM emulator ≥ 2GB |
| `pub get` โหลดช้า/ค้าง | เน็ต/พร็อกซี — ลองใหม่ หรือ `flutter clean` แล้ว `flutter pub get` |
| พื้นที่ไม่พอ | Flutter+Android SDK+emulator กินรวม ~15GB เผื่อไว้ |

---

## 📌 หมายเหตุของโปรเจกต์นี้ (ที่ต้ารู้ไว้)
- **เงินเก็บเป็นสตางค์** (int) — แสดงผลใช้ `Money.formatBaht()` เสมอ (อย่าใช้ float)
- ธีมกลางอยู่ที่ `lib/app/theme.dart` · route อยู่ `lib/app/router.dart` (go_router + auth guard)
- **`speech_to_text`** (รับเสียง) ใช้ได้เฉพาะมือถือจริง → บน emulator/web ต้อง guard ไว้ (มีทำแล้ว)
- **`image_picker`** (เลือกรูป/สแกนสลิป) ต้องขอ permission กล้อง/รูปบนเครื่องจริง
- dependencies หลัก: `flutter_riverpod` · `go_router` · `dio` · `hive` · `fl_chart` · `flutter_secure_storage` (ดู `pubspec.yaml`)
- งานแรกของต้ารอบนี้ = **TA-0 รื้อธีมเป็น dark + green** (ดู [tasks/TASK_Ta_Developer.md](tasks/TASK_Ta_Developer.md))

## 🆘 ติดตรงไหนถามได้
ทำ `flutter doctor -v` แล้วแคปหน้าจอส่งกลุ่ม — เบส/แตงกวาช่วยดูได้เร็วสุด
