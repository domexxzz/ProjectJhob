import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'otp_controller.dart';

// โทนสีเซ็ตเดียวกับ LoginScreen / ForgotPasswordScreen
const _kBg = Color(0xFF1F1F1F);
const _kFieldFill = Color(0xFF1A1A1A);
const _kFieldBorder = Color(0xFF2A2A2A);
const _kGreen = Color(0xFF4CD97B);
const _kHint = Color(0xFF7A7A7A);
const _kRed = Color(0xFFFF6B6B);

/// หน้ายืนยันอีเมลด้วยรหัส 6 หลัก (กรอกอีเมล → รับรหัส → ยืนยัน → เข้าแอป)
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, this.presetEmail});

  /// อีเมลที่รู้อยู่แล้ว เช่นเพิ่งสมัครเสร็จ — จะเติมให้ในช่องเลย
  final String? presetEmail;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  late final TextEditingController _emailController;
  final _codeController = TextEditingController();

  bool _codeSent = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.presetEmail ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  static const _purpose = 'verify';
  static const _title = 'ยืนยันอีเมล';

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = 'กรุณากรอกอีเมลให้ถูกต้อง');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await ref.read(otpControllerProvider).requestCode(email, _purpose);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
      if (err == null) _codeSent = true;
    });
  }

  Future<void> _submitCode() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'รหัสยืนยันเป็นตัวเลข 6 หลัก');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final otp = ref.read(otpControllerProvider);
    final email = _emailController.text.trim();
    final err = await otp.verifyEmail(email, code);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
    });
    if (err == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ยืนยันอีเมลเรียบร้อย')),
      );
      context.go('/');
    }
  }

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _kHint, fontSize: 14),
        filled: true,
        fillColor: _kFieldFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kFieldBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kFieldBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kGreen),
        ),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14)),
      );

  Widget _button(String text, VoidCallback onPressed) => SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          // ปิดปุ่มระหว่างรอเซิร์ฟเวอร์ กันกดซ้ำจนขอรหัสหลายใบ
          onPressed: _busy ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: _kGreen,
            disabledBackgroundColor: _kGreen.withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                )
              : Text(
                  text,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
        ),
      );

  Widget _errorBox() {
    if (_error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: _kRed, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_error!,
                style: const TextStyle(color: _kRed, fontSize: 13, height: 1.4)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            // กรอกรหัสอยู่แล้วกดย้อน = กลับไปแก้อีเมล ไม่ใช่ออกจากหน้านี้เลย
            if (_codeSent) {
              setState(() {
                _codeSent = false;
                _error = null;
                _codeController.clear();
              });
            } else {
              context.go('/login');
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _title,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: _kGreen,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  _codeSent
                      // ⚠️ ต้องเขียนว่า "ถ้าอีเมลนี้มีในระบบ" ไม่ใช่ "ส่งไปที่อีเมลของคุณแล้ว"
                      // เพราะ backend ตอบเหมือนกันหมดเพื่อไม่ให้คนไล่เช็กว่าใครสมัครไว้บ้าง
                      // ถ้าหน้าจอเขียนยืนยันไปเลย ก็เท่ากับทำลายการป้องกันนั้นทิ้ง
                      ? 'ถ้าอีเมลนี้มีในระบบ เราส่งรหัส 6 หลักไปให้แล้ว\nรหัสใช้ได้ 10 นาที'
                      : 'กรอกอีเมลที่ใช้สมัคร เพื่อรับรหัสยืนยัน',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _kHint, fontSize: 14, height: 1.4),
                ),
              ),
              const SizedBox(height: 36),
              if (!_codeSent) ...[
                _label('E-mail'),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: _fieldDecoration('กรอก Email'),
                ),
                const SizedBox(height: 28),
                _button('ส่งรหัสไปที่ Email', _sendCode),
              ] else ...[
                _label('รหัสยืนยัน 6 หลัก'),
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    letterSpacing: 8,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  decoration: _fieldDecoration('------').copyWith(counterText: ''),
                ),
                const SizedBox(height: 20),
                _button('ยืนยันอีเมล', _submitCode),
                Center(
                  child: TextButton(
                    onPressed: _busy ? null : _sendCode,
                    child: const Text('ไม่ได้รับรหัส? ส่งใหม่',
                        style: TextStyle(color: _kHint, fontSize: 13)),
                  ),
                ),
              ],
              _errorBox(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
