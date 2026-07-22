import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

enum BiometricAuthResult { success, unavailable, failed }

class NativeSecurityService {
  NativeSecurityService._();

  static const _channel = MethodChannel('com.projectjhob/security');
  static final LocalAuthentication _localAuth = LocalAuthentication();

  static bool get isNativeMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<BiometricAuthResult> authenticate() async {
    if (!isNativeMobile) return BiometricAuthResult.unavailable;
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final enrolled = await _localAuth.getAvailableBiometrics();
      if (!canCheck || enrolled.isEmpty) {
        return BiometricAuthResult.unavailable;
      }
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'ยืนยันตัวตนเพื่อเข้าใช้งานพี่เงิน',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      return authenticated
          ? BiometricAuthResult.success
          : BiometricAuthResult.failed;
    } catch (error) {
      debugPrint('Biometric authentication unavailable: $error');
      return BiometricAuthResult.unavailable;
    }
  }

  static Future<void> setRecentAppsPrivacy(bool enabled) async {
    if (!isNativeMobile || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('setSecureScreen', {
        'enabled': enabled,
      });
    } on PlatformException catch (error) {
      debugPrint('Unable to update Android secure screen: $error');
    } on MissingPluginException catch (_) {
      // Allows Flutter Web/tests to continue without a native implementation.
    }
  }
}
