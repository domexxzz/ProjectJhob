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
      backgroundColor: const Color(0xFF111211),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111211),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'ความเป็นส่วนตัว',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 110),
        children: [
          _PrivacySwitch(
            title: 'แสดงคำแนะนำเฉพาะบุคคล',
            subtitle: 'ใช้ข้อมูลการเงินเพื่อปรับคำแนะนำให้เหมาะกับคุณ',
            value: settings.personalizedRecommendations,
            onChanged: notifier.setPersonalizedRecommendations,
          ),
          _PrivacySwitch(
            title: 'บันทึกประวัติสนทนาเพื่อพัฒนาคำตอบ',
            subtitle: 'ปิดแล้วข้อความใหม่จะไม่ถูกบันทึกไว้บนเซิร์ฟเวอร์',
            value: settings.shareForAiImprovement,
            onChanged: notifier.setShareForAiImprovement,
          ),
          _PrivacySwitch(
            title: 'อนุญาตให้ AI วิเคราะห์ข้อมูลการเงิน',
            subtitle:
                'ให้พี่เงินใช้รายรับ รายจ่าย และงบประมาณในการวิเคราะห์',
            value: settings.allowFinancialAnalysis,
            onChanged: notifier.setAllowFinancialAnalysis,
          ),
          const SizedBox(height: 22),
          const Text(
            'App Security',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 10),
          _PrivacySwitch(
            title: 'Face ID / ลายนิ้วมือ',
            subtitle: 'ล็อกแอปด้วยข้อมูลชีวมิติบนอุปกรณ์ที่รองรับ',
            value: settings.biometricLock,
            onChanged: (value) => _setBiometric(context, notifier, value),
          ),
          _PrivacySwitch(
            title: 'ล็อกอินอัตโนมัติ',
            subtitle: 'คงสถานะเข้าสู่ระบบเมื่อเปิดแอปครั้งถัดไป',
            value: settings.autoLogin,
            onChanged: notifier.setAutoLogin,
          ),
          _PrivacySwitch(
            title: 'ซ่อนข้อมูลเมื่อเปิด Recent Apps',
            subtitle: 'ป้องกันข้อมูลสำคัญปรากฏในภาพตัวอย่างแอปล่าสุด',
            value: settings.hideInRecentApps,
            onChanged: (value) async {
              await notifier.setHideInRecentApps(value);
              await NativeSecurityService.setRecentAppsPrivacy(value);
            },
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _showPrivacyPolicy(context),
            child: const Text(
              'นโยบายความเป็นส่วนตัว',
              style: TextStyle(
                color: Color(0xFFFF4D57),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: const AppFloatingActionButton(),
      floatingActionButtonLocation: kFixedCenterDockedFabLocation,
      bottomNavigationBar: const AppBottomNavigationBar(currentTab: AppTab.none),
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

class _PrivacySwitch extends StatelessWidget {
  const _PrivacySwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF262826),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: value ? const Color(0xFF1C5835) : Colors.white10,
        ),
      ),
      child: SwitchListTile.adaptive(
        value: value,
        onChanged: onChanged,
        activeThumbColor: const Color(0xFF44C878),
        activeTrackColor: const Color(0xFF205F3A),
        inactiveThumbColor: Colors.white70,
        inactiveTrackColor: const Color(0xFF454845),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            subtitle,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ),
      ),
    );
  }
}




