/// ห้องแชท 1 ห้อง (บทสนทนา) — ผู้ใช้สร้างใหม่ได้เรื่อย ๆ
class ChatSession {
  ChatSession({
    required this.id,
    required this.title,
    required this.updatedAt,
    this.messageCount = 0,
  });

  final String id;
  final String title;
  final DateTime updatedAt;
  final int messageCount;

  factory ChatSession.fromJson(Map<String, dynamic> j) => ChatSession(
        id: j['id'] as String,
        title: (j['title'] ?? 'แชทใหม่') as String,
        updatedAt:
            DateTime.tryParse('${j['updatedAt']}')?.toLocal() ?? DateTime.now(),
        messageCount: (j['messageCount'] ?? 0) as int,
      );
}

/// รูปที่ผู้ใช้เคยส่งเข้าแชท (เก็บเป็นรูปย่อ)
class ChatMedia {
  ChatMedia({
    required this.id,
    required this.thumbnail,
    required this.createdAt,
    this.sessionId,
    this.caption,
    this.ocrPreview,
  });

  final String id;
  final String thumbnail; // data URL
  final DateTime createdAt;
  final String? sessionId;
  final String? caption;
  final String? ocrPreview;

  factory ChatMedia.fromJson(Map<String, dynamic> j) => ChatMedia(
        id: j['id'] as String,
        thumbnail: (j['thumbnail'] ?? '') as String,
        createdAt:
            DateTime.tryParse('${j['createdAt']}')?.toLocal() ?? DateTime.now(),
        sessionId: j['sessionId'] as String?,
        caption: j['caption'] as String?,
        ocrPreview: j['ocrPreview'] as String?,
      );
}

/// ไฟล์ที่พี่เงินสร้างให้ (Excel/PDF/CSV ฯลฯ)
class ChatFile {
  ChatFile({
    required this.id,
    required this.format,
    required this.filename,
    required this.label,
    required this.token,
    required this.createdAt,
    this.sessionId,
  });

  final String id;
  final String format;
  final String filename;
  final String label;
  final String token;
  final DateTime createdAt;
  final String? sessionId;

  factory ChatFile.fromJson(Map<String, dynamic> j) => ChatFile(
        id: j['id'] as String,
        format: (j['format'] ?? '') as String,
        filename: (j['filename'] ?? '') as String,
        label: (j['label'] ?? '') as String,
        token: (j['token'] ?? '') as String,
        createdAt:
            DateTime.tryParse('${j['createdAt']}')?.toLocal() ?? DateTime.now(),
        sessionId: j['sessionId'] as String?,
      );
}
