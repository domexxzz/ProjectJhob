import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

import '../../core/api/api_client.dart';

class AppUser {
  AppUser({
    required this.id,
    required this.email,
    this.displayName,
    this.monthlyIncome = 0,
    this.level = 1,
    this.streak = 0,
  });

  final String id;
  final String email;
  final String? displayName;
  final int monthlyIncome;
  final int level;
  final int streak;

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as String,
        email: j['email'] as String,
        displayName: j['displayName'] as String?,
        monthlyIncome: (j['monthlyIncome'] ?? 0) as int,
        level: (j['level'] ?? 1) as int,
        streak: (j['streak'] ?? 0) as int,
      );
}

class AuthState {
  const AuthState({this.user, this.loading = false, this.error});
  final AppUser? user;
  final bool loading;
  final String? error;

  bool get isAuthenticated => user != null;

  AuthState copyWith({AppUser? user, bool? loading, String? error, bool clearError = false}) =>
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
    final token = await _tokens.read();
    if (token == null) return;
    try {
      final res = await _dio.get('/auth/me');
      state = state.copyWith(user: AppUser.fromJson(res.data['user'] as Map<String, dynamic>));
    } catch (_) {
      await _tokens.clear();
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

  Future<bool> _authRequest(String path, Map<String, dynamic> body) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final res = await _dio.post(path, data: body);
      await _tokens.write(res.data['token'] as String);
      state = AuthState(user: AppUser.fromJson(res.data['user'] as Map<String, dynamic>));
      return true;
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = data is Map ? data['error']?.toString() : null;
      state = state.copyWith(loading: false, error: msg ?? 'เชื่อมต่อเซิร์ฟเวอร์ไม่สำเร็จ');
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
      final accessToken = auth.accessToken; // เว็บให้ accessToken (idToken เป็น null)
      if (idToken == null && accessToken == null) {
        state = state.copyWith(loading: false, error: 'ไม่ได้รับ Google token');
        return false;
      }
      return _authRequest('/auth/google', {
        if (idToken != null) 'idToken': idToken,
        if (accessToken != null) 'accessToken': accessToken,
      });
    } catch (e) {
      state = state.copyWith(loading: false, error: 'ล็อกอิน Google ไม่สำเร็จ ลองใหม่อีกครั้ง');
      return false;
    }
  }

  /// ล็อกอินด้วย Facebook → ส่ง accessToken ให้ backend verify
  Future<bool> loginWithFacebook() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final result = await FacebookAuth.instance.login(permissions: const ['email', 'public_profile']);
      final token = result.accessToken;
      if (result.status != LoginStatus.success || token == null) {
        state = state.copyWith(loading: false, error: result.message ?? 'ยกเลิก/ล็อกอิน Facebook ไม่สำเร็จ');
        return false;
      }
      return _authRequest('/auth/facebook', {'accessToken': token.token});
    } catch (e) {
      state = state.copyWith(loading: false, error: 'ล็อกอิน Facebook ไม่สำเร็จ (ตรวจการตั้งค่า OAuth)');
      return false;
    }
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

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) => AuthController(ref));
