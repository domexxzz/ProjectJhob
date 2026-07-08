import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import 'notifications_repository.dart';

/// ศูนย์การแจ้งเตือน — รายการแจ้งเตือน + อ่านแล้ว/ยังไม่อ่าน + อ่านทั้งหมด
/// backend: GET /notifications · PATCH /:id/read · POST /read-all · POST /run-triggers
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsProvider);
    final messenger = ScaffoldMessenger.of(context);

    Future<void> refresh() async {
      ref.invalidate(notificationsProvider);
      await ref.read(notificationsProvider.future);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text('การแจ้งเตือน', style: TextStyle(color: Colors.white)),
        actions: [
          // เดโม: ตรวจงบเดี๋ยวนี้ (cron ปิดอยู่ในเดฟ)
          IconButton(
            tooltip: 'ตรวจตอนนี้',
            icon: const Icon(Icons.bolt_outlined, color: AppColors.primary),
            onPressed: () async {
              try {
                final n = await ref.read(notificationsRepoProvider).runTriggers();
                await refresh();
                messenger.showSnackBar(SnackBar(
                  content: Text(n > 0 ? 'มีแจ้งเตือนใหม่ $n รายการ 🔔' : 'ยังไม่มีอะไรต้องเตือนตอนนี้ 👍'),
                ));
              } catch (_) {
                messenger.showSnackBar(const SnackBar(content: Text('ตรวจไม่สำเร็จ ลองใหม่อีกครั้ง')));
              }
            },
          ),
          TextButton(
            onPressed: () async {
              try {
                await ref.read(notificationsRepoProvider).markAllRead();
                await refresh();
              } catch (_) {
                messenger.showSnackBar(const SnackBar(content: Text('ทำเครื่องหมายไม่สำเร็จ')));
              }
            },
            child: const Text('อ่านทั้งหมด', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: refresh,
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (e, _) => ListView(children: [
            const SizedBox(height: 120),
            Center(child: Text('โหลดไม่ได้: $e', style: const TextStyle(color: Colors.redAccent))),
          ]),
          data: (data) {
            if (data.items.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 140),
                Icon(Icons.notifications_off_outlined, color: Colors.white24, size: 56),
                SizedBox(height: 12),
                Center(child: Text('ยังไม่มีการแจ้งเตือน', style: TextStyle(color: Colors.white54))),
              ]);
            }
            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: data.items.length,
              itemBuilder: (_, i) => _NotifCard(
                notif: data.items[i],
                onTap: () async {
                  if (!data.items[i].read) {
                    await ref.read(notificationsRepoProvider).markRead(data.items[i].id);
                    ref.invalidate(notificationsProvider);
                  }
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NotifCard extends StatelessWidget {
  const _NotifCard({required this.notif, required this.onTap});
  final AppNotification notif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _visual(notif.type);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          // ยังไม่อ่าน = พื้นเข้มอมเขียวจาง + ขอบเขียว
          color: notif.read ? const Color(0xFF1C1C1C) : const Color(0xFF122017),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: notif.read ? Colors.white.withOpacity(0.06) : AppColors.primary.withOpacity(0.35),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notif.title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: notif.read ? FontWeight.w600 : FontWeight.w800,
                          ),
                        ),
                      ),
                      if (!notif.read)
                        Container(
                          width: 9,
                          height: 9,
                          margin: const EdgeInsets.only(left: 6, top: 4),
                          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(notif.body, style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.35)),
                  const SizedBox(height: 6),
                  Text(_timeAgo(notif.createdAt), style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  (IconData, Color) _visual(String type) {
    switch (type) {
      case 'budget_over':
        return (Icons.error_outline, AppColors.expense);
      case 'budget_near':
        return (Icons.warning_amber_rounded, AppColors.warning);
      case 'subscription':
        return (Icons.receipt_long, AppColors.primary);
      case 'prediction':
        return (Icons.auto_graph, AppColors.warning);
      case 'goal':
        return (Icons.flag_rounded, AppColors.primary);
      case 'daily_summary':
        return (Icons.summarize_outlined, AppColors.primary);
      default:
        return (Icons.notifications_outlined, AppColors.primary);
    }
  }
}

/// เวลาแบบไทยสั้น ๆ: เมื่อสักครู่ / N นาที / N ชม. / N วัน / วันที่
String _timeAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'เมื่อสักครู่';
  if (d.inMinutes < 60) return '${d.inMinutes} นาทีที่แล้ว';
  if (d.inHours < 24) return '${d.inHours} ชม.ที่แล้ว';
  if (d.inDays < 7) return '${d.inDays} วันที่แล้ว';
  return '${t.day}/${t.month}/${t.year}';
}
