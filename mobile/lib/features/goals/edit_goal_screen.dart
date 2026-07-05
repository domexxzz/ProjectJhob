import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
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
  String _selectedType = 'short';
  String _selectedEmoji = '🎯';
  int _currentSavings = 0;

  final List<String> _emojis = ['🌴', '🔌', '🛡️', '🚗', '🏠', '✈️', '🎓', '🎮', '💍', '💰', '📈', '🍔'];

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
          _selectedType = goal.type;
          _selectedEmoji = goal.emoji;
          _currentSavings = goal.current;
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
    final isEdit = widget.goalId != null;
    final int targetVal = (int.tryParse(_targetController.text) ?? 0) * 100;
    final int remaining = (targetVal - _currentSavings).clamp(0, targetVal);
    final double progress = targetVal > 0 ? (_currentSavings / targetVal).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          isEdit ? 'แก้ไขเป้าหมาย' : 'เพิ่มเป้าหมาย',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Emoji Circle Preview
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(0.1),
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(_selectedEmoji, style: const TextStyle(fontSize: 44)),
              ),
              const SizedBox(height: 16),
              
              // Emoji Horizontal Selector List
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _emojis.length,
                  itemBuilder: (context, index) {
                    final em = _emojis[index];
                    final isSelected = em == _selectedEmoji;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedEmoji = em),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? AppColors.primary.withOpacity(0.2) : Colors.transparent,
                          border: Border.all(
                            color: isSelected ? AppColors.primary : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Text(em, style: const TextStyle(fontSize: 20)),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Goal Title Text Field
              TextFormField(
                controller: _nameController,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary),
                decoration: const InputDecoration(
                  hintText: 'ตั้งชื่อเป้าหมาย',
                  hintStyle: TextStyle(color: AppColors.textMuted),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'กรุณากรอกชื่อเป้าหมาย' : null,
              ),
              const SizedBox(height: 16),

              // Wireframe-Matched Progress Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('ออมแล้ว', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(
                              '฿ ${Money.format(_currentSavings)}',
                              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('จากเป้าหมาย', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(
                              '฿ ${Money.format(targetVal)}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        height: 8,
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: const Color(0xFF1E293B),
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'เหลืออีก ฿ ${Money.format(remaining)}',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                        Text(
                          '${(progress * 100).toStringAsFixed(0)} %',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Target Amount Input Field
              TextFormField(
                controller: _targetController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'จำนวนเงินเป้าหมาย (บาท)',
                  labelStyle: const TextStyle(color: AppColors.textMuted),
                  prefixIcon: const Icon(Icons.monetization_on_outlined, color: AppColors.primary),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF1E293B)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF1E293B)),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'กรุณากรอกจำนวนเงิน';
                  if ((double.tryParse(val) ?? 0) <= 0) return 'จำนวนเงินต้องมากกว่า 0';
                  return null;
                },
                onChanged: (val) => setState(() {}),
              ),
              const SizedBox(height: 16),

              // Date Selector Tile
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFF1E293B)),
                ),
                tileColor: AppColors.surface,
                leading: const Icon(Icons.calendar_today_rounded, color: AppColors.primary),
                title: const Text('กำหนดระยะเวลา', style: TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: Text(
                  _selectedDate != null ? DateFormat('d MMM yyyy').format(_selectedDate!) : 'ไม่ได้กำหนดระยะเวลา',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate ?? DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (date != null) setState(() => _selectedDate = date);
                },
              ),
              const SizedBox(height: 16),

              // Type Selector Tile
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFF1E293B)),
                ),
                tileColor: AppColors.surface,
                leading: const Icon(Icons.outlined_flag_rounded, color: AppColors.primary),
                title: const Text('ประเภทเป้าหมาย', style: TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: Text(
                  _getTypeLabel(_selectedType),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                onTap: () => _showTypeSelectionDialog(),
              ),
              const SizedBox(height: 24),

              // AI Coach recommendation card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F3A22).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF0D6E37).withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primary,
                      child: Icon(Icons.android_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'พี่เงินขอแนะนำ',
                            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getAIRecommendationText(targetVal),
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Action Buttons Bottom Bar
              Row(
                children: [
                  if (isEdit) ...[
                    Expanded(
                      flex: 1,
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton(
                          onPressed: () => _deleteGoal(),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.expense),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text('ลบ', style: TextStyle(color: AppColors.expense, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => _saveGoal(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          isEdit ? 'ยืนยันการแก้ไข' : 'สร้างเป้าหมาย',
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getAIRecommendationText(int target) {
    if (target <= 0) return 'เริ่มออมเงินวันนี้เพื่อสร้างวินัยทางการเงินที่ดีกันครับ!';
    final monthly = ((target / 100) / 3).round();
    return 'มีเวลาอีก 3 เดือน ให้แบ่งเก็บเดือนละ ฿ ${NumberFormat('#,###').format(monthly)} ครับ';
  }

  void _showTypeSelectionDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
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
            ],
          ),
        );
      },
    );
  }

  void _saveGoal() {
    if (_formKey.currentState!.validate()) {
      final name = _nameController.text.trim();
      final target = int.parse(_targetController.text.trim()) * 100;

      if (widget.goalId != null) {
        ref.read(goalsProvider.notifier).updateGoal(widget.goalId!, name, target, _selectedDate, _selectedType, _selectedEmoji);
      } else {
        ref.read(goalsProvider.notifier).addGoal(name, target, _selectedDate, _selectedType, _selectedEmoji);
      }
      context.pop();
    }
  }

  void _deleteGoal() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('ลบเป้าหมาย', style: TextStyle(color: Colors.white)),
        content: const Text('ต้องการลบเป้าหมายการออมนี้ใช่หรือไม่?', style: TextStyle(color: AppColors.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              ref.read(goalsProvider.notifier).deleteGoal(widget.goalId!);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('ลบ', style: TextStyle(color: AppColors.expense)),
          ),
        ],
      ),
    );
  }
}