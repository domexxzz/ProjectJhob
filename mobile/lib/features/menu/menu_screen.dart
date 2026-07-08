import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../auth/auth_controller.dart';
import '../notifications/notif_bell.dart';

/// หน้า เมนู (P15) — ทางเข้า บัญชี / การตั้งค่า / ความเป็นส่วนตัว / Subscription
class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Column(
        children: [
          _MenuHeader(name: user?.displayName ?? 'เพื่อน', streak: user?.streak ?? 0),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 100),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _MenuCard(
                          icon: Icons.person,
                          title: 'บัญชีผู้ใช้',
                          subtitle: 'เข้าสู่ระบบ, ตรวจสอบสิทธิ์',
                          onTap: () => context.push('/profile'),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _MenuCard(
                          icon: Icons.settings,
                          title: 'การตั้งค่า',
                          subtitle: 'ตั้งค่าบัญชี,\nตั้งค่าการแจ้งเตือน',
                          onTap: () => _soon(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _MenuCard(
                          icon: Icons.lock,
                          title: 'ความเป็นส่วนตัว',
                          subtitle: 'การจัดการรหัสผ่าน,\nและตั้งค่าความเป็นส่วนตัว',
                          onTap: () => _soon(context),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _MenuCard(
                          icon: Icons.receipt_long,
                          title: 'Subscription',
                          subtitle: 'การสมัครสมาชิก,\nบิลประจำงวด',
                          onTap: () => context.push('/subscriptions'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'menuFab',
        onPressed: () => context.push('/add'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        elevation: 6,
        child: const Icon(Icons.add, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: const _MenuNav(),
    );
  }

  void _soon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('อยู่ระหว่างพัฒนา (Sprint 7) 🔧')),
    );
  }
}

class _MenuHeader extends StatelessWidget {
  const _MenuHeader({required this.name, required this.streak});
  final String name;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topPad + 14, 20, 40),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF06120A), Color(0xFF334E3D), Color(0xFF3CAE63)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade700,
              border: Border.all(color: AppColors.primary.withOpacity(0.5), width: 2),
            ),
            child: const Icon(Icons.person, color: Colors.white70, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                  ),
                  child: Text('ใช้งานต่อเนื่อง $streak วัน',
                      style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const NotifBell(),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 150,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF262626),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF1A1A1A), size: 24),
            ),
            const Spacer(),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11, height: 1.3)),
          ],
        ),
      ),
    );
  }
}

class _MenuNav extends StatelessWidget {
  const _MenuNav();

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: const Color(0xFF121212),
      elevation: 12,
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      height: 66,
      padding: EdgeInsets.zero,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _MenuNavItem(icon: Icons.home_rounded, label: 'หน้าหลัก', onTap: () => context.go('/')),
          _MenuNavItem(icon: Icons.bar_chart_rounded, label: 'งบ', onTap: () => context.push('/budgets')),
          const SizedBox(width: 40),
          _MenuNavItem(icon: Icons.smart_toy_rounded, label: 'พี่เงิน', onTap: () => context.push('/chat')),
          const _MenuNavItem(icon: Icons.grid_view_rounded, label: 'เมนู', active: true),
        ],
      ),
    );
  }
}

class _MenuNavItem extends StatelessWidget {
  const _MenuNavItem({required this.icon, required this.label, this.active = false, this.onTap});
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : Colors.white38;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                )),
          ],
        ),
      ),
    );
  }
}
