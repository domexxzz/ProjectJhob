import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/money.dart';
import '../auth/auth_controller.dart';
import '../transactions/transaction.dart';
import '../transactions/transactions_repository.dart';
import '../notifications/notif_bell.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Dashboard Screen (Main)
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
          // ── Header ─────────────────────────────────────────────────────────
          _GreenHeader(
            name: user?.displayName ?? 'เพื่อน',
            streak: user?.streak ?? 0,
          ),
          // ── Scrollable content ─────────────────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                await ref.read(transactionsRepoProvider).syncPending();
                ref.invalidate(dashboardProvider);
                ref.invalidate(budgetsListProvider);
                await ref.read(dashboardProvider.future);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  dashboard.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                    ),
                    error: (e, _) => _ErrorBox(
                      message: '$e',
                      onRetry: () => ref.invalidate(dashboardProvider),
                    ),
                    data: (d) {
                      // Calculate totals
                      int totalIncome = 0;
                      int totalExpense = 0;
                      for (final t in d.items) {
                        if (t.type == 'income') {
                          totalIncome += t.amount;
                        } else {
                          totalExpense += t.amount;
                        }
                      }
                      final balance = totalIncome - totalExpense;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Balance Card
                          _BalanceCard(
                            balance: balance,
                            income: totalIncome,
                            expense: totalExpense,
                          ),
                          const SizedBox(height: 12),

                          // 2. Goals Card
                          const _GoalsCard(),
                          const SizedBox(height: 12),

                          // 3. Budgets Card
                          const _BudgetsCard(),
                          const SizedBox(height: 12),

                          // 4. Recent Transactions (horizontal scroll)
                          if (d.items.isNotEmpty) ...[
                            _RecentTxnCards(txns: d.items.take(6).toList()),
                            const SizedBox(height: 12),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push('/slip');
          ref.invalidate(dashboardProvider);
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        elevation: 6,
        child: const Icon(Icons.add, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: const _DashboardNav(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header (Green gradient top bar — style matches mockup)
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
      padding: EdgeInsets.fromLTRB(20, topPad + 14, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF06120A), Color(0xFF334E3D), Color(0xFF3CAE63)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(0),
          bottomRight: Radius.circular(0),
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade700,
              border: Border.all(color: AppColors.primary.withOpacity(0.5), width: 2),
            ),
            child: const Icon(Icons.person, color: Colors.white70, size: 26),
          ),
          const SizedBox(width: 12),
          // Name + Streak badge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                  ),
                  child: Text(
                    'ใช้งานต่อเนื่อง $streak วัน',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Notification bell → Notification Center (+ badge จำนวนยังไม่อ่าน)
          const NotifBell(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Balance Card
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ยอดคงเหลือ',
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
              Icon(Icons.edit_outlined, size: 16, color: Colors.white38),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${Money.formatBaht(balance)} ฿',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _MiniStatRow(label: 'รายรับ', value: income, color: AppColors.income),
                  const SizedBox(height: 4),
                  _MiniStatRow(label: 'รายจ่าย', value: expense, color: AppColors.expense),
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
  const _MiniStatRow({required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('$label  ', style: const TextStyle(color: Colors.white54, fontSize: 12)),
        Text(
          '${Money.formatBaht(value)} ฿',
          style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Goals Card (mock data — จะเชื่อมต่อ API จริงใน Sprint ถัดไป)
// ─────────────────────────────────────────────────────────────────────────────
class _GoalsCard extends ConsumerWidget {
  const _GoalsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use real goals data if available
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF262626), Color(0xFF907116), Color(0xFFFBBC05)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'เป้าหมาย',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              GestureDetector(
                onTap: () => context.push('/goals'),
                child: Icon(Icons.edit_outlined, size: 16, color: Colors.white38),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ซื้อตู้เย็น', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              Text('2,400 / 4000', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: 2400 / 4000,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.15),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFC107)),
            ),
          ),
          const SizedBox(height: 6),
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              'เหลืออีก 1600 บาท',
              style: TextStyle(color: Colors.amber, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Budgets Card (status badges: อันตราย / เสี่ยง / ปลอดภัย)
// ─────────────────────────────────────────────────────────────────────────────
class _BudgetsCard extends ConsumerWidget {
  const _BudgetsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(budgetsListProvider);
    final budgetStatuses = ref.watch(budgetStatusProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF010F0C), Color(0xFF061E13)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'งบประมาณ',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              Icon(Icons.edit_outlined, size: 16, color: Colors.white38),
            ],
          ),
          const SizedBox(height: 12),
          budgetsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            error: (e, _) => Text('โหลดงบไม่ได้: $e', style: const TextStyle(color: Colors.red)),
            data: (budgets) {
              if (budgets.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text(
                      'ยังไม่ได้ตั้งงบประมาณ — เริ่มใช้งานได้เลย',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ),
                );
              }
              return Column(
                children: budgetStatuses.map((status) {
                  // Determine status level
                  final pct = status.percentage;
                  String statusLabel;
                  Color statusColor;
                  Color barColor;

                  if (pct >= 1.0) {
                    statusLabel = 'อันตราย';
                    statusColor = AppColors.expense;
                    barColor = AppColors.expense;
                  } else if (pct >= 0.8) {
                    statusLabel = 'เสี่ยง';
                    statusColor = Colors.orange;
                    barColor = Colors.orange;
                  } else {
                    statusLabel = 'ปลอดภัย';
                    statusColor = AppColors.income;
                    barColor = AppColors.income;
                  }

                  final cat = status.category;
                  final remaining = status.amount - status.spent;
                  final overBy = status.spent - status.amount;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                cat?.nameTh ?? 'งบรวม',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            // Status badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                statusLabel,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '฿ ${Money.formatBaht(status.spent)} / ${Money.formatBaht(status.amount)}',
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: pct.clamp(0.0, 1.0),
                            minHeight: 7,
                            backgroundColor: Colors.white.withOpacity(0.12),
                            valueColor: AlwaysStoppedAnimation<Color>(barColor),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            pct >= 1.0
                                ? 'ใช้เกินไป ${Money.formatBaht(overBy)} บาท'
                                : 'ใช้ได้อีก ${Money.formatBaht(remaining)} บาท',
                            style: TextStyle(color: statusColor, fontSize: 11),
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recent Transactions — horizontal scrollable cards
// ─────────────────────────────────────────────────────────────────────────────
class _RecentTxnCards extends StatelessWidget {
  const _RecentTxnCards({required this.txns});
  final List<Txn> txns;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: txns.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final t = txns[i];
          final cat = t.category;
          return Container(
            width: 110,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1C),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(cat?.icon ?? (t.isIncome ? '💰' : '💸'),
                        style: const TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '฿ ${Money.formatBaht(t.amount)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  cat?.nameTh ?? (t.isIncome ? 'รายรับ' : 'อื่นๆ'),
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
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
// Quick Actions Grid (4 items in a row — matches mockup)
// ─────────────────────────────────────────────────────────────────────────────
class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid();

  @override
  Widget build(BuildContext context) {
    final items = <({IconData icon, String label, VoidCallback onTap})>[
      (icon: Icons.document_scanner_outlined, label: 'สแกนสลิป', onTap: () => context.push('/slip')),
      (icon: Icons.smart_toy_rounded, label: 'ปรึกษาพี่เงิน', onTap: () => context.push('/chat')),
      (icon: Icons.flag_rounded, label: 'เป้าหมาย', onTap: () => context.push('/goals')),
      (icon: Icons.add_circle_outline_rounded, label: 'เพิ่มรายการ', onTap: () => context.push('/add')),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: items.map((it) {
          return GestureDetector(
            onTap: it.onTap,
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Icon(it.icon, color: Colors.white70, size: 26),
                ),
                const SizedBox(height: 8),
                Text(
                  it.label,
                  style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w500),
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
// Error Box
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
        const Text('โหลดข้อมูลไม่ได้ 😢', style: TextStyle(color: Colors.white)),
        const SizedBox(height: 4),
        Text(message,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            textAlign: TextAlign.center),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: onRetry,
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary),
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
    return BottomAppBar(
      color: const Color(0xFF121212),
      elevation: 12,
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      height: 66,
      padding: EdgeInsets.zero,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          const _NavItem(icon: Icons.home_rounded, label: 'หน้าหลัก', active: true),
          _NavItem(icon: Icons.bar_chart_rounded, label: 'งบ', onTap: () => context.push('/budgets')),
          const SizedBox(width: 40),
          _NavItem(icon: Icons.smart_toy_rounded, label: 'พี่เงิน', onTap: () => context.push('/chat')),
          _NavItem(icon: Icons.grid_view_rounded, label: 'เมนู', onTap: () => context.push('/menu')),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, this.active = false, this.onTap});
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : Colors.white38;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                )),
          ],
        ),
      ),
    );
  }
}

