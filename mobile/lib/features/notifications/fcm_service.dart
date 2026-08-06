import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// ขอสิทธิ์แจ้งเตือน + เอา FCM device token ส่งเข้า backend
/// เรียกหลังผู้ใช้ล็อกอินสำเร็จ (เพราะ POST /notifications/token ต้องมี auth)
/// ห่อ try/catch ทั้งหมด — ถ้า Firebase ยังไม่พร้อม/บนเว็บ ก็ไม่ทำให้แอปพัง
Future<void> registerFcm(Dio dio) async {
  try {
    final messaging = FirebaseMessaging.instance;

    // ขอสิทธิ์ (Android 13+ / iOS ต้องขอ; รุ่นเก่าอนุญาตอัตโนมัติ)
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[FCM] ผู้ใช้ปฏิเสธการแจ้งเตือน');
      return;
    }

    final token = await messaging.getToken();
    if (token != null) {
      await _sendToken(dio, token);
    }

    // token อาจหมุนเปลี่ยน → ส่งตัวใหม่เข้า backend ทุกครั้ง
    messaging.onTokenRefresh.listen((t) => _sendToken(dio, t));

    // ข้อความที่เข้ามาตอนเปิดแอปอยู่ (foreground) — ระบบไม่เด้งเองบน Android
    // ตอนนี้แค่ log ไว้ (การ์ด/กระดิ่งในแอปดึงข้อมูลเองอยู่แล้ว)
    FirebaseMessaging.onMessage.listen((msg) {
      debugPrint('[FCM] foreground: ${msg.notification?.title} — ${msg.notification?.body}');
    });
  } catch (e) {
    debugPrint('[FCM] register skipped: $e');
  }
}

Future<void> _sendToken(Dio dio, String token) async {
  try {
    await dio.post('/notifications/token', data: {'token': token});
    debugPrint('[FCM] ลงทะเบียน token สำเร็จ');
  } catch (e) {
    debugPrint('[FCM] ส่ง token ไม่สำเร็จ: $e');
  }
}
