import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// VAPID key (Web Push certificate) จาก Firebase Console
/// → Project settings → Cloud Messaging → Web Push certificates → Generate key pair
/// override ตอน build ได้: flutter build web --dart-define=FCM_VAPID_KEY=BXXXX...
const String kFcmVapidKey = String.fromEnvironment(
  'FCM_VAPID_KEY',
  defaultValue:
      'BGMQeYKoN3lYGgmjfNDL3lIpjHhXd4ttRV1X3-0I0MLZyZvICpandjMAKPW2YuTZ-ozs17OFhFL-k_VGgCsX6Qw',
);

/// ขอสิทธิ์แจ้งเตือน + เอา FCM token ส่งเข้า backend
/// เรียกหลังผู้ใช้ล็อกอินสำเร็จ (เพราะ POST /notifications/token ต้องมี auth)
///
/// ⚠️ บนเว็บ (โดยเฉพาะ iOS Safari) การขอสิทธิ์ต้องเกิดจาก "การกดของผู้ใช้" เท่านั้น
/// ฟังก์ชันนี้จึงไม่เด้งขอสิทธิ์เองบนเว็บ — แค่ต่อ token ถ้าผู้ใช้เคยอนุญาตไว้แล้ว
/// (ให้ผู้ใช้กดปุ่มในหน้าตั้งค่า → เรียก [enableWebNotifications] แทน)
Future<void> registerFcm(Dio dio) async {
  try {
    final messaging = FirebaseMessaging.instance;

    if (kIsWeb) {
      // เว็บ: เช็กสถานะเดิม ถ้ายังไม่เคยอนุญาต ให้รอผู้ใช้กดปุ่มเอง
      final current = await messaging.getNotificationSettings();
      if (current.authorizationStatus != AuthorizationStatus.authorized) {
        debugPrint('[FCM] web: ยังไม่ได้อนุญาต — รอผู้ใช้กดปุ่มเปิดแจ้งเตือน');
        return;
      }
    } else {
      // มือถือ: ขอสิทธิ์ได้เลย (Android 13+ / iOS ต้องขอ; รุ่นเก่าอนุญาตอัตโนมัติ)
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[FCM] ผู้ใช้ปฏิเสธการแจ้งเตือน');
        return;
      }
    }

    await _registerToken(dio, messaging);

    // ข้อความที่เข้ามาตอนเปิดแอปอยู่ (foreground) — ระบบไม่เด้งเองบน Android
    // ตอนนี้แค่ log ไว้ (การ์ด/กระดิ่งในแอปดึงข้อมูลเองอยู่แล้ว)
    FirebaseMessaging.onMessage.listen((msg) {
      debugPrint('[FCM] foreground: ${msg.notification?.title} — ${msg.notification?.body}');
    });
  } catch (e) {
    debugPrint('[FCM] register skipped: $e');
  }
}

/// เปิดแจ้งเตือนบนเว็บ/PWA — ต้องเรียกจาก "การกดปุ่ม" ของผู้ใช้ (ข้อบังคับของ iOS)
/// คืนข้อความอธิบายผลลัพธ์ให้เอาไปโชว์ได้เลย
Future<({bool ok, String message})> enableWebNotifications(Dio dio) async {
  try {
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return (
        ok: false,
        message: 'คุณปฏิเสธการแจ้งเตือนไว้ — เปิดใหม่ได้ที่ตั้งค่าของเบราว์เซอร์/เครื่อง',
      );
    }
    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      return (ok: false, message: 'ยังไม่ได้รับอนุญาตให้แจ้งเตือน ลองอีกครั้งครับ');
    }

    final token = await _registerToken(dio, messaging);
    if (token == null) {
      return (
        ok: false,
        message: kIsWeb && kFcmVapidKey.isEmpty
            ? 'ยังไม่ได้ตั้งค่า VAPID key ของเว็บ (แจ้งผู้ดูแลระบบ)'
            : 'ขอ token แจ้งเตือนไม่สำเร็จ ลองใหม่อีกครั้ง',
      );
    }
    return (ok: true, message: 'เปิดการแจ้งเตือนแล้ว ✅');
  } catch (e) {
    debugPrint('[FCM] enable web notifications failed: $e');
    return (
      ok: false,
      message: 'เปิดแจ้งเตือนไม่สำเร็จ — บน iPhone ต้อง "เพิ่มลงหน้าจอโฮม" ก่อน แล้วเปิดจากไอคอนนั้น',
    );
  }
}

/// ขอ token แล้วส่งเข้า backend + คอยส่งตัวใหม่เมื่อ token หมุนเปลี่ยน
Future<String?> _registerToken(Dio dio, FirebaseMessaging messaging) async {
  // เว็บบังคับต้องมี VAPID key ถึงจะขอ token ได้
  if (kIsWeb && kFcmVapidKey.isEmpty) {
    debugPrint('[FCM] web: ไม่มี VAPID key — ข้ามการขอ token');
    return null;
  }
  final token = kIsWeb
      ? await messaging.getToken(vapidKey: kFcmVapidKey)
      : await messaging.getToken();
  if (token != null) await _sendToken(dio, token);
  messaging.onTokenRefresh.listen((t) => _sendToken(dio, t));
  return token;
}

Future<void> _sendToken(Dio dio, String token) async {
  try {
    await dio.post('/notifications/token', data: {'token': token});
    debugPrint('[FCM] ลงทะเบียน token สำเร็จ');
  } catch (e) {
    debugPrint('[FCM] ส่ง token ไม่สำเร็จ: $e');
  }
}
