import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/money.dart';
import 'goals_provider.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          // 1. Top Green Header
          _HeaderSection(),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                // 2. Robot Coach Banner
                const _CoachBanner(),
                const SizedBox(height: 20),

                // 3. Section Title
                const Text(
                  'เป้าหมายของฉัน',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),

                // 4. Goals Cards
                if (goals.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'ไม่มีเป้าหมายที่อยู่ระหว่างดำเนินการ',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  )
                else
                  ...goals.map((g) => Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: _GoalItemCard(goal: g),
                      )),

                // 5. Add Goal Dashed Outlined Button
                const SizedBox(height: 8),
                _AddGoalButton(),
                const SizedBox(height: 24),

                // 6. Recommendation section
                const Text(
                  'แนะนำสำหรับคุณ',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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

class _HeaderSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 52, 16, 20),
      decoration: const BoxDecoration(
        gradient: kHeaderGradient,
      ),
      child: Row(
        children: [
          // Avatar
          const CircleAvatar(
            radius: 22,
            backgroundColor: Color(0xFF1E293B),
            child: Icon(Icons.person_rounded, color: AppColors.textMuted),
          ),
          const SizedBox(width: 12),
          // User Name & Streak
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Fanta Inazuma',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D6E47).withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'ใช้งานต่อเนื่อง 20 วัน',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Notifications
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 24),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

class _CoachBanner extends StatelessWidget {
  const _CoachBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Row(
        children: [
          // Robot Illustration Placeholder
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF0F3A22),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 1.5),
            ),
            child: const Icon(Icons.adb_rounded, color: AppColors.primary, size: 36),
          ),
          const SizedBox(width: 16),
          // Banner text
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ตั้งเป้าหมายวันนี้\nเพื่ออนาคตที่ดีกว่า',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'ทำได้แน่!',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalItemCard extends StatelessWidget {
  const _GoalItemCard({required this.goal});

  final GoalModel goal;

  @override
  Widget build(BuildContext context) {
    final remaining = (goal.target - goal.current).clamp(0, goal.target);

    return GestureDetector(
      onTap: () => context.push('/goals/edit?id=${goal.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: softCard(radius: 20),
        child: Column(
          children: [
            Row(
              children: [
                // Circular Emoji Container with Glow
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withOpacity(0.08),
                    border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(goal.emoji, style: const TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                // Goal details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'เป้าหมาย ${Money.format(goal.target)}',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                // Percentage & Chevron
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(goal.progressPercentage * 100).toStringAsFixed(0)} %',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 8,
                child: LinearProgressIndicator(
                  value: goal.progressPercentage,
                  backgroundColor: const Color(0xFF1E293B),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Saved vs Target / Deposit quick actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '฿ ${Money.format(goal.current)} / ${Money.format(goal.target)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    Text(
                      'เหลืออีก ${Money.format(remaining)} บาท',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                    const SizedBox(width: 8),
                    // Quick Deposit button
                    GestureDetector(
                      onTap: () => context.push('/goals/deposit?id=${goal.id}'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primary, width: 1),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.add, size: 12, color: AppColors.primary),
                            Text(
                              'ฝากเงิน',
                              style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddGoalButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/goals/add'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.5),
            width: 1.5,
            style: BorderStyle.solid, // Simple border fallback for design system
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline_rounded, color: AppColors.primary, size: 20),
            SizedBox(width: 8),
            Text(
              'เพิ่มเป้าหมาย',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: softCard(radius: 20),
      child: Row(
        children: [
          // Robot avatar circle
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Color(0xFF0F3A22),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.android_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: 16),
          // Recommendation details
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'แนะนำเป้าหมายระยะสั้น',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'ลองตั้งเป้าหมายระยะสั้นก่อน เพื่อสร้างวินัยทางการเงิน',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
