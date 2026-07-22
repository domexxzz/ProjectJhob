import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import 'auth_controller.dart';
import 'social_login_buttons.dart'; // ดึงปุ่มโซเชียลเซ็ตเดียวกับหน้า Login มาใช้

// ใช้โทนสีชุดเดียวกับ LoginScreen เป๊ะๆ
const _kBg = Color(0xFF1F1F1F);
const _kFieldFill = Color(0xFF1A1A1A);
const _kFieldBorder = Color(0xFF2A2A2A);
const _kGreen = Color(0xFF4CD97B);
const _kHint = Color(0xFF7A7A7A);

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = await ref
        .read(authControllerProvider.notifier)
        .register(_email.text.trim(), _password.text, _name.text.trim());
    if (ok && mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    return Scaffold(
      backgroundColor: _kBg, // ปรับสีพื้นหลังให้เหมือนหน้า Login
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24), // ความห่างเท่าหน้า Login
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, // ให้ฟิลด์ต่างๆ ชิดซ้ายเหมือนหน้า Login
            children: [
              const SizedBox(height: 12),
              // จัดหัวข้อให้อยู่ตรงกลางเหมือนหน้า Login ด้วยรูปแบบฟอนต์เดียวกัน
              Center(
                child: const Text(
                  'สมัครสมาชิก',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: _kGreen,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              _LabeledField(
                label: 'Full name*',
                controller: _name,
                hint: 'ตั้งชื่อของคุณ',
              ),
              const SizedBox(height: 20),

              _LabeledField(
                label: 'E-mail',
                controller: _email,
                hint: 'กรอก Email',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),

              _LabeledField(
                label: 'Password',
                controller: _password,
                hint: 'ตั้งรหัสผ่าน',
                obscureText: _obscure,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: _kHint,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              const SizedBox(height: 20),

              _LabeledField(
                label: 'Phone number',
                controller: _phone,
                hint: 'ใส่เบอร์โทรศัพท์',
                keyboardType: TextInputType.phone,
              ),

              if (auth.error != null) ...[
                const SizedBox(height: 12),
                Text(
                  auth.error!, 
                  style: const TextStyle(color: AppColors.expense),
                ),
              ],

              const SizedBox(height: 24),
              // ปรับขนาดและดีไซน์ปุ่มสมัครสมาชิกให้เท่าและสีเดียวกันกับหน้า Login
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: auth.loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: auth.loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'สร้างบัญชี',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 28),
              // ตัวคั่น "or continue with" ดีไซน์แบบเดียวกับหน้า Login
              Row(
                children: [
                  const Expanded(child: Divider(color: _kFieldBorder)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'or continue with',
                      style: TextStyle(color: _kHint, fontSize: 13),
                    ),
                  ),
                  const Expanded(child: Divider(color: _kFieldBorder)),
                ],
              ),
              const SizedBox(height: 20),

              // ดึงแถบปุ่ม SocialLoginButtons ตัวเดียวกับหน้า Login มาแสดงเพื่อความเหมือนเป๊ะ
              Center(
                child: const SocialLoginButtons(),
              ),

              const SizedBox(height: 24),
              // ลิงก์สลับกลับไปหน้าล็อกอินดีไซน์ RichText ตัวเดียวกับหน้า Login
              Center(
                child: GestureDetector(
                  onTap: () => context.go('/login'),
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(fontSize: 14),
                      children: [
                        TextSpan(
                          text: 'คุณมีแอคเคาท์อยู่แล้ว? ',
                          style: TextStyle(color: Colors.white),
                        ),
                        TextSpan(
                          text: 'ล็อกอิน',
                          style: TextStyle(
                            color: _kGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const SocialLoginButtons(),
            ],
          ),
        ),
      ),
    );
  }
}

// ปรับปรุง Custom Widget ให้ดึงสไตล์ช่องกรอกข้อมูล (InputDecoration) แบบเดียวกับหน้า Login 
class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    required this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.suffixIcon,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
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
          ),
        ),
      ],
    );
  }
}