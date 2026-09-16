import 'package:flutter/material.dart';

/// 1 ขั้นของทัวร์แนะนำการใช้งาน — ชี้ไปที่ปุ่มจริงบนหน้าจอ
class CoachStep {
  const CoachStep({
    required this.title,
    required this.body,
    required this.icon,
    this.targetKey,
    this.circle = false,
  });

  /// widget ที่จะไฮไลต์ (null = แสดงกลางจอ ไม่เจาะรู)
  final GlobalKey? targetKey;
  final String title;
  final String body;
  final IconData icon;

  /// true = เจาะรูเป็นวงกลม (เช่นปุ่ม + ), false = สี่เหลี่ยมมุมมน
  final bool circle;
}

/// เปิดทัวร์แนะนำ — ทับหน้าจอเดิม (ยังเห็นของจริงข้างหลัง)
Future<void> showCoachTour(BuildContext context, List<CoachStep> steps) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, __, ___) => _CoachTourOverlay(steps: steps),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ),
  );
}

class _CoachTourOverlay extends StatefulWidget {
  const _CoachTourOverlay({required this.steps});
  final List<CoachStep> steps;

  @override
  State<_CoachTourOverlay> createState() => _CoachTourOverlayState();
}

class _CoachTourOverlayState extends State<_CoachTourOverlay> {
  int _i = 0;

  void _next() {
    if (_i >= widget.steps.length - 1) {
      Navigator.of(context).pop();
    } else {
      setState(() => _i++);
    }
  }

  void _skip() => Navigator.of(context).pop();

  /// หาตำแหน่งจริงของ widget เป้าหมายบนหน้าจอ
  Rect? _targetRect(CoachStep step) {
    final ctx = step.targetKey?.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    final origin = box.localToGlobal(Offset.zero);
    return origin & box.size;
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_i];
    final screen = MediaQuery.of(context).size;
    final safeTop = MediaQuery.of(context).padding.top;
    final raw = _targetRect(step);

    // เผื่อขอบรอบเป้าหมายให้ดูโปร่ง
    final hole = raw == null
        ? null
        : Rect.fromLTRB(
            (raw.left - 8).clamp(0.0, screen.width),
            (raw.top - 8).clamp(0.0, screen.height),
            (raw.right + 8).clamp(0.0, screen.width),
            (raw.bottom + 8).clamp(0.0, screen.height),
          );

    // การ์ดคำอธิบาย: ถ้าเป้าหมายอยู่ครึ่งล่าง → วางการ์ดไว้ด้านบน (และกลับกัน)
    final targetBelowMiddle = hole == null || hole.center.dy > screen.height / 2;
    const cardH = 190.0;
    final double cardTop = hole == null
        ? (screen.height - cardH) / 2
        : targetBelowMiddle
            ? (hole.top - cardH - 16).clamp(safeTop + 12, screen.height - cardH)
            : (hole.bottom + 16).clamp(safeTop + 12, screen.height - cardH - 12);

    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _next, // แตะตรงไหนก็ไปขั้นถัดไป
        child: Stack(
          children: [
            // ฉากมืด + เจาะรูตรงปุ่มที่กำลังอธิบาย
            Positioned.fill(
              child: CustomPaint(
                painter: _SpotlightPainter(hole: hole, circle: step.circle),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              top: cardTop,
              child: _StepCard(
                step: step,
                index: _i,
                total: widget.steps.length,
                onNext: _next,
                onSkip: _skip,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.step,
    required this.index,
    required this.total,
    required this.onNext,
    required this.onSkip,
  });

  final CoachStep step;
  final int index;
  final int total;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final isLast = index == total - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF16202E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF3CAE63).withValues(alpha: 0.5)),
        boxShadow: const [
          BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3CAE63).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(step.icon, color: const Color(0xFF4CD97B), size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  step.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '${index + 1}/$total',
                style: const TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            step.body,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // จุดบอกขั้น
              ...List.generate(
                total,
                (i) => Container(
                  width: i == index ? 18 : 7,
                  height: 7,
                  margin: const EdgeInsets.only(right: 5),
                  decoration: BoxDecoration(
                    color: i == index
                        ? const Color(0xFF4CD97B)
                        : Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const Spacer(),
              if (!isLast)
                TextButton(
                  onPressed: onSkip,
                  child: const Text('ข้าม',
                      style: TextStyle(color: Colors.white54, fontSize: 14)),
                ),
              const SizedBox(width: 4),
              ElevatedButton(
                onPressed: onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3CAE63),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(isLast ? 'เริ่มใช้งาน' : 'ถัดไป',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// วาดฉากมืดทับทั้งจอ แล้วเจาะรูตรงปุ่มที่กำลังอธิบาย + ตีกรอบเรืองแสง
class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({required this.hole, required this.circle});
  final Rect? hole;
  final bool circle;

  @override
  void paint(Canvas canvas, Size size) {
    final scrim = Paint()..color = Colors.black.withValues(alpha: 0.80);
    final full = Path()..addRect(Offset.zero & size);

    if (hole == null) {
      canvas.drawPath(full, scrim);
      return;
    }

    final r = circle
        ? RRect.fromRectAndRadius(hole!, Radius.circular(hole!.width))
        : RRect.fromRectAndRadius(hole!, const Radius.circular(16));

    canvas.drawPath(
      Path.combine(PathOperation.difference, full, Path()..addRRect(r)),
      scrim,
    );
    canvas.drawRRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = const Color(0xFF4CD97B),
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.hole != hole || old.circle != circle;
}
