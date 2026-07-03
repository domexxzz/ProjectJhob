import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/router.dart' show onboardingDoneProvider;
import '../../app/theme.dart';
import 'welcome_1_screen.dart' show WelcomeDots;

class Welcome3Screen extends ConsumerStatefulWidget {
  const Welcome3Screen({super.key});

  @override
  ConsumerState<Welcome3Screen> createState() => _Welcome3ScreenState();
}

class _Welcome3ScreenState extends ConsumerState<Welcome3Screen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scaleAnim = Tween<double>(begin: 0.7, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _slideAnim = Tween<Offset>(
            begin: const Offset(0.3, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ── Animated icon ──────────────────────────────────
              ScaleTransition(
                scale: _scaleAnim,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.income.withOpacity(0.18),
                          AppColors.income.withOpacity(0.04),
                        ],
                      ),
                      border: Border.all(
                          color: AppColors.income.withOpacity(0.35), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.income.withOpacity(0.28),
                          blurRadius: 48,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 90,
                      color: AppColors.income,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 52),

              // ── Page indicator ─────────────────────────────────
              const WelcomeDots(current: 2, total: 3),

              const SizedBox(height: 36),

              // ── Text ───────────────────────────────────────────
              SlideTransition(
                position: _slideAnim,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Column(
                    children: [
                      Text(
                        'ปรับระบบการเงินให้คล่องตัว',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Outfit',
                          color: AppColors.income,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'เชื่อมต่อ QR ธนาคาร Statement และอื่นๆ\nของคุณเพื่อติดตามข้อมูลได้อย่างราบรื่น\nรับข้อมูลอัปเดตแบบเรียลไทม์และบริหาร\nจัดการเงินของคุณได้อย่างเต็มที่',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textMuted,
                          height: 1.7,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(flex: 3),

              // ── Button ─────────────────────────────────────────
              FadeTransition(
                opacity: _fadeAnim,
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.income,
                        ),
                        onPressed: () {
                          // บอก router ว่า onboarding เสร็จแล้ว
                          // เพื่อไม่ให้ redirect ข้าม /login ไป home
                          ref.read(onboardingDoneProvider.notifier).state = true;
                          context.go('/login');
                        },
                        child: const Text('เริ่มต้นใช้งาน'),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
