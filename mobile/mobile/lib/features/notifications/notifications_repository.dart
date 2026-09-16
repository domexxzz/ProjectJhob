import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../settings/settings_screen.dart';

/// การแจ้งเตือน — ตรงกับ Notification model ฝั่ง backend
class AppNotification {
  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
  });

  final String id;
  final String
      type; // budget_near | budget_over | daily_summary | goal | subscription
  final String title;
  final String body;
  final bool read;
  final DateTime createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as String,
        type: (j['type'] as String?) ?? 'general',
        title: (j['title'] as String?) ?? '',
        body: (j['body'] as String?) ?? '',
        read: (j['read'] as bool?) ?? false,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

typedef NotificationList = ({List<AppNotification> items, int unreadCount});

class NotificationsRepository {
  NotificationsRepository(this._dio);
  final Dio _dio;

  Future<NotificationList> list() async {
    final res = await _dio.get('/notifications');
    final data = res.data as Map<String, dynamic>;
    final items = (data['notifications'] as List)
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
    return (items: items, unreadCount: (data['unreadCount'] as int?) ?? 0);
  }

  Future<void> markRead(String id) => _dio.patch('/notifications/$id/read');

  Future<void> markAllRead() => _dio.post('/notifications/read-all');

  /// ตรวจงบเดี๋ยวนี้ → สร้างแจ้งเตือน (ใช้เดโม/ทดสอบ เพราะ cron ปิดอยู่)
  Future<int> runTriggers({bool includeBudgetAlerts = true}) async {
    final res = await _dio.post('/notifications/run-triggers', data: {
      'includeBudgetAlerts': includeBudgetAlerts,
    });
    return ((res.data as Map<String, dynamic>)['created'] as int?) ?? 0;
  }
}

final notificationsRepoProvider = Provider<NotificationsRepository>(
  (ref) => NotificationsRepository(ref.watch(dioProvider)),
);

/// รายการ + จำนวนยังไม่อ่าน (ใช้ทั้งจอ Notification และ badge ในเมนู)
final notificationsProvider = FutureProvider.autoDispose<NotificationList>(
  (ref) async {
    final settings = ref.watch(appSettingsProvider);
    if (!settings.notifications) {
      return (items: <AppNotification>[], unreadCount: 0);
    }
    final data = await ref.watch(notificationsRepoProvider).list();
    final items = settings.budgetAlerts
        ? data.items
        : data.items
            .where((item) =>
                item.type != 'budget_near' && item.type != 'budget_over')
            .toList();
    return (
      items: items,
      unreadCount: items.where((item) => !item.read).length,
    );
  },
);
