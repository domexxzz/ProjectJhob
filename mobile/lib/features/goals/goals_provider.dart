import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

class GoalModel {
  GoalModel({
    required this.id,
    required this.name,
    required this.target,
    this.current = 0,
    this.deadline,
    this.type = 'short', // short | medium | long
    this.emoji = '🎯',
    required this.createdAt,
  });

  final String id;
  final String name;
  final int target; // in satang
  final int current; // in satang
  final DateTime? deadline;
  final String type;
  final String emoji;
  final DateTime createdAt;

  double get progressPercentage {
    if (target <= 0) return 0.0;
    return (current / target).clamp(0.0, 1.0);
  }

  GoalModel copyWith({
    String? id,
    String? name,
    int? target,
    int? current,
    DateTime? deadline,
    String? type,
    String? emoji,
    DateTime? createdAt,
  }) {
    return GoalModel(
      id: id ?? this.id,
      name: name ?? this.name,
      target: target ?? this.target,
      current: current ?? this.current,
      deadline: deadline ?? this.deadline,
      type: type ?? this.type,
      emoji: emoji ?? this.emoji,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'target': target,
        'current': current,
        'deadline': deadline?.toIso8601String(),
        'type': type,
        'emoji': emoji,
        'createdAt': createdAt.toIso8601String(),
      };

  factory GoalModel.fromJson(Map<String, dynamic> j) => GoalModel(
        id: j['id'] as String,
        name: j['name'] as String,
        target: j['target'] as int,
        current: (j['current'] ?? 0) as int,
        deadline: j['deadline'] != null ? DateTime.parse(j['deadline'] as String) : null,
        type: (j['type'] ?? 'short') as String,
        emoji: (j['emoji'] ?? '🎯') as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

class GoalsNotifier extends StateNotifier<List<GoalModel>> {
  GoalsNotifier() : super([]) {
    _loadGoals();
  }

  static const _boxName = 'goals_box';

  Future<void> _loadGoals() async {
    final box = await Hive.openBox(_boxName);
    final List? cached = box.get('goals');
    if (cached != null) {
      state = cached.map((item) => GoalModel.fromJson(Map<String, dynamic>.from(item as Map))).toList();
    } else {
      state = _initialGoals();
      await _saveToHive();
    }
  }

  Future<void> _saveToHive() async {
    final box = await Hive.openBox(_boxName);
    await box.put('goals', state.map((g) => g.toJson()).toList());
  }

  static List<GoalModel> _initialGoals() {
    return [
      GoalModel(
        id: 'goal-1',
        name: 'เที่ยวต่างประเทศ',
        target: 400000, // 4,000.00 Baht (matching wireframe)
        current: 240000, // 2,400.00 Baht (matching wireframe)
        deadline: DateTime(2026, 12, 31),
        type: 'short',
        emoji: '🌴',
        createdAt: DateTime(2026, 6, 1),
      ),
      GoalModel(
        id: 'goal-2',
        name: 'ซื้อตู้เย็น',
        target: 400000, // 4,000.00 Baht (matching wireframe Home.png)
        current: 240000, // 2,400.00 Baht
        deadline: DateTime(2026, 9, 30),
        type: 'short',
        emoji: '🔌',
        createdAt: DateTime(2026, 6, 10),
      ),
      GoalModel(
        id: 'goal-3',
        name: 'เงินสำรองฉุกเฉิน',
        target: 10000000, // 100,000.00 Baht
        current: 8000000, // 80,000.00 Baht
        deadline: null,
        type: 'long',
        emoji: '🛡️',
        createdAt: DateTime(2026, 5, 1),
      ),
    ];
  }

  void addGoal(String name, int target, DateTime? deadline, String type, String emoji) {
    final newGoal = GoalModel(
      id: 'goal-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      target: target,
      current: 0,
      deadline: deadline,
      type: type,
      emoji: emoji,
      createdAt: DateTime.now(),
    );
    state = [...state, newGoal];
    _saveToHive();
  }

  void updateGoal(String id, String name, int target, DateTime? deadline, String type, String emoji) {
    state = state.map((g) {
      if (g.id == id) {
        return g.copyWith(
          name: name,
          target: target,
          deadline: deadline,
          type: type,
          emoji: emoji,
        );
      }
      return g;
    }).toList();
    _saveToHive();
  }

  void deleteGoal(String id) {
    state = state.where((g) => g.id != id).toList();
    _saveToHive();
  }

  void addSavings(String goalId, int amount) {
    state = state.map((g) {
      if (g.id == goalId) {
        return g.copyWith(current: g.current + amount);
      }
      return g;
    }).toList();
    _saveToHive();
  }
}

final goalsProvider = StateNotifierProvider<GoalsNotifier, List<GoalModel>>((ref) {
  return GoalsNotifier();
});
