import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// override ตอนรัน: flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000
const String kApiBaseUrl =
    String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:4000');

final secureStorageProvider =
    Provider<FlutterSecureStorage>((ref) => const FlutterSecureStorage());

/// เก็บ/อ่าน JWT
/// - มือถือจริง: flutter_secure_storage (Keychain/Keystore ปลอดภัย)
/// - เว็บ: shared_preferences (localStorage) — เพราะ secure_storage บนเว็บต้องใช้
///   crypto.subtle ที่มีเฉพาะ secure context (https/localhost); ผ่าน http+IP จะพัง
class TokenStore {
  TokenStore(this._storage);
  final FlutterSecureStorage _storage;
  static const _key = 'auth_token';

  Future<String?> read() async {
    if (kIsWeb) return (await SharedPreferences.getInstance()).getString(_key);
    return _storage.read(key: _key);
  }

  Future<void> write(String token) async {
    if (kIsWeb) {
      await (await SharedPreferences.getInstance()).setString(_key, token);
      return;
    }
    await _storage.write(key: _key, value: token);
  }

  Future<void> clear() async {
    if (kIsWeb) {
      await (await SharedPreferences.getInstance()).remove(_key);
      return;
    }
    await _storage.delete(key: _key);
  }
}

final tokenStoreProvider =
    Provider<TokenStore>((ref) => TokenStore(ref.watch(secureStorageProvider)));

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: '$kApiBaseUrl/api/v1',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));
  final tokenStore = ref.watch(tokenStoreProvider);
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await tokenStore.read();
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
      handler.next(options);
    },
  ));
  return dio;
});
