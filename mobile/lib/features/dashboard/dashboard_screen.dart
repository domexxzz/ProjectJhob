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
                      child: Center(child: CircularProgressIndicator(color: Color(0xFF3CAE63))),
                    ),
                    error: (e, _) => _ErrorBox(
                      message: '$e',
                      onRetry: () => ref.invalidate(dashboardProvider),
                    ),
                    data: (d) {
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
      _BalanceCard(
        balance: balance,
        income: totalIncome,
        expense: totalExpense,
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
            await context.push('/add');
            ref.invalidate(dashboardProvider);
          },
          backgroundColor: const Color(0xFF3CAE63),
          foregroundColor: Colors.black,
          shape: const CircleBorder(),
          elevation: 4,
          child: const Icon(Icons.add, size: 32),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
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
// Balance Card (ยอดคงเหลือ)
// ─────────────────────────────────────────────────────────────────────────────
class _BalanceCard extends ConsumerWidget {
  const _BalanceCard({
    required this.balance,
    required this.income,
    required this.expense,
  });
  final int balance;
  final int income;
  final int expense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              GestureDetector(
                onTap: () async {
                  await context.push('/edit-balance');
                  ref.invalidate(dashboardProvider); // ดึงยอดใหม่ทันทีที่กลับมา
                },
                child: const Icon(Icons.edit_outlined, size: 16, color: Colors.white38),
              ),
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
// Goals Card (เป้าหมาย)
// ─────────────────────────────────────────────────────────────────────────────
class _GoalsCard extends ConsumerWidget {
  const _GoalsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF262626), Color(0xFF907116), Color(0xFFFBBC05)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'เป้าหมาย',
                style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
              ),
              GestureDetector(
                onTap: () => context.push('/goals'),
                child: Icon(Icons.edit_note_rounded, size: 22, color: Colors.white.withOpacity(0.6)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ซื้อตู้เย็น', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
              Text('2,400 / 4000', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: 2400 / 4000,
              minHeight: 12,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFBBC05)),
            ),
          ),
          const SizedBox(height: 6),
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              'เหลืออีก 1600 บาท',
              style: TextStyle(color: Color(0xFFFBBC05), fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
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

    return Container(
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
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))
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
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              Icon(Icons.edit_note_rounded, size: 22, color: Colors.white.withOpacity(0.6)),
            ],
          ),
          const SizedBox(height: 16),
          budgetsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF3CAE63))),
            error: (e, _) => Text('โหลดงบไม่ได้: $e', style: const TextStyle(color: Colors.red)),
            data: (budgets) {
              if (budgets.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text(
                      'ยังไม่ได้ตั้งงบประมาณ — เริ่มใช้งานได้เลย',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                  ),
                );
              }
              return Column(
                children: budgetStatuses.map((status) {
                  final pct = status.percentage;
                  String statusLabel;
                  Color statusColor;

                  if (pct >= 1.0) {
                    statusLabel = 'อันตราย';
                    statusColor = const Color(0xFFFF4B4B);
                  } else if (pct >= 0.8) {
                    statusLabel = 'เสี่ยง';
                    statusColor = const Color(0xFFFFB03A);
                  } else {
                    statusLabel = 'ปลอดภัย';
                    statusColor = const Color(0xFF3CAE63);
                  }

                  final cat = status.category;
                  final remaining = status.amount - status.spent;
                  final overBy = status.spent - status.amount;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                cat?.nameTh ?? 'งบรวม',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Text(
                              statusLabel,
                              style: TextStyle(color: statusColor, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '฿ ${Money.formatBaht(status.spent)} / ${Money.formatBaht(status.amount)}',
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
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
                            valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            pct >= 1.0
                                ? 'ใช้เกินไป ${Money.formatBaht(overBy)} บาท'
                                : 'ใช้ได้อีก ${Money.formatBaht(remaining)} บาท',
                            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
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
              border: Border.all(color: const Color(0xFF3CAE63).withOpacity(0.3)),
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
                      '฿ ${Money.formatBaht(t.amount)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cat?.nameTh ?? (t.isIncome ? 'รายรับ' : 'อื่นๆ'),
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
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
      (icon: Icons.camera_alt_outlined, label: 'สแกนสลิป', onTap: () => context.push('/add')),
      (icon: Icons.chat_bubble_outline_rounded, label: 'ปรึกษาพี่เงิน', onTap: () => context.push('/chat')),
      (icon: Icons.flag_outlined, label: 'เป้าหมาย', onTap: () => context.push('/goals')),
      (icon: Icons.add_outlined, label: 'เพิ่มรายการ', onTap: () => context.push('/add')),
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
                  style: const TextStyle(color: Color(0xFF4CD97B), fontSize: 12, fontWeight: FontWeight.w500),
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
        const Text('โหลดข้อมูลไม่ได้ 😢', style: TextStyle(color: Colors.white)),
        const SizedBox(height: 4),
        Text(message,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            textAlign: TextAlign.center),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: onRetry,
          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF3CAE63)),
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
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, -2))
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
            const _NavItem(icon: Icons.home_outlined, label: 'หน้าหลัก', active: true),
            _NavItem(icon: Icons.insert_chart_outlined_rounded, label: 'งบ', onTap: () => context.push('/budgets')),
            const SizedBox(width: 48),
            _NavItem(icon: Icons.chat_bubble_outline_rounded, label: 'พี่เงิน', onTap: () => context.push('/chat')),
            _NavItem(icon: Icons.grid_view_rounded, label: 'เมนู', onTap: () => context.push('/menu')),
          ],
        ),
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