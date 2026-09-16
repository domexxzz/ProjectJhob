import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/forgot_password_screen.dart'; // ➕ อิมพอร์ตหน้าลืมรหัสผ่านเข้ามาเพิ่ม
import '../features/dashboard/dashboard_screen.dart';
import '../features/dashboard/financial_dashboard_screen.dart';
import '../features/transactions/slip_screen.dart';
import '../features/transactions/select_date_screen.dart';
import '../features/transactions/transaction.dart';
import '../features/chat/chat_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/goals/goals_screen.dart';
import '../features/goals/edit_goal_screen.dart';
import '../features/goals/deposit_goal_screen.dart';
import '../features/budgets/budget_list_screen.dart';
import '../features/budgets/budget_edit_screen.dart';
import '../features/budgets/budget_amount_screen.dart';
import '../features/budgets/budget_duration_screen.dart';
import '../features/onboarding/launch_screen.dart';
import '../features/onboarding/welcome_1_screen.dart';
import '../features/onboarding/welcome_2_screen.dart';
import '../features/onboarding/welcome_3_screen.dart';
import '../features/subscriptions/subscriptions_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/menu/menu_screen.dart';
import '../features/predictions/predictions_screen.dart';
import '../features/goals/set_deadline_screen.dart';
import '../features/privacy/privacy_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/auth/oauth_redirect_screen.dart';

/// Set เป็น true หลังจากผ่าน Welcome3 แล้วกด "เริ่มต้นใช้งาน"
/// ใช้ควบคุม redirect ไม่ให้ข้าม Login page เมื่อมี token เดิมค้างอยู่
final onboardingDoneProvider = StateProvider<bool>((ref) => false);

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    // ── เริ่มต้นที่ Launch เสมอ ──────────────────────────────────────
    initialLocation: '/launch',
    redirect: (context, state) {
      final authed = ref.read(authControllerProvider).isAuthenticated;
      final onboardingDone = ref.read(onboardingDoneProvider);
      final loc = state.matchedLocation;

      // หน้า Launch & onboarding — ไม่ต้องตรวจ auth
      final onOnboarding =
          loc == '/launch' ||
          loc == '/welcome1' ||
          loc == '/welcome2' ||
          loc == '/welcome3';
      if (onOnboarding) return null;

      // หน้ารับ token จาก server-side OAuth (Facebook) — ปล่อยผ่าน
      // ตอนเพิ่งกลับมา auth ยังโหลดไม่เสร็จ ถ้า guard เตะไป /login จะเข้าแอปไม่ได้
      if (loc == '/oauth') return null;

      // 💡 เพิ่มการตรวจจับหน้าลืมรหัสผ่าน เพื่อไม่ให้ระบบเตะกลับไปหน้า Login ขณะที่ user ทำการกู้คืนรหัส
      final onAuthPage =
          loc == '/login' || loc == '/register' || loc == '/forgot-password';

      if (!authed) return onAuthPage ? null : '/login';

      // ถ้ายังไม่ผ่าน onboarding (มาจาก Welcome flow)
      // อนุญาตให้แสดง /login แม้ว่า token เดิมจะยังค้างอยู่
      if (onAuthPage && !onboardingDone) return null;

      if (onAuthPage) return '/';
      return null;
    },
    routes: [
      // ── Launch ──────────────────────────────────────────────────────────
      GoRoute(
        path: '/launch',
        pageBuilder: (context, state) => _fadeTransitionPage(
          key: state.pageKey,
          child: const LaunchScreen(),
        ),
      ),

      // ── Onboarding ──────────────────────────────────────────────────────
      GoRoute(
        path: '/welcome1',
        pageBuilder: (context, state) => _fadeTransitionPage(
          key: state.pageKey,
          child: const Welcome1Screen(),
        ),
      ),
      GoRoute(
        path: '/welcome2',
        pageBuilder: (context, state) => _fadeTransitionPage(
          key: state.pageKey,
          child: const Welcome2Screen(),
        ),
      ),
      GoRoute(
        path: '/welcome3',
        pageBuilder: (context, state) => _fadeTransitionPage(
          key: state.pageKey,
          child: const Welcome3Screen(),
        ),
      ),

      // ── Auth ─────────────────────────────────────────────────────────────
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => _fadeTransitionPage(
          key: state.pageKey,
          child: const LoginScreen(),
        ),
      ),
      // กลับจาก Facebook server-side OAuth: /oauth?token=<JWT> (หรือ ?fb_error=...)
      GoRoute(
        path: '/oauth',
        builder: (_, state) => OAuthRedirectScreen(
          token: state.uri.queryParameters['token'],
          error: state.uri.queryParameters['fb_error'],
        ),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) => _fadeTransitionPage(
          key: state.pageKey,
          child: const RegisterScreen(),
        ),
      ),
      // ➕ เพิ่มเส้นทางสำหรับหน้าลืมรหัสผ่าน (3 สเต็ปในหน้าเดียวที่เราทำไว้)
      GoRoute(
        path: '/forgot-password',
        pageBuilder: (context, state) => _fadeTransitionPage(
          key: state.pageKey,
          child: const ForgotPasswordScreen(),
        ),
      ),

      // ── App ──────────────────────────────────────────────────────────────
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => _fadeTransitionPage(
          key: state.pageKey,
          child: const DashboardScreen(),
        ),
      ),
      GoRoute(
        path: '/financial-dashboard',
        pageBuilder: (context, state) => _fadeTransitionPage(
          key: state.pageKey,
          child: const FinancialDashboardScreen(),
        ),
      ),
      GoRoute(
        path: '/slip',
        pageBuilder: (context, state) => _fadeTransitionPage(
          key: state.pageKey,
          child: SlipScreen(
            startInManualMode: state.uri.queryParameters['mode'] == 'manual',
          ),
        ),
      ),
      GoRoute(
        path: '/transactions/select-date',
        pageBuilder: (context, state) => _fadeTransitionPage(
          key: state.pageKey,
          child: SelectDateScreen(
            initialDate: state.extra as DateTime?,
          ),
        ),
      ),
      GoRoute(
        path: '/chat',
        pageBuilder: (context, state) => _fadeTransitionPage(
          key: state.pageKey,
          child: const ChatScreen(),
        ),
      ),
      GoRoute(
        path: '/budgets',
        pageBuilder: (context, state) => _fadeTransitionPage(
          key: state.pageKey,
          child: const BudgetListScreen(),
        ),
      ),
      GoRoute(
        path: '/budgets/edit',
        pageBuilder: (context, state) => _fadeTransitionPage(
          key: state.pageKey,
          child: BudgetEditScreen(status: state.extra as BudgetStatus),
        ),
      ),
      GoRoute(
        path: '/budgets/amount',
        pageBuilder: (context, state) => _fadeTransitionPage(
          key: state.pageKey,
          child: const BudgetAmountScreen(),
        ),
      ),
      GoRoute(
        path: '/budgets/duration',
        pageBuilder: (context, state) => _fadeTransitionPage(
          key: state.pageKey,
          child: const BudgetDurationScreen(),
        ),
      ),
      GoRoute(
        path: '/profile',
        pageBuilder: (context, state) => _fadeTransitionPage(
          key: state.pageKey,
          child: const ProfileScreen(),
        ),
      ),
      GoRoute(
        path: '/profile/edit',
        pageBuilder: (context, state) => _fadeTransitionPage(
          key: state.pageKey,
          child: const EditProfileScreen(),
        ),
      ),
      GoRoute(
        path: '/menu',
        pageBuilder: (context, state) => _fadeTransitionPage(
          key: state.pageKey,
          child: const MenuScreen(),
        ),
      ),
      GoRoute(
        path: '/privacy',
        pageBuilder: (context, state) => _fadeTransitionPage(
          key: state.pageKey,
          child: const PrivacyScreen(),
        ),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) => _fadeTransitionPage(
          key: state.pageKey,
          child: const SettingsScreen(),
        ),
      ),
      GoRoute(
        path: '/subscriptions',
        pageBuilder: (context, state) => _fadeTransitionPage(
          key: state.pageKey,
          child: const SubscriptionsScreen(),
        ),
      ),
      GoRoute(
        path: '/notifications',
        pageBuilder: (context, state) => _fadeTransitionPage(
          key: state.pageKey,
          child: const NotificationsScreen(),
        ),
      ),
      GoRoute(
        path: '/predictions',
        pageBuilder: (context, state) => _fadeTransitionPage(
          key: state.pageKey,
          child: const PredictionsScreen(),
        ),
      ),
      GoRoute(
        path: '/goals',
        pageBuilder: (context, state) => _fadeTransitionPage(
          key: state.pageKey,
          child: const GoalsScreen(),
        ),
      ),
      GoRoute(
        path: '/goals/add',
        pageBuilder: (context, state) => _fadeTransitionPage(
          key: state.pageKey,
          child: const EditGoalScreen(),
        ),
      ),
      GoRoute(
        path: '/goals/edit',
        pageBuilder: (context, state) {
          final id = state.uri.queryParameters['id'];
          return _fadeTransitionPage(
            key: state.pageKey,
            child: EditGoalScreen(goalId: id),
          );
        },
      ),
      GoRoute(
        path: '/goals/deposit',
        pageBuilder: (context, state) {
          final id = state.uri.queryParameters['id'];
          return _fadeTransitionPage(
            key: state.pageKey,
            child: DepositGoalScreen(goalId: id ?? ''),
          );
        },
      ),
      GoRoute(
        path: '/goals/duration',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, DateTime?>?;
          return _fadeTransitionPage(
            key: state.pageKey,
            child: SetDeadlineScreen(
              initialStartDate: extra?['startDate'],
              initialEndDate: extra?['endDate'],
            ),
          );
        },
      ),
    ],
  );
});

CustomTransitionPage<void> _fadeTransitionPage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (
      context,
      animation,
      secondaryAnimation,
      child,
    ) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
          reverseCurve: Curves.easeOut,
        ),
        child: FadeTransition(
          opacity: Tween<double>(begin: 1.0, end: 0.0).animate(
            CurvedAnimation(
              parent: secondaryAnimation,
              curve: Curves.easeOut,
              reverseCurve: Curves.easeOut,
            ),
          ),
          child: child,
        ),
      );
    },
  );
}
