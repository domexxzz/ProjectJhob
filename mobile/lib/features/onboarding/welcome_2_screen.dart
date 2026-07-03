import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/router.dart' show onboardingDoneProvider;
import '../../app/theme.dart';
import 'welcome_1_screen.dart' show WelcomeDots;

class Welcome2Screen extends ConsumerStatefulWidget {
  const Welcome2Screen({super.key});

  @override
  ConsumerState<Welcome2Screen> createState() => _Welcome2ScreenState();
}

class _Welcome2ScreenState extends ConsumerState<Welcome2Screen>
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
    const accentColor = Color(0xFF6C63FF);
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
                          accentColor.withOpacity(0.18),
                          accentColor.withOpacity(0.04),
                        ],
                      ),
                      border: Border.all(
                          color: accentColor.withOpacity(0.35), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withOpacity(0.28),
                          blurRadius: 48,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.bar_chart_rounded,
                      size: 90,
                      color: accentColor,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 52),

              // ── Page indicator ─────────────────────────────────
              const WelcomeDots(current: 1, total: 3),

              const SizedBox(height: 36),

              // ── Text ───────────────────────────────────────────
              SlideTransition(
                position: _slideAnim,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: const Column(
                    children: [
                      Text(
                        'วางแผนอย่างชาญฉลาด',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Outfit',
                          color: accentColor,
                        ),
                      ),
                      SizedBox(height: 20),
                      Text(
                        'กำหนดงบประมาณรายเดือน ติดตามค่าใช้จ่าย\nและออมเงินให้มีประสิทธิภาพยิ่งขึ้น\nด้วยการวิเคราะห์อัจฉริยะที่ช่วยให้คุณ\nตัดสินใจทางการเงินได้อย่างถูกต้อง',
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

              // ── Buttons ────────────────────────────────────────
              FadeTransition(
                opacity: _fadeAnim,
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                        ),
                        onPressed: () => context.go('/welcome3'),
                        child: const Text('ต่อไป'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        ref.read(onboardingDoneProvider.notifier).state = true;
                        context.go('/login');
                      },
                      child: const Text(
                        'ข้าม',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
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
