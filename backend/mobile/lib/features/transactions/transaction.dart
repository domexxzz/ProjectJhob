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
    required this.occurredAt,
  });

  final String id;
  final String type; // income | expense
  final int amount; // satang
  final String? note;
  final String source;
  final Category? category;
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
        occurredAt: DateTime.parse(j['occurredAt'] as String),
      );
}

class TxnSummary {
  TxnSummary({required this.income, required this.expense, required this.balance});
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
    this.categoryId,
    required this.amount,
    required this.period,
    this.category,
  });

  final String id;
  final String userId;
  final String? categoryId;
  final int amount;
  final String period;
  final Category? category;

  factory Budget.fromJson(Map<String, dynamic> j) => Budget(
        id: j['id'] as String,
        userId: j['userId'] as String,
        categoryId: j['categoryId'] as String?,
        amount: (j['amount'] as num).toInt(),
        period: (j['period'] ?? 'monthly') as String,
        category: j['category'] != null
            ? Category.fromJson(j['category'] as Map<String, dynamic>)
            : null,
      );
}

class BudgetStatus {
  BudgetStatus({
    required this.id,
    this.categoryId,
    this.category,
    required this.amount,
    required this.spent,
    required this.remaining,
    required this.percentage,
    required this.isExceeded,
    required this.period,
  });

  final String id;
  final String? categoryId;
  final Category? category;
  final int amount;
  final int spent;
  final int remaining;
  final double percentage;
  final bool isExceeded;
  final String period;

  factory BudgetStatus.fromJson(Map<String, dynamic> j) => BudgetStatus(
        id: j['id'] as String,
        categoryId: j['categoryId'] as String?,
        category: j['category'] != null
            ? Category.fromJson(j['category'] as Map<String, dynamic>)
            : null,
        amount: (j['amount'] as num).toInt(),
        spent: (j['spent'] as num).toInt(),
        remaining: (j['remaining'] as num).toInt(),
        percentage: (j['percentage'] as num).toDouble(),
        isExceeded: j['isExceeded'] as bool,
        period: j['period'] as String,
      );
}
