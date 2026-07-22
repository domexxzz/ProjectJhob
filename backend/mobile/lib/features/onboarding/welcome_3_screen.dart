import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/router.dart' show onboardingDoneProvider;
import '../../app/theme.dart';

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
            begin: const Offset(0, 0.2), end: Offset.zero)
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
              const SizedBox(height: 48),

              // ── Header: ผู้ช่วยทางการเงิน (เหมือนกันทุกหน้าตาม Mockup) ──
              FadeTransition(
                opacity: _fadeAnim,
                child: RichText(
                  textAlign: TextAlign.center,
                  text: const TextSpan(
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
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
              ),

              const Spacer(flex: 2),

              // ── โลโก้ขนาดใหญ่ 280x280 ตรงกลาง (พร้อมไฟสีเขียวสว่าง) ──
              ScaleTransition(
                scale: _scaleAnim,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.income.withOpacity(0.25),
                          blurRadius: 50,
                          spreadRadius: 6,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),

              const Spacer(flex: 2),

              // ── ส่วนข้อความอธิบายด้านล่าง ──
              SlideTransition(
                position: _slideAnim,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Column(
                    children: [
                      const Text(
                        'ปรับระบบการเงินของคุณให้คล่องตัว',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'เชื่อมต่อQr ธนาคาร Statement และอื่นๆ\nของคุณเพื่อติดตามข้อมูลได้อย่างราบรื่น\nรับข้อมูลอัปเดตแบบเรียลไทม์และบริหารจัดการเงินของ\nคุณได้อย่างเต็มที่',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textMuted,
                          height: 1.7,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(flex: 2),

              // ── ปุ่มนำทางด้านล่างสุด ──
              FadeTransition(
                opacity: _fadeAnim,
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                        ),
                        onPressed: () {
                          ref.read(onboardingDoneProvider.notifier).state = true;
                          context.go('/login');
                        },
                        child: const Text('เริ่มต้น'),
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
