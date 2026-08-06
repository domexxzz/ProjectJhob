import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../../core/api/api_client.dart';
import '../auth/auth_controller.dart';

class GoalModel {
  GoalModel({
    required this.id,
    required this.name,
    required this.target,
    this.current = 0,
    this.deadline,
    this.startDate,
    this.type = 'short', // short | medium | long
    this.emoji = '🎯',
    this.imagePath,
    required this.createdAt,
  });

  final String id;
  final String name;
  final int target; // in satang
  final int current; // in satang
  final DateTime? deadline;
  final DateTime?
      startDate; // วันเริ่มต้นของช่วงระยะเวลาที่เลือก (จำคู่กับ deadline ที่เป็นวันสิ้นสุด)
  final String type;
  final String emoji;
  final String? imagePath;
  final DateTime createdAt;

  double get progressPercentage {
    if (target <= 0) return 0.0;
    return (current / target).clamp(0.0, 1.0);
  }

  String get calculatedType {
    if (startDate != null && deadline != null) {
      final int months = ((deadline!.year - startDate!.year) * 12) + (deadline!.month - startDate!.month);
      if (months <= 6) return 'short';
      if (months <= 12) return 'medium';
      return 'long';
    } else if (deadline != null) {
      final int months = ((deadline!.year - createdAt.year) * 12) + (deadline!.month - createdAt.month);
      if (months <= 6) return 'short';
      if (months <= 12) return 'medium';
      return 'long';
    }
    return type;
  }

  String get typeLabel {
    switch (calculatedType) {
      case 'medium':
        return 'ระยะกลาง (6-12 เดือน)';
      case 'long':
        return 'ระยะยาว (1 ปีขึ้นไป)';
      default:
        return 'ระยะสั้น (0-6 เดือน)';
    }
  }

  GoalModel copyWith({
    String? id,
    String? name,
    int? target,
    int? current,
    DateTime? deadline,
    DateTime? startDate,
    bool clearStartDate = false,
    String? type,
    String? emoji,
    String? imagePath,
    bool clearImage = false,
    DateTime? createdAt,
  }) {
    return GoalModel(
      id: id ?? this.id,
      name: name ?? this.name,
      target: target ?? this.target,
      current: current ?? this.current,
      deadline: deadline ?? this.deadline,
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      type: type ?? this.type,
      emoji: emoji ?? this.emoji,
      imagePath: clearImage ? null : (imagePath ?? this.imagePath),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'target': target,
        'current': current,
        'deadline': deadline?.toIso8601String(),
        'startDate': startDate?.toIso8601String(),
        'type': type,
        'emoji': emoji,
        'imagePath': imagePath,
        'createdAt': createdAt.toIso8601String(),
      };

  factory GoalModel.fromJson(Map<String, dynamic> j) => GoalModel(
        id: j['id'] as String,
        name: j['name'] as String,
        target: j['target'] as int,
        current: (j['current'] ?? 0) as int,
        deadline: j['deadline'] != null
            ? DateTime.parse(j['deadline'] as String)
            : null,
        startDate: j['startDate'] != null
            ? DateTime.parse(j['startDate'] as String)
            : null,
        type: (j['type'] ?? 'short') as String,
        emoji: (j['emoji'] ?? '🎯') as String,
        imagePath: j['imagePath'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

class GoalsNotifier extends StateNotifier<List<GoalModel>> {
  GoalsNotifier(this._ref) : super([]) {
    _loadGoals();
  }
  final Ref _ref;

  static const _boxName = 'goals_box';

  Future<void> _loadGoals() async {
    try {
      final box = await Hive.openBox(_boxName);
      final List? cached = box.get('goals');
      if (cached != null) {
        state = cached
            .map((item) =>
                GoalModel.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
        return;
      }
      state = _initialGoals();
      await _saveToHive();
    } catch (_) {
      state = _initialGoals();
    }
  }

  Future<void> _saveToHive() async {
    try {
      final box = await Hive.openBox(_boxName);
      await box.put('goals', state.map((g) => g.toJson()).toList());
    } catch (_) {
      // ใช้งานต่อด้วย state ในหน่วยความจำ เมื่อ Web storage ไม่พร้อม
    }
  }

  static List<GoalModel> _initialGoals() {
    // เริ่มต้นด้วยรายการว่าง — ให้ผู้ใช้สร้างเป้าหมายเอง (โชว์ empty state)
    return [];
  }

  Future<void> addGoal(String name, int target, DateTime? deadline, String type,
      String emoji, String? imagePath,
      {DateTime? startDate}) async {
    final newId = 'goal-${DateTime.now().millisecondsSinceEpoch}';
    final newGoal = GoalModel(
      id: newId,
      name: name,
      target: target,
      current: 0,
      deadline: deadline,
      startDate: startDate,
      type: type,
      emoji: emoji,
      imagePath: imagePath,
      createdAt: DateTime.now(),
    );
    state = [...state, newGoal];
    await _saveToHive();

    try {
      final dio = _ref.read(dioProvider);
      await dio.post('/goals', data: {
        'id': newId,
        'name': name,
        'target': target,
        'current': 0,
        if (deadline != null) 'deadline': deadline.toUtc().toIso8601String(),
      });
      _ref.read(authControllerProvider.notifier).refreshProfile();
    } catch (_) {}
  }

  void updateGoal(String id, String name, int target, DateTime? deadline,
      String type, String emoji, String? imagePath,
      {DateTime? startDate}) {
    state = state.map((g) {
      if (g.id == id) {
        return g.copyWith(
          name: name,
          target: target,
          deadline: deadline,
          startDate: startDate,
          clearStartDate: startDate == null,
          type: type,
          emoji: emoji,
          imagePath: imagePath,
          clearImage: imagePath == null,
        );
      }
      return g;
    }).toList();
    _saveToHive();
  }

  Future<void> deleteGoal(String id) async {
    state = state.where((g) => g.id != id).toList();
    await _saveToHive();

    try {
      final dio = _ref.read(dioProvider);
      await dio.delete('/goals/$id');
    } catch (_) {}
  }

  Future<void> addSavings(String goalId, int amount) async {
    state = state.map((g) {
      if (g.id == goalId) {
        return g.copyWith(current: g.current + amount);
      }
      return g;
    }).toList();
    await _saveToHive();

    try {
      final dio = _ref.read(dioProvider);
      await dio.post('/goals/$goalId/deposit', data: {
        'amount': amount,
      });
      _ref.read(authControllerProvider.notifier).refreshProfile();
    } catch (_) {}
  }
}

final goalsProvider =
    StateNotifierProvider<GoalsNotifier, List<GoalModel>>((ref) {
  return GoalsNotifier(ref);
});
