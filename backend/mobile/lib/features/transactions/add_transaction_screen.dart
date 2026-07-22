import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/money.dart';
import 'transaction.dart';
import 'transactions_repository.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key, this.transaction});
  
  final Txn? transaction;

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  String _type = 'expense';
  String? _categoryId;
  final _amount = TextEditingController();
  final _note = TextEditingController();
  bool _saving = false;
  bool _analyzing = false;

  bool get _isEditMode => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      final t = widget.transaction!;
      _type = t.type;
      _categoryId = t.category?.id;
      _amount.text = (t.amount / 100).toStringAsFixed(2);
      _note.text = t.note ?? '';
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final baht = double.tryParse(_amount.text.replaceAll(',', '').trim());
    if (baht == null || baht <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('กรอกจำนวนเงินให้ถูกต้อง')));
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(transactionsRepoProvider);
      String? anomalyAlert;
      if (_isEditMode) {
        anomalyAlert = await repo.update(
          widget.transaction!.id,
          type: _type,
          amount: Money.toSatang(baht),
          categoryId: _categoryId,
          note: _note.text,
        );
      } else {
        anomalyAlert = await repo.create(
          type: _type,
          amount: Money.toSatang(baht),
          categoryId: _categoryId,
          note: _note.text,
          source: _note.text.contains('(Scan)') ? 'ocr' : 'manual',
        );
      }
      if (mounted) {
        if (anomalyAlert != null) {
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('แจ้งเตือนการใช้จ่าย'),
                ],
              ),
              content: Text(anomalyAlert!),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ตกลง'),
                ),
              ],
            ),
          );
        }
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('บันทึกไม่สำเร็จ: $e')));
      }
    }
  }

  void _showMockOcrDialog() {
    final templates = [
      (
        label: 'สลิป KBank (ข้าวกะเพรา 120 บาท)',
        text: 'ธนาคารกสิกรไทย โอนเงินสำเร็จ 20 มิ.ย. 67 14:32 น. ไปยัง ร้านอาหารตามสั่ง จำนวน 120.00 บาท รหัสอ้างอิง 01522006271432'
      ),
      (
        label: 'สลิป SCB (ช้อปปิ้ง Shopee Pay 250 บาท)',
        text: 'ไทยพาณิชย์ สแกนจ่ายสำเร็จ วันที่ 20 มิ.ย. 2567 - 14:32 เข้าบัญชี Shopee Pay จำนวนเงิน 250.00 บาท เลขที่รายการ 2024062012345'
      ),
      (
        label: 'สลิปกรุงเทพ (ค่าเดินทาง BTS 50 บาท)',
        text: 'ธนาคารกรุงเทพ รายการโอนเงิน 20/06/2567 14:32 ไปยัง BTS Skytrain จำนวนเงิน: 50.00 บาท เลขที่อ้างอิง BBL123456789'
      ),
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'จำลองการสแกนสลิป (Mock OCR) 📸',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
                const SizedBox(height: 8),
                const Text(
                  'เลือกสลิปจำลองด้านล่าง ระบบจะสแกนข้อความและกรอกข้อมูลฟอร์มให้อัตโนมัติ เพื่อให้ท่านกดยืนยัน',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 16),
                ...templates.map((t) => ListTile(
                      title: Text(t.label),
                      leading: const Icon(Icons.qr_code_scanner, color: AppColors.primary),
                      onTap: () {
                        Navigator.pop(context);
                        _runMockOcr(t.text);
                      },
                    )),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _runMockOcr(String text) async {
    setState(() => _analyzing = true);
    try {
      final repo = ref.read(transactionsRepoProvider);
      final analyzed = await repo.analyzeText(text);
      
      setState(() {
        _type = 'expense'; // default for slips
        if (analyzed.amount != null) {
          _amount.text = (analyzed.amount! / 100).toStringAsFixed(2);
        }
        _categoryId = analyzed.categoryId;
        _note.text = '${analyzed.merchant ?? "ชำระเงิน"} (Scan)';
        _analyzing = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('สแกนสำเร็จ! โปรดตรวจสอบข้อมูลและกดยืนยันบันทึก')),
        );
      }
    } catch (e) {
      setState(() => _analyzing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('สแกนล้มเหลว: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'แก้ไขรายการ' : 'เพิ่มรายการ'),
        actions: [
          if (!_isEditMode)
            IconButton(
              tooltip: 'จำลองสแกนสลิป',
              onPressed: _showMockOcrDialog,
              icon: const Icon(Icons.camera_alt, color: AppColors.primary),
            )
        ],
      ),
      body: SafeArea(
        child: _analyzing
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('กำลังสแกนวิเคราะห์สลิป...', style: TextStyle(color: AppColors.textMuted)),
                  ],
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1) ประเภท
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'expense', label: Text('รายจ่าย'), icon: Icon(Icons.south_west)),
                        ButtonSegment(value: 'income', label: Text('รายรับ'), icon: Icon(Icons.north_east)),
                      ],
                      selected: {_type},
                      onSelectionChanged: (s) => setState(() {
                        _type = s.first;
                        _categoryId = null;
                      }),
                    ),
                    const SizedBox(height: 20),
                    // 2) จำนวนเงิน
                    TextField(
                      controller: _amount,
                      autofocus: !_isEditMode,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(prefixText: '฿ ', hintText: '0'),
                    ),
                    const SizedBox(height: 20),
                    const Text('หมวดหมู่', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    // 3) หมวด
                    Expanded(
                      child: categories.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Text('โหลดหมวดไม่ได้: $e'),
                        data: (cats) {
                          final filtered = cats.where((c) => c.type == _type).toList();
                          return GridView.count(
                            crossAxisCount: 4,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.85,
                            children: filtered.map((c) {
                              final selected = c.id == _categoryId;
                              return GestureDetector(
                                onTap: () => setState(() => _categoryId = c.id),
                                child: Column(
                                  children: [
                                    CircleAvatar(
                                      radius: 26,
                                      backgroundColor:
                                          selected ? AppColors.primary : hexColor(c.color).withOpacity(0.15),
                                      child: Text(c.icon, style: const TextStyle(fontSize: 24)),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(c.nameTh,
                                        style: const TextStyle(fontSize: 11),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(controller: _note, decoration: const InputDecoration(labelText: 'โน้ต (ไม่บังคับ)')),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              height: 22, width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(_isEditMode ? 'บันทึกการแก้ไข' : 'บันทึก'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
