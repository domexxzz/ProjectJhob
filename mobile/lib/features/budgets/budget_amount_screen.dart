import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../core/money.dart';
import '../transactions/transaction.dart';
import '../transactions/transactions_repository.dart';
import '../settings/settings_screen.dart';

class BudgetAmountScreen extends ConsumerStatefulWidget {
  const BudgetAmountScreen({super.key});

  @override
  ConsumerState<BudgetAmountScreen> createState() => _BudgetAmountScreenState();
}

class _BudgetAmountScreenState extends ConsumerState<BudgetAmountScreen> {
  final _amountController = TextEditingController();
  String? _categoryId;
  String _period = 'monthly'; // 'monthly' | 'weekly' | 'custom'

  DateTimeRange? _customDateRange;
  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _selectCustomDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _customDateRange ??
          DateTimeRange(
            start: DateTime.now(),
            end: DateTime.now().add(const Duration(days: 7)),
          ),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.black,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF121212),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _period = 'custom';
      });
    }
  }

  Future<void> _save() async {
    final rawAmount = _amountController.text.replaceAll(',', '');
    final amountBaht = num.tryParse(rawAmount);

    if (_categoryId == null) {
      _showMessage('กรุณาเลือกหมวดงบประมาณ');
      return;
    }
    if (amountBaht == null || amountBaht <= 0) {
      _showMessage('กรุณากรอกวงเงินที่มากกว่า 0 ${Money.symbol}');
      return;
    }
    if (_period == 'custom' && _customDateRange == null) {
      _showMessage('กรุณาเลือกช่วงเวลาสำหรับงบประมาณกำหนดเอง');
      return;
    }

    setState(() => _saving = true);
    try {
      final amountSatang = Money.toSatang(amountBaht);

      await ref.read(transactionsRepoProvider).createBudget(
            categoryId: _categoryId!,
            amount: amountSatang,
            period: _period,
          );

      ref.invalidate(budgetsListProvider);
      ref.invalidate(dashboardProvider);

      if (mounted) {
        _showMessage('สร้างงบประมาณสำเร็จแล้ว');
        context.pop();
      }
    } catch (e) {
      _showMessage('เกิดข้อผิดพลาด: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.income,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final moneySettings = ref.watch(
      appSettingsProvider.select((s) => (s.currency, s.usdRate)),
    );
    Money.configure(moneySettings.$1, thbToUsdRate: moneySettings.$2);
    final categoriesAsync = ref.watch(categoriesProvider);
    final dateFormat = DateFormat('dd MMM yyyy');
    final isAmountEmpty = _amountController.text.trim().isEmpty;

    return Scaffold(
      backgroundColor: AppColors.bg, // ใช้พื้นหลังเดียวกับ Goal
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.primary), // ไอคอนเดียวกับ Goal
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'ตั้งค่าวงเงินงบประมาณ',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'งบประมาณที่ต้องการตั้ง',
              style: TextStyle(
                  color: Colors.white60,
                  fontSize: 14,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),

            // กล่องกรอกเงินดีไซน์เดียวกับ DepositGoalScreen (Goal)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF0C2E1B), // ธีมเขียวเข้มแบบ Goal
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Text(
                    Money.symbol,
                    style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: '0.00',
                        hintStyle: TextStyle(color: Colors.white24),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        fillColor: Colors.transparent,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}')),
                      ],
                      onChanged: (val) => setState(() {}),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            const Text(
              'เลือกหมวดหมู่สำหรับงบนี้',
              style: TextStyle(
                  color: Colors.white60,
                  fontSize: 14,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            categoriesAsync.when(
              data: (categories) {
                if (categories.isEmpty) return const _EmptyCategories();
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.95,
                  ),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final isSelected = _categoryId == cat.id;

                    return _CategoryCard(
                      title: cat.nameTh,
                      emoji: cat.icon,
                      selected: isSelected,
                      onTap: () => setState(() => _categoryId = cat.id),
                    );
                  },
                );
              },
              loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary)),
              error: (err, stack) =>
                  _LoadError(onRetry: () => ref.invalidate(categoriesProvider)),
            ),
            const SizedBox(height: 32),

            // ── เลือกระยะเวลารอบงบประมาณ ──
            const Text(
              'ระยะเวลาที่ต้องการควบคุม',
              style: TextStyle(
                  color: Colors.white60,
                  fontSize: 14,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _PeriodButton(
                    title: 'รายเดือน',
                    active: _period == 'monthly',
                    onTap: () => setState(() => _period = 'monthly'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PeriodButton(
                    title: 'รายสัปดาห์',
                    active: _period == 'weekly',
                    onTap: () => setState(() => _period = 'weekly'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PeriodButton(
                    title: 'กำหนดเอง',
                    active: _period == 'custom',
                    onTap: _selectCustomDateRange,
                  ),
                ),
              ],
            ),

            if (_period == 'custom' && _customDateRange != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_rounded,
                        color: AppColors.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'ช่วงเวลา: ${dateFormat.format(_customDateRange!.start)} - ${dateFormat.format(_customDateRange!.end)}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                    InkWell(
                      onTap: _selectCustomDateRange,
                      child: const Text(
                        'เปลี่ยนวัน',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold),
                      ),
                    )
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
      // วางปุ่ม "ต่อไป" ไว้ใน bottomNavigationBar ให้เหมือนกับหน้า Goal เป๊ะๆ
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: ElevatedButton(
          onPressed: (isAmountEmpty || _saving) ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.black, strokeWidth: 2),
                )
              : const Text('สร้างงบประมาณ'),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.title,
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0C2E1B) : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : const Color(0xFF1E293B),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 28),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontSize: 13,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodButton extends StatelessWidget {
  const _PeriodButton({
    required this.title,
    required this.active,
    required this.onTap,
  });

  final String title;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF0C2E1B) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? AppColors.primary : const Color(0xFF1E293B),
          ),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: active ? AppColors.primary : Colors.white38,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const Text('ไม่สามารถโหลดข้อมูลหมวดหมู่ได้',
              style: TextStyle(color: Colors.white60)),
          TextButton(
              onPressed: onRetry,
              child: const Text('ลองใหม่อีกครั้ง',
                  style: TextStyle(color: AppColors.primary))),
        ],
      ),
    );
  }
}

class _EmptyCategories extends StatelessWidget {
  const _EmptyCategories();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text('ไม่มีหมวดหมู่ให้เลือกในขณะนี้',
            style: TextStyle(color: Colors.white38)),
      ),
    );
  }
}
