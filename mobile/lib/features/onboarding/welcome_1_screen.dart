import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/router.dart' show onboardingDoneProvider;
import '../../app/theme.dart';

class Welcome1Screen extends ConsumerStatefulWidget {
  const Welcome1Screen({super.key});

  @override
  ConsumerState<Welcome1Screen> createState() => _Welcome1ScreenState();
}

class _Welcome1ScreenState extends ConsumerState<Welcome1Screen>
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
            begin: const Offset(0, 0.3), end: Offset.zero)
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
                          AppColors.primary.withOpacity(0.18),
                          AppColors.primary.withOpacity(0.04),
                        ],
                      ),
                      border: Border.all(
                          color: AppColors.primary.withOpacity(0.35), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.28),
                          blurRadius: 48,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.savings_rounded,
                      size: 90,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 52),

              // ── Page indicator ─────────────────────────────────
              const WelcomeDots(current: 0, total: 3),

              const SizedBox(height: 36),

              // ── Text ───────────────────────────────────────────
              SlideTransition(
                position: _slideAnim,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Column(
                    children: [
                      RichText(
                        textAlign: TextAlign.center,
                        text: const TextSpan(
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Outfit',
                          ),
                          children: [
                            TextSpan(
                                text: 'ผู้ช่วย',
                                style: TextStyle(color: Colors.white)),
                            TextSpan(
                                text: 'ทางการเงิน',
                                style: TextStyle(color: AppColors.primary)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'การช่วยการจัดการเงินของคุณ',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'ยินดีต้อนรับสู่ พี่เงิน!\nเพื่อนคู่ใจด้านการเงินส่วนตัวของคุณ\nให้คุณจัดการเรื่องเงินได้อย่างง่ายดาย\nพร้อมด้วยระบบแชทอัจฉริยะที่ขับเคลื่อนด้วย AI\nคอยดูแลและช่วยเหลือคุณในทุกขั้นตอน',
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
                        onPressed: () => context.go('/welcome2'),
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

// ── Shared dot indicator (exported for use in Welcome 2 & 3) ─────────────────
class WelcomeDots extends StatelessWidget {
  const WelcomeDots({super.key, required this.current, required this.total});
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: active
                ? AppColors.primary
                : AppColors.textMuted.withOpacity(0.3),
          ),
        );
      }),
    );
  }
}
