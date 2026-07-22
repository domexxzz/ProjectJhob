import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import 'predictions_model.dart';

class PredictionsRepository {
  final Dio _dio;

  PredictionsRepository(this._dio);

  Future<PredictionsResponse> getPredictions() async {
    try {
      final response = await _dio.get('/predictions');
      return PredictionsResponse.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }
}

final predictionsRepoProvider = Provider<PredictionsRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return PredictionsRepository(dio);
});

final predictionsProvider = FutureProvider<PredictionsResponse>((ref) async {
  final repository = ref.watch(predictionsRepoProvider);
  return repository.getPredictions();
});
