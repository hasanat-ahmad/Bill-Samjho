import 'package:flutter/material.dart';

import '../data/models/finding.dart';
import 'constants.dart';

class AppColors {
  static const green = Color(0xFF2E7D32);
  static const amber = Color(0xFFF9A825);
  static const red = Color(0xFFC62828);
  static const primary = Color(0xFF1565C0);
  static const background = Colors.white;
}

/// Colour + icon + word for each verdict; never colour alone (NFR-03).
class VerdictStyle {
  const VerdictStyle(this.color, this.onColor, this.icon, this.label);

  final Color color;
  final Color onColor;
  final IconData icon;
  final String label;

  static VerdictStyle of(Verdict v) => switch (v) {
        Verdict.normal => const VerdictStyle(AppColors.green, Colors.white, Icons.check_circle, Labels.verdictNormal),
        Verdict.check => const VerdictStyle(AppColors.amber, Colors.black, Icons.error, Labels.verdictCheck),
        Verdict.wrong => const VerdictStyle(AppColors.red, Colors.white, Icons.cancel, Labels.verdictWrong),
      };

  static (Color, IconData) ofSeverity(Severity s) => switch (s) {
        Severity.info => (AppColors.primary, Icons.info),
        Severity.check => (AppColors.amber, Icons.error),
        Severity.wrong => (AppColors.red, Icons.cancel),
      };
}

/// Western-digit numbers in a plain font so large amounts read clearly (NFR-02).
const numberStyle = TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.bold);

const _minTap = Size(56, 56);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    surface: AppColors.background,
    error: AppColors.red,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'NotoNastaliqUrdu',
    scaffoldBackgroundColor: AppColors.background,
  );
  const buttonText = TextStyle(fontSize: 20, fontWeight: FontWeight.w600, fontFamily: 'NotoNastaliqUrdu');
  const buttonPadding = EdgeInsets.symmetric(horizontal: 24, vertical: 12);

  return base.copyWith(
    // Minimum 18 sp everywhere (NFR-03).
    textTheme: base.textTheme.copyWith(
      bodySmall: const TextStyle(fontSize: 18),
      bodyMedium: const TextStyle(fontSize: 18),
      bodyLarge: const TextStyle(fontSize: 20),
      labelSmall: const TextStyle(fontSize: 18),
      labelMedium: const TextStyle(fontSize: 18),
      labelLarge: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      titleSmall: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      titleMedium: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      titleLarge: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      headlineSmall: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
      headlineMedium: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      centerTitle: true,
      titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'NotoNastaliqUrdu', color: Colors.white),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: _minTap, textStyle: buttonText, padding: buttonPadding),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(minimumSize: _minTap, textStyle: buttonText, padding: buttonPadding),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: _minTap, textStyle: buttonText, padding: buttonPadding),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: _minTap, textStyle: buttonText),
    ),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(minimumSize: _minTap)),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      extendedTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'NotoNastaliqUrdu'),
      extendedSizeConstraints: BoxConstraints(minHeight: 64, minWidth: 64),
      extendedIconLabelSpacing: 12,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    cardTheme: const CardThemeData(
      color: Colors.white,
      elevation: 1.5,
      margin: EdgeInsets.symmetric(vertical: 6),
    ),
    chipTheme: base.chipTheme.copyWith(
      labelStyle: const TextStyle(fontSize: 20, fontFamily: 'NotoNastaliqUrdu'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(minimumSize: _minTap, textStyle: buttonText),
    ),
    snackBarTheme: const SnackBarThemeData(contentTextStyle: TextStyle(fontSize: 18, fontFamily: 'NotoNastaliqUrdu')),
  );
}
