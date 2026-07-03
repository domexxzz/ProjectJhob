import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../core/money.dart';
import 'goals_provider.dart';

class DepositGoalScreen extends ConsumerStatefulWidget {
  const DepositGoalScreen({super.key, required this.goalId});

  final String goalId;

  @override
  ConsumerState<DepositGoalScreen> createState() => _DepositGoalScreenState();
}

class _DepositGoalScreenState extends ConsumerState<DepositGoalScreen> {
  final TextEditingController _amountController = TextEditingController();

  final List<int> _presetAmounts = [500, 1000, 1500, 2000, 2500, 3000, 4000, 5000, 6000];

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final goal = ref.watch(goalsProvider).firstWhere((g) => g.id == widget.goalId);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'กำหนดเงินเข้าเป้าหมาย',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Target Goal Icon circle with glow
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.1),
                border: Border.all(color: AppColors.primary, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                goal.emoji,
                style: const TextStyle(fontSize: 48),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              goal.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
            const SizedBox(height: 32),

            // Large Amount Input card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF0C2E1B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Text(
                    '฿',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        fillColor: Colors.transparent,
                      ),
                      onChanged: (val) => setState(() {}),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Preset Amount Grid (3 columns)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.0,
              ),
              itemCount: _presetAmounts.length,
              itemBuilder: (context, index) {
                final amt = _presetAmounts[index];
                return ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _amountController.text = amt.toString();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF1E293B)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    NumberFormat('#,###').format(amt),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: ElevatedButton(
          onPressed: _amountController.text.trim().isEmpty ? null : () => _confirmDeposit(goal.name),
          child: const Text('ต่อไป'),
        ),
      ),
    );
  }

  void _confirmDeposit(String goalName) {
    final text = _amountController.text.trim();
    final baht = double.tryParse(text) ?? 0;
    if (baht > 0) {
      final satang = Money.toSatang(baht);
      ref.read(goalsProvider.notifier).addSavings(widget.goalId, satang);
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ฝากเงินสำเร็จ! +${Money.formatBaht(satang)} เข้า $goalName'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.income,
        ),
      );
    }
  }
}
