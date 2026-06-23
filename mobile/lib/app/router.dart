import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/transactions/add_transaction_screen.dart';
import '../features/transactions/transaction.dart';
import '../features/chat/chat_screen.dart';
import '../features/profile/profile_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final authed = ref.read(authControllerProvider).isAuthenticated;
      final loc = state.matchedLocation;
      final onAuthPage = loc == '/login' || loc == '/register';
      if (!authed) return onAuthPage ? null : '/login';
      if (onAuthPage) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const DashboardScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(
        path: '/add',
        builder: (context, state) => AddTransactionScreen(transaction: state.extra as Txn?),
      ),
      GoRoute(path: '/chat', builder: (_, __) => const ChatScreen()),
      GoRoute(path: '/budgets', builder: (_, __) => const BudgetScreen()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
    ],
  );
});
