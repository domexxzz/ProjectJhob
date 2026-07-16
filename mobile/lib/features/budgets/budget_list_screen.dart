import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/money.dart';
import '../transactions/transaction.dart';
import '../transactions/transactions_repository.dart';

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
    final budgets = ref.watch(budgetsListProvider);
    final statuses = ref.watch(budgetStatusProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF101210),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101210),
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: const Text(
          'งบประมาณ',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => _refresh(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            const _BudgetBanner(),
            const SizedBox(height: 22),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'งบประมาณของฉัน',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${statuses.length} หมวด',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 12),
            budgets.when(
              loading: () => const SizedBox(
                height: 180,
                child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary)),
              ),
              error: (error, _) => _BudgetError(
                message: '$error',
                onRetry: () => _refresh(ref),
              ),
              data: (items) {
                if (items.isEmpty) return const _EmptyBudgetState();
                return _BudgetOverviewCard(statuses: statuses);
              },
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () async {
                final created = await context.push<bool>('/budgets/amount');
                if (created == true) await _refresh(ref);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.65)),
                backgroundColor: const Color(0xFF11261A),
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13)),
              ),
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: const Text(
                'เพิ่มงบประมาณ',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'ประมาณการความเสี่ยง',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            _RiskRecommendation(statuses: statuses),
          ],
        ),
      ),
    );
  }
}

class _BudgetBanner extends StatelessWidget {
  const _BudgetBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 118,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF031B0D), Color(0xFF0B2D18)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: Color(0xFF07130A),
            child: Text('🤖', style: TextStyle(fontSize: 38)),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('คุมรายจ่ายให้ทัน',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                Text('ก่อนงบจะหมด',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                SizedBox(height: 5),
                Text('ทำได้แน่!',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetOverviewCard extends StatelessWidget {
  const _BudgetOverviewCard({required this.statuses});

  final List<BudgetStatus> statuses;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00150E), Color(0xFF052D1B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        boxShadow: const [
          BoxShadow(
              color: Colors.black26, blurRadius: 12, offset: Offset(0, 5)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('ภาพรวมงบประมาณ',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ),
              Icon(Icons.edit_note_rounded,
                  color: Colors.white.withValues(alpha: 0.65), size: 21),
            ],
          ),
          const SizedBox(height: 8),
          ...statuses.map((status) => _BudgetStatusRow(status: status)),
        ],
      ),
    );
  }
}

class _BudgetStatusRow extends StatelessWidget {
  const _BudgetStatusRow({required this.status});

  final BudgetStatus status;

  @override
  Widget build(BuildContext context) {
    final risk = _riskStyle(status.riskLevel);
    final remaining = status.amount - status.spent;
    final projectedOver = status.projectedSpend - status.amount;

    return InkWell(
      onTap: () => context.push('/budgets/edit', extra: status),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 5, 0, 10),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    status.category?.nameTh ?? 'งบรวม',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    risk.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: risk.color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    '${Money.formatBaht(status.spent)} / ${Money.formatBaht(status.amount)}',
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: status.percentage.clamp(0.0, 1.0),
                minHeight: 7,
                backgroundColor: Colors.white.withValues(alpha: 0.62),
                valueColor: AlwaysStoppedAnimation(risk.color),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    status.period == 'weekly' ? 'งบรายสัปดาห์' : 'งบรายเดือน',
                    style: const TextStyle(color: Colors.white38, fontSize: 9),
                  ),
                ),
                Text(
                  remaining < 0
                      ? 'ใช้เกิน ${Money.formatBaht(-remaining)}'
                      : projectedOver > 0
                          ? 'คาดว่าจะเกิน ${Money.formatBaht(projectedOver)}'
                          : 'ใช้ได้อีก ${Money.formatBaht(remaining)}',
                  style: TextStyle(
                    color: status.riskLevel == 'danger'
                        ? risk.color
                        : Colors.white60,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RiskRecommendation extends StatelessWidget {
  const _RiskRecommendation({required this.statuses});

  final List<BudgetStatus> statuses;

  @override
  Widget build(BuildContext context) {
    if (statuses.isEmpty) {
      return const _AdviceCard(
        color: AppColors.primary,
        icon: Icons.lightbulb_outline_rounded,
        title: 'เริ่มจากหมวดที่ใช้บ่อย',
        message:
            'ลองเพิ่มงบค่ากิน ค่าเดินทาง หรือค่าของใช้ เพื่อให้พี่เงินช่วยเฝ้าระวัง',
      );
    }

    final sorted = [...statuses]
      ..sort((a, b) => _riskScore(b).compareTo(_riskScore(a)));
    final worst = sorted.first;
    final risk = _riskStyle(worst.riskLevel);
    final name = worst.category?.nameTh ?? 'งบรวม';

    if (worst.riskLevel == 'danger') {
      final projectedDifference = worst.projectedSpend - worst.amount;
      final excess = projectedDifference > 0 ? projectedDifference : 0;
      return _AdviceCard(
        color: risk.color,
        icon: Icons.warning_amber_rounded,
        title: '$name มีความเสี่ยงสูง',
        message:
            'หากใช้ในอัตราเดิม คาดว่าสิ้นรอบจะเกินประมาณ ${Money.formatBaht(excess)} เหลือเวลา ${worst.daysRemaining} วัน',
      );
    }

    if (worst.riskLevel == 'warning') {
      return _AdviceCard(
        color: risk.color,
        icon: Icons.speed_rounded,
        title: '$name เริ่มเข้าเขตเสี่ยง',
        message:
            'คาดว่าสิ้นรอบจะใช้ ${Money.formatBaht(worst.projectedSpend)} จากงบ ${Money.formatBaht(worst.amount)} ควรชะลอรายจ่ายที่ไม่จำเป็น',
      );
    }

    return const _AdviceCard(
      color: AppColors.primary,
      icon: Icons.verified_rounded,
      title: 'ภาพรวมยังอยู่ในระดับปลอดภัย',
      message:
          'อัตราการใช้จ่ายปัจจุบันยังสอดคล้องกับวงเงินที่ตั้งไว้ รักษาแบบนี้ต่อได้เลย',
    );
  }
}

class _AdviceCard extends StatelessWidget {
  const _AdviceCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.message,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    )),
                const SizedBox(height: 4),
                Text(message,
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 11, height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyBudgetState extends StatelessWidget {
  const _EmptyBudgetState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF151815),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: const Column(
        children: [
          Icon(Icons.account_balance_wallet_outlined,
              color: Colors.white30, size: 38),
          SizedBox(height: 10),
          Text('ยังไม่มีงบประมาณ',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          SizedBox(height: 4),
          Text('เพิ่มงบเพื่อเริ่มติดตามและประเมินความเสี่ยง',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 11)),
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

({String label, Color color}) _riskStyle(String level) {
  switch (level) {
    case 'danger':
      return (label: 'อันตราย', color: const Color(0xFFFF4444));
    case 'warning':
      return (label: 'เสี่ยง', color: const Color(0xFFFFE568));
    default:
      return (label: 'ปลอดภัย', color: const Color(0xFF3FC776));
  }
}

double _riskScore(BudgetStatus status) {
  final priority = switch (status.riskLevel) {
    'danger' => 3,
    'warning' => 2,
    _ => 1,
  };
  final projectedRatio =
      status.amount == 0 ? 0 : status.projectedSpend / status.amount;
  return (priority * 10 + projectedRatio).toDouble();
}
