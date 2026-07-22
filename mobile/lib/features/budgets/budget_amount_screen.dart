import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../goals/set_deadline_screen.dart';
import '../transactions/transactions_repository.dart';

class BudgetAmountScreen extends ConsumerStatefulWidget {
  const BudgetAmountScreen({super.key});

  @override
  ConsumerState<BudgetAmountScreen> createState() => _BudgetAmountScreenState();
}

class _BudgetAmountScreenState extends ConsumerState<BudgetAmountScreen> {
  final _amountController = TextEditingController();
  final _nameController = TextEditingController();
  bool _showOnDashboard = true;
  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final rawAmount = _amountController.text.replaceAll(',', '');
    final amountBaht = num.tryParse(rawAmount);
    final budgetName = _nameController.text.trim();

    if (budgetName.isEmpty) {
      _showMessage('กรุณาใส่ชื่อหัวข้องบประมาณ');
      return;
    }
    if (amountBaht == null || amountBaht <= 0) {
      _showMessage('กรุณากรอกวงเงินที่มากกว่า 0 บาท');
      return;
    }

    setState(() => _saving = true);
    try {
      final amountSatang = (amountBaht * 100).toInt();

      await ref.read(transactionsRepoProvider).createBudget(
            name: budgetName,
            amount: amountSatang,
            showOnDashboard: _showOnDashboard,
          );

      ref.invalidate(budgetsListProvider);
      ref.invalidate(dashboardProvider);

      if (mounted) {
        _showMessage('สร้างงบประมาณสำเร็จแล้ว');
        context.pop();
      }
    } on DioException catch (e) {
      final msg = e.response?.data['error'] ?? e.message ?? e.toString();
      _showMessage('เกิดข้อผิดพลาด: $msg', isError: true);
    } catch (e) {
      _showMessage('เกิดข้อผิดพลาด: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.redAccent : AppColors.income,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isReady = _amountController.text.trim().isNotEmpty &&
        _nameController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.primary),
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
            // ── ชื่อหัวข้องบประมาณ ──
            const Text(
              'ชื่อหัวข้องบประมาณ',
              style: TextStyle(
                  color: Colors.white60,
                  fontSize: 14,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: TextField(
                controller: _nameController,
                autofocus: true,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'เช่น ค่าอาหาร, ท่องเที่ยว, สุขภาพ...',
                  hintStyle: TextStyle(color: Colors.white24, fontSize: 15),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 16),
                  fillColor: Colors.transparent,
                  prefixIcon: Icon(Icons.label_outline_rounded,
                      color: AppColors.primary, size: 22),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 28),

            // ── วงเงินงบประมาณ ──
            const Text(
              'งบประมาณที่ต้องการตั้ง',
              style: TextStyle(
                  color: Colors.white60,
                  fontSize: 14,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF0C2E1B),
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Text(
                    '฿',
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
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
            // ── ตัวเลือกแสดงผลบน Dashboard ──
            const SizedBox(height: 28),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1C2224),
                borderRadius: BorderRadius.circular(16),
              ),
              child: SwitchListTile(
                title: const Text('แสดงบน Dashboard', style: TextStyle(color: Colors.white, fontSize: 15)),
                subtitle: const Text('จำกัดการแสดงผลบนหน้าแรกสูงสุด 6 รายการ', style: TextStyle(color: Colors.white54, fontSize: 13)),
                value: _showOnDashboard,
                onChanged: (val) => setState(() => _showOnDashboard = val),
                activeColor: AppColors.primary,
                inactiveTrackColor: Colors.white12,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: ElevatedButton(
          onPressed: (isReady && !_saving) ? _save : null,
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