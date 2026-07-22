import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../core/money.dart';
import '../privacy/privacy_screen.dart';
import '../settings/settings_screen.dart';
import '../transactions/transaction.dart';
import '../transactions/transactions_repository.dart'; // ตรวจสอบตำแหน่งอ้างอิงของ Provider งบประมาณตามโปรเจกต์ของคุณ
import '../goals/set_deadline_screen.dart';

class BudgetEditScreen extends ConsumerStatefulWidget {
  const BudgetEditScreen({super.key, required this.status});
  final BudgetStatus status;

  @override
  ConsumerState<BudgetEditScreen> createState() => _BudgetEditScreenState();
}

class _BudgetEditScreenState extends ConsumerState<BudgetEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _amountController;
  late bool _showOnDashboard;

  bool _didApplyDisplayCurrency = false;

  @override
  void initState() {
    super.initState();
    _showOnDashboard = widget.status.showOnDashboard;
    // ใช้ชื่อที่ผู้ใช้ตั้งเอง (name) ก่อน ถ้าไม่มีค่อย fallback ไป nameTh ของ category
    _nameController = TextEditingController(
      text: widget.status.name?.isNotEmpty == true
          ? widget.status.name!
          : (widget.status.category?.nameTh ?? ''),
    );

    // แปลงจำนวนเงินสตางค์กลับเป็นหน่วยบาทเพื่อแสดงผลในช่องกรอกเงินแบบเข้าใจง่าย
    _amountController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final moneySettings = ref.watch(
      appSettingsProvider.select((s) => (s.currency, s.usdRate)),
    );
    Money.configure(moneySettings.$1, thbToUsdRate: moneySettings.$2);
    if (!_didApplyDisplayCurrency) {
      _amountController.text = Money.format(widget.status.amount);
      _didApplyDisplayCurrency = true;
    }
    final personalized =
        ref.watch(privacySettingsProvider).personalizedRecommendations;
    // คำนวณเปอร์เซ็นต์แบบ Real-time ตามตัวเลขที่ผู้ใช้กรอกเข้ามาใหม่
    final double inputtedBaht = double.tryParse(_amountController.text) ?? 0;
    final int targetAmountInSubunits = Money.toSatang(inputtedBaht);

    final pct = targetAmountInSubunits > 0
        ? (widget.status.spent / targetAmountInSubunits).clamp(0.0, 9.9)
        : 0.0;

    final color = pct >= 1.0
        ? const Color(0xFFFF5959) // แดงนีออนสุดพรีเมียม
        : (pct >= 0.8
            ? const Color(0xFFFFD54F)
            : const Color(0xFF4CD97B)); // เหลือง / เขียวนีออน

    final remaining = (targetAmountInSubunits - widget.status.spent)
        .clamp(0, double.infinity)
        .toInt();

    return Scaffold(
      backgroundColor: const Color(
          0xFF16191D), // ธีม Premium Dark UI แบบเดียวกับ EditGoalScreen
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // 1. ส่วนหัว App Bar ดีไซน์พรีเมียมสีเขียวของหน้าแก้ไขเป้าหมาย
              Padding(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 20,
                  right: 20,
                  bottom: 10,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () => context.pop(),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF3CAE63),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF3CAE63).withOpacity(0.4),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.arrow_back_rounded,
                              color: Colors.white, size: 24),
                        ),
                      ),
                    ),
                    const Text(
                      'แก้ไขงบประมาณ',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                          color: Colors.white,
                          letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),

              // 2. ไอคอนแสดงหมวดหมู่งบประมาณพร้อมขอบเรืองแสง (Neon Glow Circle)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Container(
                      width: 124,
                      height: 124,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE2F1FC), Color(0xFFBDD7EE)],
                        ),
                        border: Border.all(color: color, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.4),
                            blurRadius: 25,
                            spreadRadius: 6,
                          )
                        ],
                      ),
                      child: Center(
                        child: Text(widget.status.category?.icon ?? '📊',
                            style: const TextStyle(fontSize: 56)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _nameController.text.isNotEmpty
                              ? _nameController.text
                              : 'หมวดหมู่',
                          style: TextStyle(
                              color: color,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.edit_note_rounded,
                            color: Colors.white60, size: 22),
                      ],
                    ),
                  ],
                ),
              ),

              // 3. ส่วนช่องกรอกแก้ไขข้อมูลสไตล์หน้า EditGoal[cite: 29]
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ช่องแก้ไขชื่อ/หัวข้อของงบประมาณ[cite: 29]
                    Text(
                      'ชื่อหมวดหมู่หรือรายการงบประมาณ',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 14,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF22272F),
                        prefixIcon: const Icon(Icons.edit_note_rounded,
                            color: Color(0xFF4CD97B), size: 26),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear_rounded,
                              color: Colors.white38, size: 20),
                          onPressed: () =>
                              setState(() => _nameController.clear()),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        hintText: 'กรอกชื่อหมวดหมู่ใหม่...',
                        hintStyle:
                            TextStyle(color: Colors.white.withOpacity(0.25)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                              color: Color(0xFF4CD97B), width: 1.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Colors.white10),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                              color: Color(0xFFFF5959), width: 1.5),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                              color: Color(0xFFFF5959), width: 1.5),
                        ),
                      ),
                      onChanged: (val) => setState(() {}),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'กรุณากรอกชื่อหมวดหมู่งบประมาณก่อนบันทึก';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),

                    // ช่องแก้ไขและกำหนดยอดเงินเป้าหมายของงบประมาณ[cite: 29]
                    Text(
                      'ยอดเงินงบประมาณสูงสุดที่ตั้งไว้',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 14,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4CD97B)),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF22272F),
                        prefixIcon: const Icon(Icons.stars_rounded,
                            color: Color(0xFF3CAE63), size: 24),
                        suffixText: Money.symbol,
                        suffixStyle: const TextStyle(
                            color: Colors.white54,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        hintText: 'ตั้งจำนวนเงินงบประมาณ...',
                        hintStyle:
                            TextStyle(color: Colors.white.withOpacity(0.25)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                              color: Color(0xFF4CD97B), width: 1.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Colors.white10),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                              color: Color(0xFFFF5959), width: 1.5),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                              color: Color(0xFFFF5959), width: 1.5),
                        ),
                      ),
                      onChanged: (val) => setState(() {}),
                      validator: (value) {
                        if (value == null ||
                            double.tryParse(value) == null ||
                            double.parse(value) <= 0) {
                          return 'กรุณากรอกจำนวนเงินงบประมาณที่มากกว่า 0';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 4. ส่วนแสดงข้อมูลและปุ่มทั้งหมด
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Progress Card (แปลงดีไซน์เป็น Gradient พื้นหลังเข้ม-เขียว สไตล์พรีเมียมแบบเดียวกับเป้าหมาย)[cite: 29]
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF1B3227), Color(0xFF0F241B)],
                        ),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                            color: const Color(0xFF3CAE63).withOpacity(0.2)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text('ใช้ไปแล้ว',
                                  style: TextStyle(
                                      color: Color(0xAAFFFFFF),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500)),
                              Text('ใช้ได้ไม่เกิน',
                                  style: TextStyle(
                                      color: Color(0xAAFFFFFF),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                Money.formatBaht(widget.status.spent),
                                style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 24),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'เหลืออีก ${Money.formatBaht(remaining)}',
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.5),
                                        fontSize: 12),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${(pct * 100).toInt()} %',
                                    style: TextStyle(
                                        color: color,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          // Linear Progress Bar มินิมอลสไตล์พรีเมียม
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              height: 8,
                              child: LinearProgressIndicator(
                                value: pct.clamp(0.0, 1.0),
                                backgroundColor: Colors.white.withOpacity(0.12),
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(color),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

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

                    // ส่วนแนะนำอัจฉริยะ (AI Smart Assistant Card)
                    if (personalized)
                      const Text(
                        'แนะนำสำหรับคุณ',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3),
                      ),
                    if (personalized) const SizedBox(height: 12),
                    if (personalized)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF0C241B), Color(0xFF071812)],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                              color: const Color(0xFF3CAE63).withOpacity(0.15)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF133526),
                              ),
                              child: const Icon(Icons.smart_toy_rounded,
                                  color: Color(0xFF4CD97B), size: 28),
                            ),

                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'พี่เงินขอแนะนำ',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  remaining > 0 ? 'ยังเหลือให้ใช้ได้อีก ${Money.formatBaht(remaining * 100)} บาท' : 'คุณใช้เงินเกินงบไปแล้ว',
                                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                                )
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded,
                              color: Colors.white30, size: 14),
                          ],
                        ),
                      ),
                    SizedBox(height: personalized ? 48 : 24),

                    // ปุ่มลบ และ ยืนยันการแก้ไข สไตล์ปุ่มพรีเมียมแบบคู่ขนานด้านล่าง[cite: 29]
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 56,
                            child: ElevatedButton(
                              onPressed: () {
                                _deleteBudget();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF5959),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ),
                              child: const Text('ลบ',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: SizedBox(
                            height: 56,
                            child: ElevatedButton(
                              onPressed: () {
                                _saveBudget();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3CAE63),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ),
                              child: const Text(
                                'ยืนยันการแก้ไข',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ฟังก์ชันบันทึกและแก้ไขข้อมูลงบประมาณ (เพิ่ม async หลังชื่อฟังก์ชัน)
  Future<void> _saveBudget() async {
    if (_formKey.currentState!.validate()) {
      final double bahtAmount = double.tryParse(_amountController.text) ?? 0;
      final int targetSubunits = (bahtAmount * 100).toInt();
      final String budgetName = _nameController.text.trim();

      // บันทึกและอัปเดตข้อมูลผ่าน Repository
      await ref.read(transactionsRepoProvider).updateBudget(
        widget.status.id,
        name: budgetName.isNotEmpty ? budgetName : null,
        amount: targetSubunits,
        showOnDashboard: _showOnDashboard,
      );

      // สั่งให้รีเฟรชค่าในแอปพลิเคชัน
      ref.invalidate(budgetsListProvider);
      ref.invalidate(dashboardProvider);

      // ปิดหน้าจอแก้ไข
      if (mounted) context.pop();
    }
  }

  // ฟังก์ชันลบข้อมูลผ่าน Repository (เพิ่ม async หลังชื่อฟังก์ชัน)
  Future<void> _deleteBudget() async {
    await ref.read(transactionsRepoProvider).deleteBudget(widget.status.id);

    // สั่งให้รีเฟรชค่าในแอปพลิเคชัน
    ref.invalidate(budgetsListProvider);
    ref.invalidate(dashboardProvider);

    // ปิดหน้าจอแก้ไข
    if (mounted) context.pop();
  }

  // ตัวช่วยสร้างรายการเมนูแบบ Card Gradient ดึงดีไซน์ตามหน้า Edit Goal[cite: 29]
  Widget _buildMenuRowCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0C241B), Color(0xFF071812)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF3CAE63).withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF3CAE63), size: 26),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.45), fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white30, size: 14),
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