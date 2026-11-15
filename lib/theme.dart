import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const primary = Color(0xFF1D4ED8);
  static const primaryDark = Color(0xFF1E40AF);
  static const primaryTint = Color(0xFFE0EAFF);
  static const ink = Color(0xFF0F172A);
  static const navy2 = Color(0xFF1E293B);
  static const navyLine = Color(0xFF334155);
  static const muted = Color(0xFF475569);
  static const mutedOnDark = Color(0xFFCBD5E1);
  static const ground = Color(0xFFF4F5FF);
  static const surface = Colors.white;
  static const soft = Color(0xFFF8FAFC);
  static const border = Color(0xFFE2E8F0);
  static const amber = Color(0xFFF59E0B);
  static const amberDark = Color(0xFFD97706);
  static const amberTint = Color(0xFFFEF3C7);
  static const amberText = Color(0xFF92400E);
  static const orange = Color(0xFFC2410C);
  static const orangeTint = Color(0xFFFFE4D6);
  static const orangeText = Color(0xFF9A3412);
  static const warnBg = Color(0xFFFFF7ED);
  static const warnBorder = Color(0xFFFED7AA);
  static const warnText = Color(0xFF7C2D12);
  static const highlight = Color(0xFFFBBF24);
  static const camera = Color(0xFF0B1220);
  static const success = Color(0xFF15803D);

  /// Main brand gradient: electric blue → violet.
  static const hero = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Soft page background wash behind the header.
  static const headerWash = LinearGradient(
    colors: [Color(0xFFE0E7FF), Color(0xFFF3E8FF), Color(0xFFF4F5FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Each meter gets its own colour pair so a home with 3 meters is easy to tell apart.
class MeterAccent {
  final Color a, b;
  const MeterAccent(this.a, this.b);
  LinearGradient get gradient =>
      LinearGradient(colors: [a, b], begin: Alignment.topLeft, end: Alignment.bottomRight);
  Color get tint => a.withValues(alpha: 0.10);
}

const meterAccents = [
  MeterAccent(Color(0xFF2563EB), Color(0xFF06B6D4)), // blue → cyan
  MeterAccent(Color(0xFF7C3AED), Color(0xFFDB2777)), // violet → pink
  MeterAccent(Color(0xFF0D9488), Color(0xFF16A34A)), // teal → green
  MeterAccent(Color(0xFFEA580C), Color(0xFFD97706)), // orange → amber
];

MeterAccent accentFor(int index) => meterAccents[index % meterAccents.length];

/// Big numbers (readings, units) use Space Grotesk.
TextStyle numStyle(double size,
        {Color color = AppColors.ink, FontWeight weight = FontWeight.w700}) =>
    GoogleFonts.spaceGrotesk(
        fontSize: size, fontWeight: weight, color: color, height: 1.1);

TextStyle titleStyle(double size, {Color color = AppColors.ink}) =>
    GoogleFonts.spaceGrotesk(
        fontSize: size, fontWeight: FontWeight.w700, color: color);

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: AppColors.ground,
  );
  final radius = BorderRadius.circular(14);
  return base.copyWith(
    textTheme: GoogleFonts.interTextTheme(base.textTheme)
        .apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.ground,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        minimumSize: const Size(48, 52),
        side: const BorderSide(color: Color(0xFFCBD5E1)),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: AppColors.primary, width: 2)),
    ),
  );
}
