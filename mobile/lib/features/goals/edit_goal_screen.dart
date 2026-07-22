import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../privacy/privacy_screen.dart';
import '../settings/settings_screen.dart';
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

  // ตัวแปรเก็บไฟล์รูปภาพที่เลือก
  XFile? _selectedImageFile;
  final ImagePicker _picker = ImagePicker();

  final List<String> _emojiList = ['🏔️', '🏠', '🌴', '💻', '💍'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _targetController = TextEditingController();

    if (widget.goalId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final goal =
            ref.read(goalsProvider).firstWhere((g) => g.id == widget.goalId);
        setState(() {
          _nameController.text = goal.name;

          // เปลี่ยนจาก .round() เป็นเช็คทศนิยม เพื่อรองรับเงินที่เป็นเศษสตางค์ได้อย่างถูกต้อง
          _targetController.text = Money.format(goal.target);

          _selectedDate = goal.deadline;
          _startDate = goal.startDate;
          _endDate = goal.deadline;
          _selectedType = goal.type;
          _selectedEmoji = goal.emoji;
          if (goal.imagePath != null) {
            _selectedImageFile = XFile(goal.imagePath!);
          }
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

  // ฟังก์ชันสำหรับการเปิด Gallery เพื่อเลือกรูปภาพ
  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1000,
        maxHeight: 1000,
      );
      if (pickedFile != null) {
        // ส่งไฟล์ภาพไปยัง Crop Dialog ที่เขียนด้วย Flutter โดยตรง (หมดห่วงเรื่อง Error บน Web)
        _showCropDialog(pickedFile);
      }
    } catch (e) {
      debugPrint('เกิดข้อผิดพลาดในการเลือกรูปภาพ: $e');
    }
  }

  // หน้าต่างการครอป/ปรับตำแหน่งรูปภาพทรงกลมแบบ Interactive (รองรับ Web และ Mobile 100%)
  void _showCropDialog(XFile pickedFile) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        double scale = 1.0;
        final TransformationController transformController =
            TransformationController();

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1D222B),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              title: const Text(
                'ปรับแต่งตำแหน่งรูปภาพ',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // กรอบพรีวิวทรงกลมพร้อมเส้นกรอบเรืองแสงสีเขียวนีออนสุดพรีเมียม
                  Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: const Color(0xFF4CD97B), width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4CD97B).withOpacity(0.3),
                          blurRadius: 15,
                        )
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InteractiveViewer(
                      transformationController: transformController,
                      boundaryMargin: const EdgeInsets.all(100),
                      minScale: 0.5,
                      maxScale: 4.0,
                      onInteractionUpdate: (details) {
                        // อัปเดตตัวเลื่อน Slider อ้างอิงตามระดับการซูมจริง
                        setDialogState(() {
                          scale = transformController.value.getMaxScaleOnAxis();
                        });
                      },
                      child: kIsWeb
                          ? Image.network(pickedFile.path,
                              fit: BoxFit.cover, width: 220, height: 220)
                          : Image.file(File(pickedFile.path),
                              fit: BoxFit.cover, width: 220, height: 220),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'ใช้สองนิ้วจีบย่อ-ขยาย หรือลากเพื่อจัดตำแหน่งรูปภาพ',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  // แถบเลื่อนขยายซูมเพิ่มความละเอียดในการตั้งค่าภาพ
                  Slider(
                    value: scale.clamp(1.0, 4.0),
                    min: 1.0,
                    max: 4.0,
                    activeColor: const Color(0xFF4CD97B),
                    inactiveColor: Colors.white12,
                    onChanged: (val) {
                      setDialogState(() {
                        scale = val;
                        // ปรับระดับซูมตามตำแหน่งสไลเดอร์
                        final matrix = Matrix4.identity()..scale(val);
                        transformController.value = matrix;
                      });
                    },
                  ),
                ],
              ),
              actionsPadding:
                  const EdgeInsets.only(bottom: 20, left: 16, right: 16),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('ยกเลิก',
                            style: TextStyle(color: Colors.white54)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3CAE63),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          setState(() {
                            _selectedImageFile = pickedFile;
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('บันทึก',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  // คำนวณจำนวนเดือนจากช่วงวันที่ แล้วแปลงเป็นประเภทเป้าหมายอัตโนมัติ
  // 0-6 เดือน = ระยะสั้น, 6-12 เดือน = ระยะกลาง, มากกว่า 12 เดือน = ระยะยาว
  String _autoDetectGoalType(DateTime start, DateTime end) {
    final int months =
        ((end.year - start.year) * 12) + (end.month - start.month);
    if (months <= 6) {
      return 'short';
    } else if (months <= 12) {
      return 'medium';
    } else {
      return 'long';
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'short':
        return 'ระยะสั้น (0-6เดือน)';
      case 'medium':
        return 'ระยะกลาง (1ปี)';
      case 'long':
        return 'ระยะยาว (1 ปีขึ้นไป)';
      default:
        return 'ระยะสั้น (ภายใน 0-6 เดือน)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final moneySettings = ref.watch(
      appSettingsProvider.select((s) => (s.currency, s.usdRate)),
    );
    Money.configure(moneySettings.$1, thbToUsdRate: moneySettings.$2);
    final personalized =
        ref.watch(privacySettingsProvider).personalizedRecommendations;
    final goals = ref.watch(goalsProvider);
    final int currentSavings = widget.goalId != null
        ? (goals
            .firstWhere((g) => g.id == widget.goalId, orElse: () => goals.first)
            .current)
        : 0;

    // แก้ไขบัคตรงนี้: เปลี่ยนมาใช้ double.tryParse เพื่อไม่ให้ระบบเออร์เรอร์เวลาลบตัวเลขหรือใส่จุดทศนิยม
    final double bahtVal = double.tryParse(_targetController.text) ?? 0;
    final int targetVal = Money.toSatang(bahtVal);

    final int remaining = (targetVal - currentSavings).clamp(0, targetVal);
    final double progress =
        targetVal > 0 ? (currentSavings / targetVal).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF16191D),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // ส่วนหัว App Bar
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
                    'แก้ไขเป้าหมาย',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                        color: Colors.white,
                        letterSpacing: 0.5),
                  ),
                ],
              ),
            ),

            // ดีไซน์อัปโหลดรูปภาพ / เลือกไอคอน
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  SizedBox(
                    height: 140,
                    child: Center(
                      child: _selectedImageFile != null
                          ? GestureDetector(
                              onTap: _pickImage,
                              child: Container(
                                width: 124,
                                height: 124,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  image: DecorationImage(
                                    image: kIsWeb
                                        ? NetworkImage(_selectedImageFile!.path)
                                        : FileImage(
                                                File(_selectedImageFile!.path))
                                            as ImageProvider,
                                    fit: BoxFit.cover,
                                  ),
                                  border: Border.all(
                                      color: const Color(0xFF4CD97B), width: 3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF4CD97B)
                                          .withOpacity(0.4),
                                      blurRadius: 25,
                                      spreadRadius: 6,
                                    )
                                  ],
                                ),
                              ),
                            )
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 40),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: _emojiList.map((emoji) {
                                  final isSelected = _selectedEmoji == emoji;
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedEmoji = emoji;
                                        _selectedImageFile = null;
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 250),
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 8),
                                      width: isSelected ? 124 : 80,
                                      height: isSelected ? 124 : 80,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isSelected
                                            ? null
                                            : const Color(0xFF22272F),
                                        gradient: isSelected
                                            ? const LinearGradient(
                                                colors: [
                                                  Color(0xFFE2F1FC),
                                                  Color(0xFFBDD7EE)
                                                ],
                                              )
                                            : null,
                                        border: isSelected
                                            ? Border.all(
                                                color: const Color(0xFF4CD97B),
                                                width: 3)
                                            : Border.all(
                                                color: Colors.white12,
                                                width: 1.5),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: const Color(0xFF4CD97B)
                                                      .withOpacity(0.4),
                                                  blurRadius: 25,
                                                  spreadRadius: 6,
                                                )
                                              ]
                                            : [],
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        emoji,
                                        style: TextStyle(
                                            fontSize: isSelected ? 56 : 38),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ปุ่มแก้ไขรูปภาพ
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 8),
                          decoration: BoxDecoration(
                              color: const Color(0xFF22272F),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                )
                              ]),
                          child: Row(
                            children: [
                              const Icon(Icons.add_a_photo_rounded,
                                  color: Color(0xFF4CD97B), size: 20),
                              const SizedBox(width: 8),
                              Text(
                                _selectedImageFile != null
                                    ? 'ครอป / เปลี่ยนรูปภาพ'
                                    : 'อัปโหลดและครอปรูปภาพ',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'ปรับแต่งและครอปรูปภาพให้เป็นทรงกลมพรีเมียมได้ทันที',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.4), fontSize: 13),
                  ),
                  const SizedBox(height: 20),

                  // ฟอร์มข้อมูลหลัก
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. ช่องกรอกชื่อเป้าหมาย
                          Text(
                            'ชื่อเป้าหมายของคุณ',
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
                                onPressed: () => _nameController.clear(),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 16),
                              hintText: 'กรอกชื่อเป้าหมายใหม่...',
                              hintStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.25)),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                    color: Color(0xFF4CD97B), width: 1.5),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide:
                                    const BorderSide(color: Colors.white10),
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
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'กรุณากรอกชื่อเป้าหมายก่อนบันทึก';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),

                          // 2. ช่องกรอกเงินตั้งเป้าหมาย
                          Text(
                            'เงินตั้งเป้าหมายทั้งหมด',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 14,
                                fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _targetController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
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
                              hintText: 'ตั้งเป้าหมายจำนวนเงิน...',
                              hintStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.25)),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                    color: Color(0xFF4CD97B), width: 1.5),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide:
                                    const BorderSide(color: Colors.white10),
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
                              // แก้ไขบัคตรงนี้: ปรับมาตรวจเช็คด้วย double.tryParse เพื่อป้องกัน Error ตอนกรอกเลขหรือจุดทศนิยม
                              if (value == null ||
                                  double.tryParse(value) == null ||
                                  double.parse(value) <= 0) {
                                return 'กรุณากรอกจำนวนเงินเป้าหมายที่มากกว่า 0';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ส่วนความคืบหน้า (Progress Indicator)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      if (widget.goalId == null) return;
                      context.push('/goals/deposit?id=${widget.goalId}');
                    },
                    child: Container(
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
                              Text('ออมแล้ว',
                                  style: TextStyle(
                                      color: Color(0xAAFFFFFF),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500)),
                              Text('จากเป้าหมายทั้งหมด',
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
                                Money.formatBaht(currentSavings),
                                style: const TextStyle(
                                    color: Color(0xFF4CD97B),
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
                                    '${(progress * 100).toStringAsFixed(0)} %',
                                    style: const TextStyle(
                                        color: Color(0xFF4CD97B),
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              height: 8,
                              child: LinearProgressIndicator(
                                value: progress,
                                backgroundColor: Colors.white.withOpacity(0.12),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    Color(0xFF3CAE63)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  _buildMenuRowCard(
                    icon: Icons.calendar_month_rounded,
                    title: 'กำหนดระยะเวลา',
                    subtitle: _startDate != null && _endDate != null
                        ? "${DateFormat('d MMMM', 'th').format(_startDate!)} - ${DateFormat('d MMMM yyyy', 'th').format(_endDate!)}"
                        : 'เลือกกำหนดระยะเวลา',
                    onTap: () async {
                      final Map<String, DateTime?>? result =
                          await context.push<Map<String, DateTime?>>(
                        '/goals/duration',
                        extra: {'startDate': _startDate, 'endDate': _endDate},
                      );
                      if (result != null) {
                        setState(() {
                          _startDate = result['startDate'];
                          _endDate = result['endDate'];
                          _selectedDate = result['endDate'];
                          // ให้ระบบเลือกประเภทเป้าหมายให้อัตโนมัติตามระยะเวลาที่เลือก
                          if (_startDate != null && _endDate != null) {
                            _selectedType =
                                _autoDetectGoalType(_startDate!, _endDate!);
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  _buildMenuRowCard(
                    icon: Icons.flag_rounded,
                    title: 'ประเภทเป้าหมาย',
                    subtitle: _getTypeLabel(_selectedType),
                    onTap: () => _showTypeSelectionBottomSheet(),
                  ),
                  const SizedBox(height: 24),

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

                  // AI Smart Assistant Card
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
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      fontSize: 15),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'มีเวลาอีก 3 เดือน ให้แบ่งเก็บเดือนละ ${Money.formatBaht(100000)}',
                                  style: TextStyle(
                                      color: Colors.white.withOpacity(0.5),
                                      fontSize: 13),
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

                  // ปุ่มลบ และ ยืนยันการแก้ไข
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            onPressed: () => _deleteGoal(),
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
                            onPressed: () => _saveGoal(),
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

  void _showTypeSelectionBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1D222B),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 22),
                child: Text('เลือกประเภทเป้าหมาย',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: Colors.white)),
              ),
              ListTile(
                title: const Text('ระยะสั้น (ภายใน 0-12 เดือน)',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  setState(() => _selectedType = 'short');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('ระยะกลาง (1 ปี)',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  setState(() => _selectedType = 'medium');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('ระยะยาว (1 ปีขึ้นไป)',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  setState(() => _selectedType = 'long');
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _saveGoal() {
    if (_formKey.currentState!.validate()) {
      final name = _nameController.text.trim();

      // แก้ไขบัคตรงนี้: แปลงค่าเป็น double ก่อนแล้วค่อยคูณ 100 เพื่อเซฟหน่วยสตางค์เข้า Database/Provider ได้อย่างเสถียร
      final double bahtVal = double.tryParse(_targetController.text) ?? 0;
      final int targetVal = Money.toSatang(bahtVal);

      final imagePath = _selectedImageFile?.path;

      if (widget.goalId != null) {
        ref.read(goalsProvider.notifier).updateGoal(
              widget.goalId!,
              name,
              targetVal,
              _selectedDate,
              _selectedType,
              _selectedEmoji,
              imagePath,
              startDate: _startDate,
            );
      } else {
        ref.read(goalsProvider.notifier).addGoal(
              name,
              targetVal,
              _selectedDate,
              _selectedType,
              _selectedEmoji,
              imagePath,
              startDate: _startDate,
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
