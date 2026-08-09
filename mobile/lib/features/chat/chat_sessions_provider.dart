import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'chat_repository.dart';
import 'chat_session.dart';

/// ห้องที่กำลังเปิดอยู่ (null = ยังไม่ได้เลือก → backend จะใช้ห้องล่าสุด/สร้างใหม่)
final currentSessionIdProvider = StateProvider<String?>((ref) => null);

/// เปิด/ปิด sidebar
final sidebarOpenProvider = StateProvider<bool>((ref) => false);

/// รายการห้องแชททั้งหมด
final chatSessionsProvider =
    FutureProvider.autoDispose<List<ChatSession>>((ref) async {
  return ref.watch(chatRepoProvider).listSessions();
});

/// รูปที่ผู้ใช้เคยส่ง
final chatMediaProvider = FutureProvider.autoDispose<List<ChatMedia>>((ref) {
  return ref.watch(chatRepoProvider).listMedia();
});

/// ไฟล์ที่พี่เงินเคยสร้างให้
final chatFilesProvider = FutureProvider.autoDispose<List<ChatFile>>((ref) {
  return ref.watch(chatRepoProvider).listFiles();
});

/// ย่อรูปให้เล็กก่อนเก็บลงแกลเลอรี (กันฐานข้อมูลบวม)
/// ใช้ dart:ui ล้วน ไม่ต้องเพิ่ม dependency — คืน data URL ของ PNG กว้างไม่เกิน [maxWidth]
Future<String?> makeThumbnail(String dataUrl, {int maxWidth = 240}) async {
  try {
    final comma = dataUrl.indexOf(',');
    if (comma < 0) return null;
    final bytes = base64Decode(dataUrl.substring(comma + 1));

    final codec = await ui.instantiateImageCodec(
      Uint8List.fromList(bytes),
      targetWidth: maxWidth,
    );
    final frame = await codec.getNextFrame();
    final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    frame.image.dispose();
    codec.dispose();
    if (png == null) return null;

    final out = base64Encode(png.buffer.asUint8List());
    // เผื่อรูปย่อยังใหญ่เกินไป (ภาพซับซ้อน) — ไม่เก็บดีกว่าทำให้ request ใหญ่
    if (out.length > 350000) return null;
    return 'data:image/png;base64,$out';
  } catch (_) {
    return null; // ย่อไม่สำเร็จก็ไม่เป็นไร แค่ไม่มีรูปในแกลเลอรี
  }
}
