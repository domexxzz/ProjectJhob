import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme.dart';
import '../../core/money.dart';
import 'transaction.dart';
import 'transactions_repository.dart';

const _thMonths = ['', 'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.', 'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'];
String _fmtThaiDate(DateTime d) => '${d.day} ${_thMonths[d.month]} ${d.year + 543}';

// เส้นขอบการ์ดเข้มอมเขียวตามดีไซน์
const _boxBorder = Color(0xFF2C4636);

/// หน้า "เลือกสลิป" — อัพสลิป (OCR อัตโนมัติ) หรือเขียนเอง → ยืนยันบันทึกรายการ
class SlipScreen extends ConsumerStatefulWidget {
  const SlipScreen({super.key});

  @override
  ConsumerState<SlipScreen> createState() => _SlipScreenState();
}

class _SlipScreenState extends ConsumerState<SlipScreen> {
  final _picker = ImagePicker();
  final _amount = TextEditingController();
  final _desc = TextEditingController();

  bool _imageMode = true; // true = เลือกไฟล์รูป, false = เขียนเอง
  String _type = 'expense';
  String? _categoryId;
  DateTime? _date;
  String? _fileName;
  bool _analyzing = false;
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pickSlip() async {
    try {
      final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 1600);
      if (file == null) return;
      setState(() {
        _analyzing = true;
        _fileName = file.name;
      });
      final bytes = await file.readAsBytes();
      final dataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      final a = await ref.read(transactionsRepoProvider).parseSlip(dataUrl);
      if (!mounted) return;
      setState(() {
        _type = 'expense';
        if ((a.amount ?? 0) > 0) _amount.text = Money.format(a.amount!);
        if (a.date != null) _date = DateTime.tryParse(a.date!);
        _categoryId = a.categoryId;
        if ((a.merchant?.trim().isNotEmpty ?? false)) _desc.text = a.merchant!.trim();
        _analyzing = false;
      });
      final ok = (a.amount ?? 0) > 0;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'อ่านสลิปสำเร็จ! ตรวจสอบแล้วกดยืนยัน ✅' : 'อ่านยอดไม่เจอ กรอกเองได้เลย'),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _analyzing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('อ่านสลิปไม่สำเร็จ: $e')));
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _pickCategory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          // watch แบบ reactive → โหลดเสร็จเมื่อไหร่ลิสต์ขึ้นเอง (แก้ปัญหา read ตอนยังโหลดไม่เสร็จ)
          child: Consumer(builder: (ctx, ref2, __) {
            final async = ref2.watch(categoriesProvider);
            return async.when(
              loading: () => const SizedBox(height: 160, child: Center(child: CircularProgressIndicator(color: AppColors.primary))),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(20),
                child: Text('โหลดหมวดไม่ได้: $e', style: const TextStyle(color: Colors.redAccent)),
              ),
              data: (cats) {
                final filtered = cats.where((c) => c.type == _type).toList();
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                      child: Text(_type == 'income' ? 'เลือกหมวดรายรับ' : 'เลือกหมวดรายจ่าย',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    if (filtered.isEmpty)
                      const Padding(padding: EdgeInsets.all(20), child: Text('ยังไม่มีหมวดหมู่', style: TextStyle(color: Colors.white54)))
                    else
                      Flexible(
                        child: GridView.count(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          crossAxisCount: 4,
                          shrinkWrap: true,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.78,
                          children: filtered.map((c) {
                            final sel = c.id == _categoryId;
                            return GestureDetector(
                              onTap: () {
                                setState(() => _categoryId = c.id);
                                Navigator.pop(ctx);
                              },
                              child: Column(children: [
                                CircleAvatar(
                                  radius: 26,
                                  backgroundColor: sel ? AppColors.primary : hexColor(c.color).withOpacity(0.15),
                                  child: Text(c.icon, style: const TextStyle(fontSize: 24)),
                                ),
                                const SizedBox(height: 4),
                                Text(c.nameTh,
                                    style: TextStyle(fontSize: 11, color: sel ? AppColors.primary : Colors.white70),
                                    textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                              ]),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                );
              },
            );
          }),
        ),
      ),
    );
  }

  Future<void> _confirm() async {
    final baht = double.tryParse(_amount.text.replaceAll(',', '').trim());
    if (baht == null || baht <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรอกจำนวนเงินให้ถูกต้อง')));
      return;
    }
    setState(() => _saving = true);
    try {
      final alert = await ref.read(transactionsRepoProvider).create(
            type: _type,
            amount: Money.toSatang(baht),
            categoryId: _categoryId,
            note: _desc.text.trim(),
            source: _imageMode ? 'ocr' : 'manual',
            occurredAt: _date,
          );
      ref.invalidate(dashboardProvider);
      if (!mounted) return;
      if (alert != null) {
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Row(children: [Icon(Icons.warning, color: Colors.orange), SizedBox(width: 8), Text('แจ้งเตือน')]),
            content: Text(alert),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('ตกลง'))],
          ),
        );
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('บันทึกไม่สำเร็จ: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // watch เพื่อ "อุ่นเครื่อง" ให้เริ่มโหลดหมวดหมู่ตั้งแต่เปิดหน้า (จะได้พร้อมตอนกดเลือก)
    final cats = ref.watch(categoriesProvider).value ?? const <Category>[];
    String? catName;
    if (_categoryId != null) {
      for (final c in cats) {
        if (c.id == _categoryId) { catName = '${c.icon} ${c.nameTh}'; break; }
      }
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            ),
          ),
        ),
        title: const Text('เลือกสลิป', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
      ),
      body: _analyzing
          ? const Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                CircularProgressIndicator(color: AppColors.primary),
                SizedBox(height: 12),
                Text('กำลังอ่านสลิป...', style: TextStyle(color: AppColors.textMuted)),
              ]),
            )
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                children: [
                  // ── Tabs: เลือกไฟล์รูป / เขียนเอง ──
                  _ModeTabs(
                    imageMode: _imageMode,
                    onChanged: (v) => setState(() => _imageMode = v),
                  ),
                  const SizedBox(height: 18),

                  // ── กล่องเลือกไฟล์ (เฉพาะโหมดรูป) ──
                  if (_imageMode) ...[
                    GestureDetector(
                      onTap: _pickSlip,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                        decoration: _boxDeco(),
                        child: Row(children: [
                          const Icon(Icons.cloud_upload_outlined, color: AppColors.primary, size: 26),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              _fileName ?? 'แตะเพื่อเลือกรูปสลิป',
                              style: TextStyle(color: _fileName != null ? Colors.white : AppColors.textMuted, fontSize: 14),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  Text(_imageMode ? 'ข้อมูลที่ได้จากสลิป' : 'กรอกข้อมูลรายการ',
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),

                  // ── จำนวนเงิน ──
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    decoration: _boxDeco(),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('จำนวนเงิน', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      TextField(
                        controller: _amount,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                        style: const TextStyle(color: AppColors.primary, fontSize: 26, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 4),
                          border: InputBorder.none, hintText: '0', hintStyle: TextStyle(color: Color(0xFF3A5546)),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),

                  // ── วันที่ ──
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                      decoration: _boxDeco(),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('วันที่', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        const SizedBox(height: 4),
                        Row(children: [
                          Text(_date != null ? _fmtThaiDate(_date!) : 'แตะเพื่อเลือกวันที่',
                              style: TextStyle(
                                  color: _date != null ? AppColors.primary : AppColors.textMuted,
                                  fontSize: 20, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          const Icon(Icons.calendar_today, color: AppColors.textMuted, size: 18),
                        ]),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // ── รายรับ / รายจ่าย ──
                  Row(children: [
                    _TypePill(label: 'รายรับ', selected: _type == 'income', color: AppColors.primary,
                        onTap: () => setState(() { _type = 'income'; _categoryId = null; })),
                    const SizedBox(width: 8),
                    _TypePill(label: 'รายจ่าย', selected: _type == 'expense', color: AppColors.expense,
                        onTap: () => setState(() { _type = 'expense'; _categoryId = null; })),
                  ]),
                  const SizedBox(height: 16),

                  // ── หมวดหมู่ ──
                  const Text('จัดไปที่หมวดหมู่', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickCategory,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                      decoration: _boxDeco(),
                      child: Row(children: [
                        Expanded(
                          child: Text(catName ?? 'เลือกหมวดหมู่',
                              style: TextStyle(
                                  color: catName != null ? Colors.white : AppColors.primary,
                                  fontSize: 16, fontWeight: FontWeight.bold),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── คำอธิบาย ──
                  const Text('คำอธิบาย (ไม่บังคับ)', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: _boxDeco(),
                    child: TextField(
                      controller: _desc,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                        hintText: 'เขียนคำอธิบาย', hintStyle: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── ปุ่มยืนยัน ──
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _confirm,
                      child: _saving
                          ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('ยืนยันการแก้ไข', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  BoxDecoration _boxDeco() => BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF16281D), Color(0xFF0F1712)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _boxBorder),
      );
}

/// แท็บสลับโหมด — เลือกไฟล์รูป (เขียว) / เขียนเอง (แดงเมื่อเลือก)
class _ModeTabs extends StatelessWidget {
  const _ModeTabs({required this.imageMode, required this.onChanged});
  final bool imageMode;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFF0F1712), borderRadius: BorderRadius.circular(30), border: Border.all(color: _boxBorder)),
      child: Row(children: [
        _tab('เลือกไฟล์รูป', imageMode, AppColors.primary, () => onChanged(true)),
        _tab('เขียนเอง', !imageMode, AppColors.expense, () => onChanged(false)),
      ]),
    );
  }

  Widget _tab(String label, bool active, Color activeColor, VoidCallback onTap) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: active ? activeColor : Colors.transparent,
              borderRadius: BorderRadius.circular(26),
            ),
            alignment: Alignment.center,
            child: Text(label,
                style: TextStyle(
                    color: active ? Colors.white : AppColors.textMuted,
                    fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ),
      );
}

/// ปิ่นรายรับ/รายจ่าย
class _TypePill extends StatelessWidget {
  const _TypePill({required this.label, required this.selected, required this.color, required this.onTap});
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : const Color(0xFF1E2A22),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : AppColors.textMuted,
                fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }
}
