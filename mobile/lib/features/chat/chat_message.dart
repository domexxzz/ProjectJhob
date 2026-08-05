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
  final String format; // xlsx | xml | pdf | docx | csv | json | txt | html
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

/// การ์ด "จดสำเร็จ" เมื่อพี่เงินบันทึกรายรับ-รายจ่ายให้ผ่านแชท (มีปุ่มลบ/แก้)
class TxnCard {
  TxnCard({
    required this.id,
    required this.type,
    required this.amountBaht,
    required this.category,
    required this.categoryId,
    required this.note,
    required this.date,
  });

  final String id;
  final String type; // income | expense
  final num amountBaht;
  final String category; // ชื่อหมวด (ไทย)
  final String? categoryId; // ให้แก้ไขโดยคงหมวดเดิม
  final String note;
  final String date; // YYYY-MM-DD

  bool get isIncome => type == 'income';

  factory TxnCard.fromJson(Map<String, dynamic> j) => TxnCard(
        id: j['id'] as String,
        type: (j['type'] ?? 'expense') as String,
        amountBaht: (j['amountBaht'] ?? 0) as num,
        category: (j['category'] ?? 'ไม่ระบุ') as String,
        categoryId: j['categoryId'] as String?,
        note: (j['note'] ?? '') as String,
        date: (j['date'] ?? '') as String,
      );
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.attachment,
    this.hasImage = false,
    this.cards = const [],
  });

  final String id;
  final String role; // user | assistant
  final String content;
  final DateTime createdAt;
  final ChatAttachment? attachment;
  final bool hasImage;
  final List<TxnCard> cards; // การ์ดรายการที่พี่เงินบันทึกให้ในข้อความนี้

  bool get isUser => role == 'user';

  factory ChatMessage.fromJson(Map<String, dynamic> j) {
    // attachment/cards ฝังมาใน context (JSON: {source, attachment, cards}) — ใช้ได้ทั้งข้อความใหม่และประวัติ
    ChatAttachment? att;
    bool hasImg = false;
    List<TxnCard> cards = const [];
    final ctx = j['context'];
    if (ctx is String && ctx.isNotEmpty) {
      try {
        final parsed = jsonDecode(ctx);
        if (parsed is Map) {
          if (parsed['attachment'] is Map) {
            att = ChatAttachment.fromJson(
                Map<String, dynamic>.from(parsed['attachment'] as Map));
          }
          if (parsed['hasImage'] == true) {
            hasImg = true;
          }
          if (parsed['cards'] is List) {
            cards = (parsed['cards'] as List)
                .whereType<Map>()
                .map((e) => TxnCard.fromJson(Map<String, dynamic>.from(e)))
                .toList();
          }
        }
      } catch (_) {}
    }
    return ChatMessage(
      id: j['id'] as String,
      role: j['role'] as String,
      content: j['content'] as String,
      createdAt: DateTime.parse(j['createdAt'] as String),
      attachment: att,
      hasImage: hasImg,
      cards: cards,
    );
  }
}
