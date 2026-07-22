import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../core/api/api_client.dart';
import 'transaction.dart';

typedef DashboardData = ({List<Txn> items, TxnSummary summary});

class AnalyzedSlip {
  AnalyzedSlip({this.amount, this.date, this.ref, this.merchant, this.categoryId});
  final int? amount;
  final String? date;
  final String? ref;
  final String? merchant;
  final String? categoryId;

  factory AnalyzedSlip.fromJson(Map<String, dynamic> j) => AnalyzedSlip(
        amount: j['amount'] as int?,
        date: j['date'] as String?,
        ref: j['ref'] as String?,
        merchant: j['merchant'] as String?,
        categoryId: j['categoryId'] as String?,
      );
}

class TransactionsRepository {
  TransactionsRepository(this._dio);
  final Dio _dio;

  Future<Box> _getCacheBox() => Hive.openBox('cache');
  Future<Box> _getPendingBox() => Hive.openBox('pending_sync');

  Future<DashboardData> list({String? month, String? type}) async {
    final cacheBox = await _getCacheBox();
    final cacheKey = 'txns_${month ?? 'all'}_${type ?? 'all'}';

    try {
      final res = await _dio.get('/transactions', queryParameters: {
        if (month != null) 'month': month,
        if (type != null) 'type': type,
      });
      final data = res.data as Map<String, dynamic>;
      
      // Save raw JSON to cache for offline-first read
      await cacheBox.put(cacheKey, jsonEncode(data));

      return _parseDashboardData(data);
    } catch (e) {
      // Offline fallback: read from Hive cache
      final cachedJson = cacheBox.get(cacheKey) as String?;
      if (cachedJson != null) {
        final decoded = jsonDecode(cachedJson) as Map<String, dynamic>;
        return _parseDashboardData(decoded);
      }
      rethrow;
    }
  }

  DashboardData _parseDashboardData(Map<String, dynamic> data) {
    final items = (data['transactions'] as List)
        .map((e) => Txn.fromJson(e as Map<String, dynamic>))
        .toList();
    return (
      items: items, 
      summary: TxnSummary.fromJson(data['summary'] as Map<String, dynamic>)
    );
  }

  Future<String?> create({
    required String type,
    required int amount,
    String? categoryId,
    String? note,
    String source = 'manual',
    DateTime? occurredAt,
  }) async {
    final payload = {
      'type': type,
      'amount': amount,
      if (categoryId != null) 'categoryId': categoryId,
      if (note != null && note.isNotEmpty) 'note': note,
      'source': source,
      if (occurredAt != null) 'occurredAt': occurredAt.toIso8601String(),
    };

    try {
      final res = await _dio.post('/transactions', data: payload);
      final data = res.data as Map<String, dynamic>;
      return data['anomalyAlert'] as String?;
    } catch (e) {
      // Offline fallback: Queue write operation
      final pendingBox = await _getPendingBox();
      final pendingActions = pendingBox.get('actions', defaultValue: []) as List;
      pendingActions.add({
        'action': 'create',
        'data': payload,
        'timestamp': DateTime.now().toIsoformatString(),
      });
      await pendingBox.put('actions', pendingActions);
      return null;
    }
  }

  Future<String?> update(
    String id, {
    required String type,
    required int amount,
    String? categoryId,
    String? note,
  }) async {
    final payload = {
      'type': type,
      'amount': amount,
      'categoryId': categoryId,
      'note': note ?? '',
    };

    try {
      final res = await _dio.patch('/transactions/$id', data: payload);
      final data = res.data as Map<String, dynamic>;
      return data['anomalyAlert'] as String?;
    } catch (e) {
      final pendingBox = await _getPendingBox();
      final pendingActions = pendingBox.get('actions', defaultValue: []) as List;
      pendingActions.add({
        'action': 'update',
        'id': id,
        'data': payload,
        'timestamp': DateTime.now().toIsoformatString(),
      });
      await pendingBox.put('actions', pendingActions);
      return null;
    }
  }

  Future<void> delete(String id) async {
    try {
      await _dio.delete('/transactions/$id');
    } catch (e) {
      final pendingBox = await _getPendingBox();
      final pendingActions = pendingBox.get('actions', defaultValue: []) as List;
      pendingActions.add({
        'action': 'delete',
        'id': id,
        'timestamp': DateTime.now().toIsoformatString(),
      });
      await pendingBox.put('actions', pendingActions);
    }
  }

  /// Sync pending offline actions with server
  Future<void> syncPending() async {
    final pendingBox = await _getPendingBox();
    final pendingActions = pendingBox.get('actions', defaultValue: []) as List;
    if (pendingActions.isEmpty) return;

    final List failedActions = [];

    for (final act in pendingActions) {
      final map = act as Map;
      final action = map['action'] as String;
      try {
        if (action == 'create') {
          await _dio.post('/transactions', data: map['data']);
        } else if (action == 'update') {
          await _dio.patch('/transactions/${map['id']}', data: map['data']);
        } else if (action == 'delete') {
          await _dio.delete('/transactions/${map['id']}');
        }
      } catch (e) {
        // Keep in queue if server error
        failedActions.add(act);
      }
    }

    await pendingBox.put('actions', failedActions);
  }

  Future<List<Category>> categories() async {
    try {
      final res = await _dio.get('/categories');
      final cats = ((res.data as Map<String, dynamic>)['categories'] as List)
          .map((e) => Category.fromJson(e as Map<String, dynamic>))
          .toList();
      return cats;
    } catch (e) {
      // Fallback
      return [];
    }
  }

  Future<AnalyzedSlip> analyzeText(String text) async {
    final res = await _dio.post('/transactions/analyze-text', data: {'text': text});
    return AnalyzedSlip.fromJson(res.data as Map<String, dynamic>);
  }

  /// อัพสลิป (data URL) → backend OCR + ดึงยอด/วันที่/ร้าน/หมวด (เรียกครั้งเดียว)
  Future<AnalyzedSlip> parseSlip(String dataUrl) async {
    final res = await _dio.post('/transactions/parse-slip', data: {'imageBase64': dataUrl});
    return AnalyzedSlip.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<Budget>> listBudgets() async {
    try {
      final res = await _dio.get('/budgets');
      final list = ((res.data as Map<String, dynamic>)['budgets'] as List)
          .map((e) => Budget.fromJson(e as Map<String, dynamic>))
          .toList();
      return list;
    } catch (e) {
      return [];
    }
  }

  Future<List<BudgetStatus>> listBudgetStatuses({String? period}) async {
    try {
      final res = await _dio.get('/budgets/status', queryParameters: {
        if (period != null) 'period': period,
      });
      final list = ((res.data as Map<String, dynamic>)['budgetsStatus'] as List)
          .map((e) => BudgetStatus.fromJson(e as Map<String, dynamic>))
          .toList();
      return list;
    } catch (e) {
      return [];
    }
  }
}

extension on DateTime {
  String toIsoformatString() => toIso8601String();
}

enum DashboardPeriod { day, week, month }

final dashboardPeriodProvider = StateProvider<DashboardPeriod>((ref) => DashboardPeriod.month);

final transactionsRepoProvider =
    Provider<TransactionsRepository>((ref) => TransactionsRepository(ref.watch(dioProvider)));

final dashboardProvider =
    FutureProvider.autoDispose<DashboardData>((ref) async {
  final repo = ref.watch(transactionsRepoProvider);
  // Auto-sync pending actions before fetching
  await repo.syncPending();
  return repo.list();
});

final categoriesProvider =
    FutureProvider.autoDispose<List<Category>>((ref) => ref.watch(transactionsRepoProvider).categories());

final budgetsListProvider = FutureProvider.autoDispose<List<Budget>>((ref) async {
  final repo = ref.watch(transactionsRepoProvider);
  return repo.listBudgets();
});

final budgetStatusProvider = Provider.autoDispose<List<BudgetStatus>>((ref) {
  final budgetsAsync = ref.watch(budgetsListProvider);
  final dashboardAsync = ref.watch(dashboardProvider);

  if (budgetsAsync.hasError || dashboardAsync.hasError) return [];
  final budgets = budgetsAsync.value ?? [];
  final transactions = dashboardAsync.value?.items ?? [];

  final now = DateTime.now();
  
  final startOfMonth = DateTime(now.year, now.month, 1);
  final endOfMonth = DateTime(now.year, now.month + 1, 1);

  final day = now.weekday; // 1 is Monday, 7 is Sunday
  final startOfWeek = DateTime(now.year, now.month, now.day - (day - 1));
  final endOfWeek = startOfWeek.add(const Duration(days: 7));

  return budgets.map((b) {
    final isWeekly = b.period == 'weekly';
    final start = isWeekly ? startOfWeek : startOfMonth;
    final end = isWeekly ? endOfWeek : endOfMonth;

    final filtered = transactions.where((t) {
      if (t.type != 'expense') return false;
      if (t.occurredAt.isBefore(start) || t.occurredAt.isAfter(end)) return false;
      if (b.categoryId != null && t.category?.id != b.categoryId) return false;
      return true;
    });

    final spent = filtered.fold<int>(0, (sum, t) => sum + t.amount);

    return BudgetStatus(
      id: b.id,
      categoryId: b.categoryId,
      category: b.category,
      amount: b.amount,
      spent: spent,
      remaining: b.amount - spent,
      percentage: b.amount > 0 ? spent / b.amount : 0.0,
      isExceeded: spent > b.amount,
      period: b.period,
    );
  }).toList();
});
