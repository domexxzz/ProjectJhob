import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../settings/settings_screen.dart';

class AppUser {
  AppUser({
    required this.id,
    required this.email,
    this.phone,
    this.displayName,
    this.monthlyIncome = 0,
    this.level = 1,
    this.streak = 0,
    this.points = 0,
    this.avatarUrl,
    this.createdAt,
  });

  final String id;
  final String email;
  final String? phone;
  final String? displayName;
  final int monthlyIncome;
  final int level;
  final int streak;
  final int points;
  final String? avatarUrl;
  final DateTime? createdAt;

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as String,
        email: j['email'] as String,
        phone: j['phone'] as String?,
        displayName: j['displayName'] as String?,
        monthlyIncome: (j['monthlyIncome'] ?? 0) as int,
        level: (j['level'] ?? 1) as int,
        streak: (j['streak'] ?? 0) as int,
        points: (j['points'] ?? 0) as int,
        avatarUrl: j['avatarUrl'] as String?,
        createdAt: j['createdAt'] != null
            ? DateTime.tryParse(j['createdAt'] as String)
            : null,
      );
}

class AuthState {
  const AuthState({this.user, this.loading = false, this.error});
  final AppUser? user;
  final bool loading;
  final String? error;

  bool get isAuthenticated => user != null;

  AuthState copyWith(
          {AppUser? user,
          bool? loading,
          String? error,
          bool clearError = false}) =>
      AuthState(
        user: user ?? this.user,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
      );
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._ref) : super(const AuthState()) {
    _bootstrap();
  }
  final Ref _ref;

  Dio get _dio => _ref.read(dioProvider);
  TokenStore get _tokens => _ref.read(tokenStoreProvider);

  Future<void> _bootstrap() async {
    await _consumeOAuthRedirect();
    final token = await _tokens.read();
    if (token == null) return;
    try {
      final res = await _dio.get('/auth/me');
      state = state.copyWith(
          user: AppUser.fromJson(res.data['user'] as Map<String, dynamic>));
      await _ref
          .read(appSettingsProvider.notifier)
          .refreshNotificationPreferences();
    } catch (_) {
      await _tokens.clear();
    }
  }

  /// เว็บ: รับ JWT ที่ backend ส่งกลับหลัง server-side OAuth (#/oauth?token=... )
  /// หรือแสดง error ที่ส่งกลับมา (#/login?fb_error=...) แล้วล้าง URL ให้สะอาด
  Future<void> _consumeOAuthRedirect() async {
    if (!kIsWeb) return;
    final frag = Uri.base.fragment; // เช่น "/oauth?token=xxx"
    if (frag.isEmpty) return;
    final qIndex = frag.indexOf('?');
    if (qIndex < 0) return;
    final params = Uri.splitQueryString(frag.substring(qIndex + 1));

    final err = params['fb_error'];
    if (err != null && err.isNotEmpty) {
      state = state.copyWith(loading: false, error: err);
      return;
    }
    final token = params['token'];
    if (token == null || token.isEmpty) return;
    await _tokens.write(token);
  }

  /// รับ JWT ที่ได้จาก server-side OAuth (หน้า /oauth) → เก็บ token + โหลดโปรไฟล์
  Future<bool> applyOAuthToken(String token) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      await _tokens.write(token);
      final res = await _dio.get('/auth/me');
      state = state.copyWith(
        user: AppUser.fromJson(res.data['user'] as Map<String, dynamic>),
        loading: false,
      );
      await _ref
          .read(appSettingsProvider.notifier)
          .refreshNotificationPreferences();
      return true;
    } catch (_) {
      await _tokens.clear();
      state = state.copyWith(loading: false, error: 'ล็อกอินไม่สำเร็จ กรุณาลองใหม่');
      return false;
    }
  }

  Future<bool> login(String email, String password) =>
      _authRequest('/auth/login', {'email': email, 'password': password});

  Future<bool> register(String email, String password, String displayName) =>
      _authRequest('/auth/register', {
        'email': email,
        'password': password,
        if (displayName.isNotEmpty) 'displayName': displayName,
      });

  Future<bool> updateProfile({
    required String displayName,
    required String email,
    String? phone,
    required int monthlyIncome,
    String? avatarUrl,
  }) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final res = await _dio.patch('/auth/me', data: {
        'displayName': displayName.trim(),
        'email': email.trim(),
        'phone': phone?.trim(),
        'monthlyIncome': monthlyIncome,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
      });
      state = AuthState(
        user: AppUser.fromJson(res.data['user'] as Map<String, dynamic>),
      );
      return true;
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = data is Map ? data['error']?.toString() : null;
      state = state.copyWith(
        loading: false,
        error: msg ?? 'บันทึกข้อมูลไม่สำเร็จ กรุณาลองใหม่',
      );
      return false;
    }
  }

  Future<bool> _authRequest(String path, Map<String, dynamic> body) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final res = await _dio.post(path, data: body);
      await _tokens.write(res.data['token'] as String);
      state = AuthState(
          user: AppUser.fromJson(res.data['user'] as Map<String, dynamic>));
      await _ref
          .read(appSettingsProvider.notifier)
          .refreshNotificationPreferences();
      return true;
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = data is Map ? data['error']?.toString() : null;
      state = state.copyWith(
          loading: false, error: msg ?? 'เชื่อมต่อเซิร์ฟเวอร์ไม่สำเร็จ');
      return false;
    }
  }

  /// ล็อกอินด้วย Google → ส่ง idToken ให้ backend verify
  Future<bool> loginWithGoogle() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final account = await GoogleSignIn(scopes: const ['email']).signIn();
      if (account == null) {
        state = state.copyWith(loading: false); // ผู้ใช้ยกเลิก
        return false;
      }
      final auth = await account.authentication;
      final idToken = auth.idToken; // มือถือให้ idToken
      final accessToken =
          auth.accessToken; // เว็บให้ accessToken (idToken เป็น null)
      if (idToken == null && accessToken == null) {
        state = state.copyWith(loading: false, error: 'ไม่ได้รับ Google token');
        return false;
      }
      return _authRequest('/auth/google', {
        if (idToken != null) 'idToken': idToken,
        if (accessToken != null) 'accessToken': accessToken,
      });
    } catch (e) {
      state = state.copyWith(
          loading: false, error: 'ล็อกอิน Google ไม่สำเร็จ ลองใหม่อีกครั้ง');
      return false;
    }
  }

  /// ล็อกอินด้วย Facebook → ส่ง accessToken ให้ backend verify
  ///
  /// เว็บ/PWA: ไม่ใช้ FB JS SDK เพราะ iOS Safari (ITP) บล็อก connect.facebook.net
  /// ("window.FB is undefined") → เด้งไป server-side OAuth (/auth/facebook/start)
  /// ซึ่งจะ redirect กลับมาที่ #/oauth?token=... แล้ว consumeOAuthToken() รับต่อ
  Future<bool> loginWithFacebook() async {
    if (kIsWeb) {
      state = state.copyWith(loading: true, clearError: true);
      // kApiBaseUrl บนเว็บเป็น '' (same-origin) → ใช้ origin ปัจจุบัน
      final origin = kApiBaseUrl.isNotEmpty ? kApiBaseUrl : Uri.base.origin;
      await launchUrl(
        Uri.parse('$origin/api/v1/auth/facebook/start'),
        webOnlyWindowName: '_self', // เด้งทั้งแท็บ (ไม่โดน popup blocker บน iOS)
      );
      return false; // ออกจากหน้าไปแล้ว — จะกลับมาที่ #/oauth?token=...
    }
    state = state.copyWith(loading: true, clearError: true);
    try {
      final result = await FacebookAuth.instance
          .login(permissions: const ['email', 'public_profile']);
      final token = result.accessToken;
      if (result.status != LoginStatus.success || token == null) {
        state = state.copyWith(
            loading: false,
            error: result.message ?? 'ยกเลิก/ล็อกอิน Facebook ไม่สำเร็จ');
        return false;
      }
      return _authRequest('/auth/facebook', {'accessToken': token.token});
    } catch (e) {
      state = state.copyWith(
          loading: false,
          error: 'ล็อกอิน Facebook ไม่สำเร็จ (ตรวจการตั้งค่า OAuth)');
      return false;
    }
  }

  Future<void> refreshProfile() async {
    final token = await _tokens.read();
    if (token == null) return;
    try {
      final res = await _dio.get('/auth/me');
      state = state.copyWith(
          user: AppUser.fromJson(res.data['user'] as Map<String, dynamic>));
    } catch (_) {}
  }

  Future<void> logout() async {
    await _tokens.clear();
    try {
      await GoogleSignIn().signOut();
      await FacebookAuth.instance.logOut();
    } catch (_) {}
    state = const AuthState();
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
    (ref) => AuthController(ref));
