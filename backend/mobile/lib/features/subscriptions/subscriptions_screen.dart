import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../core/money.dart';
import 'subscriptions_repository.dart';

class SubscriptionsScreen extends ConsumerWidget {
  const SubscriptionsScreen({super.key});

  String _fmtDate(DateTime d) =>
      '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(subscriptionsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text('Subscription', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            tooltip: 'นำเข้าจาก Gmail',
            icon: const Icon(Icons.mark_email_read_outlined, color: AppColors.primary),
            onPressed: () => _importGmail(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(subscriptionsProvider);
          await ref.read(subscriptionsProvider.future);
        },
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (e, _) => ListView(children: [
            const SizedBox(height: 120),
            Center(child: Text('โหลดไม่ได้: $e', style: const TextStyle(color: Colors.redAccent))),
          ]),
          data: (data) => ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              _TotalCard(totalMonthly: data.totalMonthly),
              const SizedBox(height: 20),
              const Text('รายการสมัครสมาชิก',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (data.items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: Text('ยังไม่มีรายการสมัครสมาชิก', style: TextStyle(color: Colors.white54))),
                )
              else
                ...data.items.map((s) => _SubCard(
                      sub: s,
                      dateText: _fmtDate(s.nextBilling),
                      onTap: () => _openForm(context, ref, existing: s),
                    )),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => _openForm(context, ref),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF142B1A),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_circle_outline, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('เพิ่ม Subscription',
                        style: TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openForm(BuildContext context, WidgetRef ref, {Subscription? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _SubscriptionForm(existing: existing),
      ),
    );
  }

  /// นำเข้า subscription จาก Gmail — server-side OAuth (robust)
  /// ขอ URL จาก backend → เปิดหน้ายินยอม Google เต็มหน้า → backend จัดการ callback + import เอง
  Future<void> _importGmail(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final url = await ref.read(subscriptionsRepoProvider).gmailAuthUrl();
      final ok = await launchUrl(
        Uri.parse(url),
        webOnlyWindowName: '_blank', // เปิดแท็บใหม่บนเว็บ
        mode: LaunchMode.externalApplication,
      );
      if (!ok) {
        messenger.showSnackBar(const SnackBar(content: Text('เปิดหน้ายินยอม Google ไม่ได้')));
        return;
      }
      messenger.showSnackBar(const SnackBar(
        content: Text('เปิดหน้ายินยอม Google แล้ว 📧 · เสร็จแล้วกลับมาที่นี่ ลากลงเพื่อรีเฟรช'),
        duration: Duration(seconds: 5),
      ));
    } catch (e) {
      final msg = e is DioException
          ? (e.response?.data is Map ? (e.response!.data['message'] ?? e.message) : e.message)
          : e;
      messenger.showSnackBar(SnackBar(content: Text('นำเข้าไม่สำเร็จ: $msg')));
    }
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.totalMonthly});
  final int totalMonthly;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF042004), Color(0xFF0B140B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('รวมค่าบริการต่อเดือน', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 6),
          Text(Money.formatBaht(totalMonthly),
              style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _SubCard extends StatelessWidget {
  const _SubCard({required this.sub, required this.dateText, required this.onTap});
  final Subscription sub;
  final String dateText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final perLabel = sub.cycle == 'yearly' ? 'ปี' : 'เดือน';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
              child: Center(child: Text(sub.logo ?? '💳', style: const TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sub.name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text('ตัดเงินถัดไป $dateText', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(Money.formatBaht(sub.amount),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                Text('/$perLabel', style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
            const Icon(Icons.chevron_right, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}

class _SubscriptionForm extends ConsumerStatefulWidget {
  const _SubscriptionForm({this.existing});
  final Subscription? existing;

  @override
  ConsumerState<_SubscriptionForm> createState() => _SubscriptionFormState();
}

class _SubscriptionFormState extends ConsumerState<_SubscriptionForm> {
  late final TextEditingController _name;
  late final TextEditingController _amount; // baht
  late final TextEditingController _logo;
  String _cycle = 'monthly';
  DateTime _nextBilling = DateTime.now().add(const Duration(days: 30));
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _amount = TextEditingController(text: e != null ? (e.amount / 100).round().toString() : '');
    _logo = TextEditingController(text: e?.logo ?? '');
    if (e != null) {
      _cycle = e.cycle;
      _nextBilling = e.nextBilling;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _logo.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final baht = int.tryParse(_amount.text.trim());
    if (name.isEmpty || baht == null || baht <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรอกชื่อและจำนวนเงินให้ถูกต้อง')),
      );
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(subscriptionsRepoProvider);
    try {
      final e = widget.existing;
      if (e == null) {
        await repo.create(
          name: name,
          amount: Money.toSatang(baht),
          cycle: _cycle,
          nextBilling: _nextBilling,
          logo: _logo.text.trim(),
        );
      } else {
        await repo.update(
          e.id,
          name: name,
          amount: Money.toSatang(baht),
          cycle: _cycle,
          nextBilling: _nextBilling,
          logo: _logo.text.trim(),
        );
      }
      ref.invalidate(subscriptionsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (err) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('บันทึกไม่สำเร็จ: $err')));
      }
    }
  }

  Future<void> _delete() async {
    final e = widget.existing;
    if (e == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(subscriptionsRepoProvider).delete(e.id);
      ref.invalidate(subscriptionsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (err) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ลบไม่สำเร็จ: $err')));
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextBilling,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _nextBilling = picked);
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.primary),
          borderRadius: BorderRadius.circular(12),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isEdit ? 'แก้ไข Subscription' : 'เพิ่ม Subscription',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(controller: _name, style: const TextStyle(color: Colors.white), decoration: _dec('ชื่อ (เช่น Netflix)')),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: _dec('จำนวนเงิน (บาท)'),
          ),
          const SizedBox(height: 12),
          TextField(controller: _logo, style: const TextStyle(color: Colors.white), decoration: _dec('ไอคอน/emoji (ไม่บังคับ)')),
          const SizedBox(height: 12),
          Row(
            children: [
              _CycleChip(label: 'รายเดือน', selected: _cycle == 'monthly', onTap: () => setState(() => _cycle = 'monthly')),
              const SizedBox(width: 8),
              _CycleChip(label: 'รายปี', selected: _cycle == 'yearly', onTap: () => setState(() => _cycle = 'yearly')),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: Colors.white54, size: 18),
                  const SizedBox(width: 10),
                  Text('ตัดเงินถัดไป: ${_nextBilling.day}/${_nextBilling.month}/${_nextBilling.year}',
                      style: const TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              if (isEdit) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : _delete,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFF03E3E)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('ลบ', style: TextStyle(color: Color(0xFFF03E3E))),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('บันทึก', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CycleChip extends StatelessWidget {
  const _CycleChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(color: selected ? Colors.white : Colors.white54, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
