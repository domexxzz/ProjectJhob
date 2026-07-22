import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme.dart';
import '../../core/money.dart';
import '../auth/auth_controller.dart';
import '../settings/settings_screen.dart';
import 'profile_avatar.dart';

const _pageBackground = Color(0xFF101110);
const _fieldBorder = Color(0xFF2B302D);

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moneySettings = ref.watch(
      appSettingsProvider.select((s) => (s.currency, s.usdRate)),
    );
    Money.configure(moneySettings.$1, thbToUsdRate: moneySettings.$2);
    final user = ref.watch(authControllerProvider).user;
    return Scaffold(
      backgroundColor: _pageBackground,
      body: Stack(
        children: [
          const _ProfileHeaderBackground(height: 222),
          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  title: 'บัญชีผู้ใช้',
                  trailing: IconButton(
                    tooltip: 'แก้ไขโปรไฟล์',
                    onPressed: () => context.push('/profile/edit'),
                    icon: const Icon(Icons.edit_outlined, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 18),
                ProfileAvatar(imageUrl: user?.avatarUrl),
                const SizedBox(height: 18),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 30),
                    children: [
                      _LabeledValue(
                          label: 'ชื่อ-นามสกุล',
                          value: user?.displayName ?? 'ผู้ใช้'),
                      _LabeledValue(label: 'อีเมล', value: user?.email ?? '-'),
                      _LabeledValue(
                          label: 'เบอร์โทร',
                          value: user?.phone?.isNotEmpty == true
                              ? user!.phone!
                              : '-'),
                      const SizedBox(height: 6),
                      _StatRow(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'รายได้ต่อเดือน',
                        value: user == null
                            ? '-'
                            : Money.formatBaht(user.monthlyIncome),
                      ),
                      _StatRow(
                        icon: Icons.local_fire_department_outlined,
                        label: 'การใช้งานต่อเนื่อง',
                        value: '${user?.streak ?? 0} วัน',
                      ),
                      _StatRow(
                        icon: Icons.star_border_rounded,
                        label: 'ลำดับ',
                        value: '${user?.level ?? 1}',
                      ),
                      const SizedBox(height: 32),
                      Center(
                        child: SizedBox(
                          width: 190,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF5B63),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () async {
                              await ref
                                  .read(authControllerProvider.notifier)
                                  .logout();
                              if (context.mounted) context.go('/login');
                            },
                            icon: const Icon(Icons.logout_rounded),
                            label: const Text('ออกจากระบบ'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Center(
                        child: Text(
                          'พี่เงิน · ที่ปรึกษาการเงิน AI',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _incomeController = TextEditingController();
  Uint8List? _imageBytes;
  String? _imageDataUrl;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final user = ref.read(authControllerProvider).user;
    _nameController.text = user?.displayName ?? '';
    _emailController.text = user?.email ?? '';
    _phoneController.text = user?.phone ?? '';
    _incomeController.text =
        user == null ? '' : Money.format(user.monthlyIncome);
    _initialized = true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _incomeController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 640,
      maxHeight: 640,
      imageQuality: 75,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (bytes.length > 10 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('รูปมีขนาดใหญ่เกินไป กรุณาเลือกรูปไม่เกิน 10 MB')),
        );
      }
      return;
    }
    final mime = picked.mimeType ?? 'image/jpeg';
    setState(() {
      _imageBytes = bytes;
      _imageDataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final income =
        double.tryParse(_incomeController.text.replaceAll(',', '').trim());
    final ok = await ref.read(authControllerProvider.notifier).updateProfile(
          displayName: _nameController.text,
          email: _emailController.text,
          phone: _phoneController.text,
          monthlyIncome: Money.toSatang(income ?? 0),
          avatarUrl: _imageDataUrl,
        );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกข้อมูลเรียบร้อยแล้ว')),
      );
      context.pop();
    } else {
      final message =
          ref.read(authControllerProvider).error ?? 'บันทึกข้อมูลไม่สำเร็จ';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final moneySettings = ref.watch(
      appSettingsProvider.select((s) => (s.currency, s.usdRate)),
    );
    Money.configure(moneySettings.$1, thbToUsdRate: moneySettings.$2);
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;
    return Scaffold(
      backgroundColor: _pageBackground,
      body: Stack(
        children: [
          const _ProfileHeaderBackground(height: 236),
          SafeArea(
            child: Column(
              children: [
                const _TopBar(title: 'แก้ไขโปรไฟล์'),
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: auth.loading ? null : _pickAvatar,
                  child: ProfileAvatar(
                    imageUrl: user?.avatarUrl,
                    imageBytes: _imageBytes,
                    showEditBadge: true,
                  ),
                ),
                const SizedBox(height: 28),
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
                      children: [
                        _ProfileField(
                          label: 'ชื่อ-นามสกุล',
                          controller: _nameController,
                          textInputAction: TextInputAction.next,
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'กรุณากรอกชื่อ-นามสกุล'
                                  : null,
                        ),
                        _ProfileField(
                          label: 'อีเมล',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            final email = value?.trim() ?? '';
                            if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                .hasMatch(email)) {
                              return 'กรุณากรอกอีเมลให้ถูกต้อง';
                            }
                            return null;
                          },
                        ),
                        _ProfileField(
                          label: 'เบอร์โทร',
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9+\- ]'))
                          ],
                          validator: (value) {
                            final digits =
                                (value ?? '').replaceAll(RegExp(r'\D'), '');
                            if (digits.isNotEmpty && digits.length < 9) {
                              return 'กรุณากรอกเบอร์โทรให้ครบ';
                            }
                            return null;
                          },
                        ),
                        _ProfileField(
                          label: 'รายได้ต่อเดือน (${Money.symbol})',
                          controller: _incomeController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9,.]'))
                          ],
                          validator: (value) {
                            final number = double.tryParse(
                                (value ?? '').replaceAll(',', ''));
                            return number == null || number < 0
                                ? 'กรุณากรอกรายได้ให้ถูกต้อง'
                                : null;
                          },
                        ),
                        const SizedBox(height: 48),
                        Center(
                          child: SizedBox(
                            width: 190,
                            child: ElevatedButton(
                              onPressed: auth.loading ? null : _save,
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              child: auth.loading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('ยืนยันการแก้ไข'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeaderBackground extends StatelessWidget {
  const _ProfileHeaderBackground({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _HeaderClipper(),
      child: Container(
        height: height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF102F1C), Color(0xFF244F33)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }
}

class _HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height * .72)
      ..quadraticBezierTo(size.width * .75, size.height * 1.08,
          size.width * .52, size.height * .78)
      ..quadraticBezierTo(
          size.width * .25, size.height * .56, 0, size.height * .72)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: Row(
        children: [
          IconButton(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back, color: Colors.white)),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(width: 48, child: trailing),
        ],
      ),
    );
  }
}

class _LabeledValue extends StatelessWidget {
  const _LabeledValue({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 7),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: _fieldBorder),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(value, style: const TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: _fieldBorder),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 23),
          const SizedBox(width: 14),
          Expanded(
              child:
                  Text(label, style: const TextStyle(color: Colors.white60))),
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            inputFormatters: inputFormatters,
            validator: validator,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.transparent,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                  borderSide: const BorderSide(color: _fieldBorder)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                  borderSide: const BorderSide(color: _fieldBorder)),
            ),
          ),
        ],
      ),
    );
  }
}
