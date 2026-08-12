import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import 'chat_message.dart';
import 'chat_session.dart';

class ChatRepository {
  ChatRepository(this._dio);
  final Dio _dio;

  Future<List<ChatMessage>> history() async {
    final res = await _dio.get('/chat');
    return ((res.data as Map<String, dynamic>)['messages'] as List)
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── ห้องแชท (session) ──────────────────────────────────────────────────────

  Future<List<ChatSession>> listSessions() async {
    final res = await _dio.get('/chat/sessions');
    return ((res.data as Map<String, dynamic>)['sessions'] as List)
        .map((e) => ChatSession.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<ChatSession> createSession() async {
    final res = await _dio.post('/chat/sessions', data: {});
    return ChatSession.fromJson(Map<String, dynamic>.from(
        (res.data as Map<String, dynamic>)['session'] as Map));
  }

  Future<void> renameSession(String id, String title) =>
      _dio.patch('/chat/sessions/$id', data: {'title': title});

  Future<void> deleteSession(String id) => _dio.delete('/chat/sessions/$id');

  /// ข้อความของห้องใดห้องหนึ่ง (ไม่ระบุ = ทุกห้องรวมกัน แบบเดิม)
  Future<List<ChatMessage>> historyOf(String? sessionId) async {
    final res = await _dio.get('/chat',
        queryParameters: sessionId == null ? null : {'sessionId': sessionId});
    return ((res.data as Map<String, dynamic>)['messages'] as List)
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── แกลเลอรี ───────────────────────────────────────────────────────────────

  Future<List<ChatMedia>> listMedia() async {
    final res = await _dio.get('/chat/media');
    return ((res.data as Map<String, dynamic>)['media'] as List)
        .map((e) => ChatMedia.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<ChatFile>> listFiles() async {
    final res = await _dio.get('/chat/files');
    return ((res.data as Map<String, dynamic>)['files'] as List)
        .map((e) => ChatFile.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<ChatMessage> send(
    String message, {
    String? imageBase64,
    String? thumbnail, // รูปย่อไว้โชว์ในแกลเลอรี
    String? sessionId, // ห้องที่ส่งเข้า
    String? slipType, // 'income' | 'expense' — ผู้ใช้เลือกตอนแนบสลิป
    bool includeFinancialContext = true,
    bool personalizedRecommendations = true,
    bool storeConversationHistory = true,
    CancelToken? cancelToken,
  }) async {
    final res = await _dio.post(
      '/chat',
      data: {
        'message': message,
        if (imageBase64 != null) 'imageBase64': imageBase64,
        if (thumbnail != null) 'thumbnail': thumbnail,
        if (sessionId != null) 'sessionId': sessionId,
        if (slipType != null) 'slipType': slipType,
        'includeFinancialContext': includeFinancialContext,
        'personalizedRecommendations': personalizedRecommendations,
        'storeConversationHistory': storeConversationHistory,
      },
      cancelToken: cancelToken,
    );
    return ChatMessage.fromJson(
        (res.data as Map<String, dynamic>)['message'] as Map<String, dynamic>);
  }

  /// ส่งรูป (data URL) ให้ backend OCR ด้วย Typhoon OCR → คืนข้อความที่อ่านได้
  Future<String> ocrImage(String dataUrl) async {
    final res = await _dio.post('/chat/ocr', data: {'imageBase64': dataUrl});
    return ((res.data as Map<String, dynamic>)['text'] as String?) ?? '';
  }
}

final chatRepoProvider =
    Provider<ChatRepository>((ref) => ChatRepository(ref.watch(dioProvider)));
