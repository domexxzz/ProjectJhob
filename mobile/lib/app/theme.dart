import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF00C850); // Emerald green
  static const primaryDark = Color(0xFF0D6E37); // Darker green
  static const accent = Color(0xFF00C850);
  static const income = Color(0xFF00C850);
  static const expense = Color(0xFFFF4D4D);
  static const warning = Color(0xFFFFA500);
  static const bg = Color(0xFF0D1117); // Dark background
  static const surface = Color(0xFF16202E); // Dark surface card
  static const textDark = Color(0xFFFFFFFF);
  static const textMuted = Color(0xFF8A9BB0);
  static const chipBg = Color(0xFF1F2937);
}

/// เงานุ่มสำหรับการ์ด — ให้ดู "ลอย" ไม่แบน
const List<BoxShadow> kSoftShadow = [
  BoxShadow(color: Color(0x1F000000), blurRadius: 20, offset: Offset(0, 8)),
];
const List<BoxShadow> kCardShadow = [
  BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4)),
];

/// gradient ส่วนหัวแบบ fintech
const LinearGradient kHeaderGradient = LinearGradient(
  colors: [Color(0xFF073820), Color(0xFF0D1117)],
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
);
const LinearGradient kBalanceGradient = LinearGradient(
  colors: [Color(0xFF00C850), Color(0xFF0D6E37)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// การ์ดดำมุมมน + เงานุ่ม (ใช้ซ้ำทั่วแอป)
BoxDecoration softCard({double radius = 20, Color color = AppColors.surface}) =>
    BoxDecoration(color: color, borderRadius: BorderRadius.circular(radius), boxShadow: kSoftShadow);

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.surface,
    ),
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
          (s) => s.contains(WidgetState.selected) ? AppColors.primary : AppColors.surface,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : AppColors.textMuted,
        ),
        side: WidgetStateProperty.all(const BorderSide(color: Color(0xFF1E293B))),
        shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
        textStyle: WidgetStateProperty.all(const TextStyle(fontWeight: FontWeight.w600)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF1E293B)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF1E293B)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      labelStyle: const TextStyle(color: AppColors.textMuted),
      hintStyle: const TextStyle(color: AppColors.textMuted),
    ),
  );
}

/// "#FF6B6B" -> Color
Color hexColor(String hex) {
  var h = hex.replaceAll('#', '').trim();
  if (h.length == 6) h = 'FF$h';
  return Color(int.parse(h, radix: 16));
}

