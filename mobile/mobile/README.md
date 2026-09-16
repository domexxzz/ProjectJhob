# 📱 Mobile — AI Finance Coach (Flutter)

> ⚠️ เครื่องที่ scaffold ตัวนี้ยังไม่ได้ลง Flutter SDK — โค้ดเป็น Sprint 1 skeleton ที่ยังไม่ได้ `flutter analyze`. ลง Flutter SDK ก่อนรัน.

## รัน
```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000   # Android emulator
# iOS simulator ใช้ http://localhost:4000 ; เครื่องจริงใช้ IP ของ PC ที่รัน backend
```

## โครงสร้าง
```
lib/
├── main.dart                      init Hive + ProviderScope + MaterialApp.router
├── app/
│   ├── theme.dart                 design system (สี/ปุ่ม/ฟอนต์) + hexColor()
│   └── router.dart                go_router + auth redirect guard
├── core/
│   ├── money.dart                 แปลงสตางค์ <-> บาท (เงินเก็บเป็น int สตางค์)
│   └── api/api_client.dart        Dio + JWT interceptor + secure token store
└── features/
    ├── auth/                      login / register + AuthController (Riverpod)
    ├── dashboard/                 หน้าหลัก: การ์ดคงเหลือ + summary + รายการล่าสุด
    └── transactions/              model + repository + หน้าเพิ่มรายการ (3-tap)
```

## State management
Riverpod 2 (`StateNotifierProvider` สำหรับ auth, `FutureProvider.autoDispose` สำหรับ dashboard/categories).
Token เก็บใน `flutter_secure_storage`; Dio interceptor แนบ `Authorization: Bearer` ให้อัตโนมัติ.

## Sprint 1 ครอบคลุม
login/register → dashboard (คงเหลือ + รายการ) → เพิ่ม transaction (3-tap: ประเภท → จำนวน → หมวด). 
Sprint 2+ จะเพิ่ม: กล้อง+OCR, edit/delete, chart, โค้ช AI chat.
