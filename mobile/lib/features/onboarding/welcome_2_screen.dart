import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/router.dart' show onboardingDoneProvider;
import '../../app/theme.dart';

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
    const accentColor = Color(0xFF6C63FF);
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

              // ── โลโก้ขนาดใหญ่ 280x280 ตรงกลาง (พร้อมไฟสีม่วง) ──
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
                          color: accentColor.withOpacity(0.25),
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
                  child: const Column(
                    children: [
                      Text(
                        'วางแผนอย่างชาญฉลาด',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 20),
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
