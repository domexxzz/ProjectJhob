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
  String _selectedType = 'short'; // short | medium | long
  String _selectedEmoji = '🎯';
  int _currentSavings = 0;

  final List<String> _emojis = ['🌴', '🔌', '🛡️', '🚗', '🏠', '✈️', '🎓', '🎮', '💍', '💰', '📈', '🍔'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _targetController = TextEditingController();

    if (widget.goalId != null) {
      // Load existing goal
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
    final double progress = targetVal > 0 ? (_currentSavings / targetVal).clamp(0.0, 1.0) : 1.0;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          isEdit ? 'แก้ไขเป้าหมาย' : 'เพิ่มเป้าหมาย',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Emoji Circle Preview with Glow
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(0.1),
                  border: Border.all(color: AppColors.primary, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  _selectedEmoji,
                  style: const TextStyle(fontSize: 48),
                ),
              ),
              const SizedBox(height: 12),
              // Emoji selection grid
              SizedBox(
                height: 48,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _emojis.length,
                  itemBuilder: (context, index) {
                    final em = _emojis[index];
                    final isSelected = em == _selectedEmoji;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedEmoji = em),
                        child: Container(
                          padding: const EdgeInsets.all(8),
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
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              // Title / Name Input
              TextFormField(
                controller: _nameController,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
                decoration: const InputDecoration(
                  hintText: 'ตั้งเป้าหมาย',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  fillColor: Colors.transparent,
                  suffixIcon: Icon(Icons.edit, color: AppColors.textMuted, size: 18),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'กรุณากรอกชื่อเป้าหมาย' : null,
                onChanged: (val) => setState(() {}),
              ),
              const SizedBox(height: 24),

              // Progress Card (Matching Wireframe)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
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
                              '${Money.format(_currentSavings)} ฿',
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
                              Money.format(targetVal),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Progress Bar
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
                          'เหลืออีก ${Money.format(remaining)}',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                        ),
                        Text(
                          '${(progress * 100).toStringAsFixed(0)} %',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Form fields
              TextFormField(
                controller: _targetController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'จำนวนเงินเป้าหมาย (บาท)',
                  prefixIcon: Icon(Icons.monetization_on_outlined),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'กรุณากรอกเป้าหมาย';
                  final amt = double.tryParse(val) ?? 0;
                  if (amt <= 0) return 'เป้าหมายต้องมากกว่า 0';
                  return null;
                },
                onChanged: (val) => setState(() {}),
              ),
              const SizedBox(height: 16),

              // Target date tile
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFF1E293B)),
                ),
                tileColor: AppColors.surface,
                leading: const Icon(Icons.calendar_today_rounded, color: AppColors.primary),
                title: const Text('กำหนดระยะเวลา', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(
                  _selectedDate != null
                      ? DateFormat('d ธ.ค. yyyy').format(_selectedDate!) // Using Thai format placeholder style
                      : 'ยังไม่ได้กำหนดระยะเวลา',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate ?? DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (date != null) {
                    setState(() => _selectedDate = date);
                  }
                },
              ),
              const SizedBox(height: 16),

              // Goal Type tile
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFF1E293B)),
                ),
                tileColor: AppColors.surface,
                leading: const Icon(Icons.outlined_flag_rounded, color: AppColors.primary),
                title: const Text('ประเภทเป้าหมาย', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(
                  _getTypeLabel(_selectedType),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
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
                    Image.asset(
                      'assets/coach_avatar.png', // Fallback or placeholder icon
                      width: 48,
                      height: 48,
                      errorBuilder: (context, _, __) => const CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.primary,
                        child: Icon(Icons.android_rounded, color: Colors.white),
                      ),
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
                    const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Bottom Button bar
              Row(
                children: [
                  if (isEdit) ...[
                    Expanded(
                      flex: 1,
                      child: ElevatedButton(
                        onPressed: () => _deleteGoal(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.expense,
                        ),
                        child: const Text('ลบ'),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () => _saveGoal(),
                      child: const Text('ยืนยันการแก้ไข'),
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
    return 'มีเวลาอีก 3 เดือน ให้แบ่งเก็บเดือนละ $monthly บาท';
  }

  void _showTypeSelectionDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'เลือกประเภทเป้าหมาย',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              ListTile(
                title: const Text('ระยะสั้น (ภายใน 1 ปี)'),
                onTap: () {
                  setState(() => _selectedType = 'short');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('ระยะกลาง (1 - 3 ปี)'),
                onTap: () {
                  setState(() => _selectedType = 'medium');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('ระยะยาว (3 ปีขึ้นไป)'),
                onTap: () {
                  setState(() => _selectedType = 'long');
                  Navigator.pop(context);
                },
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
        ref.read(goalsProvider.notifier).updateGoal(
              widget.goalId!,
              name,
              target,
              _selectedDate,
              _selectedType,
              _selectedEmoji,
            );
      } else {
        ref.read(goalsProvider.notifier).addGoal(
              name,
              target,
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
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('ลบเป้าหมาย'),
          content: const Text('ต้องการลบเป้าหมายการออมนี้ใช่หรือไม่?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก', style: TextStyle(color: AppColors.textMuted)),
            ),
            TextButton(
              onPressed: () {
                ref.read(goalsProvider.notifier).deleteGoal(widget.goalId!);
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Return to list
              },
              child: const Text('ลบ', style: TextStyle(color: AppColors.expense)),
            ),
          ],
        ),
      );
    }
  }
}
