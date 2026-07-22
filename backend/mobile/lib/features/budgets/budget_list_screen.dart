import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/money.dart';
import '../transactions/transactions_repository.dart';

class BudgetListScreen extends ConsumerWidget {
  const BudgetListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(budgetsListProvider);
    final budgetStatuses = ref.watch(budgetStatusProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(budgetsListProvider);
          await ref.read(budgetsListProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            // Banner "ตั้งเป้าหมายวันนี้เพื่ออนาคตที่ดีกว่า"
            Container(
              height: 140,
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1C),
                borderRadius: BorderRadius.circular(20),
                image: const DecorationImage(
                  // We'll use a placeholder or local asset if available.
                  // Just standard color for now, since we don't have the exact robot image.
                  image: AssetImage('assets/images/logo.png'), 
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.contain,
                ),
                gradient: const LinearGradient(
                  colors: [Color(0xFF042004), Color(0xFF0B140B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: 20,
                    top: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: const [
                        Text('ตั้งเป้าหมายวันนี้', style: TextStyle(color: Colors.white, fontSize: 13)),
                        Text('เพื่ออนาคตที่ดีกว่า', style: TextStyle(color: Colors.white, fontSize: 13)),
                        SizedBox(height: 8),
                        Text('ทำได้แน่!', style: TextStyle(color: AppColors.primary, fontSize: 24, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'งบประมาณของฉัน',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            budgetsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (e, _) => Center(child: Text('โหลดงบไม่ได้: $e', style: const TextStyle(color: Colors.red))),
              data: (budgets) {
                if (budgets.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'ยังไม่มีงบประมาณที่ตั้งไว้',
                        style: TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                    ),
                  );
                }

                return Column(
                  children: budgetStatuses.map((status) {
                    final pct = status.percentage;
                    
                    Color color;
                    if (pct >= 1.0) color = const Color(0xFFF03E3E); // อันตราย (แดง)
                    else if (pct >= 0.8) color = const Color(0xFFF59F00); // เสี่ยง (เหลือง)
                    else color = AppColors.primary; // ปลอดภัย (เขียว)

                    final isExceeded = pct >= 1.0;
                    final overBy = status.spent - status.amount;
                    final remaining = status.amount - status.spent;

                    return GestureDetector(
                      onTap: () {
                        context.push('/budgets/edit', extra: status);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1C1C),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                // Icon
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade100, // Background icon
                                    shape: BoxShape.circle,
                                    border: Border.all(color: color, width: 2),
                                  ),
                                  child: Center(
                                    child: Text(status.category?.icon ?? '🏝️', style: const TextStyle(fontSize: 22)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        status.category?.nameTh ?? 'หมวดหมู่',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                      Text(
                                        'ใช้ไม่เกิน ${Money.formatBaht(status.amount)}',
                                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                // Percentage
                                Row(
                                  children: [
                                    Text(
                                      '${(pct * 100).toInt()} %',
                                      style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(Icons.chevron_right, color: Colors.white54, size: 20),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Progress bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: pct.clamp(0.0, 1.0),
                                minHeight: 6,
                                backgroundColor: Colors.white.withOpacity(0.1),
                                valueColor: AlwaysStoppedAnimation<Color>(color),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Footer text
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '฿ ${Money.formatBaht(status.spent)} / ${Money.formatBaht(status.amount)}',
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                                Text(
                                  isExceeded
                                      ? 'ใช้เกินไป ${Money.formatBaht(overBy)} บาท'
                                      : 'เหลืออีก ${Money.formatBaht(remaining)} บาท',
                                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 16),
            // Add budget button
            OutlinedButton(
              onPressed: () {
                // Navigate to amount screen with new state
                context.push('/budgets/amount');
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.primary.withOpacity(0.5), width: 1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFF142B1A),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.add_circle_outline, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text('เพิ่มงบประมาณ', style: TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),

            const SizedBox(height: 32),
            const Text(
              'แนะนำสำหรับคุณ',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF16251A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black26,
                    ),
                    child: const Center(child: Text('🤖', style: TextStyle(fontSize: 24))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('พี่เงินขอแนะนำ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        SizedBox(height: 4),
                        Text('พี่เงินว่า แบบนี้อันตรายเกินไปครับ\nพี่ว่าเราเอาแบบนี้ดีกว่า', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white54),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
