import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import 'auth_controller.dart';

/// ปุ่มล็อกอินด้วย Google / Facebook — ใช้ทั้งหน้า Login และ Register
/// สไตล์: divider "or continue with" + ปุ่มวงกลมพื้นขาว (ตาม mockup register)
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
        Row(
          children: [
            
          ],
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SocialCircleButton(
              icon: Icons.facebook,
              iconColor: const Color(0xFF1877F2),
              onTap: loading ? null : () => run(() => ref.read(authControllerProvider.notifier).loginWithFacebook()),
            ),
            const SizedBox(width: 20),
            _SocialCircleButton(
              // 📌 Material ไม่มีโลโก้ Google หลายสีในตัว — ถ้าต้องการโลโก้จริง
              // ให้ใช้ asset รูป (เช่น assets/images/google.png) แทน Icon นี้
              icon: Icons.g_mobiledata_rounded,
              iconColor: const Color(0xFFEA4335),
              iconSize: 32,
              onTap: loading ? null : () => run(() => ref.read(authControllerProvider.notifier).loginWithGoogle()),
            ),
          ],
        ),
      ],
    );
  }
}

class _SocialCircleButton extends StatelessWidget {
  const _SocialCircleButton({
    required this.icon,
    required this.iconColor,
    required this.onTap,
    this.iconSize = 24,
  });

  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 64,
        height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, color: iconColor, size: iconSize),
      ),
    );
  }
}
