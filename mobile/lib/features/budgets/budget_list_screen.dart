import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/money.dart';
import '../transactions/transaction.dart';
import '../transactions/transactions_repository.dart';
import '../auth/auth_controller.dart'; 
import '../settings/settings_screen.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import 'package:intl/intl.dart';

class BudgetListScreen extends ConsumerWidget {
  const BudgetListScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(budgetsListProvider);
    ref.invalidate(dashboardProvider);
    await Future.wait([
      ref.read(budgetsListProvider.future),
      ref.read(dashboardProvider.future),
    ]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moneySettings = ref.watch(
      appSettingsProvider.select((s) => (s.currency, s.usdRate)),
    );
    Money.configure(moneySettings.$1, thbToUsdRate: moneySettings.$2);
    final budgets = ref.watch(budgetsListProvider);
    final statuses = ref.watch(budgetStatusProvider);
    final user = ref.watch(authControllerProvider).user;

    return Scaffold(
      backgroundColor: const Color(
          0xFF121212), // ธีม Premium Dark UI แบบเดียวกับเป้าหมายและแดชบอร์ด
      body: Column(
        children: [
          // 1. Top Green Gradient Header Bar (ถอดดีไซน์ไล่ระดับสีแบบเดียวกับ Goals Screen เป๊ะๆ)
          _GreenHeader(
            name: user?.displayName ?? 'Fanta Inazuma',
            streak: user?.streak ?? 20,
          ),

          // 2. ส่วนแสดงเนื้อหารายการงบประมาณ
          Expanded(
            child: RefreshIndicator(
              color: const Color(0xFF3CAE63),
              onRefresh: () => _refresh(ref),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'งบประมาณของคุณ 📊',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      IconButton(
                        onPressed: () => context.push('/budgets/amount'),
                        icon: const Icon(Icons.add_circle_outline,
                            color: AppColors.primary, size: 26),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // จัดการสถานะการโหลดข้อมูลจาก Provider
                  budgets.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primary)),
                    ),
                    error: (err, _) => _BudgetError(
                      message: err.toString(),
                      onRetry: () => _refresh(ref),
                    ),
                    data: (list) {
                      final activeStatuses = statuses;
                      if (activeStatuses.isEmpty) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFF3CAE63).withOpacity(0.2)),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.pie_chart_outline_rounded,
                                  color: Colors.white24, size: 44),
                              SizedBox(height: 12),
                              Text(
                                'ยังไม่มีการตั้งงบประมาณ',
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'เพิ่มงบประมาณเพื่อควบคุมค่าใช้จ่ายในแต่ละหมวดหมู่กันเลย 💸',
                                style: TextStyle(
                                    color: Colors.white38, fontSize: 11),
                              ),
                            ],
                          ),
                        );
                      }

                      // เรียงลำดับจากระดับความเสี่ยงการใช้เงินเกินงบมากที่สุดไปน้อย
                      final sorted = List<BudgetStatus>.from(activeStatuses);
                      sorted.sort((a, b) => _riskScore(b).compareTo(_riskScore(a)));

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: sorted.length,
                        itemBuilder: (context, idx) {
                          final status = sorted[idx];
                          final pct = status.percentage;

                          // ดึงรายละเอียดสี สัญลักษณ์ของ Badge
                          final badge = _getBudgetStatusDetails(pct);

                          // คำนวณยอดเงินเหลือ / เกิน
                          final remaining = status.amount - status.spent;
                          final overBy = status.spent - status.amount;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              // ปรับสีพื้นหลัง Gradient โทนล่างขึ้นบน [0xFF0C3A1E] -> [0xFF203231] ตัวเดียวกับ Goal Item Card
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
                                )
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Text(status.category?.icon ?? '📊', style: const TextStyle(fontSize: 24)),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        status.displayName,
                                                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    // Badge บอกระดับความปลอดภัย
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                      decoration: BoxDecoration(
                                                        color: badge.$3,
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(badge.$2, size: 10, color: badge.$4),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            badge.$1,
                                                            style: TextStyle(
                                                              color: badge.$4,
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    GestureDetector(
                                      onTap: () => context.push('/budgets/edit',
                                          extra: status),
                                      child: Icon(Icons.edit_note_rounded,
                                          size: 24,
                                          color: Colors.white.withOpacity(0.6)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),

                                // ปรับค่าตัวเลขและสัญลักษณ์ให้อยู่ในระนาบเดียวกันแบบแอปฟินเทค
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'ยอดใช้จ่ายสะสม',
                                      style: TextStyle(
                                          color: Colors.white60, fontSize: 13),
                                    ),
                                    Text(
                                      '${Money.formatBaht(status.spent)} / ${Money.formatBaht(status.amount)}',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Stack Progress Bar มินิมอลเรียบหรู ถอดแบบจาก Goals
                                Stack(
                                  children: [
                                    Container(
                                      height: 8,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEEEEEE)
                                            .withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    FractionallySizedBox(
                                      widthFactor: pct.clamp(0.0, 1.0),
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 300),
                                        curve: Curves.easeOutCubic,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: badge
                                              .$4, // ใช้แถบสีเดียวกับสถานะ Badge
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    pct >= 1.0
                                        ? 'ใช้เงินเกินงบไปแล้ว ${Money.formatBaht(overBy)} 🚨'
                                        : 'เหลืออีก ${Money.formatBaht(remaining)}',
                                    style: TextStyle(
                                        color: badge.$4,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: AppFloatingActionButton(),
      floatingActionButtonLocation: kFixedCenterDockedFabLocation,
      bottomNavigationBar: AppBottomNavigationBar(currentTab: AppTab.budgets),
    );
  }


  (String, IconData, Color, Color) _getBudgetStatusDetails(double pct) {
    if (pct >= 0.8) {
      return (
        'อันตราย',
        Icons.error_outline_rounded,
        const Color(0xFFFF4D4F).withOpacity(0.15),
        const Color(
            0xFFFF4D4F), // สีแดงเดียวกับเป้าหมายที่สำเร็จแล้วหรือใช้เกิน
      );
    } else if (pct >= 0.5) {
      return (
        'เสี่ยง',
        Icons.warning_amber_rounded,
        const Color(0xFFFFC067).withOpacity(0.15),
        const Color(0xFFFFC067), // สีทอง/เหลือง
      );
    } else {
      return (
        'ปลอดภัย',
        Icons.check_circle_outline_rounded,
        const Color(0xFF37C871).withOpacity(0.15),
        const Color(0xFF37C871), // สีเขียว
      );
    }
  }

  double _riskScore(BudgetStatus status) {
    return status.percentage;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. Green Header (ปรับแต่ง Gradient ให้ตรงกับหน้า GoalsScreen เป๊ะๆ)
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
            icon: const Icon(Icons.notifications_none_rounded,
                color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }
}



class _BudgetError extends StatelessWidget {
  const _BudgetError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1515),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          const Text('โหลดงบประมาณไม่สำเร็จ',
              style: TextStyle(color: Colors.white)),
          const SizedBox(height: 5),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 10)),
          TextButton(onPressed: onRetry, child: const Text('ลองใหม่')),
        ],
      ),
    );
  }
}
