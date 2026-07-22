import 'package:flutter_test/flutter_test.dart';
import 'package:ai_finance_coach/core/money.dart';

void main() {
  tearDown(() => Money.configure('THB'));

  test('converts THB amounts to USD and converts USD input back to satang', () {
    Money.configure('THB');
    expect(Money.formatBaht(240000), '฿2,400');

    Money.configure('USD', thbToUsdRate: 0.0297);
    expect(Money.formatBaht(240000), r'$71.28');
    expect(Money.formatBaht(43649199), r'$12,963.81');
    expect(Money.formatBaht(55967300), r'$16,622.29');
    expect(Money.formatBaht(12318101), r'$3,658.48');
    expect(Money.toSatang(71.28), 240000);
  });
}
