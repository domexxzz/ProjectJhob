import 'package:intl/intl.dart';

/// จำนวนเงินจาก backend เก็บเป็น "สตางค์" (int, 1 บาท = 100).
/// helper นี้แปลงไป-กลับ บาท สำหรับแสดงผล/รับ input.
class Money {
  static final NumberFormat _input = NumberFormat('0.##');
  static final NumberFormat _whole = NumberFormat('#,##0');
  static String _currency = 'THB';
  static double _thbToUsdRate = 0.0297;

  static String get currency => _currency;
  static String get symbol => _currency == 'USD' ? '\$' : '฿';

  static void configure(String currency, {double? thbToUsdRate}) {
    _currency = currency == 'USD' ? 'USD' : 'THB';
    if (thbToUsdRate != null && thbToUsdRate > 0) {
      _thbToUsdRate = thbToUsdRate;
    }
  }

  /// ยอดจากฐานข้อมูลเป็นสตางค์ไทยเสมอ แล้วค่อยแปลงเพื่อแสดงผล
  static double displayValue(int satang) {
    final baht = satang / 100;
    return _currency == 'USD' ? baht * _thbToUsdRate : baht;
  }

  /// สตางค์ -> "1,234.5"
  static String format(int satang) => _input.format(displayValue(satang));

  /// สตางค์ -> "฿1,234"
  static String formatBaht(int satang) {
    final value = displayValue(satang);
    final formatted = _currency == 'USD'
        ? NumberFormat('#,##0.00').format(value)
        : _whole.format(value.round());
    return '$symbol$formatted';
  }

  /// บาท (จาก user input) -> สตางค์
  static int toSatang(num amount) {
    final baht = _currency == 'USD' ? amount / _thbToUsdRate : amount;
    return (baht * 100).round();
  }
}
