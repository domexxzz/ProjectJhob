import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class SetDeadlineScreen extends StatefulWidget {
  const SetDeadlineScreen({super.key, this.initialStartDate, this.initialEndDate});

  final DateTime? initialStartDate;
  final DateTime? initialEndDate;

  @override
  State<SetDeadlineScreen> createState() => _SetDeadlineScreenState();
}

class _SetDeadlineScreenState extends State<SetDeadlineScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  // รายชื่อเดือนภาษาไทยสำหรับ Dropdown
  final List<String> _monthsTh = [
    'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
    'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม'
  ];

  @override
  void initState() {
    super.initState();
    _rangeStart = widget.initialStartDate ?? DateTime.now();
    _rangeEnd = widget.initialEndDate ?? DateTime.now().add(const Duration(days: 90));
    _focusedDay = _rangeStart ?? DateTime.now();
  }

  // คำนวณหาจำนวนเดือนระหว่างช่วงที่เลือกมาแสดงใน Timeline
  int _calculateMonthsDifference(DateTime start, DateTime end) {
    return ((end.year - start.year) * 12) + end.month - start.month;
  }

  @override
  Widget build(BuildContext context) {
    final kToday = DateTime.now();
    final kFirstDay = DateTime(kToday.year - 5, kToday.month, kToday.day);
    final kLastDay = DateTime(kToday.year + 10, kToday.month, kToday.day);

    // สร้างลิสต์ปี ค.ศ. สำหรับ Dropdown (ย้อนหลัง 5 ปี - ล่วงหน้า 10 ปี)
    final List<int> _yearsList = List.generate(16, (index) => kToday.year - 5 + index);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'กำหนดระยะเวลา',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),

          // 🔽 ส่วน Dropdown เลือกเดือนและปี (Header ของปฏิทินตามรูปดีไซน์)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                // Dropdown เลือกเดือน
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _focusedDay.month,
                        dropdownColor: const Color(0xFF1A1A1A),
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white60),
                        items: List.generate(12, (index) {
                          return DropdownMenuItem(
                            value: index + 1,
                            child: Text(_monthsTh[index]),
                          );
                        }),
                        onChanged: (month) {
                          if (month != null) {
                            setState(() {
                              _focusedDay = DateTime(_focusedDay.year, month, 1);
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Dropdown เลือกปี
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _focusedDay.year,
                        dropdownColor: const Color(0xFF1A1A1A),
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white60),
                        items: _yearsList.map((year) {
                          return DropdownMenuItem(
                            value: year,
                            child: Text('พ.ศ. ${year + 543}'), // แสดงผลเป็นปี พ.ศ. ให้สวยงามตามรูปแบบไทย
                          );
                        }).toList(),
                        onChanged: (year) {
                          if (year != null) {
                            setState(() {
                              _focusedDay = DateTime(year, _focusedDay.month, 1);
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 🗓️ ตัวปฏิทินแสดงผลผูกตาม Dropdown
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            padding: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: TableCalendar(
              locale: 'th_TH',
              firstDay: kFirstDay,
              lastDay: kLastDay,
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              rangeStartDay: _rangeStart,
              rangeEndDay: _rangeEnd,
              rangeSelectionMode: RangeSelectionMode.enforced,
              headerVisible: false, // ปิด Header เดิมเพื่อใช้ Dropdown ด้านบนแทน
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle: TextStyle(color: Colors.white38, fontSize: 13),
                weekendStyle: TextStyle(color: Colors.white38, fontSize: 13),
              ),
              calendarStyle: CalendarStyle(
                isTodayHighlighted: true,
                outsideDaysVisible: false,
                defaultTextStyle: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
                weekendTextStyle: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
                todayDecoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                rangeStartDecoration: const BoxDecoration(
                  color: Color(0xFF3CAE63),
                  shape: BoxShape.circle,
                ),
                rangeStartTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                rangeEndDecoration: const BoxDecoration(
                  color: Color(0xFF3CAE63),
                  shape: BoxShape.circle,
                ),
                rangeEndTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                rangeHighlightColor: const Color(0xFF3CAE63).withOpacity(0.15),
                withinRangeTextStyle: const TextStyle(color: Color(0xFF4CD97B)),
              ),
              onRangeSelected: (start, end, focusedDay) {
                setState(() {
                  _rangeStart = start;
                  _rangeEnd = end;
                  _focusedDay = focusedDay;
                });
              },
            ),
          ),

          // 🌲 ส่วนแสดงผล Timeline ด้านล่าง (อิงข้อมูลจริงจากปฏิทินที่เลือกสำเร็จ)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ไทม์ไลน์เป้าหมายของคุณ',
                    style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 16),
                  
                  // บล็อก Timeline ขั้นตอนที่ 1 (วันเริ่ม)
                  _buildTimelineStep(
                    isFirst: true,
                    isLast: false,
                    title: 'เริ่มต้นการออมเป้าหมาย',
                    dateText: _rangeStart != null ? DateFormat('d MMMM yyyy', 'th').format(_rangeStart!) : '-',
                    iconColor: const Color(0xFF3CAE63),
                  ),

                  // บล็อก Timeline ขั้นตอนกลาง (สรุประยะเวลาเดือน)
                  if (_rangeStart != null && _rangeEnd != null)
                    _buildTimelineStep(
                      isFirst: false,
                      isLast: false,
                      title: 'ระยะเวลาเก็บออมทั้งหมด',
                      dateText: '${_calculateMonthsDifference(_rangeStart!, _rangeEnd!)} เดือน',
                      iconColor: Colors.white30,
                      customIcon: Icons.timelapse_rounded,
                    ),

                  // บล็อก Timeline ขั้นตอนสุดท้าย (วันสิ้นสุด)
                  _buildTimelineStep(
                    isFirst: false,
                    isLast: true,
                    title: 'เป้าหมายสำเร็จสมบูรณ์ 🎉',
                    dateText: _rangeEnd != null ? DateFormat('d MMMM yyyy', 'th').format(_rangeEnd!) : 'กำลังเลือกวันสิ้นสุด...',
                    iconColor: const Color(0xFF4CD97B),
                  ),
                ],
              ),
            ),
          ),

          // 💾 ปุ่มบันทึกส่งข้อมูลกลับไปหน้า edit goal
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            child: ElevatedButton(
              onPressed: () {
                context.pop({
                  'startDate': _rangeStart,
                  'endDate': _rangeEnd,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3CAE63),
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text(
                'บันทึกระยะเวลานี้',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget ช่วยวาดเส้นโครงสร้างลำดับเหตุการณ์ Timeline
  Widget _buildTimelineStep({
    required bool isFirst,
    required bool isLast,
    required String title,
    required String dateText,
    required Color iconColor,
    IconData? customIcon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: iconColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white12, width: 2),
              ),
              child: customIcon != null 
                  ? Icon(customIcon, size: 10, color: Colors.black) 
                  : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 45,
                color: Colors.white10,
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                dateText,
                style: const TextStyle(color: Color(0xFF4CD97B), fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }
}