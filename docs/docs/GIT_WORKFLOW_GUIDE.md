# 📖 Git Workflow Guide — ทีมพี่เงิน

> คู่มือสั้น ๆ ให้ทุกคนส่งงานแบบเดียวกัน — feature branch → PR → review → merge เข้า `main`

## 🌿 กติกา branch
- `main` = โค้ดที่ใช้ได้เสมอ (ห้าม push ตรง)
- 1 งานย่อย = 1 branch:
  - แตงกวา: `feature/taengkwa-se-<งาน>` (เช่น `feature/taengkwa-se-requirements`)
  - ต้า: `feature/ta-<งาน>` (เช่น `feature/ta-budget-edit`)
  - โดม: `feature/dome-<งาน>` (เช่น `feature/dome-goals-api`)

## 🔄 ขั้นตอนต่อ 1 งาน

```bash
# 1) อัปเดต main ล่าสุดก่อนเริ่ม
git checkout main
git pull origin main

# 2) แตก branch ใหม่
git checkout -b feature/ta-budget-edit

# 3) ทำงาน + commit ย่อย ๆ (ข้อความสื่อความหมาย)
git add .
git commit -m "feat(budget): add budget edit form + validation"

# 4) push ขึ้น remote
git push -u origin feature/ta-budget-edit

# 5) เปิด PR บน GitHub → ขอ review → แก้ตาม comment → merge เข้า main
```

## ✍️ รูปแบบข้อความ commit (Conventional Commits)
`<type>(<scope>): <สรุปสั้น>`
- `feat` ฟีเจอร์ใหม่ · `fix` แก้บั๊ก · `docs` เอกสาร · `refactor` จัดโค้ด · `test` เทสต์ · `chore` งานจิปาถะ
- ตัวอย่าง: `feat(goals): add /goals CRUD API` · `docs(se): add requirement traceability matrix`

## ✅ ก่อนเปิด PR (เช็คลิสต์)
- [ ] **Mobile:** `flutter analyze` = 0 error
- [ ] **Backend:** typecheck ผ่าน (`npm run build` / `tsc --noEmit`)
- [ ] อัปเดตเอกสารที่เกี่ยว (README API contract ถ้าเพิ่ม endpoint)
- [ ] เขียน PR description: ทำอะไร, ทดสอบยังไง, กระทบหน้าไหน

## 👀 การรีวิว
- **แตงกวา** รีวิวด้วย **Acceptance Criteria / test cases** (SE-5) — เป็น QA gate
- ต้า/โดม รีวิวโค้ดกันเอง (อ่านง่าย, ไม่ hardcode, reuse widget/pattern)
- ผ่าน review อย่างน้อย 1 คน → merge

## ⚠️ กันพลาด
- อย่า commit `.env`, token, `node_modules/`, `dev.db` (ดู `.gitignore`)
- 🔑 อย่า hardcode API key ในโค้ด (Typhoon key เคยหลุดใน log — ใช้ env เสมอ)
- conflict: `git pull origin main` เข้า branch ตัวเอง แก้ conflict แล้ว commit
