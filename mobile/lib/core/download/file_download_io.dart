import 'package:url_launcher/url_launcher.dart';

/// ดาวน์โหลดไฟล์บนมือถือ (Android/iOS native) — เปิดด้วยเบราว์เซอร์ของเครื่อง
void downloadFile(String url, String filename) {
  launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}
