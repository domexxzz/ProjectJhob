import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/money.dart';
import '../auth/auth_controller.dart';
import '../transactions/transaction.dart';
import '../transactions/transactions_repository.dart';
import '../notifications/notif_bell.dart';
import '../goals/goals_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Dashboard Screen (Main) - Premium Dark UI Redesign
// ─────────────────────────────────────────────────────────────────────────────
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final dashboard = ref.watch(dashboardProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Column(
        children: [
          // ── Header (Gradient Top Bar จากภาพ Home.png) ─────────────────────
          _GreenHeader(
            name: user?.displayName ?? 'Fanta Inazuma',
            streak: user?.streak ?? 20,
          ),
          // ── Scrollable content ─────────────────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              color: const Color(0xFF3CAE63),
              onRefresh: () async {
                await ref.read(transactionsRepoProvider).syncPending();
                ref.invalidate(dashboardProvider);
                ref.invalidate(budgetsListProvider);
                await ref.read(dashboardProvider.future);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                children: [
                  dashboard.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF3CAE63))),
                    ),
                    error: (e, _) => _ErrorBox(
                      message: '$e',
                      onRetry: () => ref.invalidate(dashboardProvider),
                    ),
                    data: (d) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _BalanceCard(
                            balance: d.summary.balance,
                            income: d.summary.income,
                            expense: d.summary.expense,
                          ),
                          const SizedBox(height: 16),

                          // 2. Goals Card (Left -> Right Gradient)
                          const _GoalsCard(),
                          const SizedBox(height: 16),

                          // 3. Budgets Card (Top -> Bottom Gradient)
                          const _BudgetsCard(),
                          const SizedBox(height: 16),

                          // 4. Recent Transactions (Horizontal scroll)
                          if (d.items.isNotEmpty) ...[
                            _RecentTxnCards(txns: d.items.take(6).toList()),
                            const SizedBox(height: 16),
                          ],

                          // 5. Quick Actions Grid
                          const _QuickActionsGrid(),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Container(
        height: 64,
        width: 64,
        margin: const EdgeInsets.only(top: 10),
        child: FloatingActionButton(
          onPressed: () async {
            await context.push('/slip'); // ปุ่ม + → หน้าเลือกสลิป
            ref.invalidate(dashboardProvider);
            await ref.read(
                dashboardProvider.future); // รอโหลดเสร็จให้ balance อัปเดตทันที
          },
          backgroundColor: const Color(0xFF3CAE63),
          foregroundColor: Colors.black,
          shape: const CircleBorder(),
          elevation: 4,
          child: const Icon(Icons.add, size: 32),
        ),
      ),
      floatingActionButtonLocation: kFixedCenterDockedFabLocation,
      bottomNavigationBar: const _DashboardNav(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header (ตามภาพ Home.png)
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
          const NotifBell(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Balance Card (ยอดคงเหลือ)
// ─────────────────────────────────────────────────────────────────────────────
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.balance,
    required this.income,
    required this.expense,
  });
  final int balance;
  final int income;
  final int expense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF010C0C), Color(0xFF3CAE63)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ยอดคงเหลือ',
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    Money.formatBaht(balance),
                    maxLines: 1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _MiniStatRow(
                      label: 'รายรับ', value: income, color: AppColors.income),
                  const SizedBox(height: 4),
                  _MiniStatRow(
                      label: 'รายจ่าย',
                      value: expense,
                      color: AppColors.expense),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStatRow extends StatelessWidget {
  const _MiniStatRow(
      {required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('$label  ',
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
        Text(
          Money.formatBaht(value),
          style: TextStyle(
              color: color, fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Goals Card (เป้าหมาย) — สไลด์เปลี่ยนดูเป้าหมายอื่นได้ พร้อมอัปเดตข้อมูลจริงเรียลไทม์
// ─────────────────────────────────────────────────────────────────────────────
class _GoalsCard extends ConsumerStatefulWidget {
  const _GoalsCard();

  @override
  ConsumerState<_GoalsCard> createState() => _GoalsCardState();
}

class _GoalsCardState extends ConsumerState<_GoalsCard> {
  int _currentPage = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ฟังก์ชันดึงป้ายกำกับและสีตามประเภทเป้าหมาย (ใช้ Record แบบ Positioned มั่นใจได้ 100%)
  (String, IconData, Color, Color) _getTypeBadgeDetails(String type) {
    switch (type) {
      case 'medium':
        return (
          'ระยะกลาง (1 ปี)',
          Icons.timelapse_rounded,
          const Color(0xFF56D384).withOpacity(0.15),
          const Color(0xFF56D384)
        );
      case 'long':
        return (
          'ระยะยาว (1 ปีขึ้นไป)',
          Icons.trending_up_rounded,
          const Color(0xFF63B3ED).withOpacity(0.15),
          const Color(0xFF63B3ED)
        );
      default: // short
        return (
          'ระยะสั้น (ใน 0-6 เดือน)',
          Icons.shutter_speed_rounded,
          const Color(0xFFFBBC05).withOpacity(0.15),
          const Color(0xFFFBBC05)
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final goals = ref.watch(goalsProvider);

    if (goals.isEmpty) {
      return GestureDetector(
        onTap: () => context.push('/goals'),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [Color(0xFF262626), Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: const Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('เป้าหมาย',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                  Icon(Icons.add_circle_outline,
                      color: AppColors.primary, size: 20),
                ],
              ),
              SizedBox(height: 24),
              Icon(Icons.track_changes_rounded,
                  color: Colors.white24, size: 40),
              SizedBox(height: 12),
              Text(
                'ยังไม่มีเป้าหมายการเงินในขณะนี้',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                'แตะที่นี่เพื่อตั้งเป้าหมายแรกและเริ่มจดเงินออม 🎯',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 164, 
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemCount: goals.length,
            itemBuilder: (context, index) {
              final g = goals[index];

              // ไล่ระดับสีตามประเภทเป้าหมายเพื่อความพรีเมียม
              List<Color> gradientColors;
              Color accentColor;
              if (g.type == 'medium') {
                gradientColors = [
                  const Color(0xFF1A1A1A),
                  const Color(0xFF0F3B20),
                  const Color(0xFF227A41)
                ];
                accentColor = const Color(0xFF56D384);
              } else if (g.type == 'long') {
                gradientColors = [
                  const Color(0xFF1A1A1A),
                  const Color(0xFF122847),
                  const Color(0xFF2463AC)
                ];
                accentColor = const Color(0xFF63B3ED);
              } else {
                // short / default
                gradientColors = [
                  const Color(0xFF1A1A1A),
                  const Color(0xFF634D0E),
                  const Color(0xFFD69E0A)
                ];
                accentColor = const Color(0xFFFBBC05);
              }

              final remaining = g.target - g.current;
              final isSuccess = remaining <= 0;
              final badge = _getTypeBadgeDetails(g.type); 

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 8,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(g.emoji, style: const TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            const Text(
                              'เป้าหมาย',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(width: 8),
                            // Badge แสดงประเภทระยะเวลาเป้าหมาย (แก้ไขเรียกผ่านตัวระบุตำแหน่งดัชนี ดึงค่าถูกต้องแน่นอน)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: badge.$3, // badgeBg
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(badge.$2, size: 11, color: badge.$4), // icon, badgeText
                                  const SizedBox(width: 3),
                                  Text(
                                    badge.$1, // label
                                    style: TextStyle(
                                      color: badge.$4, // badgeText
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => context.push('/goals'),
                          child: Icon(Icons.edit_note_rounded,
                              size: 22, color: Colors.white.withOpacity(0.6)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            g.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${Money.formatBaht(g.current)} / ${Money.formatBaht(g.target)}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: g.progressPercentage,
                        minHeight: 12,
                        backgroundColor: Colors.white.withOpacity(0.18),
                        valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        isSuccess
                            ? 'สำเร็จเป้าหมายแล้ว! 🎉'
                            : 'เหลืออีก ${Money.formatBaht(remaining)} บาท',
                        style: TextStyle(
                            color: accentColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (goals.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              goals.length,
              (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _currentPage == index ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: _currentPage == index
                      ? AppColors.primary
                      : Colors.white30,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Budgets Card (งบประมาณ)
// ─────────────────────────────────────────────────────────────────────────────
class _BudgetsCard extends ConsumerWidget {
  const _BudgetsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(budgetsListProvider);
    final budgetStatuses = ref.watch(budgetStatusProvider);

    return Semantics(
      button: true,
      label: 'เปิดรายการงบประมาณ',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          await context.push('/budgets');
          ref.invalidate(budgetsListProvider);
          ref.invalidate(dashboardProvider);
        },
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF010F0C), Color(0xFF061E13)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'งบประมาณ',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold),
                  ),
                  Icon(Icons.edit_note_rounded,
                      size: 22, color: Colors.white.withOpacity(0.6)),
                ],
              ),
              const SizedBox(height: 16),
              budgetsAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(color: Color(0xFF3CAE63))),
                error: (e, _) => Text('โหลดงบไม่ได้: $e',
                    style: const TextStyle(color: Colors.red)),
                data: (budgets) {
                  final activeStatuses = budgetStatuses
                      .where((s) => s.showOnDashboard)
                      .take(6)
                      .toList();
                  
                  if (activeStatuses.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: Text(
                          'ไม่มีงบประมาณที่กำลังเปิดใช้งาน',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 13),
                        ),
                      ),
                    );
                  }
                  
                  return Column(
                    children: activeStatuses.map((status) {
                      final pct = status.percentage;
                      String statusLabel;
                      Color statusColor;

                      if (pct >= 0.8) {
                        statusLabel = 'อันตราย';
                        statusColor = const Color(0xFFFF4D4F);
                      } else if (pct >= 0.5) {
                        statusLabel = 'เสี่ยง';
                        statusColor = const Color(0xFFFFC067);
                      } else {
                        statusLabel = 'ปลอดภัย';
                        statusColor = const Color(0xFF37C871);
                      }

                      final cat = status.category;
                      final remaining = status.remaining;
                      final overBy = status.spent - status.amount;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    status.name?.isNotEmpty == true
                                        ? status.name!
                                        : (cat?.nameTh ?? 'งบรวม'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Text(
                                  statusLabel,
                                  style: TextStyle(
                                      color: statusColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '${Money.formatBaht(status.spent)} / ${Money.formatBaht(status.amount)}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: pct.clamp(0.0, 1.0),
                                minHeight: 10,
                                backgroundColor: Colors.white.withOpacity(0.12),
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(statusColor),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                overBy > 0
                                    ? 'ใช้เกินไป ${Money.formatBaht(overBy)} บาท'
                                    : 'เหลืออีก ${Money.formatBaht(remaining)} บาท',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recent Transactions
// ─────────────────────────────────────────────────────────────────────────────
class _RecentTxnCards extends StatelessWidget {
  const _RecentTxnCards({required this.txns});
  final List<Txn> txns;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 135,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: txns.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final t = txns[i];
          final cat = t.category;
          return Container(
            width: 135,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF041E14), Color(0xFF0A2B1D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: const Color(0xFF3CAE63).withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(cat?.icon ?? (t.isIncome ? '💰' : '💸'),
                        style: const TextStyle(fontSize: 22)),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Money.formatBaht(t.amount),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cat?.nameTh ?? (t.isIncome ? 'รายรับ' : 'อื่นๆ'),
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.6), fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick Actions Grid
// ─────────────────────────────────────────────────────────────────────────────
class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid();

  @override
  Widget build(BuildContext context) {
    final items = <({IconData icon, String label, VoidCallback onTap})>[
      (
        icon: Icons.document_scanner_outlined,
        label: 'สแกนสลิป',
        onTap: () => context.push('/slip')
      ),
      (
        icon: Icons.chat_bubble_outline_rounded,
        label: 'ปรึกษาพี่เงิน',
        onTap: () => context.push('/chat')
      ),
      (
        icon: Icons.flag_outlined,
        label: 'เป้าหมาย',
        onTap: () => context.push('/goals')
      ),
      (
        icon: Icons.edit_note_rounded,
        label: 'บันทึกสลิป',
        onTap: () => context.push('/slip?mode=manual')
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF061A13),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF3CAE63).withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items.map((it) {
          return GestureDetector(
            onTap: it.onTap,
            child: Column(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(it.icon, color: Colors.black87, size: 28),
                ),
                const SizedBox(height: 8),
                Text(
                  it.label,
                  style: const TextStyle(
                      color: Color(0xFF4CD97B),
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error Box Widget
// ─────────────────────────────────────────────────────────────────────────────
class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        const Text('โหลดข้อมูลไม่ได้ 😢',
            style: TextStyle(color: Colors.white)),
        const SizedBox(height: 4),
        Text(message,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            textAlign: TextAlign.center),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: onRetry,
          style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF3CAE63)),
          child: const Text('ลองใหม่'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom Navigation Bar
// ─────────────────────────────────────────────────────────────────────────────
class _DashboardNav extends StatelessWidget {
  const _DashboardNav();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, -2))
        ],
      ),
      child: BottomAppBar(
        color: Colors.transparent,
        elevation: 0,
        notchMargin: 10,
        height: 74,
        padding: EdgeInsets.zero,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            const _NavItem(
                icon: Icons.home_outlined, label: 'หน้าหลัก', active: true),
            _NavItem(
              icon: Icons.dashboard_outlined,
              label: 'แดชบอร์ด',
              onTap: () => context.push('/financial-dashboard'),
            ),
            const SizedBox(width: 48),
            _NavItem(
                icon: Icons.chat_bubble_outline_rounded,
                label: 'พี่เงิน',
                onTap: () => context.push('/chat')),
            _NavItem(
                icon: Icons.grid_view_rounded,
                label: 'เมนู',
                onTap: () => context.push('/menu')),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem(
      {required this.icon,
      required this.label,
      this.active = false,
      this.onTap});
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF4CD97B) : Colors.white60;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: active ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
