# 🔐 คู่มือตั้งค่า Social Login + Gmail Import (อัปเดต)

> อัปเดต 4 ก.ค. 2569 · โปรเจกต์อยู่ที่ **`D:\Project-JhobSAMNOR`** แล้ว
> โค้ดพร้อมทั้ง backend + mobile · เหลือตั้งค่าในบัญชี Google/Facebook ของคุณ (ผมทำแทนไม่ได้)

## ✅ ทำให้แล้ว (ไม่ต้องทำซ้ำ)
- Backend รันจาก D: ที่ `http://localhost:4000` · Flutter web ที่ **`http://localhost:5000`** (port คงที่)
- **Google Web Client ID ตั้งแล้ว** ทั้ง 2 ที่:
  - `backend/.env` → `GOOGLE_CLIENT_ID=910041172864-...apps.googleusercontent.com`
  - `mobile/web/index.html` → `<meta name="google-signin-client_id" ...>`
- โค้ด: ปุ่ม Google/Facebook (Login+Register) · ปุ่ม 📧 นำเข้า Gmail (หน้า Subscription) · endpoint verify token + Gmail import

---

## 👉 เหลือทำแค่นี้ (Google Cloud ของคุณ) แล้ว Google Login ทำงาน

### 1. เพิ่ม Authorized JavaScript origins ⭐ (จำเป็นสำหรับเว็บ)
Google Cloud Console → **APIs & Services → Credentials** → เปิด **OAuth 2.0 Client ID (Web)** ตัวที่ใช้ →
ช่อง **Authorized JavaScript origins** → **+ ADD URI** →
```
http://localhost:5000
```
(ถ้าจะรัน port อื่น ให้เพิ่ม origin ให้ตรง) → **Save** แล้วรอ ~1 นาที

### 2. เพิ่มตัวเองเป็น Test user
**OAuth consent screen** → เลื่อนลงหา **Test users** → **+ ADD USERS** → ใส่อีเมล Google ที่จะล็อกอิน
(เพราะแอปยังโหมด *Testing* — เฉพาะ test user เท่านั้นที่ล็อกอินได้ ไม่ต้องผ่าน verification)

### 3. เปิด API ที่ต้องใช้ (APIs & Services → Library → Enable)
- **People API** ⭐ **จำเป็นสำหรับ Google login บนเว็บ** — google_sign_in ดึงโปรไฟล์ผ่าน People API · ไม่เปิด = login error `People API has not been used in project ... or it is disabled`
- **Gmail API** — สำหรับปุ่มนำเข้า Gmail
- **OAuth consent screen → Data Access** → เพิ่ม scope `.../auth/gmail.readonly`
  > ⚠️ เป็น *restricted scope* — production ต้องผ่าน Google review แต่ **test user ใช้ได้เลย**

---

## 🧪 ทดสอบ
1. เปิด **http://localhost:5000** (แอปรันอยู่แล้ว)
2. หน้า Login → **"เข้าสู่ระบบด้วย Google"** → เลือกบัญชี test → เข้าแอปได้ (backend verify → JWT)
3. หน้า Subscription (เมนู → Subscription) → กด 📧 **นำเข้าจาก Gmail** → ยินยอม scope → ระบบสแกนใบเสร็จ → สร้างรายการ

> ถ้าเจอ error `redirect_uri_mismatch` / `origin not allowed` → ยังไม่ได้เพิ่ม origin (ข้อ 1) หรือยังไม่ครบ 1 นาที
> ถ้าเจอ `access_blocked` → ยังไม่ได้เพิ่มเป็น test user (ข้อ 2)

---

## 📘 Facebook (ทางเลือก — ยังไม่ได้ตั้ง)
ปุ่ม Facebook จะ error จนกว่าจะทำ:
1. https://developers.facebook.com → **Create App** (Consumer) → เพิ่ม **Facebook Login**
2. **Settings → Basic** → เอา **App ID** + **App Secret**
3. ใส่ใน `backend/.env`:
   ```env
   FACEBOOK_APP_ID=xxxxxxxxxx
   FACEBOOK_APP_SECRET=xxxxxxxx
   ```
4. ตั้ง platform config (Android package+key hash / iOS bundle / Web domain) + init FB SDK บนเว็บ
5. **restart backend** หลังแก้ `.env`

---

## 🔁 ถ้าต้องรีสตาร์ทเอง (path ใหม่ = D:)
```bash
# Backend
cd D:\Project-JhobSAMNOR\backend
npm run dev                       # http://localhost:4000

# Mobile web (port คงที่ 5000)
cd D:\Project-JhobSAMNOR\mobile
flutter run -d chrome --web-port=5000 --dart-define=API_BASE_URL=http://localhost:4000
```
> ⚠️ แก้ `.env` ทุกครั้งต้อง restart backend (ไม่ reload อัตโนมัติ)

## ⚠️ หมายเหตุ
- **Gmail import = best-effort:** จับบริการยอดฮิต (Netflix/Spotify/YouTube/Disney+/iCloud/Prime) + ใส่ราคาเริ่มต้น (อ่านยอดจากเมลแม่นยำยาก) → ผู้ใช้แก้ทีหลังได้ · ปรับได้ที่ `backend/src/modules/subscriptions/gmail_import.ts`
- **ความปลอดภัย:** ไม่เก็บเนื้อเมล/token ลง DB (ใช้แล้วทิ้ง) · บัญชี Google/FB ที่อีเมลตรงกับบัญชีเดิม → ผูกให้อัตโนมัติ
- **Client ID เป็นค่า public** (ใส่ในเว็บได้) แต่ **Client Secret / App Secret ห้าม commit** ขึ้น git

## 📁 ไฟล์ที่เกี่ยวข้อง
- Backend: `modules/auth/oauth.service.ts` · `modules/auth/auth.routes.ts` · `modules/subscriptions/gmail_import.ts` · `config/env.ts`
- Mobile: `features/auth/auth_controller.dart` · `features/auth/social_login_buttons.dart` · `features/subscriptions/subscriptions_screen.dart` (`_importGmail`) · `web/index.html`
