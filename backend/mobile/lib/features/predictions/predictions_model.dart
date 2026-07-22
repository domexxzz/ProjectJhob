class ForecastItem {
  final String date;
  final int balance;
  final int lower;
  final int upper;

  ForecastItem({
    required this.date,
    required this.balance,
    required this.lower,
    required this.upper,
  });

  factory ForecastItem.fromJson(Map<String, dynamic> json) {
    return ForecastItem(
      date: json['date'] as String,
      balance: json['balance'] as int,
      lower: json['lower'] as int,
      upper: json['upper'] as int,
    );
  }
}

class PredictionAlert {
  final String type;
  final String title;
  final String body;

  PredictionAlert({
    required this.type,
    required this.title,
    required this.body,
  });

  factory PredictionAlert.fromJson(Map<String, dynamic> json) {
    return PredictionAlert(
      type: json['type'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
    );
  }
}

class PredictionAnomaly {
  final String? id;
  final String date;
  final int amount;
  final String note;
  final String description;

  PredictionAnomaly({
    this.id,
    required this.date,
    required this.amount,
    required this.note,
    required this.description,
  });

  factory PredictionAnomaly.fromJson(Map<String, dynamic> json) {
    return PredictionAnomaly(
      id: json['id'] as String?,
      date: json['date'] as String,
      amount: json['amount'] as int,
      note: json['note'] as String,
      description: json['description'] as String,
    );
  }
}

class PredictionsResponse {
  final List<ForecastItem> forecast;
  final int predictedTotalExpense;
  final int predictedTotalIncome;
  final int projectedEndingBalance;
  final List<PredictionAlert> alerts;
  final List<PredictionAnomaly> anomalies;

  PredictionsResponse({
    required this.forecast,
    required this.predictedTotalExpense,
    required this.predictedTotalIncome,
    required this.projectedEndingBalance,
    required this.alerts,
    required this.anomalies,
  });

  factory PredictionsResponse.fromJson(Map<String, dynamic> json) {
    return PredictionsResponse(
      forecast: (json['forecast'] as List<dynamic>)
          .map((item) => ForecastItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      predictedTotalExpense: json['predictedTotalExpense'] as int,
      predictedTotalIncome: json['predictedTotalIncome'] as int,
      projectedEndingBalance: json['projectedEndingBalance'] as int,
      alerts: (json['alerts'] as List<dynamic>)
          .map((item) => PredictionAlert.fromJson(item as Map<String, dynamic>))
          .toList(),
      anomalies: (json['anomalies'] as List<dynamic>)
          .map((item) => PredictionAnomaly.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
