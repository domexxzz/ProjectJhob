import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';

/// รายการค่าบริการรายเดือน (Netflix/Spotify/YouTube ฯลฯ) — เงินเป็นสตางค์
class Subscription {
  Subscription({
    required this.id,
    required this.name,
    required this.amount,
    required this.cycle,
    required this.nextBilling,
    this.logo,
  });

  final String id;
  final String name;
  final int amount; // satang ต่อรอบ
  final String cycle; // monthly | yearly
  final DateTime nextBilling;
  final String? logo;

  factory Subscription.fromJson(Map<String, dynamic> j) => Subscription(
        id: j['id'] as String,
        name: j['name'] as String,
        amount: j['amount'] as int,
        cycle: (j['cycle'] as String?) ?? 'monthly',
        nextBilling: DateTime.parse(j['nextBilling'] as String),
        logo: j['logo'] as String?,
      );
}

typedef SubscriptionList = ({List<Subscription> items, int totalMonthly});

class SubscriptionsRepository {
  SubscriptionsRepository(this._dio);
  final Dio _dio;

  Future<SubscriptionList> list() async {
    final res = await _dio.get('/subscriptions');
    final data = res.data as Map<String, dynamic>;
    final items = (data['subscriptions'] as List)
        .map((e) => Subscription.fromJson(e as Map<String, dynamic>))
        .toList();
    return (items: items, totalMonthly: (data['totalMonthly'] as int?) ?? 0);
  }

  Future<void> create({
    required String name,
    required int amount,
    String cycle = 'monthly',
    required DateTime nextBilling,
    String? logo,
  }) async {
    await _dio.post('/subscriptions', data: {
      'name': name,
      'amount': amount,
      'cycle': cycle,
      'nextBilling': nextBilling.toIso8601String(),
      if (logo != null && logo.isNotEmpty) 'logo': logo,
    });
  }

  Future<void> update(
    String id, {
    String? name,
    int? amount,
    String? cycle,
    DateTime? nextBilling,
    String? logo,
  }) async {
    await _dio.patch('/subscriptions/$id', data: {
      if (name != null) 'name': name,
      if (amount != null) 'amount': amount,
      if (cycle != null) 'cycle': cycle,
      if (nextBilling != null) 'nextBilling': nextBilling.toIso8601String(),
      if (logo != null) 'logo': logo,
    });
  }

  Future<void> delete(String id) async {
    await _dio.delete('/subscriptions/$id');
  }
}

final subscriptionsRepoProvider = Provider<SubscriptionsRepository>(
  (ref) => SubscriptionsRepository(ref.watch(dioProvider)),
);

final subscriptionsProvider = FutureProvider.autoDispose<SubscriptionList>(
  (ref) => ref.watch(subscriptionsRepoProvider).list(),
);
