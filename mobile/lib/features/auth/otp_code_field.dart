import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ช่องกรอกรหัส OTP แบบแยกกล่องทีละหลัก
///
/// ทำไมไม่ใช้ TextField เดี่ยว: รหัส 6 หลักที่พิมพ์รวมในช่องเดียวอ่านยาก
/// ผู้ใช้นับไม่ออกว่าพิมพ์ไปกี่ตัวแล้ว และมองไม่เห็นว่าเหลืออีกกี่ช่อง
///
/// พฤติกรรมที่ใส่ไว้ให้ใช้งานจริงได้ลื่น
///  - พิมพ์แล้วเลื่อนไปช่องถัดไปเอง
///  - กด backspace ในช่องว่าง ย้อนกลับไปช่องก่อนหน้าแล้วลบให้
///  - วางรหัสทั้ง 6 หลักทีเดียวได้ (กระจายลงทุกช่องให้)
///  - ครบทุกช่องแล้วเรียก onCompleted ให้หน้าจอยืนยันอัตโนมัติได้
///
/// ค่าที่กรอกถูกเขียนกลับเข้า [controller] ตัวเดิมของหน้าจอ
/// โค้ดที่อ่าน controller.text อยู่แล้วจึงไม่ต้องแก้อะไร
class OtpCodeField extends StatefulWidget {
  const OtpCodeField({
    super.key,
    required this.controller,
    this.length = 6,
    this.onCompleted,
    this.enabled = true,
  });

  final TextEditingController controller;
  final int length;

  /// เรียกเมื่อกรอกครบทุกช่อง — ส่งรหัสเต็มกลับไป
  final ValueChanged<String>? onCompleted;
  final bool enabled;

  @override
  State<OtpCodeField> createState() => _OtpCodeFieldState();
}

class _OtpCodeFieldState extends State<OtpCodeField> {
  late final List<TextEditingController> _boxes;
  late final List<FocusNode> _nodes;

  static const _fill = Color(0xFF1A1A1A);
  static const _border = Color(0xFF2A2A2A);
  static const _green = Color(0xFF4CD97B);

  @override
  void initState() {
    super.initState();
    _boxes = List.generate(widget.length, (_) => TextEditingController());
    _nodes = List.generate(widget.length, (_) => FocusNode());
    // หน้าจอสั่งล้างค่า (เช่นกดย้อนกลับ) → ล้างทุกช่องตามด้วย
    widget.controller.addListener(_syncFromParent);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncFromParent);
    for (final c in _boxes) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _syncFromParent() {
    if (widget.controller.text.isEmpty && _boxes.any((c) => c.text.isNotEmpty)) {
      for (final c in _boxes) {
        c.clear();
      }
      if (mounted) setState(() {});
    }
  }

  /// รวมตัวเลขทุกช่องเขียนกลับเข้า controller ของหน้าจอ
  void _publish() {
    final code = _boxes.map((c) => c.text).join();
    widget.controller.text = code;
    if (code.length == widget.length) {
      FocusScope.of(context).unfocus();
      widget.onCompleted?.call(code);
    }
  }

  void _onChanged(int index, String value) {
    // วางรหัสมาทั้งชุด — กระจายลงทุกช่องแทนที่จะยัดลงช่องเดียว
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
      for (var i = 0; i < widget.length; i++) {
        _boxes[i].text = i < digits.length ? digits[i] : '';
      }
      final next = digits.length.clamp(0, widget.length - 1);
      _nodes[next].requestFocus();
      setState(() {});
      _publish();
      return;
    }

    if (value.isNotEmpty && index < widget.length - 1) {
      _nodes[index + 1].requestFocus();
    }
    setState(() {}); // ให้กรอบเปลี่ยนสีตามช่องที่มีค่าแล้ว
    _publish();
  }

  /// backspace ในช่องว่าง = ย้อนไปช่องก่อนหน้าแล้วลบให้
  /// ถ้าไม่ทำ ผู้ใช้ต้องกดย้ายช่องเองซึ่งงงมากบนมือถือ
  KeyEventResult _onKey(int index, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.backspace) return KeyEventResult.ignored;
    if (_boxes[index].text.isNotEmpty || index == 0) return KeyEventResult.ignored;

    _boxes[index - 1].clear();
    _nodes[index - 1].requestFocus();
    setState(() {});
    _publish();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(widget.length, (i) {
        final filled = _boxes[i].text.isNotEmpty;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == widget.length - 1 ? 0 : 8),
            child: AspectRatio(
              // กล่องสี่เหลี่ยมสูงกว่ากว้างเล็กน้อย ให้ตัวเลขอยู่กลางพอดี
              aspectRatio: 0.82,
              child: Focus(
                onKeyEvent: (_, event) => _onKey(i, event),
                child: TextField(
                  controller: _boxes[i],
                  focusNode: _nodes[i],
                  enabled: widget.enabled,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  // ไม่จำกัดความยาวไว้ที่ 1 เพราะต้องรับการ "วางรหัสทั้งชุด" ได้
                  // แต่กรองให้เหลือเฉพาะตัวเลขเสมอ
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: _fill,
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: filled ? _green : _border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: filled ? _green : _border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _green, width: 2),
                    ),
                  ),
                  onChanged: (v) => _onChanged(i, v),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
