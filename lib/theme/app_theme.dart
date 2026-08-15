import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand palette pulled from the new Result Desk icon: deep navy base,
/// bright "trust" blue accent, clean white surfaces, plus semantic
/// pass/fail/absent/withheld colors reused across result cards & chips.
class AppColors {
  static const Color navy = Color(0xFF0B1F3A); // icon's dark navy
  static const Color navyDeep = Color(0xFF071527);
  static const Color blue = Color(0xFF2D6CDF); // icon's bright blue accent
  static const Color blueSoft = Color(0xFF6FA0F5);
  static const Color surface = Color(0xFFF6F8FC);
  static const Color card = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF10192B);
  static const Color textMuted = Color(0xFF5B6B85);

  static const Color pass = Color(0xFF1E8A5F);
  static const Color fail = Color(0xFFC0392B);
  static const Color absent = Color(0xFF7A8699);
  static const Color withheld = Color(0xFFB07A18);
  static const Color cancelled = Color(0xFF7A8699);

  static const Color gradeAPlus = Color(0xFFB8933F);
  static const Color gradeA = Color(0xFF1E8A5F);
  static const Color gradeB = Color(0xFF1F7A8C);
  static const Color gradeC = Color(0xFF2D5FA6);
  static const Color gradeD = Color(0xFFB07A18);
  static const Color gradeE = Color(0xFFB0392B);
}

class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.surface,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.blue,
        brightness: Brightness.light,
        primary: AppColors.blue,
        surface: AppColors.surface,
      ),
    );
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
      titleLarge: GoogleFonts.lexend(
        fontWeight: FontWeight.w700,
        color: AppColors.textDark,
      ),
      titleMedium: GoogleFonts.lexend(
        fontWeight: FontWeight.w600,
        color: AppColors.textDark,
      ),
    );
    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.lexend(
          fontWeight: FontWeight.w700,
          fontSize: 20,
          color: Colors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.blue, width: 1.6),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.black.withOpacity(0.06)),
        ),
      ),
    );
  }
}
