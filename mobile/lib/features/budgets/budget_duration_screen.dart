import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';

class BudgetDurationScreen extends StatefulWidget {
  const BudgetDurationScreen({super.key});

  @override
  State<BudgetDurationScreen> createState() => _BudgetDurationScreenState();
}

class _BudgetDurationScreenState extends State<BudgetDurationScreen> {
  // ปฏิทินจริง — อิงเดือน/ปีปัจจุบัน เปลี่ยนเดือนได้ เลือกวันได้
  late DateTime _visibleMonth;
  late int _selectedDay;

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June', //
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
    _selectedDay = now.day;
  }

  int get _daysInMonth =>
      DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
      if (_selectedDay > _daysInMonth) _selectedDay = _daysInMonth;
    });
  }

  @override
  Widget build(BuildContext context) {
    // ช่องว่างก่อนวันที่ 1 (สัปดาห์เริ่มวันจันทร์: DateTime.weekday 1=Mon..7=Sun)
    final leadingBlanks =
        DateTime(_visibleMonth.year, _visibleMonth.month, 1).weekday - 1;
    final daysInMonth = _daysInMonth;
    final totalCells = ((leadingBlanks + daysInMonth) / 7).ceil() * 7;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        centerTitle: true,
        title: const Text('กำหนดระยะเวลา',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
          onPressed: () {
            if (Navigator.of(context).canPop() || context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Header Icon
            Center(
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 10,
                    )
                  ],
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
                child: const Center(
                  child: Text('🏝️', style: TextStyle(fontSize: 48)),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Calendar Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1C),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Column(
                children: [
                  // Month/Year selector — เปลี่ยนเดือนได้จริงด้วยลูกศรซ้าย/ขวา
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => _changeMonth(-1),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFF262626),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.chevron_left,
                              color: Colors.white, size: 20),
                        ),
                      ),
                      Text(
                        '${_monthNames[_visibleMonth.month - 1]} ${_visibleMonth.year}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                      GestureDetector(
                        onTap: () => _changeMonth(1),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFF262626),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.chevron_right,
                              color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Days of week
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text('Mo',
                          style: TextStyle(
                              color: Colors.white54,
                              fontWeight: FontWeight.bold)),
                      Text('Tu',
                          style: TextStyle(
                              color: Colors.white54,
                              fontWeight: FontWeight.bold)),
                      Text('We',
                          style: TextStyle(
                              color: Colors.white54,
                              fontWeight: FontWeight.bold)),
                      Text('Th',
                          style: TextStyle(
                              color: Colors.white54,
                              fontWeight: FontWeight.bold)),
                      Text('Fr',
                          style: TextStyle(
                              color: Colors.white54,
                              fontWeight: FontWeight.bold)),
                      Text('Sa',
                          style: TextStyle(
                              color: Colors.white54,
                              fontWeight: FontWeight.bold)),
                      Text('Su',
                          style: TextStyle(
                              color: Colors.white54,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Calendar grid — วันจริงของเดือนที่เลือก
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemCount: totalCells,
                    itemBuilder: (context, index) {
                      final day = index - leadingBlanks + 1;
                      if (day < 1 || day > daysInMonth) {
                        return const SizedBox.shrink();
                      }
                      final isSelected = day == _selectedDay;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedDay = day),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : const Color(0xFF262626),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '$day',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Next Button
            SizedBox(
              width: 160,
              child: ElevatedButton(
                onPressed: () => context.pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('ต่อไป',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
