import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF6C5CE7);
  static const primaryDark = Color(0xFF5240C4);
  static const accent = Color(0xFF00C9A7);
  static const income = Color(0xFF37B24D);
  static const expense = Color(0xFFFF6B6B);
  static const bg = Color(0xFFF5F6FB);
  static const surface = Colors.white;
  static const textDark = Color(0xFF1A1B2E);
  static const textMuted = Color(0xFF8A8FA3);
  static const chipBg = Color(0xFFEDEBFF);
}

/// เงานุ่มสำหรับการ์ด — ให้ดู "ลอย" ไม่แบน
const List<BoxShadow> kSoftShadow = [
  BoxShadow(color: Color(0x14000000), blurRadius: 20, offset: Offset(0, 8)),
];
const List<BoxShadow> kCardShadow = [
  BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, 4)),
];

/// gradient ส่วนหัวแบบ fintech (นุ่ม ๆ ม่วงอ่อน → พื้นหลัง)
const LinearGradient kHeaderGradient = LinearGradient(
  colors: [Color(0xFFEDE9FF), Color(0xFFF5F6FB)],
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
);
const LinearGradient kBalanceGradient = LinearGradient(
  colors: [Color(0xFF8273F2), AppColors.primaryDark],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// การ์ดขาวมุมมน + เงานุ่ม (ใช้ซ้ำทั่วแอป)
BoxDecoration softCard({double radius = 20, Color color = Colors.white}) =>
    BoxDecoration(color: color, borderRadius: BorderRadius.circular(radius), boxShadow: kSoftShadow);

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary, primary: AppColors.primary),
    scaffoldBackgroundColor: AppColors.bg,
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      foregroundColor: AppColors.textDark,
      centerTitle: false,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.chipBg,
      labelStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.primary : Colors.white,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : AppColors.textMuted,
        ),
        side: WidgetStateProperty.all(const BorderSide(color: Color(0xFFE7E9F3))),
        shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
        textStyle: WidgetStateProperty.all(const TextStyle(fontWeight: FontWeight.w600)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE7E9F3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE7E9F3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    ),
  );
}

/// "#FF6B6B" -> Color
Color hexColor(String hex) {
  var h = hex.replaceAll('#', '').trim();
  if (h.length == 6) h = 'FF$h';
  return Color(int.parse(h, radix: 16));
}
