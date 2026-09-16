/// ดาวน์โหลดไฟล์ — เลือกวิธีตามแพลตฟอร์มอัตโนมัติ
/// เว็บ/PWA ใช้ <a download> (iOS standalone เปิด URL attachment ตรง ๆ ไม่ได้)
/// มือถือ native ใช้เบราว์เซอร์ของเครื่อง
export 'file_download_io.dart'
    if (dart.library.js_interop) 'file_download_web.dart';
