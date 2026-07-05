import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import 'auth_controller.dart';

/// ปุ่มล็อกอินด้วย Google / Facebook — ใช้ทั้งหน้า Login และ Register
class SocialLoginButtons extends ConsumerWidget {
  const SocialLoginButtons({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loading = ref.watch(authControllerProvider).loading;

    Future<void> run(Future<bool> Function() fn) async {
      final ok = await fn();
      if (ok && context.mounted) context.go('/');
    }

    return Column(
      children: [
        const Row(
          children: [
            Expanded(child: Divider(color: Colors.white24)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('หรือ', style: TextStyle(color: AppColors.textMuted)),
            ),
            Expanded(child: Divider(color: Colors.white24)),
          ],
        ),
        const SizedBox(height: 16),
        _SocialButton(
          label: 'เข้าสู่ระบบด้วย Google',
          icon: Icons.g_mobiledata_rounded,
          bg: Colors.white,
          fg: Colors.black87,
          onTap: loading ? null : () => run(() => ref.read(authControllerProvider.notifier).loginWithGoogle()),
        ),
        const SizedBox(height: 12),
        _SocialButton(
          label: 'เข้าสู่ระบบด้วย Facebook',
          icon: Icons.facebook,
          bg: const Color(0xFF1877F2),
          fg: Colors.white,
          onTap: loading ? null : () => run(() => ref.read(authControllerProvider.notifier).loginWithFacebook()),
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.icon,
    required this.bg,
    required this.fg,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color bg;
  final Color fg;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: fg, size: 26),
        label: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
