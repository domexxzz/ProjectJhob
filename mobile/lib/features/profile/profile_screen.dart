import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/money.dart';
import '../auth/auth_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    return Scaffold(
      appBar: AppBar(title: const Text('ฉัน', style: TextStyle(fontWeight: FontWeight.bold))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 42,
                  backgroundColor: AppColors.chipBg,
                  child: Icon(Icons.person_rounded, size: 44, color: AppColors.primary),
                ),
                const SizedBox(height: 12),
                Text(user?.displayName ?? 'ผู้ใช้',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                const SizedBox(height: 2),
                Text(user?.email ?? '', style: const TextStyle(color: AppColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _InfoRow(
            icon: Icons.account_balance_wallet_rounded,
            label: 'รายได้ต่อเดือน',
            value: user != null ? Money.formatBaht(user.monthlyIncome) : '-',
          ),
          _InfoRow(
            icon: Icons.local_fire_department_rounded,
            label: 'Streak',
            value: '${user?.streak ?? 0} วัน',
          ),
          _InfoRow(icon: Icons.star_rounded, label: 'Level', value: '${user?.level ?? 1}'),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout),
            label: const Text('ออกจากระบบ'),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text('พี่เงิน · ที่ปรึกษาการเงิน AI', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: softCard(),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: AppColors.textMuted)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark)),
        ],
      ),
    );
  }
}
