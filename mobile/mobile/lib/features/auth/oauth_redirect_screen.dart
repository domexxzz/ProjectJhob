import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import 'auth_controller.dart';

/// หน้าพักระหว่างกลับจาก server-side OAuth (Facebook)
/// backend เด้งมาที่ /oauth?token=<JWT> → เก็บ token → โหลดโปรไฟล์ → เข้าแอป
/// (ใช้บนเว็บ/PWA เพราะ iOS Safari บล็อก FB JS SDK จึงต้องใช้ redirect flow)
class OAuthRedirectScreen extends ConsumerStatefulWidget {
  const OAuthRedirectScreen({super.key, this.token, this.error});

  final String? token;
  final String? error;

  @override
  ConsumerState<OAuthRedirectScreen> createState() =>
      _OAuthRedirectScreenState();
}

class _OAuthRedirectScreenState extends ConsumerState<OAuthRedirectScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handle());
  }

  Future<void> _handle() async {
    // มี error ส่งกลับมาจาก backend → กลับหน้า login
    if (widget.error != null && widget.error!.isNotEmpty) {
      if (mounted) context.go('/login');
      return;
    }

    final auth = ref.read(authControllerProvider.notifier);
    var ok = ref.read(authControllerProvider).isAuthenticated;

    // ปกติ _bootstrap() อ่าน token จาก URL ไปแล้ว — ถ้ายังไม่เข้า ใช้ token จาก route ซ้ำอีกชั้น
    if (!ok && widget.token != null && widget.token!.isNotEmpty) {
      ok = await auth.applyOAuthToken(widget.token!);
    }

    // เผื่อ bootstrap ยังทำงานค้างอยู่ — รอสั้น ๆ แล้วเช็กซ้ำ
    if (!ok) {
      for (var i = 0; i < 20 && mounted; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        if (ref.read(authControllerProvider).isAuthenticated) {
          ok = true;
          break;
        }
      }
    }

    if (!mounted) return;
    if (ok) {
      // ผ่าน onboarding แล้ว (ไม่งั้น guard จะยอมให้ค้างหน้า /login)
      ref.read(onboardingDoneProvider.notifier).state = true;
      context.go('/');
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text('กำลังเข้าสู่ระบบ...',
                style: TextStyle(color: Colors.white70, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}
