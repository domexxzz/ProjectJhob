class Category {
  Category({
    required this.id,
    required this.nameTh,
    required this.icon,
    required this.color,
    required this.type,
  });

  final String id;
  final String nameTh;
  final String icon;
  final String color;
  final String type;

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: j['id'] as String,
        nameTh: (j['nameTh'] ?? j['name']) as String,
        icon: (j['icon'] ?? '💸') as String,
        color: (j['color'] ?? '#845EF7') as String,
        type: (j['type'] ?? 'expense') as String,
      );
}

class Txn {
  Txn({
    required this.id,
    required this.type,
    required this.amount,
    this.note,
    required this.source,
    this.category,
    this.budgetId,
    required this.occurredAt,
  });

  final String id;
  final String type; // income | expense
  final int amount; // satang
  final String? note;
  final String source;
  final Category? category;
  final String? budgetId;
  final DateTime occurredAt;

  bool get isIncome => type == 'income';

  factory Txn.fromJson(Map<String, dynamic> j) => Txn(
        id: j['id'] as String,
        type: j['type'] as String,
        amount: (j['amount'] as num).toInt(),
        note: j['note'] as String?,
        source: (j['source'] ?? 'manual') as String,
        category: j['category'] != null
            ? Category.fromJson(j['category'] as Map<String, dynamic>)
            : null,
        budgetId: j['budgetId'] as String?,
        occurredAt: DateTime.parse(j['occurredAt'] as String),
      );
}

class TxnSummary {
  TxnSummary(
      {required this.income, required this.expense, required this.balance});
  final int income;
  final int expense;
  final int balance;

  factory TxnSummary.fromJson(Map<String, dynamic> j) => TxnSummary(
        income: (j['income'] as num).toInt(),
        expense: (j['expense'] as num).toInt(),
        balance: (j['balance'] as num).toInt(),
      );
}

class Budget {
  Budget({
    required this.id,
    required this.userId,
    this.name,
    this.categoryId,
    required this.amount,
    this.showOnDashboard = true,
    required this.createdAt,
    this.category,
  });

  final String id;
  final String userId;
  final String? name;
  final String? categoryId;
  final int amount;
  final bool showOnDashboard;
  final DateTime createdAt;
  final Category? category;

  /// ชื่อที่แสดงในหน้า UI: ใช้ชื่อที่ตั้งเอง >> nameTh จาก category >> 'งบประมาณทั่วไป'
  String get displayName =>
      (name?.isNotEmpty == true)
          ? name!
          : (category?.nameTh.isNotEmpty == true ? category!.nameTh : 'งบประมาณทั่วไป');

  factory Budget.fromJson(Map<String, dynamic> j) => Budget(
        id: j['id'] as String,
        userId: j['userId'] as String,
        name: j['name'] as String?,
        categoryId: j['categoryId'] as String?,
        amount: (j['amount'] as num).toInt(),
        showOnDashboard: j['showOnDashboard'] as bool? ?? true,
        createdAt: j['createdAt'] != null ? DateTime.parse(j['createdAt'] as String) : DateTime.now(),
        category: j['category'] != null
            ? Category.fromJson(j['category'] as Map<String, dynamic>)
            : null,
      );
}

class BudgetStatus {
  BudgetStatus({
    required this.id,
    this.name,
    this.categoryId,
    this.category,
    required this.amount,
    required this.spent,
    required this.remaining,
    required this.percentage,
    required this.isExceeded,
    this.showOnDashboard = true,
    this.riskLevel = 'safe',
  });

  final String id;
  final String? name;
  final String? categoryId;
  final Category? category;
  final int amount;
  final int spent;
  final int remaining;
  final double percentage;
  final bool isExceeded;
  final bool showOnDashboard;
  final String riskLevel; // safe | warning | danger

  String get displayName =>
      (name?.isNotEmpty == true)
          ? name!
          : (category?.nameTh.isNotEmpty == true ? category!.nameTh : 'งบประมาณทั่วไป');

  factory BudgetStatus.fromJson(Map<String, dynamic> j) => BudgetStatus(
        id: j['id'] as String,
        name: j['name'] as String?,
        categoryId: j['categoryId'] as String?,
        category: j['category'] != null
            ? Category.fromJson(j['category'] as Map<String, dynamic>)
            : null,
        amount: (j['amount'] as num).toInt(),
        spent: (j['spent'] as num).toInt(),
        remaining: (j['remaining'] as num).toInt(),
        percentage: (j['percentage'] as num).toDouble(),
        isExceeded: j['isExceeded'] as bool,
        showOnDashboard: j['showOnDashboard'] as bool? ?? true,
        riskLevel: (j['riskLevel'] ?? 'safe') as String,
      );
}
