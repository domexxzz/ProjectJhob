import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth_controller.dart';

// โทนสีเซ็ตเดียวกับ LoginScreen
const _kBg = Color(0xFF1F1F1F);
const _kFieldFill = Color(0xFF1A1A1A);
const _kFieldBorder = Color(0xFF2A2A2A);
const _kGreen = Color(0xFF4CD97B);
const _kHint = Color(0xFF7A7A7A);

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  int _currentStep = 1; // 1: กรอก Email, 2: กรอก OTP, 3: ตั้งรหัสใหม่

  // Controllers สำหรับดักจับข้อมูล
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // รหัสผ่านซ่อน/แสดง
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ตัวตกแต่ง TextField ถอดมาจาก login_screen.dart
  InputDecoration _fieldDecoration(String hint, {Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _kHint, fontSize: 14),
      filled: true,
      fillColor: _kFieldFill,
      suffixIcon: suffixIcon,
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
  }

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      );

  // ปุ่มกดหลักด้านล่าง
  Widget _actionButton(
      {required String text, required VoidCallback? onPressed}) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _kGreen,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.black,
                  strokeWidth: 2,
                ),
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
  }

  Widget _errorBanner() {
    if (_errorMessage == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4)),
        ),
        child: Text(
          _errorMessage!,
          style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13),
        ),
      ),
    );
  }

  // ปุ่มกดย้อนกลับด้านล่างสุดของทุกหน้า
  Widget _backButton() {
    return Center(
      child: TextButton(
        onPressed: () {
          setState(() => _errorMessage = null);
          if (_currentStep > 1) {
            setState(() => _currentStep--);
          } else {
            context.go('/login');
          }
        },
        child: const Text(
          'ย้อนกลับ',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ส่วนเนื้อหาด้านบน (เปลี่ยนไปตามลำดับหน้า)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 40),
                        _errorBanner(),
                        if (_currentStep == 1) _buildEmailStep(),
                        if (_currentStep == 2) _buildOtpStep(),
                        if (_currentStep == 3) _buildResetPasswordStep(),
                      ],
                    ),
                    // ปุ่มย้อนกลับล็อกให้อยู่ท้ายหน้าจอเสมอแบบในภาพ
                    _backButton(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // หน้าที่ 1: ลืมรหัสผ่าน (กรอก Email)
  // ---------------------------------------------------------------------------
  Widget _buildEmailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(
          child: Text(
            'ลืมรหัสผ่าน',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: _kGreen,
            ),
          ),
        ),
        const SizedBox(height: 40),
        _fieldLabel('E-mail'),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: Colors.white),
          decoration: _fieldDecoration('กรอก Email'),
        ),
        const SizedBox(height: 28),
        _actionButton(
          text: 'ส่ง OTP ไปที่ Email',
          onPressed: _onRequestOtp,
        ),
      ],
    );
  }

  Future<void> _onRequestOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = 'กรุณากรอกอีเมลให้ถูกต้อง');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final res = await ref
        .read(authControllerProvider.notifier)
        .requestForgotPasswordOtp(email);

    if (!mounted) return;
    setState(() => _loading = false);

    if (res.success) {
      if (res.otp != null) {
        _otpController.text = res.otp!;
      }
      setState(() => _currentStep = 2);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: _kGreen,
        ),
      );
    } else {
      setState(() => _errorMessage = res.message);
    }
  }

  // ---------------------------------------------------------------------------
  // หน้าที่ 2: กรอกรหัสยืนยัน (OTP)
  // ---------------------------------------------------------------------------
  Widget _buildOtpStep() {
    final displayEmail = _emailController.text.isNotEmpty
        ? _emailController.text
        : 'อีเมลของคุณ';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(
          child: Text(
            'กรอกรหัสยืนยัน',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: _kGreen,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(fontSize: 14, height: 1.4),
              children: [
                const TextSpan(
                    text: 'ส่งรหัสไปที่\n', style: TextStyle(color: _kHint)),
                TextSpan(
                    text: displayEmail,
                    style: const TextStyle(
                        color: _kGreen, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        _fieldLabel('OTP'),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: _fieldDecoration('กรอกรหัสยืนยัน'),
        ),
        const SizedBox(height: 28),
        _actionButton(
          text: 'ยืนยัน',
          onPressed: _onVerifyOtp,
        ),
      ],
    );
  }

  Future<void> _onVerifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty) {
      setState(() => _errorMessage = 'กรุณากรอกรหัส OTP');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final res = await ref
        .read(authControllerProvider.notifier)
        .verifyForgotPasswordOtp(_emailController.text, otp);

    if (!mounted) return;
    setState(() => _loading = false);

    if (res.success) {
      setState(() => _currentStep = 3);
    } else {
      setState(() => _errorMessage = res.message);
    }
  }

  // ---------------------------------------------------------------------------
  // หน้าที่ 3: ตั้งค่ารหัสผ่านใหม่
  // ---------------------------------------------------------------------------
  Widget _buildResetPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(
          child: Text(
            'ตั้งค่ารหัสผ่านใหม่',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: _kGreen,
            ),
          ),
        ),
        const SizedBox(height: 40),
        _fieldLabel('Password'),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: const TextStyle(color: Colors.white),
          decoration: _fieldDecoration(
            'ตั้งรหัสผ่าน',
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: _kHint,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _fieldLabel('Confirm Password'),
        TextField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          style: const TextStyle(color: Colors.white),
          decoration: _fieldDecoration(
            'ยืนยันรหัสผ่าน',
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: _kHint,
              ),
              onPressed: () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
          ),
        ),
        const SizedBox(height: 28),
        _actionButton(
          text: 'ยืนยันการเปลี่ยนรหัส',
          onPressed: _onResetPassword,
        ),
      ],
    );
  }

  Future<void> _onResetPassword() async {
    final newPassword = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (newPassword.isEmpty || newPassword.length < 6) {
      setState(() => _errorMessage = 'รหัสผ่านใหม่ต้องอย่างน้อย 6 ตัวอักษร');
      return;
    }
    if (newPassword != confirmPassword) {
      setState(() => _errorMessage = 'รหัสผ่านใหม่ทั้งสองช่องไม่ตรงกัน');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final res = await ref
        .read(authControllerProvider.notifier)
        .resetPasswordWithOtp(
          _emailController.text,
          _otpController.text,
          newPassword,
        );

    if (!mounted) return;
    setState(() => _loading = false);

    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: _kGreen,
        ),
      );
      context.go('/login');
    } else {
      setState(() => _errorMessage = res.message);
    }
  }
}