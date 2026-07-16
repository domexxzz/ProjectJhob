import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/money.dart';
import '../transactions/transaction.dart';
import '../transactions/transactions_repository.dart';

class BudgetAmountScreen extends ConsumerStatefulWidget {
  const BudgetAmountScreen({super.key});

  @override
  ConsumerState<BudgetAmountScreen> createState() => _BudgetAmountScreenState();
}

class _BudgetAmountScreenState extends ConsumerState<BudgetAmountScreen> {
  final _amountController = TextEditingController();
  String? _categoryId;
  String _period = 'monthly';
  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final rawAmount = _amountController.text.replaceAll(',', '');
    final amountBaht = num.tryParse(rawAmount);
    if (_categoryId == null) {
      _showMessage('กรุณาเลือกหมวดงบประมาณ');
      return;
    }
    if (amountBaht == null || amountBaht <= 0) {
      _showMessage('กรุณากรอกวงเงินที่มากกว่า 0 บาท');
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(transactionsRepoProvider).createBudget(
            categoryId: _categoryId!,
            amount: Money.toSatang(amountBaht),
            period: _period,
          );
      ref.invalidate(budgetsListProvider);
      ref.invalidate(dashboardProvider);
      if (mounted) context.pop(true);
    } catch (error) {
      if (mounted) {
        _showMessage(_friendlyError(error));
        setState(() => _saving = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message), backgroundColor: const Color(0xFF8B2424)),
    );
  }

  String _friendlyError(Object error) {
    final message = error.toString();
    if (message.contains('ถูกตั้งไว้แล้ว')) {
      return 'หมวดนี้มีงบประมาณในรอบที่เลือกอยู่แล้ว';
    }
    return 'บันทึกงบประมาณไม่สำเร็จ กรุณาลองใหม่';
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF101210),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101210),
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: const Text(
          'เพิ่มงบประมาณ',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            const _StepTitle(
              number: '1',
              title: 'เลือกหมวดค่าใช้จ่าย',
              subtitle: 'งบแต่ละหมวดจะเทียบกับรายการจากสลิปอัตโนมัติ',
            ),
            const SizedBox(height: 14),
            categories.when(
              loading: () => const SizedBox(
                height: 120,
                child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary)),
              ),
              error: (_, __) => _LoadError(
                onRetry: () => ref.invalidate(categoriesProvider),
              ),
              data: (items) {
                final expenseCategories =
                    items.where((item) => item.type == 'expense').toList();
                if (expenseCategories.isEmpty) {
                  return const _EmptyCategories();
                }
                return _CategoryGrid(
                  categories: expenseCategories,
                  selectedId: _categoryId,
                  onSelected: (id) => setState(() => _categoryId = id),
                );
              },
            ),
            const SizedBox(height: 28),
            const _StepTitle(
              number: '2',
              title: 'กำหนดวงเงิน',
              subtitle: 'ใส่จำนวนสูงสุดที่ต้องการใช้ในหนึ่งรอบ',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                prefixText: '฿  ',
                prefixStyle: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800),
                hintText: 'เช่น 4,000',
                hintStyle: const TextStyle(color: Colors.white24, fontSize: 20),
                filled: true,
                fillColor: const Color(0xFF14271B),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.25)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [1000, 2000, 3000, 4000, 5000, 10000]
                  .map((amount) => ActionChip(
                        label: Text('฿${_formatNumber(amount)}'),
                        onPressed: () =>
                            _amountController.text = amount.toString(),
                        backgroundColor: const Color(0xFF202420),
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.08)),
                        labelStyle: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 28),
            const _StepTitle(
              number: '3',
              title: 'เลือกรอบงบประมาณ',
              subtitle: 'ระบบจะเริ่มคำนวณใหม่เมื่อขึ้นรอบถัดไป',
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _PeriodOption(
                    icon: Icons.calendar_view_week_rounded,
                    title: 'รายสัปดาห์',
                    subtitle: 'จันทร์–อาทิตย์',
                    selected: _period == 'weekly',
                    onTap: () => setState(() => _period = 'weekly'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PeriodOption(
                    icon: Icons.calendar_month_rounded,
                    title: 'รายเดือน',
                    subtitle: 'วันที่ 1–สิ้นเดือน',
                    selected: _period == 'monthly',
                    onTap: () => setState(() => _period = 'monthly'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor:
                    AppColors.primary.withValues(alpha: 0.35),
                foregroundColor: Colors.black,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.add_circle_outline_rounded),
              label: Text(
                _saving ? 'กำลังบันทึก...' : 'เพิ่มงบประมาณ',
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatNumber(int value) {
  final digits = value.toString();
  return digits.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',');
}

class _StepTitle extends StatelessWidget {
  const _StepTitle({
    required this.number,
    required this.title,
    required this.subtitle,
  });

  final String number;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
              color: AppColors.primary, shape: BoxShape.circle),
          child: Text(number,
              style: const TextStyle(
                  color: Colors.black, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  final List<Category> categories;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 9,
        crossAxisSpacing: 9,
        childAspectRatio: 1.15,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final selected = selectedId == category.id;
        return InkWell(
          onTap: () => onSelected(category.id),
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.16)
                  : const Color(0xFF1B1E1B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? AppColors.primary
                    : Colors.white.withValues(alpha: 0.06),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(category.icon, style: const TextStyle(fontSize: 27)),
                const SizedBox(height: 7),
                Text(
                  category.nameTh,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? AppColors.primary : Colors.white70,
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PeriodOption extends StatelessWidget {
  const _PeriodOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.14)
              : const Color(0xFF1B1E1B),
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: selected ? AppColors.primary : Colors.white12),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? AppColors.primary : Colors.white54),
            const SizedBox(height: 8),
            Text(title,
                style: TextStyle(
                    color: selected ? AppColors.primary : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: const TextStyle(color: Colors.white38, fontSize: 9)),
          ],
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
    return OutlinedButton.icon(
      onPressed: onRetry,
      icon: const Icon(Icons.refresh_rounded),
      label: const Text('โหลดหมวดหมู่ใหม่'),
    );
  }
}

class _EmptyCategories extends StatelessWidget {
  const _EmptyCategories();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Text(
        'ยังไม่มีหมวดค่าใช้จ่าย กรุณาเพิ่มหมวดหมู่ก่อน',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white38),
      ),
    );
  }
}
