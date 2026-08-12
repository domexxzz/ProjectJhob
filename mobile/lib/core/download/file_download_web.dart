import 'package:web/web.dart' as web;

/// ดาวน์โหลดไฟล์บนเว็บ/PWA
///
/// ทำไมต้องใช้ <a download> แทน launchUrl:
/// บน iOS ที่เพิ่ม PWA ลงหน้าจอโฮม (standalone) การเปิด URL ที่ตอบกลับมาเป็น
/// Content-Disposition: attachment จะได้หน้าจอ "ขาวเปล่า" และไม่มีไฟล์ถูกบันทึก
/// การสร้างลิงก์ที่มีแอตทริบิวต์ download แล้วสั่งคลิก จะให้เบราว์เซอร์จัดการ
/// บันทึกไฟล์เอง (ใช้ได้เพราะไฟล์อยู่โดเมนเดียวกับเว็บ — same-origin)
void downloadFile(String url, String filename) {
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = url;
  anchor.download = filename;
  anchor.target = '_self';
  anchor.style.display = 'none';
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
}
