import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';

import 'chat_repository.dart';
import 'chat_session.dart';
import 'chat_sessions_provider.dart';

const _bg = Color(0xFF11181C);
const _card = Color(0xFF1A2430);
const _green = Color(0xFF3CAE63);
const _greenLight = Color(0xFF4CD97B);

/// แถบข้างของหน้าแชท — รายการห้องสนทนา + รูปที่เคยส่ง + ไฟล์ที่พี่เงินสร้าง
class ChatSidebar extends ConsumerStatefulWidget {
  const ChatSidebar({
    super.key,
    required this.onSelectSession,
    required this.onNewChat,
    required this.onClose,
  });

  final ValueChanged<String> onSelectSession;
  final VoidCallback onNewChat;
  final VoidCallback onClose;

  @override
  ConsumerState<ChatSidebar> createState() => _ChatSidebarState();
}

class _ChatSidebarState extends ConsumerState<ChatSidebar> {
  int _tab = 0; // 0 = แชท · 1 = รูป · 2 = ไฟล์
  String? _mediaFilter; // null = ทุกแชท
  String? _fileFilter;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _bg,
      child: SafeArea(
        child: Column(
          children: [
            _header(),
            _tabBar(),
            const Divider(height: 1, color: Color(0xFF243040)),
            Expanded(
              child: switch (_tab) {
                1 => _mediaTab(),
                2 => _filesTab(),
                _ => _sessionsTab(),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 6),
        child: Row(
          children: [
            const Expanded(
              child: Text('พี่เงิน',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ),
            IconButton(
              tooltip: 'ปิดแถบข้าง',
              onPressed: widget.onClose,
              icon: const Icon(Icons.chevron_left_rounded,
                  color: Colors.white70, size: 26),
            ),
          ],
        ),
      );

  Widget _tabBar() => Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        child: Row(
          children: [
            _tabChip(0, Icons.forum_rounded, 'แชท'),
            const SizedBox(width: 6),
            _tabChip(1, Icons.image_rounded, 'รูป'),
            const SizedBox(width: 6),
            _tabChip(2, Icons.insert_drive_file_rounded, 'ไฟล์'),
          ],
        ),
      );

  Widget _tabChip(int index, IconData icon, String label) {
    final active = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? _green.withValues(alpha: 0.18) : _card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: active ? _greenLight : const Color(0xFF243040)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 17, color: active ? _greenLight : Colors.white54),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      color: active ? _greenLight : Colors.white54,
                      fontWeight:
                          active ? FontWeight.bold : FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  // ── แท็บ 1: รายการห้องแชท ──────────────────────────────────────────────────
  Widget _sessionsTab() {
    final sessions = ref.watch(chatSessionsProvider);
    final currentId = ref.watch(currentSessionIdProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: widget.onNewChat,
              icon: const Icon(Icons.add_rounded, size: 19),
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13)),
              ),
              label: const Text('แชทใหม่',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ),
        Expanded(
          child: sessions.when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: _green, strokeWidth: 2)),
            error: (e, _) => _errorBox('โหลดรายการแชทไม่ได้',
                () => ref.invalidate(chatSessionsProvider)),
            data: (list) {
              if (list.isEmpty) {
                return _emptyBox(Icons.forum_outlined,
                    'ยังไม่มีบทสนทนา', 'กด "แชทใหม่" เพื่อเริ่มคุยกับพี่เงิน');
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final s = list[i];
                  final active = s.id == currentId;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: active ? _green.withValues(alpha: 0.15) : null,
                      borderRadius: BorderRadius.circular(11),
                      border: active
                          ? Border.all(color: _greenLight.withValues(alpha: 0.6))
                          : null,
                    ),
                    child: ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11)),
                      title: Text(s.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: active ? Colors.white : Colors.white70,
                              fontSize: 14,
                              fontWeight: active
                                  ? FontWeight.bold
                                  : FontWeight.w500)),
                      subtitle: Text(
                        '${s.messageCount} ข้อความ · ${_relative(s.updatedAt)}',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11),
                      ),
                      onTap: () => widget.onSelectSession(s.id),
                      trailing: IconButton(
                        tooltip: 'ตัวเลือก',
                        icon: const Icon(Icons.more_horiz_rounded,
                            color: Colors.white38, size: 19),
                        onPressed: () => _sessionMenu(s),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _sessionMenu(ChatSession s) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline_rounded,
                  color: Colors.white70),
              title: const Text('เปลี่ยนชื่อ',
                  style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, 'rename'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: Color(0xFFFF6B6B)),
              title: const Text('ลบบทสนทนานี้',
                  style: TextStyle(color: Color(0xFFFF6B6B))),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;

    final repo = ref.read(chatRepoProvider);
    if (action == 'rename') {
      final ctrl = TextEditingController(text: s.title);
      final name = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: _card,
          title: const Text('เปลี่ยนชื่อบทสนทนา',
              style: TextStyle(color: Colors.white, fontSize: 17)),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            maxLength: 80,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(counterText: ''),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('ยกเลิก')),
            TextButton(
                onPressed: () => Navigator.pop(context, ctrl.text.trim()),
                child: const Text('บันทึก')),
          ],
        ),
      );
      if (name != null && name.isNotEmpty) {
        await repo.renameSession(s.id, name);
        ref.invalidate(chatSessionsProvider);
      }
    } else if (action == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: _card,
          title: const Text('ลบบทสนทนา?',
              style: TextStyle(color: Colors.white, fontSize: 17)),
          content: Text('"${s.title}" และข้อความทั้งหมดในนี้จะถูกลบถาวร',
              style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('ยกเลิก')),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('ลบ',
                    style: TextStyle(color: Color(0xFFFF6B6B)))),
          ],
        ),
      );
      if (ok == true) {
        await repo.deleteSession(s.id);
        if (ref.read(currentSessionIdProvider) == s.id) {
          ref.read(currentSessionIdProvider.notifier).state = null;
        }
        ref.invalidate(chatSessionsProvider);
      }
    }
  }


  /// แถบเลือกกรองตามห้องแชท — สร้างรายการจากข้อมูลที่โหลดมาเลย ไม่ต้องยิง API เพิ่ม
  Widget _sessionFilterBar({
    required List<({String? id, String title})> options,
    required String? selected,
    required ValueChanged<String?> onChanged,
  }) {
    if (options.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
        itemCount: options.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final opt = i == 0 ? (id: null, title: 'ทุกแชท') : options[i - 1];
          final active = selected == opt.id;
          return GestureDetector(
            onTap: () => onChanged(opt.id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: active ? _green.withValues(alpha: 0.20) : _card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: active ? _greenLight : const Color(0xFF243040)),
              ),
              child: Text(
                opt.title,
                style: TextStyle(
                  fontSize: 11.5,
                  color: active ? _greenLight : Colors.white60,
                  fontWeight: active ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// รวมรายชื่อห้องที่ปรากฏในข้อมูล (ไม่ซ้ำ เรียงตามที่เจอ)
  List<({String? id, String title})> _optionsFrom(
      Iterable<({String? id, String? title})> items) {
    final seen = <String>{};
    final out = <({String? id, String title})>[];
    for (final it in items) {
      final id = it.id;
      if (id == null || !seen.add(id)) continue;
      out.add((id: id, title: it.title?.trim().isNotEmpty == true ? it.title! : 'ไม่มีชื่อ'));
    }
    return out;
  }

  // ── แท็บ 2: รูปที่ผู้ใช้เคยส่ง ──────────────────────────────────────────────
  Widget _mediaTab() {
    final media = ref.watch(chatMediaProvider);
    return media.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: _green, strokeWidth: 2)),
      error: (e, _) =>
          _errorBox('โหลดรูปไม่ได้', () => ref.invalidate(chatMediaProvider)),
      data: (list) {
        if (list.isEmpty) {
          return _emptyBox(Icons.image_outlined, 'ยังไม่มีรูป',
              'รูปสลิป/ใบเสร็จที่ส่งให้พี่เงินจะมาอยู่ที่นี่');
        }
        final options =
            _optionsFrom(list.map((m) => (id: m.sessionId, title: m.sessionTitle)));
        final shown = _mediaFilter == null
            ? list
            : list.where((m) => m.sessionId == _mediaFilter).toList();
        return Column(children: [
          _sessionFilterBar(
            options: options,
            selected: _mediaFilter,
            onChanged: (v) => setState(() => _mediaFilter = v),
          ),
          if (shown.isEmpty)
            Expanded(
                child: _emptyBox(Icons.filter_alt_off_rounded, 'ไม่มีรูปในแชทนี้',
                    'ลองเลือก "ทุกแชท" ดูครับ'))
          else
            Expanded(
              child: GridView.builder(
          padding: const EdgeInsets.all(10),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: shown.length,
          itemBuilder: (_, i) {
            final m = shown[i];
            return GestureDetector(
              onTap: () => _previewMedia(m),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _thumb(m.thumbnail),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        color: Colors.black.withValues(alpha: 0.55),
                        child: Text(
                          DateFormat('d MMM', 'th').format(m.createdAt),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
                },
              ),
            ),
        ]);
      },
    );
  }

  Widget _thumb(String dataUrl) {
    final comma = dataUrl.indexOf(',');
    if (comma < 0) {
      return Container(color: _card, child: const Icon(Icons.broken_image_outlined, color: Colors.white24));
    }
    try {
      return Image.memory(base64Decode(dataUrl.substring(comma + 1)),
          fit: BoxFit.cover, gaplessPlayback: true);
    } catch (_) {
      return Container(
          color: _card,
          child: const Icon(Icons.broken_image_outlined, color: Colors.white24));
    }
  }

  void _previewMedia(ChatMedia m) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: _card,
        insetPadding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(4)),
              child: SizedBox(height: 300, width: double.infinity, child: _thumb(m.thumbnail)),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('d MMM y · HH:mm', 'th').format(m.createdAt),
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  if ((m.ocrPreview ?? '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('ข้อความที่อ่านได้: ${m.ocrPreview}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13, height: 1.4)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  IconData _fileIcon(String format) => switch (format) {
        'pdf' => Icons.picture_as_pdf_rounded,
        'xlsx' || 'csv' => Icons.table_chart_rounded,
        'docx' || 'txt' || 'html' => Icons.description_rounded,
        _ => Icons.code_rounded,
      };

  /// เปิดไฟล์ที่พี่เงินสร้างไว้ — ใช้ URL เดียวกับปุ่มดาวน์โหลดในฟองแชท
  Future<void> _downloadFile(ChatFile f) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!f.downloadable) {
      messenger.showSnackBar(const SnackBar(
        content: Text('ไฟล์นี้สร้างไว้ก่อนอัปเดตระบบ จึงโหลดซ้ำไม่ได้ '
            '— บอกพี่เงินให้สร้างใหม่ได้เลยครับ'),
        duration: Duration(seconds: 4),
      ));
      return;
    }
    final url =
        '$kApiBaseUrl/api/v1/export/${f.kind}?format=${f.format}&dt=${f.token}';
    try {
      final ok = await launchUrl(
        Uri.parse(url),
        webOnlyWindowName: '_blank',
        mode: LaunchMode.externalApplication,
      );
      if (!ok && mounted) {
        messenger.showSnackBar(const SnackBar(
            content: Text('เปิดไฟล์ไม่ได้ ลองใหม่อีกครั้งครับ')));
      }
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(const SnackBar(
            content: Text('ดาวน์โหลดไม่สำเร็จ — ไฟล์อาจหมดอายุแล้ว')));
      }
    }
  }

  // ── แท็บ 3: ไฟล์ที่พี่เงินสร้างให้ ──────────────────────────────────────────
  Widget _filesTab() {
    final files = ref.watch(chatFilesProvider);
    return files.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: _green, strokeWidth: 2)),
      error: (e, _) =>
          _errorBox('โหลดไฟล์ไม่ได้', () => ref.invalidate(chatFilesProvider)),
      data: (list) {
        if (list.isEmpty) {
          return _emptyBox(Icons.folder_open_rounded, 'ยังไม่มีไฟล์',
              'ลองบอกพี่เงินว่า "ขอไฟล์ Excel สรุปรายจ่าย"');
        }
        final options =
            _optionsFrom(list.map((f) => (id: f.sessionId, title: f.sessionTitle)));
        final shown = _fileFilter == null
            ? list
            : list.where((f) => f.sessionId == _fileFilter).toList();
        return Column(children: [
          _sessionFilterBar(
            options: options,
            selected: _fileFilter,
            onChanged: (v) => setState(() => _fileFilter = v),
          ),
          if (shown.isEmpty)
            Expanded(
                child: _emptyBox(Icons.filter_alt_off_rounded,
                    'ไม่มีไฟล์ในแชทนี้', 'ลองเลือก "ทุกแชท" ดูครับ'))
          else
            Expanded(
              child: ListView.separated(
          padding: const EdgeInsets.all(10),
          itemCount: shown.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (_, i) {
            final f = shown[i];
            return Container(
              decoration: BoxDecoration(
                  color: _card, borderRadius: BorderRadius.circular(11)),
              child: ListTile(
                dense: true,
                onTap: () => _downloadFile(f),
                trailing: IconButton(
                  tooltip: f.downloadable ? 'ดาวน์โหลด' : 'โหลดซ้ำไม่ได้',
                  icon: Icon(
                      f.downloadable
                          ? Icons.download_rounded
                          : Icons.refresh_rounded,
                      color: f.downloadable ? _greenLight : Colors.white30,
                      size: 21),
                  onPressed: () => _downloadFile(f),
                ),
                leading: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                      color: _green.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(9)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_fileIcon(f.format), color: _greenLight, size: 16),
                      const SizedBox(height: 1),
                      Text(f.format.toUpperCase(),
                          style: const TextStyle(
                              color: _greenLight,
                              fontSize: 8,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                title: Text(f.label.isNotEmpty ? f.label : f.filename,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13.5)),
                subtitle: Text(
                    '${DateFormat('d MMM y', 'th').format(f.createdAt)}'
                    '${f.sessionTitle != null ? ' · ${f.sessionTitle}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 11)),
              ),
            );
                },
              ),
            ),
        ]);
      },
    );
  }

  // ── ชิ้นส่วนร่วม ───────────────────────────────────────────────────────────
  Widget _emptyBox(IconData icon, String title, String hint) => Center(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white24, size: 42),
              const SizedBox(height: 10),
              Text(title,
                  style: const TextStyle(color: Colors.white54, fontSize: 14)),
              const SizedBox(height: 5),
              Text(hint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white30, fontSize: 12)),
            ],
          ),
        ),
      );

  Widget _errorBox(String msg, VoidCallback retry) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(msg, style: const TextStyle(color: Colors.white54)),
            TextButton(onPressed: retry, child: const Text('ลองใหม่')),
          ],
        ),
      );

  String _relative(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'เมื่อครู่';
    if (d.inHours < 1) return '${d.inMinutes} นาทีที่แล้ว';
    if (d.inDays < 1) return '${d.inHours} ชม.ที่แล้ว';
    if (d.inDays < 7) return '${d.inDays} วันที่แล้ว';
    return DateFormat('d MMM', 'th').format(t);
  }
}
