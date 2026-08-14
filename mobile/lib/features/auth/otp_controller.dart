import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import 'auth_controller.dart';

/// เรียกใช้ระบบ OTP ทางอีเมลของ backend
///
/// ใช้ได้ 3 กรณีตาม purpose ที่ส่งไป
///   verify → ยืนยันอีเมลตอนสมัคร
///   reset  → ลืมรหัสผ่าน
///   login  → เข้าสู่ระบบด้วยรหัสแทนรหัสผ่าน
///
/// ทุกเมธอดคืนข้อความผิดพลาดที่ผู้ใช้อ่านรู้เรื่อง หรือ null ถ้าสำเร็จ
/// ทำแบบนี้เพื่อให้หน้าจอเอาไปแสดงได้ตรง ๆ โดยไม่ต้อง try/catch เองทุกที่
class OtpController {
  OtpController(this._ref);
  final Ref _ref;

  Dio get _dio => _ref.read(dioProvider);

  /// ดึงข้อความผิดพลาดที่ backend ส่งมา — ถ้าไม่มีให้ใช้ข้อความกลาง ๆ
  String _errorFrom(DioException e, String fallback) {
    final data = e.response?.data;
    final msg = data is Map ? data['error']?.toString() : null;
    return msg ?? fallback;
  }

  /// ขอรหัส OTP ทางอีเมล
  ///
  /// backend ตอบ 200 เสมอไม่ว่าอีเมลจะมีในระบบหรือไม่ (กันคนไล่เช็กว่าใครสมัครไว้)
  /// หน้าจอจึงต้องบอกผู้ใช้ว่า "ถ้าอีเมลนี้มีในระบบ เราส่งรหัสไปแล้ว"
  /// ไม่ใช่ "ส่งรหัสไปที่อีเมลของคุณแล้ว" ซึ่งเท่ากับยืนยันว่ามีบัญชีนี้อยู่จริง
  Future<String?> requestCode(String email, String purpose) async {
    try {
      await _dio.post('/auth/otp/request', data: {'email': email.trim(), 'purpose': purpose});
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        return 'ขอรหัสบ่อยเกินไป กรุณารอสักครู่แล้วลองใหม่';
      }
      return _errorFrom(e, 'ส่งรหัสไม่สำเร็จ กรุณาลองใหม่');
    }
  }

  /// ลืมรหัสผ่าน ขั้น 1 — ยืนยันรหัสแล้วได้ token ไว้ตั้งรหัสใหม่
  /// คืน resetToken เมื่อสำเร็จ หรือ error เมื่อไม่สำเร็จ (อย่างใดอย่างหนึ่งเป็น null เสมอ)
  Future<({String? resetToken, String? error})> verifyResetCode(
    String email,
    String code,
  ) async {
    try {
      final res = await _dio.post('/auth/otp/verify-reset', data: {
        'email': email.trim(),
        'code': code.trim(),
      });
      return (resetToken: res.data['resetToken'] as String, error: null);
    } on DioException catch (e) {
      return (resetToken: null, error: _errorFrom(e, 'รหัสไม่ถูกต้องหรือหมดอายุแล้ว'));
    }
  }

  /// ลืมรหัสผ่าน ขั้น 2 — ตั้งรหัสผ่านใหม่ด้วย token จากขั้น 1
  Future<String?> resetPassword(String resetToken, String newPassword) async {
    try {
      await _dio.post('/auth/password/reset', data: {
        'resetToken': resetToken,
        'newPassword': newPassword,
      });
      return null;
    } on DioException catch (e) {
      return _errorFrom(e, 'ตั้งรหัสผ่านใหม่ไม่สำเร็จ');
    }
  }

  /// ยืนยันอีเมลตอนสมัคร — สำเร็จแล้วเข้าแอปได้เลยเช่นกัน
  Future<String?> verifyEmail(String email, String code) async {
    try {
      final res = await _dio.post('/auth/otp/verify-email', data: {
        'email': email.trim(),
        'code': code.trim(),
      });
      final ok = await _ref
          .read(authControllerProvider.notifier)
          .applyOAuthToken(res.data['token'] as String);
      return ok ? null : 'ยืนยันอีเมลสำเร็จ แต่เข้าสู่ระบบไม่ได้ กรุณาล็อกอินใหม่';
    } on DioException catch (e) {
      return _errorFrom(e, 'รหัสไม่ถูกต้องหรือหมดอายุแล้ว');
    }
  }
}

final otpControllerProvider = Provider<OtpController>((ref) => OtpController(ref));
