import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import 'chat_message.dart';

class ChatRepository {
  ChatRepository(this._dio);
  final Dio _dio;

  Future<List<ChatMessage>> history() async {
    final res = await _dio.get('/chat');
    return ((res.data as Map<String, dynamic>)['messages'] as List)
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ChatMessage> send(String message) async {
    final res = await _dio.post('/chat', data: {'message': message});
    return ChatMessage.fromJson((res.data as Map<String, dynamic>)['message'] as Map<String, dynamic>);
  }

  /// ส่งรูป (data URL) ให้ backend OCR ด้วย Typhoon OCR → คืนข้อความที่อ่านได้
  Future<String> ocrImage(String dataUrl) async {
    final res = await _dio.post('/chat/ocr', data: {'imageBase64': dataUrl});
    return ((res.data as Map<String, dynamic>)['text'] as String?) ?? '';
  }
}

final chatRepoProvider =
    Provider<ChatRepository>((ref) => ChatRepository(ref.watch(dioProvider)));
