import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// คู่มือสั้น ๆ ประจำหน้า — เด้งครั้งแรกที่ผู้ใช้เปิดหน้านั้น ๆ
/// (หน้าหลัก "/" ใช้ทัวร์ชี้ปุ่มแบบ coach mark แทน จึงไม่มีในนี้)
class PageGuide {
  const PageGuide({
    required this.title,
    required this.icon,
    required this.tips,
  });

  final String title;
  final IconData icon;

  /// ข้อละบรรทัด สั้นที่สุดเท่าที่จะสั้นได้ (ผู้ใช้ไม่ต้องอ่านเยอะ)
  final List<String> tips;
}

const Map<String, PageGuide> kPageGuides = {
  // ── การเงินภาพรวม ────────────────────────────────────────────────────────
  '/financial-dashboard': PageGuide(
    title: 'แดชบอร์ดการเงิน',
    icon: Icons.trending_up_rounded,
    tips: [
      'ดูสรุปรายรับ-รายจ่ายเป็นกราฟ',
      'แตะที่แท่ง/วงกลมเพื่อดูรายละเอียดหมวดนั้น',
      'เลื่อนเปลี่ยนช่วงเวลาได้ (วัน/เดือน/ปี)',
    ],
  ),
  '/predictions': PageGuide(
    title: 'พยากรณ์การเงิน',
    icon: Icons.auto_graph_rounded,
    tips: [
      'AI คาดการณ์เงินคงเหลือ 30 วันข้างหน้า',
      'เส้นจาง ๆ คือช่วงที่อาจคลาดเคลื่อน',
      'ยิ่งบันทึกรายการมาก ยิ่งแม่นขึ้น',
    ],
  ),

  // ── บันทึกเงิน ───────────────────────────────────────────────────────────
  '/slip': PageGuide(
    title: 'บันทึกรายรับ-รายจ่าย',
    icon: Icons.document_scanner_outlined,
    tips: [
      'แนบรูปสลิป → ระบบอ่านยอด/วันที่/ร้านให้อัตโนมัติ',
      'เลือกก่อนว่าเป็น "รายรับ" หรือ "รายจ่าย"',
      'ไม่มีสลิปก็กรอกเองได้ ตรวจแล้วกดบันทึก',
    ],
  ),
  '/transactions/select-date': PageGuide(
    title: 'เลือกวันที่',
    icon: Icons.event_rounded,
    tips: [
      'แตะวันที่ต้องการบนปฏิทิน',
      'เลื่อนซ้าย-ขวาเพื่อเปลี่ยนเดือน',
    ],
  ),

  // ── แชท AI ───────────────────────────────────────────────────────────────
  '/chat': PageGuide(
    title: 'คุยกับพี่เงิน',
    icon: Icons.chat_bubble_rounded,
    tips: [
      'พิมพ์สั้น ๆ เช่น "กาแฟ 50" → พี่เงินจดให้ทันที',
      'ส่งรูปสลิปเข้ามาก็บันทึกให้ได้',
      'ถามได้ เช่น "เดือนนี้ใช้ไปเท่าไหร่" หรือ "ออมเงินยังไงดี"',
      'กดไมค์เพื่อพูดแทนพิมพ์ได้',
    ],
  ),

  // ── งบประมาณ ─────────────────────────────────────────────────────────────
  '/budgets': PageGuide(
    title: 'งบประมาณ',
    icon: Icons.pie_chart_rounded,
    tips: [
      'ตั้งงบแต่ละหมวด เช่น อาหาร 3,000 บาท/เดือน',
      'สีบอกสถานะ: เขียว = ปลอดภัย · แดง = เกินงบ',
      'ระบบจะเตือนอัตโนมัติเมื่อใช้ถึง 80%',
    ],
  ),
  '/budgets/edit': PageGuide(
    title: 'แก้ไขงบ',
    icon: Icons.edit_rounded,
    tips: [
      'ปรับจำนวนเงินของหมวดนี้',
      'กดบันทึกเพื่อยืนยัน',
    ],
  ),
  '/budgets/amount': PageGuide(
    title: 'ตั้งจำนวนงบ',
    icon: Icons.payments_rounded,
    tips: [
      'ใส่จำนวนเงินที่ตั้งใจใช้ไม่เกินในหมวดนี้',
      'ปรับแก้ทีหลังได้ตลอด',
    ],
  ),
  '/budgets/duration': PageGuide(
    title: 'ช่วงเวลาของงบ',
    icon: Icons.date_range_rounded,
    tips: [
      'เลือกว่างบนี้นับตั้งแต่วันไหนถึงวันไหน',
      'ปกติใช้แบบรายเดือน',
    ],
  ),

  // ── เป้าหมายออม ──────────────────────────────────────────────────────────
  '/goals': PageGuide(
    title: 'เป้าหมายการออม',
    icon: Icons.flag_rounded,
    tips: [
      'ตั้งเป้า เช่น เก็บเงินซื้อโน้ตบุ๊ก 30,000 บาท',
      'แถบสีบอกความคืบหน้าว่าเก็บได้กี่ %',
      'กด "ฝากเงิน" เพื่อเพิ่มเงินเข้าเป้าหมาย',
    ],
  ),
  '/goals/add': PageGuide(
    title: 'สร้างเป้าหมายใหม่',
    icon: Icons.add_task_rounded,
    tips: [
      'ตั้งชื่อเป้า + จำนวนเงินที่ต้องการ',
      'ใส่วันครบกำหนด แล้วระบบคำนวณให้ว่าต้องเก็บเดือนละเท่าไหร่',
    ],
  ),
  '/goals/edit': PageGuide(
    title: 'แก้ไขเป้าหมาย',
    icon: Icons.edit_note_rounded,
    tips: [
      'ปรับชื่อ จำนวนเงิน หรือวันครบกำหนดได้',
      'ลบเป้าหมายได้จากปุ่มถังขยะ',
    ],
  ),
  '/goals/deposit': PageGuide(
    title: 'ฝากเงินเข้าเป้าหมาย',
    icon: Icons.savings_rounded,
    tips: [
      'ใส่จำนวนเงินที่เก็บได้ครั้งนี้',
      'ความคืบหน้าจะอัปเดตทันที',
    ],
  ),
  '/goals/duration': PageGuide(
    title: 'กำหนดระยะเวลา',
    icon: Icons.schedule_rounded,
    tips: [
      'เลือกวันเริ่มและวันที่อยากเก็บครบ',
      'ยิ่งเวลานาน ยอดต่อเดือนยิ่งน้อยลง',
    ],
  ),

  // ── บัญชี/ตั้งค่า ────────────────────────────────────────────────────────
  '/menu': PageGuide(
    title: 'เมนูรวม',
    icon: Icons.grid_view_rounded,
    tips: [
      'ทางเข้าบัญชีผู้ใช้ ตั้งค่า และความเป็นส่วนตัว',
      'กด "วิธีใช้งาน" เพื่อดูคำแนะนำหน้าหลักอีกครั้ง',
    ],
  ),
  '/profile': PageGuide(
    title: 'บัญชีผู้ใช้',
    icon: Icons.person_rounded,
    tips: [
      'ดูแต้มสะสมและระดับ (Bronze/Silver/Gold)',
      'ได้แต้มจากการเข้าใช้ทุกวันและบันทึกรายการ',
    ],
  ),
  '/profile/edit': PageGuide(
    title: 'แก้ไขโปรไฟล์',
    icon: Icons.manage_accounts_rounded,
    tips: [
      'เปลี่ยนชื่อ รูป และรายได้ต่อเดือน',
      'ใส่รายได้ให้ถูก เพื่อให้พยากรณ์แม่นขึ้น',
    ],
  ),
  '/settings': PageGuide(
    title: 'การตั้งค่า',
    icon: Icons.settings_rounded,
    tips: [
      'เปิด/ปิดการแจ้งเตือน เสียง และการสั่น',
      'เปลี่ยนสกุลเงินที่ใช้แสดงผลได้',
    ],
  ),
  '/privacy': PageGuide(
    title: 'ความเป็นส่วนตัว',
    icon: Icons.lock_rounded,
    tips: [
      'เลือกได้ว่าจะให้ AI ใช้ข้อมูลการเงินช่วยวิเคราะห์ไหม',
      'เปิดล็อกด้วยลายนิ้วมือ/ใบหน้าได้',
    ],
  ),
  '/subscriptions': PageGuide(
    title: 'ค่าสมาชิกรายเดือน',
    icon: Icons.receipt_long_rounded,
    tips: [
      'รวมรายจ่ายประจำ เช่น Netflix, Spotify',
      'ระบบเตือนล่วงหน้าก่อนถูกตัดเงิน',
    ],
  ),
  '/notifications': PageGuide(
    title: 'การแจ้งเตือน',
    icon: Icons.notifications_rounded,
    tips: [
      'รวมเตือนงบใกล้เกิน บิลใกล้ครบ และรายจ่ายผิดปกติ',
      'แตะรายการเพื่อดูรายละเอียด',
    ],
  ),
};

/// เด้งคู่มือของหน้านี้ถ้ายังไม่เคยดู — เรียกจากตัวดักเปลี่ยนหน้าใน main.dart
Future<void> maybeShowPageGuide(BuildContext context, String location) async {
  final guide = kPageGuides[location];
  if (guide == null) return;

  final prefs = await SharedPreferences.getInstance();
  final key = 'guide_$location';
  if (prefs.getBool(key) ?? false) return;
  await prefs.setBool(key, true);

  // รอให้หน้าวาดเสร็จก่อน ผู้ใช้จะได้เห็นของจริงเป็นพื้นหลัง
  await Future<void>.delayed(const Duration(milliseconds: 550));
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _GuideSheet(guide: guide),
  );
}

/// ล้างประวัติ "เคยดูคู่มือแล้ว" ทุกหน้า (ใช้กับปุ่ม "วิธีใช้งาน" ในเมนู)
Future<void> resetAllPageGuides() async {
  final prefs = await SharedPreferences.getInstance();
  for (final k in prefs.getKeys().where((k) => k.startsWith('guide_')).toList()) {
    await prefs.remove(k);
  }
}

class _GuideSheet extends StatelessWidget {
  const _GuideSheet({required this.guide});
  final PageGuide guide;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
      decoration: const BoxDecoration(
        color: Color(0xFF16202E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ขีดจับลาก
            Center(
              child: Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3CAE63).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(guide.icon,
                      color: const Color(0xFF4CD97B), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    guide.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...guide.tips.map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 11),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 3),
                      child: Icon(Icons.check_circle_rounded,
                          color: Color(0xFF4CD97B), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        t,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3CAE63),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('เข้าใจแล้ว',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
