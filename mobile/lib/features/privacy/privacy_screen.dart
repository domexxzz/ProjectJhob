import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/theme.dart';
import '../../widgets/app_bottom_nav_bar.dart';
import 'native_security_service.dart';

class PrivacySettings {
  const PrivacySettings({
    this.isLoaded = false,
    this.personalizedRecommendations = true,
    this.shareForAiImprovement = true,
    this.allowFinancialAnalysis = true,
    this.biometricLock = false,
    this.autoLogin = true,
    this.hideInRecentApps = true,
  });

  final bool isLoaded;
  final bool personalizedRecommendations;
  final bool shareForAiImprovement;
  final bool allowFinancialAnalysis;
  final bool biometricLock;
  final bool autoLogin;
  final bool hideInRecentApps;

  PrivacySettings copyWith({
    bool? isLoaded,
    bool? personalizedRecommendations,
    bool? shareForAiImprovement,
    bool? allowFinancialAnalysis,
    bool? biometricLock,
    bool? autoLogin,
    bool? hideInRecentApps,
  }) {
    return PrivacySettings(
      isLoaded: isLoaded ?? this.isLoaded,
      personalizedRecommendations:
          personalizedRecommendations ?? this.personalizedRecommendations,
      shareForAiImprovement:
          shareForAiImprovement ?? this.shareForAiImprovement,
      allowFinancialAnalysis:
          allowFinancialAnalysis ?? this.allowFinancialAnalysis,
      biometricLock: biometricLock ?? this.biometricLock,
      autoLogin: autoLogin ?? this.autoLogin,
      hideInRecentApps: hideInRecentApps ?? this.hideInRecentApps,
    );
  }
}

class PrivacySettingsNotifier extends StateNotifier<PrivacySettings> {
  PrivacySettingsNotifier() : super(const PrivacySettings()) {
    _load();
  }

  static const _personalizedKey = 'privacy_personalized_recommendations';
  static const _shareAiKey = 'privacy_share_for_ai_improvement';
  static const _financialAnalysisKey = 'privacy_allow_financial_analysis';
  static const _biometricKey = 'privacy_biometric_lock';
  static const _autoLoginKey = 'privacy_auto_login';
  static const _recentAppsKey = 'privacy_hide_recent_apps';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = PrivacySettings(
      isLoaded: true,
      personalizedRecommendations: prefs.getBool(_personalizedKey) ?? true,
      shareForAiImprovement: prefs.getBool(_shareAiKey) ?? true,
      allowFinancialAnalysis: prefs.getBool(_financialAnalysisKey) ?? true,
      biometricLock: prefs.getBool(_biometricKey) ?? false,
      autoLogin: prefs.getBool(_autoLoginKey) ?? true,
      hideInRecentApps: prefs.getBool(_recentAppsKey) ?? true,
    );
  }

  Future<void> setPersonalizedRecommendations(bool value) async {
    state = state.copyWith(personalizedRecommendations: value);
    await _save(_personalizedKey, value);
  }

  Future<void> setShareForAiImprovement(bool value) async {
    state = state.copyWith(shareForAiImprovement: value);
    await _save(_shareAiKey, value);
  }

  Future<void> setAllowFinancialAnalysis(bool value) async {
    state = state.copyWith(allowFinancialAnalysis: value);
    await _save(_financialAnalysisKey, value);
  }

  Future<void> setBiometricLock(bool value) async {
    state = state.copyWith(biometricLock: value);
    await _save(_biometricKey, value);
  }

  Future<void> setAutoLogin(bool value) async {
    state = state.copyWith(autoLogin: value);
    await _save(_autoLoginKey, value);
  }

  Future<void> setHideInRecentApps(bool value) async {
    state = state.copyWith(hideInRecentApps: value);
    await _save(_recentAppsKey, value);
  }

  Future<void> _save(String key, bool value) async {
    await (await SharedPreferences.getInstance()).setBool(key, value);
  }
}

final privacySettingsProvider =
    StateNotifierProvider<PrivacySettingsNotifier, PrivacySettings>(
  (ref) => PrivacySettingsNotifier(),
);

class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(privacySettingsProvider);
    final notifier = ref.read(privacySettingsProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1110),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1110),
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          onPressed: () {
            if (Navigator.of(context).canPop() || context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
        ),
        title: const Text(
          'ความเป็นส่วนตัว',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 110),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const _SectionTitle(
                  icon: Icons.shield_outlined,
                  title: 'ความเป็นส่วนตัวและการใช้ข้อมูล',
                  subtitle: 'กำหนดการนำข้อมูลไปใช้วิเคราะห์และพัฒนาคำแนะนำ',
                ),
                const SizedBox(height: 12),
                _SettingsGroup(
                  children: [
                    _SettingsSwitchTile(
                      icon: Icons.psychology_outlined,
                      title: 'แสดงคำแนะนำเฉพาะบุคคล',
                      subtitle: 'ใช้ข้อมูลการเงินเพื่อปรับคำแนะนำให้เหมาะกับคุณ',
                      value: settings.personalizedRecommendations,
                      onChanged: notifier.setPersonalizedRecommendations,
                    ),
                    _SettingsSwitchTile(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'บันทึกประวัติสนทนาเพื่อพัฒนาคำตอบ',
                      subtitle: 'ปิดแล้วข้อความใหม่จะไม่ถูกบันทึกไว้บนเซิร์ฟเวอร์',
                      value: settings.shareForAiImprovement,
                      onChanged: notifier.setShareForAiImprovement,
                    ),
                    _SettingsSwitchTile(
                      icon: Icons.auto_awesome_outlined,
                      title: 'อนุญาตให้ AI วิเคราะห์ข้อมูลการเงิน',
                      subtitle:
                          'ให้พี่เงินใช้รายรับ รายจ่าย และงบประมาณในการวิเคราะห์',
                      value: settings.allowFinancialAnalysis,
                      onChanged: notifier.setAllowFinancialAnalysis,
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                const _SectionTitle(
                  icon: Icons.security_outlined,
                  title: 'ความปลอดภัยของแอป (App Security)',
                  subtitle: 'ปกป้องแอปพลิเคชันและการเข้าถึงข้อมูลชีวมิติ',
                ),
                const SizedBox(height: 12),
                _SettingsGroup(
                  children: [
                    _SettingsSwitchTile(
                      icon: Icons.fingerprint_rounded,
                      title: 'Face ID / ลายนิ้วมือ',
                      subtitle: 'ล็อกแอปด้วยข้อมูลชีวมิติบนอุปกรณ์ที่รองรับ',
                      value: settings.biometricLock,
                      onChanged: (value) =>
                          _setBiometric(context, notifier, value),
                    ),
                    _SettingsSwitchTile(
                      icon: Icons.login_rounded,
                      title: 'ล็อกอินอัตโนมัติ',
                      subtitle: 'คงสถานะเข้าสู่ระบบเมื่อเปิดแอปครั้งถัดไป',
                      value: settings.autoLogin,
                      onChanged: notifier.setAutoLogin,
                    ),
                    _SettingsSwitchTile(
                      icon: Icons.visibility_off_outlined,
                      title: 'ซ่อนข้อมูลเมื่อเปิด Recent Apps',
                      subtitle:
                          'ป้องกันข้อมูลสำคัญปรากฏในภาพตัวอย่างแอปล่าสุด',
                      value: settings.hideInRecentApps,
                      onChanged: (value) async {
                        await notifier.setHideInRecentApps(value);
                        await NativeSecurityService.setRecentAppsPrivacy(value);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                const _SectionTitle(
                  icon: Icons.gavel_outlined,
                  title: 'ข้อตกลงและนโยบาย',
                  subtitle: 'อ่านรายละเอียดนโยบายการคุ้มครองข้อมูลส่วนบุคคล',
                ),
                const SizedBox(height: 12),
                _SettingsGroup(
                  children: [
                    _SettingsActionTile(
                      icon: Icons.policy_outlined,
                      title: 'นโยบายความเป็นส่วนตัว',
                      value: 'อ่านนโยบาย',
                      onTap: () => _showPrivacyPolicy(context),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                const Center(
                  child: Text(
                    'พี่เงิน · ระบบคุ้มครองข้อมูลส่วนบุคคล',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
      floatingActionButton: const AppFloatingActionButton(),
      floatingActionButtonLocation: kFixedCenterDockedFabLocation,
      bottomNavigationBar:
          const AppBottomNavigationBar(currentTab: AppTab.none),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF202220),
      showDragHandle: true,
      builder: (context) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'นโยบายความเป็นส่วนตัว',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 14),
              Text(
                'คุณเป็นผู้ควบคุมข้อมูลของตนเอง สามารถเปิดหรือปิดการใช้ข้อมูลเพื่อคำแนะนำและการวิเคราะห์ AI ได้ทุกเมื่อ การตั้งค่าจะถูกบันทึกเฉพาะบนอุปกรณ์นี้ และข้อมูลบัญชีจะถูกใช้เท่าที่จำเป็นต่อการให้บริการเท่านั้น',
                style: TextStyle(color: Colors.white70, height: 1.55),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _setBiometric(
    BuildContext context,
    PrivacySettingsNotifier notifier,
    bool enabled,
  ) async {
    if (!enabled) {
      await notifier.setBiometricLock(false);
      return;
    }
    final result = await NativeSecurityService.authenticate();
    if (!context.mounted) return;
    if (result == BiometricAuthResult.success) {
      await notifier.setBiometricLock(true);
      return;
    }
    final message = result == BiometricAuthResult.unavailable
        ? 'อุปกรณ์นี้ยังไม่ได้ตั้งค่า Face ID หรือลายนิ้วมือ'
        : 'ยืนยันตัวตนไม่สำเร็จ จึงยังไม่เปิดการล็อกแอป';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF173522),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF4CD97B), size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(subtitle,
                  style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF202421),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF314338)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              const Divider(height: 1, indent: 62, color: Color(0xFF323632)),
          ],
        ],
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      activeThumbColor: const Color(0xFF4CD97B),
      activeTrackColor: const Color(0xFF215F39),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      secondary: Icon(icon, color: Colors.white70, size: 23),
      title: Text(title,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
          style: const TextStyle(color: Colors.white38, fontSize: 11)),
    );
  }
}

class _SettingsActionTile extends StatelessWidget {
  const _SettingsActionTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      leading: Icon(icon, color: Colors.white70, size: 23),
      title: Text(title,
          style: const TextStyle(
              color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: const TextStyle(color: Color(0xFF8BAA96), fontSize: 13)),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded,
              color: Colors.white38, size: 22),
        ],
      ),
    );
  }
}




