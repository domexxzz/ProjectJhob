import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/api_client.dart';

class AppSettings {
  const AppSettings({
    this.notifications = true,
    this.notificationSound = true,
    this.vibration = true,
    this.budgetAlerts = true,
    this.currency = 'THB',
    this.usdRate = 0.0297,
    this.exchangeRateDate = '2026-07-21',
    this.exchangeRateStale = true,
    this.exchangeRateLoading = false,
    this.language = 'th',
  });

  final bool notifications;
  final bool notificationSound;
  final bool vibration;
  final bool budgetAlerts;
  final String currency;
  final double usdRate;
  final String exchangeRateDate;
  final bool exchangeRateStale;
  final bool exchangeRateLoading;
  final String language;

  AppSettings copyWith({
    bool? notifications,
    bool? notificationSound,
    bool? vibration,
    bool? budgetAlerts,
    String? currency,
    double? usdRate,
    String? exchangeRateDate,
    bool? exchangeRateStale,
    bool? exchangeRateLoading,
    String? language,
  }) {
    return AppSettings(
      notifications: notifications ?? this.notifications,
      notificationSound: notificationSound ?? this.notificationSound,
      vibration: vibration ?? this.vibration,
      budgetAlerts: budgetAlerts ?? this.budgetAlerts,
      currency: currency ?? this.currency,
      usdRate: usdRate ?? this.usdRate,
      exchangeRateDate: exchangeRateDate ?? this.exchangeRateDate,
      exchangeRateStale: exchangeRateStale ?? this.exchangeRateStale,
      exchangeRateLoading: exchangeRateLoading ?? this.exchangeRateLoading,
      language: language ?? this.language,
    );
  }
}

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  AppSettingsNotifier(this._ref) : super(const AppSettings()) {
    _load();
  }

  final Ref _ref;

  static const _notificationsKey = 'settings_notifications';
  static const _soundKey = 'settings_notification_sound';
  static const _vibrationKey = 'settings_vibration';
  static const _budgetAlertsKey = 'settings_budget_alerts';
  static const _currencyKey = 'settings_currency';
  static const _usdRateKey = 'settings_usd_rate';
  static const _exchangeRateDateKey = 'settings_exchange_rate_date';
  static const _languageKey = 'settings_language';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = AppSettings(
      notifications: prefs.getBool(_notificationsKey) ?? true,
      notificationSound: prefs.getBool(_soundKey) ?? true,
      vibration: prefs.getBool(_vibrationKey) ?? true,
      budgetAlerts: prefs.getBool(_budgetAlertsKey) ?? true,
      currency: prefs.getString(_currencyKey) ?? 'THB',
      usdRate: prefs.getDouble(_usdRateKey) ?? 0.0297,
      exchangeRateDate: prefs.getString(_exchangeRateDateKey) ?? '2026-07-21',
      exchangeRateStale: true,
      language: 'th',
    );
    if (state.currency == 'USD') await refreshExchangeRate();
    await refreshNotificationPreferences();
  }

  Future<void> refreshExchangeRate() async {
    state = state.copyWith(exchangeRateLoading: true);
    try {
      final response = await _ref
          .read(dioProvider)
          .get('/currency/rate', queryParameters: {'from': 'THB', 'to': 'USD'});
      final data = response.data['exchangeRate'] as Map<String, dynamic>;
      final rate = (data['rate'] as num).toDouble();
      final date = data['date'] as String;
      if (rate <= 0) throw StateError('Invalid USD exchange rate');
      state = state.copyWith(
        usdRate: rate,
        exchangeRateDate: date,
        exchangeRateStale: data['stale'] as bool? ?? false,
        exchangeRateLoading: false,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_usdRateKey, rate);
      await prefs.setString(_exchangeRateDateKey, date);
    } catch (_) {
      state = state.copyWith(
        exchangeRateStale: true,
        exchangeRateLoading: false,
      );
    }
  }

  Future<void> refreshNotificationPreferences() async {
    try {
      final response =
          await _ref.read(dioProvider).get('/notifications/preferences');
      final data = response.data['preferences'] as Map<String, dynamic>;
      final notifications =
          data['notificationsEnabled'] as bool? ?? state.notifications;
      final budgetAlerts =
          data['budgetAlertsEnabled'] as bool? ?? state.budgetAlerts;
      state = state.copyWith(
        notifications: notifications,
        budgetAlerts: budgetAlerts,
      );
      await _setBool(_notificationsKey, notifications);
      await _setBool(_budgetAlertsKey, budgetAlerts);
    } catch (_) {
      // ผู้ใช้ยังไม่ล็อกอินหรือออฟไลน์: ใช้ค่าที่บันทึกไว้ในเครื่องต่อไป
    }
  }

  Future<void> _syncNotificationPreferences() async {
    try {
      await _ref.read(dioProvider).patch(
        '/notifications/preferences',
        data: {
          'notificationsEnabled': state.notifications,
          'budgetAlertsEnabled': state.budgetAlerts,
        },
      );
    } catch (_) {
      // การตั้งค่าในเครื่องมีผลทันที และจะลองอ่านจากเซิร์ฟเวอร์ใหม่ครั้งถัดไป
    }
  }

  Future<void> setNotifications(bool value) async {
    state = state.copyWith(notifications: value);
    await _setBool(_notificationsKey, value);
    await _syncNotificationPreferences();
  }

  Future<void> setNotificationSound(bool value) async {
    state = state.copyWith(notificationSound: value);
    await _setBool(_soundKey, value);
  }

  Future<void> setVibration(bool value) async {
    state = state.copyWith(vibration: value);
    await _setBool(_vibrationKey, value);
  }

  Future<void> setBudgetAlerts(bool value) async {
    state = state.copyWith(budgetAlerts: value);
    await _setBool(_budgetAlertsKey, value);
    await _syncNotificationPreferences();
  }

  Future<void> setCurrency(String value) async {
    state = state.copyWith(currency: value);
    await (await SharedPreferences.getInstance())
        .setString(_currencyKey, value);
    if (value == 'USD') await refreshExchangeRate();
  }

  Future<void> setLanguage(String value) async {
    state = state.copyWith(language: value);
    await (await SharedPreferences.getInstance())
        .setString(_languageKey, value);
  }

  Future<void> _setBool(String key, bool value) async {
    await (await SharedPreferences.getInstance()).setBool(key, value);
  }
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>(
  (ref) => AppSettingsNotifier(ref),
);

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1110),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1110),
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text(
          'การตั้งค่า',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 38),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const _SectionTitle(
                  icon: Icons.notifications_none_rounded,
                  title: 'การแจ้งเตือน',
                  subtitle: 'เลือกวิธีที่คุณต้องการให้พี่เงินแจ้งเตือน',
                ),
                const SizedBox(height: 12),
                _SettingsGroup(
                  children: [
                    _SettingsSwitchTile(
                      icon: Icons.notifications_active_outlined,
                      title: 'เปิดการแจ้งเตือน',
                      subtitle: 'รับข่าวสารและรายการสำคัญจากพี่เงิน',
                      value: settings.notifications,
                      onChanged: notifier.setNotifications,
                    ),
                    _SettingsSwitchTile(
                      icon: Icons.volume_up_outlined,
                      title: 'เสียงแจ้งเตือน',
                      subtitle: 'เล่นเสียงเมื่อมีการแจ้งเตือนใหม่',
                      value: settings.notificationSound,
                      enabled: settings.notifications,
                      onChanged: notifier.setNotificationSound,
                    ),
                    _SettingsSwitchTile(
                      icon: Icons.vibration_rounded,
                      title: 'สั่นขณะแจ้งเตือน',
                      subtitle: 'ให้อุปกรณ์สั่นเมื่อได้รับการแจ้งเตือน',
                      value: settings.vibration,
                      enabled: settings.notifications,
                      onChanged: notifier.setVibration,
                    ),
                    _SettingsSwitchTile(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'เตือนเมื่อใกล้เกินงบ',
                      subtitle: 'แจ้งเตือนเมื่อการใช้จ่ายเข้าใกล้งบที่ตั้งไว้',
                      value: settings.budgetAlerts,
                      enabled: settings.notifications,
                      onChanged: notifier.setBudgetAlerts,
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                const _SectionTitle(
                  icon: Icons.language_rounded,
                  title: 'ภาษาและภูมิภาค',
                  subtitle: 'กำหนดภาษาและรูปแบบตัวเลขที่แสดงในแอป',
                ),
                const SizedBox(height: 12),
                _SettingsGroup(
                  children: [
                    _SettingsActionTile(
                      icon: Icons.payments_outlined,
                      title: 'สกุลเงิน',
                      value: _currencyLabel(settings),
                      onTap: () =>
                          _selectCurrency(context, notifier, settings.currency),
                    ),
                    _SettingsActionTile(
                      icon: Icons.translate_rounded,
                      title: 'ภาษา',
                      value: settings.language == 'th' ? 'ไทย' : 'English',
                      onTap: () =>
                          _selectLanguage(context, notifier, settings.language),
                    ),
                  ],
                ),
                if (settings.currency == 'USD') ...[
                  const SizedBox(height: 10),
                  _ExchangeRateNote(
                    settings: settings,
                    onRefresh: notifier.refreshExchangeRate,
                  ),
                ],
                const SizedBox(height: 26),
                const _SectionTitle(
                  icon: Icons.tune_rounded,
                  title: 'การตั้งค่าขั้นสูง',
                  subtitle: 'จัดการรายละเอียดเพิ่มเติมของแอป',
                ),
                const SizedBox(height: 12),
                _SettingsGroup(
                  children: [
                    _SettingsActionTile(
                      icon: Icons.notifications_outlined,
                      title: 'รายการแจ้งเตือน',
                      value: 'จัดการ',
                      onTap: () => context.push('/notifications'),
                    ),
                    _SettingsActionTile(
                      icon: Icons.privacy_tip_outlined,
                      title: 'ความเป็นส่วนตัวและความปลอดภัย',
                      value: 'ตั้งค่า',
                      onTap: () => context.push('/privacy'),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                const Center(
                  child: Text(
                    'พี่เงิน · เวอร์ชัน 0.1.0',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  static String _currencyLabel(AppSettings settings) {
    return switch (settings.currency) {
      'USD' when settings.exchangeRateLoading => 'USD (\$) · กำลังอัปเดต',
      'USD' => 'USD (\$) · ${settings.usdRate.toStringAsFixed(4)}',
      _ => 'THB (฿)',
    };
  }

  static Future<void> _selectCurrency(
    BuildContext context,
    AppSettingsNotifier notifier,
    String current,
  ) async {
    final value = await _showPicker(
      context,
      title: 'เลือกสกุลเงิน',
      current: current,
      choices: const {
        'THB': 'THB (฿) — บาทไทย',
        'USD': 'USD (\$) — ดอลลาร์สหรัฐ',
      },
    );
    if (value == null || value == current || !context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('เปลี่ยนสกุลเงินที่แสดง'),
        content: const Text(
          'ยอดเดิมที่เก็บเป็นเงินบาทจะถูกคำนวณเป็นดอลลาร์ด้วยอัตราแลกเปลี่ยนล่าสุด และจำนวน USD ที่กรอกใหม่จะถูกแปลงกลับเป็นเงินบาทก่อนบันทึก',
        ),
        actions: [
          TextButton(
              onPressed: () => context.pop(false), child: const Text('ยกเลิก')),
          FilledButton(
              onPressed: () => context.pop(true), child: const Text('ยืนยัน')),
        ],
      ),
    );
    if (confirmed == true) await notifier.setCurrency(value);
  }

  static Future<void> _selectLanguage(
    BuildContext context,
    AppSettingsNotifier notifier,
    String current,
  ) async {
    final value = await _showPicker(
      context,
      title: 'เลือกภาษา',
      current: current,
      choices: const {'th': 'ไทย'},
    );
    if (value != null) await notifier.setLanguage(value);
  }

  static Future<String?> _showPicker(
    BuildContext context, {
    required String title,
    required String current,
    required Map<String, String> choices,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF202522),
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              for (final entry in choices.entries)
                ListTile(
                  onTap: () => context.pop(entry.key),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  leading: Icon(
                    entry.key == current
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: entry.key == current
                        ? const Color(0xFF4CD97B)
                        : Colors.white38,
                  ),
                  title: Text(entry.value,
                      style: const TextStyle(color: Colors.white)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExchangeRateNote extends StatelessWidget {
  const _ExchangeRateNote({
    required this.settings,
    required this.onRefresh,
  });

  final AppSettings settings;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final status = settings.exchangeRateStale ? 'อัตราสำรอง' : 'อัตราล่าสุด';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF17231D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF31533F)),
      ),
      child: Row(
        children: [
          const Icon(Icons.currency_exchange_rounded,
              color: Color(0xFF46D579), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '1 THB = ${settings.usdRate.toStringAsFixed(4)} USD\n$status · ${settings.exchangeRateDate}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
          IconButton(
            tooltip: 'อัปเดตอัตราแลกเปลี่ยน',
            onPressed: settings.exchangeRateLoading ? null : onRefresh,
            icon: settings.exchangeRateLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded, color: Colors.white54),
          ),
        ],
      ),
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
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : .42,
      child: SwitchListTile.adaptive(
        value: value,
        onChanged: enabled ? onChanged : null,
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
      ),
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
