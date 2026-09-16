# 📤 คู่มืออัปโหลดโค้ดเข้า GitHub — ทีมพี่เงิน

> สำหรับ **ต้า** และ **แตงกวา** · แก้ปัญหา "โค้ดไม่ตรงเวอร์ชันกัน" ให้จบ
> ทำตามนี้ทุกครั้ง แล้วจะไม่ทับงานกัน / ไม่ pull ไม่เจอของเพื่อน อีกเลย

---

## 🔴 อ่านก่อน — ต้นเหตุที่โค้ดไม่ตรงกัน

ตอนนี้ทีมมี **repo GitHub 2 อันแยกกัน** ผูกอยู่ในเครื่อง:

| ชื่อ remote | GitHub | สถานะ |
|---|---|---|
| `origin` | `github.com/Domezzxx/Project-JhobSAMNOR` | main = PR #25 (งานต้า) |
| `projectjhob` | `github.com/domexxzz/ProjectJhob` | main = งาน goals |

**นี่คือสาเหตุหลัก** — ถ้าคนหนึ่ง push เข้า `origin` อีกคน push เข้า `projectjhob` → **ต่างคนต่างเก็บโค้ดคนละที่ ไม่มีวันเห็นกัน!**

### ✅ สิ่งแรกที่ต้องทำ (ทำครั้งเดียว ทั้งทีม)

**ตกลงกันให้ใช้ repo เดียว** แล้วทุกคนชี้ไปที่อันนั้น เช่นถ้าเลือกใช้ `domexxzz/ProjectJhob`:

```bash
git remote set-url origin https://github.com/domexxzz/ProjectJhob.git
git remote remove projectjhob
git fetch origin
git branch --set-upstream-to=origin/main main
```

> เลือก repo ไหนเป็นหลักให้คุยกับโดมก่อน แล้วทุกคนตั้งให้ตรงกัน **ห้ามมีคนใช้คนละ repo เด็ดขาด** — จบปัญหาเวอร์ชันไป 80%

---

## 🌊 หลักการทอง 4 ข้อ (ท่องไว้)

1. **ดึงก่อนทำเสมอ** — เปิดคอมมาทำงาน `git pull` ก่อนแตะโค้ด
2. **ห้ามทำงานบน `main` โดยตรง** — แตก branch ของตัวเองทุกครั้ง
3. **push บ่อย ๆ** — ทำเสร็จส่วนย่อยก็ push อย่าดองไว้หลายวัน
4. **รวมงานผ่าน Pull Request** — ไม่ push ทับ main ตรง ๆ

---

## 📅 ขั้นตอนใช้ทุกวัน (ทำตามนี้เป๊ะ)

### 1) เริ่มวัน — ดึงโค้ดล่าสุดก่อน

```bash
git checkout main
git pull origin main
```
> ถ้าขึ้น error ว่ามีไฟล์ค้าง ให้ commit หรือ stash ก่อน (ดูหัวข้อแก้ปัญหา)

### 2) แตก branch ของตัวเอง

ตั้งชื่อแบบ `feature/<ชื่อ>-<งานที่ทำ>`:

```bash
git checkout -b feature/ta-login-ui
# หรือ
git checkout -b feature/taengkwa-test-plan
```

### 3) ทำงาน แล้วบันทึก (commit) เป็นระยะ

```bash
git add .
git commit -m "feat: เพิ่มหน้า login"
```
ข้อความ commit ใช้รูปแบบ: `feat:` (ฟีเจอร์ใหม่) · `fix:` (แก้บั๊ก) · `docs:` (เอกสาร) · `refactor:` · `test:`

### 4) ดึงของเพื่อนมารวมก่อน push (สำคัญมาก!)

```bash
git pull origin main
```
> ขั้นนี้กัน "เวอร์ชันชนกัน" — ดึงงานล่าสุดของเพื่อนมารวมกับของเรา**ก่อน**เอาขึ้น ถ้ามี conflict แก้ตรงนี้ (ดูข้างล่าง)

### 5) ส่งขึ้น GitHub

```bash
git push -u origin feature/ta-login-ui
```

### 6) เปิด Pull Request บนเว็บ GitHub

ไปที่ repo บนเว็บ → กด **"Compare & pull request"** → เขียนสั้น ๆ ว่าทำอะไร → กด **Create pull request** → ให้โดมรีวิว/merge เข้า main

---

## 📋 Cheat Sheet (ก็อปใช้ได้เลย)

```bash
# --- เริ่มงานใหม่ ---
git checkout main
git pull origin main
git checkout -b feature/ชื่อ-งาน

# --- ระหว่างทำ (commit ย่อย ๆ) ---
git add .
git commit -m "feat: ..."

# --- ก่อนส่งขึ้น ---
git pull origin main          # ดึงของเพื่อนมารวม
git push -u origin feature/ชื่อ-งาน

# --- เช็คสถานะ (ใช้บ่อย) ---
git status                    # ดูว่าแก้ไฟล์อะไรบ้าง
git log --oneline -5          # ดู 5 commit ล่าสุด
git branch                    # ดูว่าตอนนี้อยู่ branch ไหน
```

---

## ⚔️ เจอ Conflict (โค้ดชนกัน) ทำยังไง

พอ `git pull` แล้วขึ้น `CONFLICT` แปลว่าเรากับเพื่อนแก้ไฟล์เดียวกันบรรทัดเดียวกัน:

1. เปิดไฟล์ที่ชน จะเห็นแบบนี้:
   ```
   <<<<<<< HEAD
   โค้ดของเรา
   =======
   โค้ดของเพื่อน
   >>>>>>> main
   ```
2. **เลือกเก็บอันที่ถูก** (หรือรวมทั้งสอง) แล้วลบบรรทัด `<<<<<<<`, `=======`, `>>>>>>>` ออก
3. บันทึก:
   ```bash
   git add .
   git commit -m "merge: แก้ conflict"
   ```
> ไม่แน่ใจว่าเก็บอันไหน — **ถามในแชททีมก่อนเสมอ** อย่าเดา

---

## 🚫 ห้ามทำ (ทำแล้วเวอร์ชันพัง)

- ❌ **ห้าม `git push --force` เข้า main** — ลบงานเพื่อนทั้งหมด
- ❌ **ห้ามทำงานบน main โดยตรง** — แตก branch เสมอ
- ❌ **ห้าม commit ของพวกนี้** (มีใน `.gitignore` แล้ว แต่ห้ามฝืน `git add -f`):
  - `node_modules/` · `mobile/build/` · `dist/` (ของที่ลงใหม่ได้)
  - `.env` · `*.db` (`dev.db`) · `*service-account*.json` (ความลับ/ข้อมูล)
- ❌ **ห้ามดองโค้ดไม่ push หลายวัน** — ยิ่งดองยิ่ง conflict เยอะ

---

## 🩹 แก้ปัญหาที่เจอบ่อย

**"error: Your local changes would be overwritten by merge"** (pull ไม่ได้เพราะมีไฟล์ค้าง)
```bash
git stash          # เก็บงานที่ค้างไว้ก่อน
git pull origin main
git stash pop       # เอางานที่เก็บกลับมา
```

**"เผลอทำงานบน main"** (แก้ไปแล้วแต่ยังไม่ commit)
```bash
git stash
git checkout -b feature/ชื่อ-งาน
git stash pop        # ย้ายงานมาอยู่ branch ใหม่แล้ว
```

**"อยากรู้ว่าตัวเองตามหลัง main กี่ commit"**
```bash
git fetch origin
git log --oneline HEAD..origin/main    # commit ที่เรายังไม่มี
```

**"push แล้วขึ้น rejected"** (main มีของใหม่กว่าเรา)
```bash
git pull origin main    # ดึงมารวมก่อน แล้วค่อย push ใหม่
git push
```

---

## 👥 ข้อตกลงเฉพาะทีม (กันเวอร์ชันเพี้ยน)

1. **repo เดียวทั้งทีม** — ทำตามหัวข้อบนสุด ห้ามใช้คนละ GitHub
2. **1 คน = 1 branch ต่อ 1 งาน** — ไม่แชร์ branch กัน
3. **แก้ไฟล์ที่ใช้ร่วมกัน** (เช่น `schema.prisma`, ธีม, router) → **บอกในแชทก่อน** + แก้ไฟล์ที่เกี่ยวข้องให้ครบ + เช็คว่ารันได้ก่อน push
   - Backend: `npm run build` ต้องผ่าน
   - Mobile: `flutter analyze` ต้อง 0 error
4. **push ทุกวันก่อนเลิก** — ไม่ทิ้งงานค้างในเครื่องคนเดียว
5. **pull ทุกเช้าก่อนเริ่ม** — จะได้เห็นงานเพื่อนเสมอ

---

## 🆘 ถ้ามันพันกันจนงง

อย่าเพิ่งพยายามแก้เองจนพังหนัก — **หยุด แล้วทำ 2 อย่าง:**
1. `git status` แล้วแคป/ก็อปข้อความส่งในแชททีม
2. ถ้ากลัวงานหาย ก็อปโฟลเดอร์ทั้งอันไปเซฟไว้ที่อื่นก่อน แล้วค่อยถามโดม

> Git ไม่ได้น่ากลัว แค่ทำ **pull ก่อนทำ → แตก branch → push ผ่าน PR** ทุกครั้ง ปัญหาเวอร์ชันไม่ตรงจะหายไปเองครับ 💪
