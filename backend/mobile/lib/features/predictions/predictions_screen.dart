import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../core/money.dart';
import '../dashboard/dashboard_screen.dart';
import '../transactions/transactions_repository.dart';
import 'predictions_model.dart';
import 'predictions_service.dart';

class PredictionsScreen extends ConsumerWidget {
  const PredictionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final predictionsAsync = ref.watch(predictionsProvider);
    final dashboardAsync = ref.watch(dashboardProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'วิเคราะห์ & คาดการณ์ AI',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: predictionsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, _) => _ErrorState(
          message: err.toString(),
          onRetry: () {
            ref.invalidate(predictionsProvider);
            ref.invalidate(dashboardProvider);
          },
        ),
        data: (predictions) => dashboardAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (err, _) => _ErrorState(
            message: err.toString(),
            onRetry: () {
              ref.invalidate(predictionsProvider);
              ref.invalidate(dashboardProvider);
            },
          ),
          data: (dashboard) => _PredictionsContent(
            predictions: predictions,
            dashboard: dashboard,
          ),
        ),
      ),
    );
  }
}

class _PredictionsContent extends StatelessWidget {
  final PredictionsResponse predictions;
  final DashboardData dashboard;

  const _PredictionsContent({
    required this.predictions,
    required this.dashboard,
  });

  @override
  Widget build(BuildContext context) {
    // Generate combined chart data
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);

    // Calculate daily history (past 15 days) from transactions
    final Map<String, int> dailyHistory = {};
    int runningBalance = predictions.forecast.isNotEmpty
        ? predictions.forecast.first.balance
        : 0;

    // Walk backward from today
    for (int i = 0; i <= 15; i++) {
      final date = now.subtract(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      dailyHistory[dateStr] = runningBalance;

      // Reverse transactions on this day to calculate previous balances
      final dayTxns = dashboard.items.where((t) {
        return t.occurredAt.year == date.year &&
            t.occurredAt.month == date.month &&
            t.occurredAt.day == date.day;
      });

      for (final t in dayTxns) {
        if (t.type == 'income') {
          runningBalance -= t.amount;
        } else {
          runningBalance += t.amount;
        }
      }
    }

    final List<FlSpot> spots = [];
    final List<String> dates = [];

    // Add history (ascending order)
    final sortedHistoryKeys = dailyHistory.keys.toList()..sort();
    int index = 0;
    int todayIndex = 0;

    for (final key in sortedHistoryKeys) {
      spots.add(FlSpot(index.toDouble(), dailyHistory[key]! / 100.0));
      dates.add(key);
      if (key == todayStr) {
        todayIndex = index;
      }
      index++;
    }

    // Add future predictions
    for (final f in predictions.forecast) {
      // Avoid duplicating today's date if it is in history
      if (f.date == todayStr) continue;
      spots.add(FlSpot(index.toDouble(), f.balance / 100.0));
      dates.add(f.date);
      index++;
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        // Redraw page by invalidating providers
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          // ── AI Status Header ───────────────────────────────────────────────
          _buildStatusBanner(),
          const SizedBox(height: 20),

          // ── Analytics Chart Card ───────────────────────────────────────────
          _buildChartCard(spots, dates, todayIndex),
          const SizedBox(height: 20),

          // ── Highlights Row ─────────────────────────────────────────────────
          _buildMetricsGrid(),
          const SizedBox(height: 24),

          // ── Alerts Section ─────────────────────────────────────────────────
          if (predictions.alerts.isNotEmpty) ...[
            const Text(
              'คำเตือนและคำแนะนำจาก "พี่เงิน"',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white70),
            ),
            const SizedBox(height: 12),
            ...predictions.alerts.map((alert) => _AlertCard(alert: alert)),
            const SizedBox(height: 24),
          ],

          // ── Anomalies Section ──────────────────────────────────────────────
          if (predictions.anomalies.isNotEmpty) ...[
            const Text(
              'ตรวจพบความผิดปกติทางการเงิน',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white70),
            ),
            const SizedBox(height: 12),
            ...predictions.anomalies.map((anom) => _AnomalyCard(anomaly: anom)),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    // Determine overall health status based on alerts severity
    bool hasDanger = predictions.alerts.any((a) => a.type == 'danger');
    bool hasWarning = predictions.alerts.any((a) => a.type == 'warning');

    String statusText = "สุขภาพการเงินปลอดภัยดี";
    Color statusColor = AppColors.primary;
    IconData statusIcon = Icons.check_circle_outline_rounded;

    if (hasDanger) {
      statusText = "เงินตึงมือ มีความเสี่ยงขาดสภาพคล่อง";
      statusColor = AppColors.expense;
      statusIcon = Icons.error_outline_rounded;
    } else if (hasWarning) {
      statusText = "ควรเฝ้าระวังการใช้จ่ายล้นรายรับ";
      statusColor = AppColors.warning;
      statusIcon = Icons.warning_amber_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              statusText,
              style: TextStyle(color: statusColor, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(List<FlSpot> spots, List<String> dates, int todayIndex) {
    if (spots.isEmpty) return const SizedBox();

    double minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    double maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    
    // Add margins to Y axis scale
    minY = (minY - 500).clamp(0.0, double.infinity);
    maxY = maxY + 1000;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: kSoftShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'แนวโน้มยอดคงเหลือล่วงหน้า 30 วัน',
            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'กราฟรวมประวัติย้อนหลัง 15 วันและอนาคตที่ AI ทำนาย',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 8,
                      getTitlesWidget: (value, meta) {
                        int idx = value.toInt();
                        if (idx < 0 || idx >= dates.length) return const SizedBox();
                        
                        // Show formatted date or "Today" indicator
                        if (idx == todayIndex) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              'วันนี้',
                              style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          );
                        }
                        
                        try {
                          final parsedDate = DateTime.parse(dates[idx]);
                          final formattedStr = DateFormat('d MMM').format(parsedDate);
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              formattedStr,
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 9),
                            ),
                          );
                        } catch (_) {
                          return const SizedBox();
                        }
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (spots.length - 1).toDouble(),
                minY: minY,
                maxY: maxY,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF1E293B),
                    tooltipRoundedRadius: 12,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((barSpot) {
                        final idx = barSpot.x.toInt();
                        if (idx < 0 || idx >= dates.length) return null;
                        final dateStr = dates[idx];
                        final amtStr = NumberFormat('#,##0').format(barSpot.y);
                        
                        final parsedDate = DateTime.parse(dateStr);
                        final displayDate = DateFormat('d MMMM yyyy').format(parsedDate);
                        
                        final isFuture = idx > todayIndex;
                        final typeLabel = isFuture ? 'คาดการณ์: ' : 'จริง: ';

                        return LineTooltipItem(
                          '$displayDate\n$typeLabel$amtStr ฿',
                          const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3CAE63), Color(0xFF00C850)],
                    ),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        if (index == todayIndex) {
                          return FlDotCirclePainter(
                            radius: 6,
                            color: AppColors.primary,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          );
                        }
                        return FlDotCirclePainter(radius: 0);
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF3CAE63).withOpacity(0.2),
                          const Color(0xFF3CAE63).withOpacity(0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                extraLinesData: ExtraLinesData(
                  verticalLines: [
                    VerticalLine(
                      x: todayIndex.toDouble(),
                      color: AppColors.primary.withOpacity(0.4),
                      strokeWidth: 1.5,
                      dashArray: [5, 5],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'ปลายเดือนคาดการณ์',
                value: predictions.projectedEndingBalance,
                icon: Icons.account_balance_wallet_rounded,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'รายรับคาดการณ์ (30 วัน)',
                value: predictions.predictedTotalIncome,
                icon: Icons.arrow_upward_rounded,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                title: 'รายจ่ายคาดการณ์ (30 วัน)',
                value: predictions.predictedTotalExpense,
                icon: Icons.arrow_downward_rounded,
                color: AppColors.expense,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final int value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
                const SizedBox(height: 4),
                Text(
                  '${Money.formatBaht(value)} ฿',
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final PredictionAlert alert;

  const _AlertCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    Color cardColor = Colors.blueAccent;
    IconData icon = Icons.info_outline_rounded;
    if (alert.type == 'danger') {
      cardColor = AppColors.expense;
      icon = Icons.cancel_outlined;
    } else if (alert.type == 'warning') {
      cardColor = AppColors.warning;
      icon = Icons.error_outline_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardColor.withOpacity(0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: cardColor, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: TextStyle(color: cardColor, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  alert.body,
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnomalyCard extends StatelessWidget {
  final PredictionAnomaly anomaly;

  const _AnomalyCard({required this.anomaly});

  @override
  Widget build(BuildContext context) {
    final parsedDate = DateTime.parse(anomaly.date);
    final displayDate = DateFormat('d MMMM yyyy').format(parsedDate);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.expense.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                anomaly.note,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Text(
                '- ${Money.formatBaht(anomaly.amount)} ฿',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.expense),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            displayDate,
            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
          ),
          const SizedBox(height: 8),
          Text(
            anomaly.description,
            style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.65), height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, color: AppColors.textMuted, size: 64),
            const SizedBox(height: 16),
            const Text(
              'ไม่สามารถโหลดข้อมูลคาดการณ์ได้',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('ลองใหม่อีกครั้ง'),
            ),
          ],
        ),
      ),
    );
  }
}
