import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/money.dart';
import '../transactions/transactions_repository.dart';

class EditBalanceScreen extends ConsumerStatefulWidget {
  const EditBalanceScreen({super.key});

  @override
  ConsumerState<EditBalanceScreen> createState() => _EditBalanceScreenState();
}

class _EditBalanceScreenState extends ConsumerState<EditBalanceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _balanceController = TextEditingController();
  bool _prefilled = false;
  bool _saving = false;

  @override
  void dispose() {
    _balanceController.dispose();
    super.dispose();
  }

  void _prefillOnce(int currentBalanceSatang) {
    if (_prefilled) return;
    _prefilled = true;
    _balanceController.text = (currentBalanceSatang / 100).toStringAsFixed(2);
  }

  Future<void> _save(int currentBalanceSatang) async {
    if (!_formKey.currentState!.validate()) return;

    final bahtValue = double.tryParse(_balanceController.text.replaceAll(',', '').trim());
    if (bahtValue == null) return;

    final newBalanceSatang = Money.toSatang(bahtValue);
    final diff = newBalanceSatang - currentBalanceSatang;

    if (diff == 0) {
      if (context.mounted) context.pop();
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(transactionsRepoProvider);
      if (diff > 0) {
        await repo.create(
          type: 'income',
          amount: diff,
          note: 'ปรับยอดคงเหลือ',
          source: 'manual',
        );
      } else {
        await repo.create(
          type: 'expense',
          amount: -diff,
          note: 'ปรับยอดคงเหลือ',
          source: 'manual',
        );
      }

      ref.invalidate(dashboardProvider);

      if (context.mounted) context.pop();
    } catch (e) {
      if (context.mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('บันทึกไม่สำเร็จ: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(dashboardProvider);
    final currentBalance = dashboardAsync.value?.summary.balance ?? 0;
    _prefillOnce(currentBalance);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'แก้ไขยอดคงเหลือ',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_rounded,
                            size: 48,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: Text(
                          'ยอดคงเหลือปัจจุบัน: ${Money.formatBaht(currentBalance)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Center(
                        child: Text(
                          'ระบุยอดเงินคงเหลือที่ต้องการให้ตรง',
                          style: TextStyle(color: Colors.white60, fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text(
                              '฿',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _balanceController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: '0.00',
                                  hintStyle: TextStyle(color: Colors.white24),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'กรุณากรอกจำนวนเงิน';
                                  }
                                  if (double.tryParse(value.replaceAll(',', '')) == null) {
                                    return 'กรุณากรอกตัวเลขที่ถูกต้อง';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '* การแก้ไขยอดเงินตรงนี้จะสร้างรายการ "ปรับยอดคงเหลือ" (รายรับ/รายจ่าย) เพื่อให้ยอดในหน้าหลักตรงกับที่กรอก',
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _saving ? null : () => _save(currentBalance),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                    ),
                    child: _saving
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'บันทึกการเปลี่ยนแปลง',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}