import 'dart:convert';

/// ไฟล์แนบที่พี่เงินสร้างให้ (Excel/XML) — มีปุ่มดาวน์โหลดในฟองแชท
class ChatAttachment {
  ChatAttachment({
    required this.kind,
    required this.format,
    required this.filename,
    required this.label,
    required this.token,
  });

  final String kind; // budget | transactions | summary | subscriptions
  final String format; // xlsx | xml
  final String filename;
  final String label;
  final String token; // download token (ต่อกับ URL export)

  factory ChatAttachment.fromJson(Map<String, dynamic> j) => ChatAttachment(
        kind: j['kind'] as String,
        format: j['format'] as String,
        filename: (j['filename'] ?? '') as String,
        label: (j['label'] ?? '') as String,
        token: j['token'] as String,
      );
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.attachment,
  });

  final String id;
  final String role; // user | assistant
  final String content;
  final DateTime createdAt;
  final ChatAttachment? attachment;

  bool get isUser => role == 'user';

  factory ChatMessage.fromJson(Map<String, dynamic> j) {
    // attachment ฝังมาใน context (JSON: {source, attachment}) — ใช้ได้ทั้งข้อความใหม่และประวัติ
    ChatAttachment? att;
    final ctx = j['context'];
    if (ctx is String && ctx.isNotEmpty) {
      try {
        final parsed = jsonDecode(ctx);
        if (parsed is Map && parsed['attachment'] is Map) {
          att = ChatAttachment.fromJson(Map<String, dynamic>.from(parsed['attachment'] as Map));
        }
      } catch (_) {}
    }
    return ChatMessage(
      id: j['id'] as String,
      role: j['role'] as String,
      content: j['content'] as String,
      createdAt: DateTime.parse(j['createdAt'] as String),
      attachment: att,
    );
  }
}
