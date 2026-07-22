import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../core/money.dart';
import '../auth/auth_controller.dart';
import '../notifications/notif_bell.dart';
import '../transactions/transaction.dart';
import '../transactions/transactions_repository.dart';
import '../../widgets/app_bottom_nav_bar.dart';

enum _DashboardRange { day, week, month, year }

class FinancialDashboardScreen extends ConsumerStatefulWidget {
  const FinancialDashboardScreen({super.key});

  @override
  ConsumerState<FinancialDashboardScreen> createState() =>
      _FinancialDashboardScreenState();
}

class _FinancialDashboardScreenState
    extends ConsumerState<FinancialDashboardScreen> {
  _DashboardRange _range = _DashboardRange.month;
  bool _showIncomeCategories = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    final dashboard = ref.watch(dashboardProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0F0E),
      body: Column(
        children: [
          _GreenHeader(
            name: user?.displayName ?? 'Chnitsara Nansthit',
            streak: user?.streak ?? 0,
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                ref.invalidate(dashboardProvider);
                await ref.read(dashboardProvider.future);
              },
              child: dashboard.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (error, _) => ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const SizedBox(height: 160),
                    const Icon(Icons.cloud_off_rounded,
                        color: Colors.white38, size: 42),
                    const SizedBox(height: 12),
                    const Text(
                      'โหลดข้อมูลแดชบอร์ดไม่สำเร็จ',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
                data: (data) {
                  final visible = _filterTransactions(data.items, _range);
                  final income = visible
                      .where((item) => item.isIncome)
                      .fold<int>(0, (sum, item) => sum + item.amount);
                  final expense = visible
                      .where((item) => !item.isIncome)
                      .fold<int>(0, (sum, item) => sum + item.amount);

                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 116),
                    children: [
                      _RangeSelector(
                        selected: _range,
                        onChanged: (range) => setState(() => _range = range),
                      ),
                      const SizedBox(height: 16),
                      _TrendCard(transactions: visible, range: _range),
                      const SizedBox(height: 14),
                      _SummaryRow(income: income, expense: expense),
                      const SizedBox(height: 24),
                      _SectionHeader(
                        title: 'สัดส่วนตามหมวดหมู่',
                        trailing: _TypeSwitch(
                          showIncome: _showIncomeCategories,
                          onChanged: (value) =>
                              setState(() => _showIncomeCategories = value),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _CategoryBreakdown(
                        transactions: visible,
                        showIncome: _showIncomeCategories,
                      ),
                      const SizedBox(height: 24),
                      const _SectionHeader(title: 'รายการในช่วงเวลานี้'),
                      const SizedBox(height: 12),
                      _TransactionList(transactions: visible),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: const AppFloatingActionButton(),
      floatingActionButtonLocation: kFixedCenterDockedFabLocation,
      bottomNavigationBar: const AppBottomNavigationBar(currentTab: AppTab.dashboard),
    );
  }
}

List<Txn> _filterTransactions(List<Txn> transactions, _DashboardRange range) {
  final now = DateTime.now();
  late final DateTime start;

  switch (range) {
    case _DashboardRange.day:
      start = DateTime(now.year, now.month, now.day);
    case _DashboardRange.week:
      start = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday - 1));
    case _DashboardRange.month:
      start = DateTime(now.year, now.month, 1);
    case _DashboardRange.year:
      start = DateTime(now.year, 1, 1);
  }

  final result = transactions
      .where((item) => !item.occurredAt.toLocal().isBefore(start))
      .toList()
    ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
  return result;
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.selected, required this.onChanged});

  final _DashboardRange selected;
  final ValueChanged<_DashboardRange> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = {
      _DashboardRange.day: 'วัน',
      _DashboardRange.week: 'สัปดาห์',
      _DashboardRange.month: 'เดือน',
      _DashboardRange.year: 'ปี',
    };

    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF242624),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: _DashboardRange.values.map((range) {
          final active = range == selected;
          return Expanded(
            child: InkWell(
              onTap: () => onChanged(range),
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  labels[range]!,
                  style: TextStyle(
                    color: active ? Colors.black : Colors.white60,
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.transactions, required this.range});

  final List<Txn> transactions;
  final _DashboardRange range;

  @override
  Widget build(BuildContext context) {
    final chart = _buildChartData(transactions, range);
    final maxValue = [...chart.income, ...chart.expense]
        .fold<double>(0, (max, value) => value > max ? value : max);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF151817),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'แนวโน้มรายรับ–รายจ่าย',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              _LegendDot(color: AppColors.income, label: 'รายรับ'),
              SizedBox(width: 16),
              _LegendDot(color: AppColors.expense, label: 'รายจ่าย'),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 190,
            child: maxValue == 0
                ? const _EmptyChart()
                : LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: (chart.labels.length - 1).toDouble(),
                      minY: 0,
                      maxY: maxValue * 1.2,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval:
                            maxValue == 0 ? 1 : (maxValue * 1.2) / 4,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: Colors.white.withValues(alpha: 0.06),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1,
                            reservedSize: 28,
                            getTitlesWidget: (value, meta) {
                              final index = value.round();
                              if (index < 0 || index >= chart.labels.length) {
                                return const SizedBox.shrink();
                              }
                              return SideTitleWidget(
                                axisSide: meta.axisSide,
                                child: Text(
                                  chart.labels[index],
                                  style: const TextStyle(
                                      color: Colors.white38, fontSize: 10),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (_) => const Color(0xFF242826),
                          getTooltipItems: (spots) => spots
                              .map((spot) => LineTooltipItem(
                                    '฿${NumberFormat('#,##0').format(spot.y)}',
                                    TextStyle(
                                      color: spot.barIndex == 0
                                          ? AppColors.income
                                          : AppColors.expense,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                      lineBarsData: [
                        _line(chart.income, AppColors.income),
                        _line(chart.expense, AppColors.expense),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  LineChartBarData _line(List<double> values, Color color) {
    return LineChartBarData(
      spots: [
        for (var index = 0; index < values.length; index++)
          FlSpot(index.toDouble(), values[index]),
      ],
      isCurved: true,
      curveSmoothness: 0.25,
      color: color,
      barWidth: 2.5,
      dotData: FlDotData(show: values.length <= 7),
      belowBarData: BarAreaData(
        show: true,
        color: color.withValues(alpha: 0.08),
      ),
    );
  }
}

({List<String> labels, List<double> income, List<double> expense})
    _buildChartData(List<Txn> transactions, _DashboardRange range) {
  late final List<String> labels;
  late final int bucketCount;

  switch (range) {
    case _DashboardRange.day:
      labels = const ['00', '04', '08', '12', '16', '20'];
      bucketCount = 6;
    case _DashboardRange.week:
      labels = const ['จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส', 'อา'];
      bucketCount = 7;
    case _DashboardRange.month:
      labels = const ['1', '8', '15', '22', '29'];
      bucketCount = 5;
    case _DashboardRange.year:
      labels = const [
        'ม.ค.',
        'ก.พ.',
        'มี.ค.',
        'เม.ย.',
        'พ.ค.',
        'มิ.ย.',
        'ก.ค.',
        'ส.ค.',
        'ก.ย.',
        'ต.ค.',
        'พ.ย.',
        'ธ.ค.'
      ];
      bucketCount = 12;
  }

  final income = List<double>.filled(bucketCount, 0);
  final expense = List<double>.filled(bucketCount, 0);

  for (final item in transactions) {
    final date = item.occurredAt.toLocal();
    final int index;
    switch (range) {
      case _DashboardRange.day:
        index = (date.hour ~/ 4).clamp(0, 5);
      case _DashboardRange.week:
        index = date.weekday - 1;
      case _DashboardRange.month:
        index = ((date.day - 1) ~/ 7).clamp(0, 4);
      case _DashboardRange.year:
        index = date.month - 1;
    }
    final amount = item.amount / 100;
    if (item.isIncome) {
      income[index] += amount;
    } else {
      expense[index] += amount;
    }
  }

  return (labels: labels, income: income, expense: expense);
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 11)),
      ],
    );
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.show_chart_rounded, color: Colors.white24, size: 34),
          SizedBox(height: 8),
          Text('ยังไม่มีข้อมูลในช่วงเวลานี้',
              style: TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.income, required this.expense});

  final int income;
  final int expense;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            icon: Icons.trending_up_rounded,
            label: 'รายรับ',
            value: Money.formatBaht(income),
            color: AppColors.income,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            icon: Icons.trending_down_rounded,
            label: 'รายจ่าย',
            value: Money.formatBaht(expense),
            color: AppColors.expense,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF202220),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 11)),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _TypeSwitch extends StatelessWidget {
  const _TypeSwitch({required this.showIncome, required this.onChanged});

  final bool showIncome;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFF242624),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          _TypeOption(
            label: 'รายจ่าย',
            active: !showIncome,
            onTap: () => onChanged(false),
          ),
          _TypeOption(
            label: 'รายรับ',
            active: showIncome,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _TypeOption extends StatelessWidget {
  const _TypeOption({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.black : Colors.white54,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({
    required this.transactions,
    required this.showIncome,
  });

  final List<Txn> transactions;
  final bool showIncome;

  @override
  Widget build(BuildContext context) {
    final filtered =
        transactions.where((item) => item.isIncome == showIncome).toList();
    final groups = <String, _CategoryTotal>{};

    for (final item in filtered) {
      final key = item.category?.id ?? 'other';
      final current = groups[key];
      groups[key] = _CategoryTotal(
        name: item.category?.nameTh ?? 'อื่น ๆ',
        icon: item.category?.icon ?? (showIncome ? '💰' : '💸'),
        color: _parseColor(item.category?.color),
        amount: (current?.amount ?? 0) + item.amount,
      );
    }

    final totals = groups.values.toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    final grandTotal = totals.fold<int>(0, (sum, item) => sum + item.amount);

    if (totals.isEmpty) {
      return Container(
        height: 126,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF151817),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          showIncome ? 'ยังไม่มีข้อมูลรายรับ' : 'ยังไม่มีข้อมูลรายจ่าย',
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0A2A1B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 150,
            child: Row(
              children: [
                SizedBox(
                  width: 130,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          centerSpaceRadius: 38,
                          sectionsSpace: 2,
                          sections: totals.take(6).map((item) {
                            return PieChartSectionData(
                              color: item.color,
                              value: item.amount.toDouble(),
                              radius: 20,
                              showTitle: false,
                            );
                          }).toList(),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            showIncome ? 'รายรับ' : 'รายจ่าย',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 10),
                          ),
                          Text(
                            Money.formatBaht(grandTotal),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ListView.separated(
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: totals.take(5).length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = totals[index];
                      final percent = grandTotal == 0
                          ? 0
                          : (item.amount / grandTotal * 100).round();
                      return Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                                color: item.color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              item.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 11),
                            ),
                          ),
                          Text(
                            '$percent%',
                            style: TextStyle(
                              color: item.color,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ...totals.take(5).map((item) => _CategoryRow(
                item: item,
                total: grandTotal,
              )),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.item, required this.total});

  final _CategoryTotal item;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : item.amount / total;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          Row(
            children: [
              Text(item.icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(item.name,
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
              Text(Money.formatBaht(item.amount),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio.clamp(0, 1),
              minHeight: 5,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(item.color),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTotal {
  const _CategoryTotal({
    required this.name,
    required this.icon,
    required this.color,
    required this.amount,
  });

  final String name;
  final String icon;
  final Color color;
  final int amount;
}

Color _parseColor(String? value) {
  if (value == null) return AppColors.primary;
  final cleaned = value.replaceFirst('#', '');
  final parsed = int.tryParse(cleaned, radix: 16);
  if (parsed == null) return AppColors.primary;
  return Color(0xFF000000 | parsed);
}

class _TransactionList extends StatelessWidget {
  const _TransactionList({required this.transactions});

  final List<Txn> transactions;

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 28),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF151817),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Text('ยังไม่มีรายการในช่วงเวลานี้',
            style: TextStyle(color: Colors.white38, fontSize: 12)),
      );
    }

    return Column(
      children: transactions.take(8).map((item) {
        final color = item.isIncome ? AppColors.income : AppColors.expense;
        return Container(
          margin: const EdgeInsets.only(bottom: 9),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0xFF151817),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.18)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Text(
                    item.category?.icon ?? (item.isIncome ? '💰' : '💸'),
                    style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.category?.nameTh ??
                          (item.isIncome ? 'รายรับ' : 'รายจ่าย'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('d MMM yy, HH:mm', 'th')
                          .format(item.occurredAt.toLocal()),
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                  ],
                ),
              ),
              Text(
                '${item.isIncome ? '+' : '-'}${Money.formatBaht(item.amount)}',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top Green Header Widget
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
                      overflow: TextOverflow.ellipsis,
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


