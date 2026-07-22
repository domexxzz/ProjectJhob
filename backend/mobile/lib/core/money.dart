import 'package:intl/intl.dart';

/// จำนวนเงินจาก backend เก็บเป็น "สตางค์" (int, 1 บาท = 100).
/// helper นี้แปลงไป-กลับ บาท สำหรับแสดงผล/รับ input.
class Money {
  static final NumberFormat _decimal = NumberFormat('#,##0.##');
  static final NumberFormat _whole = NumberFormat('#,##0');

  /// สตางค์ -> "1,234.5"
  static String format(int satang) => _decimal.format(satang / 100);

  /// สตางค์ -> "฿1,234"
  static String formatBaht(int satang) => '฿${_whole.format((satang / 100).round())}';

  /// บาท (จาก user input) -> สตางค์
  static int toSatang(num baht) => (baht * 100).round();
}
