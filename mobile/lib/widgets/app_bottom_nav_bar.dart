import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/transactions/transactions_repository.dart';

enum AppTab { home, dashboard, chat, menu, goals, budgets, none }

class AppBottomNavigationBar extends StatelessWidget {
  const AppBottomNavigationBar({
    super.key,
    required this.currentTab,
  });

  final AppTab currentTab;

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: const Color(0xFF1A1A1A),
      elevation: 10,
      notchMargin: 8,
      shape: const AutomaticNotchedShape(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        CircleBorder(),
      ),
      height: 74,
      padding: EdgeInsets.zero,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            icon: currentTab == AppTab.home
                ? Icons.home_rounded
                : Icons.home_outlined,
            label: 'หน้าหลัก',
            active: currentTab == AppTab.home,
            onTap: () {
              if (currentTab != AppTab.home) {
                context.go('/');
              }
            },
          ),
          _NavItem(
            icon: Icons.trending_up_rounded,
            label: 'แดชบอร์ด',
            active: currentTab == AppTab.dashboard,
            onTap: () {
              if (currentTab != AppTab.dashboard) {
                context.go('/financial-dashboard');
              }
            },
          ),
          const SizedBox(width: 48),
          _NavItem(
            icon: currentTab == AppTab.chat
                ? Icons.chat_bubble_rounded
                : Icons.chat_bubble_outline_rounded,
            label: 'พี่เงิน',
            active: currentTab == AppTab.chat,
            onTap: () {
              if (currentTab != AppTab.chat) {
                context.go('/chat');
              }
            },
          ),
          _NavItem(
            icon: currentTab == AppTab.menu
                ? Icons.grid_view_rounded
                : Icons.grid_view_outlined,
            label: 'เมนู',
            active: currentTab == AppTab.menu,
            onTap: () {
              if (currentTab != AppTab.menu) {
                context.go('/menu');
              }
            },
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF4CD97B) : Colors.white60;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: active ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppFloatingActionButton extends ConsumerWidget {
  const AppFloatingActionButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 62,
      width: 62,
      margin: const EdgeInsets.only(top: 10),
      child: FloatingActionButton(
        onPressed: () async {
          await context.push('/slip');
          try {
            ref.invalidate(dashboardProvider);
            await ref.read(dashboardProvider.future);
          } catch (_) {}
        },
        backgroundColor: const Color(0xFF3CAE63),
        foregroundColor: Colors.black,
        shape: const CircleBorder(),
        elevation: 4,
        child: const Icon(Icons.add, size: 32),
      ),
    );
  }
}
