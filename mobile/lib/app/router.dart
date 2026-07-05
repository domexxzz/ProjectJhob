import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/auth_controller.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/forgot_password_screen.dart'; // ➕ อิมพอร์ตหน้าลืมรหัสผ่านเข้ามาเพิ่ม
import '../features/dashboard/dashboard_screen.dart';
import '../features/dashboard/edit_balance_screen.dart'; // ➕ อิมพอร์ตหน้าแก้ไขยอดเงินคงเหลือเข้ามา
import '../features/transactions/add_transaction_screen.dart';
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
import '../features/onboarding/welcome_1_screen.dart';
import '../features/onboarding/welcome_2_screen.dart';
import '../features/onboarding/welcome_3_screen.dart';
import '../features/subscriptions/subscriptions_screen.dart';
import '../features/menu/menu_screen.dart';
import '../features/dashboard/edit_balance_screen.dart';

/// Set เป็น true หลังจากผ่าน Welcome3 แล้วกด "เริ่มต้นใช้งาน"
/// ใช้ควบคุม redirect ไม่ให้ข้าม Login page เมื่อมี token เดิมค้างอยู่
final onboardingDoneProvider = StateProvider<bool>((ref) => false);

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    // ── เริ่มต้นที่ Welcome 1 เสมอ ──────────────────────────────────────
    initialLocation: '/welcome1',
    redirect: (context, state) {
      final authed = ref.read(authControllerProvider).isAuthenticated;
      final onboardingDone = ref.read(onboardingDoneProvider);
      final loc = state.matchedLocation;

      // หน้า onboarding — ไม่ต้องตรวจ auth
      final onOnboarding = loc == '/welcome1' ||
          loc == '/welcome2' ||
          loc == '/welcome3';
      if (onOnboarding) return null;

      // 💡 เพิ่มการตรวจจับหน้าลืมรหัสผ่าน เพื่อไม่ให้ระบบเตะกลับไปหน้า Login ขณะที่ user ทำการกู้คืนรหัส
      final onAuthPage = loc == '/login' || loc == '/register' || loc == '/forgot-password';

      if (!authed) return onAuthPage ? null : '/login';

      // ถ้ายังไม่ผ่าน onboarding (มาจาก Welcome flow)
      // อนุญาตให้แสดง /login แม้ว่า token เดิมจะยังค้างอยู่
      if (onAuthPage && !onboardingDone) return null;

      if (onAuthPage) return '/';
      return null;
    },
    routes: [
      // ── Onboarding ──────────────────────────────────────────────────────
      GoRoute(path: '/welcome1', builder: (_, __) => const Welcome1Screen()),
      GoRoute(path: '/welcome2', builder: (_, __) => const Welcome2Screen()),
      GoRoute(path: '/welcome3', builder: (_, __) => const Welcome3Screen()),

      // ── Auth ─────────────────────────────────────────────────────────────
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      // ➕ เพิ่มเส้นทางสำหรับหน้าลืมรหัสผ่าน (3 สเต็ปในหน้าเดียวที่เราทำไว้)
      GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),

      // ── App ──────────────────────────────────────────────────────────────
      GoRoute(path: '/', builder: (_, __) => const DashboardScreen()),
      GoRoute(
        path: '/edit-balance', // ➕ เส้นทางสำหรับหน้าแก้ไขยอดคงเหลือ
        builder: (_, __) => const EditBalanceScreen(),
      ),
      GoRoute(
        path: '/add',
        builder: (context, state) =>
            AddTransactionScreen(transaction: state.extra as Txn?),
      ),
      GoRoute(path: '/edit-balance', builder: (_, __) => const EditBalanceScreen()),
      GoRoute(path: '/chat', builder: (_, __) => const ChatScreen()),
      GoRoute(path: '/budgets', builder: (_, __) => const BudgetListScreen()),
      GoRoute(
        path: '/budgets/edit',
        builder: (context, state) => BudgetEditScreen(status: state.extra as BudgetStatus),
      ),
      GoRoute(path: '/budgets/amount', builder: (_, __) => const BudgetAmountScreen()),
      GoRoute(path: '/budgets/duration', builder: (_, __) => const BudgetDurationScreen()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/menu', builder: (_, __) => const MenuScreen()),
      GoRoute(path: '/subscriptions', builder: (_, __) => const SubscriptionsScreen()),
      GoRoute(path: '/goals', builder: (_, __) => const GoalsScreen()),
      GoRoute(path: '/goals/add', builder: (_, __) => const EditGoalScreen()),
      GoRoute(
        path: '/goals/edit',
        builder: (context, state) {
          final id = state.uri.queryParameters['id'];
          return EditGoalScreen(goalId: id);
        },
      ),
      GoRoute(
        path: '/goals/deposit',
        builder: (context, state) {
          final id = state.uri.queryParameters['id'];
          return DepositGoalScreen(goalId: id ?? '');
        },
      ),
    ],
  );
});