import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import 'goals_provider.dart';

class EditGoalScreen extends ConsumerStatefulWidget {
  const EditGoalScreen({super.key, this.goalId});

  final String? goalId;

  @override
  ConsumerState<EditGoalScreen> createState() => _EditGoalScreenState();
}

class _EditGoalScreenState extends ConsumerState<EditGoalScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _targetController;
  DateTime? _selectedDate;
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedType = 'short';
  String _selectedEmoji = '🌴';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _targetController = TextEditingController(); 

    if (widget.goalId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final goal = ref.read(goalsProvider).firstWhere((g) => g.id == widget.goalId);
        setState(() {
          _nameController.text = goal.name;
          _targetController.text = (goal.target / 100).round().toString();
          _selectedDate = goal.deadline;
          _startDate = goal.deadline;
          _endDate = null;
          _selectedType = goal.type;
          _selectedEmoji = goal.emoji;
        });
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'short':
        return 'ระยะสั้น (ภายใน 1 ปี)';
      case 'medium':
        return 'ระยะกลาง (1 - 3 ปี)';
      case 'long':
        return 'ระยะยาว (3 ปีขึ้นไป)';
      default:
        return 'ระยะสั้น (ภายใน 1 ปี)';
    }
  }

  @override
  Widget build(BuildContext context) {
    // อ่าน currentSavings โดยตรงจาก goalsProvider เสมอ
    // เพื่อให้สะท้อนยอดล่าสุดหลังจากฝากเงินจากหน้า deposit แบบ real-time
    final goals = ref.watch(goalsProvider);
    final int currentSavings = widget.goalId != null
        ? (goals.firstWhere((g) => g.id == widget.goalId, orElse: () => goals.first).current)
        : 0;
    final int targetVal = (int.tryParse(_targetController.text) ?? 0) * 100;
    final int remaining = (targetVal - currentSavings).clamp(0, targetVal);
    final double progress = targetVal > 0 ? (currentSavings / targetVal).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SingleChildScrollView(
        child: Column(
          children: [
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
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF3CAE63), 
                        ),
                        child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                      ),
                    ),
                  ),
                  const Text(
                    'แก้ไขเป้าหมาย',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFD4E6F1), 
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3CAE63).withOpacity(0.5),
                          blurRadius: 30,
                          spreadRadius: 6,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(_selectedEmoji, style: const TextStyle(fontSize: 56)),
                  ),
                  const SizedBox(height: 16),
                  Form(
                    key: _formKey,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IntrinsicWidth(
                          child: TextFormField(
                            controller: _nameController,
                            style: const TextStyle(
                              fontSize: 22, 
                              fontWeight: FontWeight.bold, 
                              color: Color(0xFF3CAE63), 
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.edit_square, color: Colors.white, size: 20), 
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      if (widget.goalId != null) {
                        context.push('/goals/deposit?id=${widget.goalId}');
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF203231), Color(0xFF0C3A1E)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF3CAE63).withOpacity(0.2)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('ออมแล้ว', style: TextStyle(color: Colors.white70, fontSize: 13)),
                              const Text('จากเป้าหมาย', style: TextStyle(color: Colors.white70, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${Money.format(currentSavings)} ฿',
                                style: const TextStyle(color: Color(0xFF4CD97B), fontWeight: FontWeight.bold, fontSize: 20),
                              ),
                              Text(
                                'เหลืออีก ${Money.format(remaining)}',
                                style: const TextStyle(color: Colors.white60, fontSize: 12),
                              ),
                              // เปลี่ยนจาก Text แข็งๆ เป็นปุ่มแก้ไขยอดเป้าหมาย
                              IntrinsicWidth(
                                child: TextFormField(
                                  controller: _targetController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                                  textAlign: TextAlign.end,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                    border: InputBorder.none,
                                    suffixText: ' ฿\n${(progress * 100).toStringAsFixed(0)} %',
                                    suffixStyle: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.normal),
                                  ),
                                  onChanged: (val) => setState(() {}),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              height: 6,
                              child: LinearProgressIndicator(
                                value: progress,
                                backgroundColor: Colors.white.withOpacity(0.15),
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF37C871)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildMenuRowCard(
                    icon: Icons.calendar_month_rounded,
                    title: 'กำหนดระยะเวลา',
                    subtitle: _startDate != null && _endDate != null
      ? "${DateFormat('d MMMM', 'th').format(_startDate!)} - ${DateFormat('d MMMM yyyy', 'th').format(_endDate!)}"
      : 'เลือกกำหนดระยะเวลา',
                    onTap: () async {
    final Map<String, DateTime?>? result = await context.push<Map<String, DateTime?>>(
      '/goals/duration',
      extra: {'startDate': _startDate, 'endDate': _endDate},
    );

                      // เมื่อผู้ใช้เลือกและกดบันทึกกลับมา ให้อัปเดต UI ทันที
                     if (result != null) {
      setState(() {
        _startDate = result['startDate'];
        _endDate = result['endDate'];
        _selectedDate = result['endDate']; // อัปเดต deadline หลักด้วย
      });
    }
                    }, // <-- ปิดฟังก์ชัน onTap ตรงนี้
                  ), // <-- ปิด _buildMenuRowCard ตรงนี้
                  const SizedBox(height: 12),
                  _buildMenuRowCard(
                    icon: Icons.flag_rounded,
                    title: 'ประเภทเป้าหมาย',
                    subtitle: _getTypeLabel(_selectedType),
                    onTap: () => _showTypeSelectionBottomSheet(),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'แนะนำสำหรับคุณ',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF041E14), Color(0xFF0A2B1D)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF3CAE63).withOpacity(0.15)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF163220),
                          ),
                          child: const Icon(Icons.smart_toy_rounded, color: Color(0xFF4CD97B), size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'พี่เงินขอแนะนำ',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'มีเวลาอีก 3 เดือน ให้แบ่งเก็บเดือนละ 1000 บาท',
                                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white30, size: 16),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 54,
                          child: ElevatedButton(
                            onPressed: () => _deleteGoal(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF6B6B),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text('ลบ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: SizedBox(
                          height: 54,
                          child: ElevatedButton(
                            onPressed: () => _saveGoal(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3CAE63),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text(
                              'ยืนยันการแก้ไข',
                              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuRowCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF041E14), Color(0xFF0A2B1D)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF3CAE63).withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF3CAE63), size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white30, size: 16),
          ],
        ),
      ),
    );
  }

  void _showTypeSelectionBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('เลือกประเภทเป้าหมาย', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
              ),
              ListTile(
                title: const Text('ระยะสั้น (ภายใน 1 ปี)', style: TextStyle(color: Colors.white)),
                onTap: () { setState(() => _selectedType = 'short'); Navigator.pop(context); },
              ),
              ListTile(
                title: const Text('ระยะกลาง (1 - 3 ปี)', style: TextStyle(color: Colors.white)),
                onTap: () { setState(() => _selectedType = 'medium'); Navigator.pop(context); },
              ),
              ListTile(
                title: const Text('ระยะยาว (3 ปีขึ้นไป)', style: TextStyle(color: Colors.white)),
                onTap: () { setState(() => _selectedType = 'long'); Navigator.pop(context); },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _saveGoal() {
    if (_formKey.currentState!.validate()) {
      final name = _nameController.text.trim();
      final int targetVal = (int.tryParse(_targetController.text) ?? 0) * 100;
      
      if (widget.goalId != null) {
        ref.read(goalsProvider.notifier).updateGoal(
          widget.goalId!,
          name,
          targetVal,
          _selectedDate,
          _selectedType,
          _selectedEmoji,
        );
      } else {
        ref.read(goalsProvider.notifier).addGoal(
          name,
          targetVal,
          _selectedDate,
          _selectedType,
          _selectedEmoji,
        );
      }
      context.pop();
    }
  }

  void _deleteGoal() {
    if (widget.goalId != null) {
      ref.read(goalsProvider.notifier).deleteGoal(widget.goalId!);
    }
    context.pop();
  }
}