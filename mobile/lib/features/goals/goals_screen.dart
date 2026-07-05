import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/money.dart';
import 'goals_provider.dart';
import '../auth/auth_controller.dart'; // เพิ่มบรรทัดนี้ตามโครงสร้างโปรเจกต์ของคุณ[cite: 20]

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider);
    final user = ref.watch(authControllerProvider).user;
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // คุมโทน Premium Dark UI แบบ Dashboard
      body: Column(
        children: [
          // 1. Top Green Gradient Header Bar (ถอดจากภาพ goal.png และ dashboard)
          // 1. Top Green Gradient Header Bar (ดึงชื่อและ streak จากระบบ login จริง)[cite: 20]
          _GreenHeader(
            name: user?.displayName ?? 'Fanta Inazuma',
            streak: user?.streak ?? 20,
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
              children: [
                // 2. Coach Banner (พี่เงินและเป้าหมายความสำเร็จ)
                const _CoachBanner(),
                const SizedBox(height: 24),

                // 3. Section Title: เป้าหมายของฉัน
                const Text(
                  'เป้าหมายของฉัน',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),

                // 4. Goals Cards List (การ์ดขอบโค้งมนตามเงื่อนไข UI)
                if (goals.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        'ไม่มีเป้าหมายที่อยู่ระหว่างดำเนินการ',
                        style: TextStyle(color: Colors.white.withOpacity(0.4)),
                      ),
                    ),
                  )
                else
                  ...goals.map((g) => Padding(
                        padding: const EdgeInsets.only(bottom: 14.0),
                        child: _GoalItemCard(goal: g),
                      )),

                // 5. Add Goal Button (ปุ่มเส้นประสีเขียวขอบมน)
                const SizedBox(height: 4),
                const _AddGoalButton(),
                const SizedBox(height: 28),

                // 6. Recommendation section
                const Text(
                  'แนะนำสำหรับคุณ',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                const _RecommendationCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. Green Header (ปรับปรุง Gradient คอนทราสต์ให้เข้าเซ็ตตามดีไซน์ Dashboard)
// ─────────────────────────────────────────────────────────────────────────────
class _GreenHeader extends StatelessWidget {
  const _GreenHeader({required this.name, required this.streak});
  final String name;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topPad + 16, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF06120A), Color(0xFF334E3D), Color(0xFF3CAE63)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF5E6E85),
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'ใช้งานต่อเนื่อง $streak วัน',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. Coach Banner (การ์ดโปรโมตหุ่นยนต์พี่เงินยิงธนูเข้าเป้า)
// ─────────────────────────────────────────────────────────────────────────────
class _CoachBanner extends StatelessWidget {
  const _CoachBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      // ใช้ ClipRRect เพื่อบีบให้มุมของรูปภาพโค้งมนเข้ากับ Container
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Image.asset(
          'assets/images/goal_banner.png', // เปลี่ยนเป็น path รูปภาพที่คุณเซฟไว้ในโปรเจกต์
          fit: BoxFit.cover, 
          width: double.infinity,
          // ในกรณีที่รูปภาพยังโหลดไม่ขึ้นหรือระบุ path ผิด จะแสดงกล่องสีดำเพื่อไม่ให้ UI พัง
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: 140,
              color: const Color(0xFF061A13),
              alignment: Alignment.center,
              child: const Icon(Icons.image_not_supported_rounded, color: Colors.white24, size: 40),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. Goal Item Card (การ์ดทอง/ส้ม ไล่ระดับเฉดสีเหลืองทองหรูหราแบบรูปภาพ goal.png)
// ─────────────────────────────────────────────────────────────────────────────
class _GoalItemCard extends StatelessWidget {
  const _GoalItemCard({required this.goal});
  final GoalModel goal;

  @override
  Widget build(BuildContext context) {
    final remaining = (goal.target - goal.current).clamp(0, goal.target);
    final int displayPercentage = (goal.progressPercentage * 100).toInt();

    Color progressColor;
    if (displayPercentage <= 50) {
      progressColor = const Color(0xFF37C871); // 0-60% สีเขียว
    } else if (displayPercentage <= 70) {
      progressColor = const Color(0xFFFFD54F); // 71-99% สีเหลือง
    } else {
      progressColor = const Color(0xFFFF4D4F); // 100% ขึ้นไป สีแดง
    }

    return GestureDetector(
      onTap: () => context.push('/goals/edit?id=${goal.id}'),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          // ใช้สีพื้นหลังไล่เฉด 0C3A1E ไป 203231 ล่างมาบน ตามที่คุณเลือกไว้ก่อนหน้านี้
          gradient: const LinearGradient(
            colors: [
              Color(0xFF0C3A1E), // ล่าง
              Color(0xFF203231), // บน
            ],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                  alignment: Alignment.center,
                  child: Text(goal.emoji, style: const TextStyle(fontSize: 24)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'เป้าหมาย ฿ ${Money.format(goal.target)}',
                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                      ),
                    ],
                  ),
                ),
                // เปอร์เซ็นต์ขนาดใหญ่ด้านขวาตามแบบ Fintech App
                Text(
                  '$displayPercentage%',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: progressColor, // เปลี่ยนสีตามเปอร์เซ็นต์อัตโนมัติ
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, color: Colors.white54),
              ],
            ),
            const SizedBox(height: 14),

            // 2. นำ Stack Progress Bar ดีไซน์มินิมอลแบบใหม่มาแทนที่ Indicator ตัวเก่าตรงนี้
            Stack(
              children: [
                // Light Gray Background Track (แทร็กพื้นหลังบางๆ)
                Container(
                  height: 8,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEEEEE).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                // Smooth Colored Fill (แถบสีวิ่งตามความคืบหน้า)
                FractionallySizedBox(
                  widthFactor: goal.progressPercentage.clamp(0.0, 1.0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    height: 8,
                    decoration: BoxDecoration(
                      color: progressColor, // สีเปลี่ยนไปตามกฎ
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 3. ปรับข้อมูลสถิติและการจัดวางชิดขวาชิดซ้ายด้านล่าง
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '฿ ${Money.format(goal.current)} / ${Money.format(goal.target)}',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                Text(
                  displayPercentage >= 100
                      ? 'สำเร็จแล้ว 🎉'
                      : 'เหลืออีก ฿ ${Money.format(remaining)} บาท',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. Add Goal Button (ปุ่มสี่เหลี่ยมขอบมนเส้นประสำหรับเพิ่มเป้าหมายใหม่)
// ─────────────────────────────────────────────────────────────────────────────
class _AddGoalButton extends StatelessWidget {
  const _AddGoalButton();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/goals/add'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          // สร้างกรอบเส้นประนุ่มนวลแมตช์เข้าเซ็ตกับ UI ในแอปพลิเคชัน
          border: Border.all(
            color: const Color(0xFF3CAE63).withOpacity(0.4),
            width: 1.5,
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline_rounded, color: Color(0xFF4CD97B), size: 24),
            SizedBox(width: 10),
            Text(
              'เพิ่มเป้าหมาย',
              style: TextStyle(
                color: Color(0xFF4CD97B),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 6. Recommendation Card (การ์ดแนะนำเป้าหมายระยะสั้นสำหรับผู้ใช้งาน)
// ─────────────────────────────────────────────────────────────────────────────
class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF041E14), Color(0xFF0A2B1D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF3CAE63).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Color(0xFF061A13),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.android_rounded, color: Color(0xFF4CD97B), size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'แนะนำเป้าหมายระยะสั้น',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ลองตั้งเป้าหมายระยะสั้นก่อน เพื่อสร้างวินัยทางการเงิน',
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 24),
        ],
      ),
    );
  }
}