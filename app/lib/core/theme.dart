import 'package:flutter/material.dart';

import '../data/models/finding.dart';
import 'i18n.dart';

/// Colour tokens. Verdict colours are from the SDA (§11); text colours pass
/// WCAG AA contrast on white.
class AppColors {
  static const primary = Color(0xFF1565C0);
  static const primaryDark = Color(0xFF0D47A1);
  static const primarySoft = Color(0xFFE8F1FC);

  static const ink = Color(0xFF0F1B2D);
  static const inkMuted = Color(0xFF4A5568);
  static const surface = Colors.white;
  static const surfaceAlt = Color(0xFFF4F7FB);
  static const border = Color(0xFFE2E8F0);

  static const green = Color(0xFF2E7D32);
  static const greenSoft = Color(0xFFE8F5E9);
  static const greenInk = Color(0xFF1B5E20);

  static const amber = Color(0xFFF9A825);
  static const amberSoft = Color(0xFFFFF6DB);
  static const amberInk = Color(0xFF6B4E00);

  static const red = Color(0xFFC62828);
  static const redSoft = Color(0xFFFDECEC);
  static const redInk = Color(0xFF8E1B1B);
}

/// Spacing scale (8-point grid).
class Gap {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const page = 20.0;
}

class Radii {
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 28.0;
}

/// Colour + icon for each verdict and severity; never colour alone (NFR-03).
class Tone {
  const Tone(this.color, this.soft, this.ink, this.icon);

  final Color color;
  final Color soft;
  final Color ink;
  final IconData icon;

  static const normal = Tone(AppColors.green, AppColors.greenSoft, AppColors.greenInk, Icons.check_circle_rounded);
  static const check = Tone(AppColors.amber, AppColors.amberSoft, AppColors.amberInk, Icons.error_rounded);
  static const wrong = Tone(AppColors.red, AppColors.redSoft, AppColors.redInk, Icons.cancel_rounded);
  static const info = Tone(AppColors.primary, AppColors.primarySoft, AppColors.primaryDark, Icons.info_rounded);

  static Tone ofVerdict(Verdict v) => switch (v) {
        Verdict.normal => normal,
        Verdict.check => check,
        Verdict.wrong => wrong,
      };

  static Tone ofSeverity(Severity s) => switch (s) {
        Severity.info => info,
        Severity.check => check,
        Severity.wrong => wrong,
      };
}

/// Numbers (amounts, units) in a plain Latin font in both languages, so
/// Western digits read clearly (NFR-02).
TextStyle numberStyle(double size, {Color color = AppColors.ink, FontWeight weight = FontWeight.w700}) =>
    TextStyle(fontFamily: 'Roboto', fontSize: size, fontWeight: weight, color: color, height: 1.15);

const _urduFamily = 'NotoNastaliqUrdu';

TextTheme _textTheme(AppLanguage lang) {
  final urdu = lang.isRtl;
  TextStyle style(double size, FontWeight weight, double height, double urduHeight, [Color color = AppColors.ink]) =>
      TextStyle(
        fontFamily: urdu ? _urduFamily : 'Roboto',
        fontSize: size,
        fontWeight: weight,
        // The Nastaliq font is variable; select its weight explicitly.
        fontVariations: urdu ? [FontVariation('wght', weight.value.toDouble().clamp(400, 700))] : null,
        // Nastaliq letters reach far above and below the font's reported
        // metrics, so Urdu needs taller lines with the space split evenly,
        // otherwise lines and labels collide.
        height: urdu ? urduHeight : height,
        leadingDistribution: TextLeadingDistribution.even,
        color: color,
        letterSpacing: 0,
      );

  // Minimum 18 sp for all text (NFR-03).
  return TextTheme(
    displaySmall: style(34, FontWeight.w800, 1.15, 1.6),
    headlineMedium: style(28, FontWeight.w700, 1.2, 1.7),
    headlineSmall: style(24, FontWeight.w700, 1.25, 1.75),
    titleLarge: style(22, FontWeight.w700, 1.3, 1.8),
    titleMedium: style(20, FontWeight.w600, 1.35, 1.85),
    titleSmall: style(18, FontWeight.w600, 1.35, 1.9),
    bodyLarge: style(18, FontWeight.w400, 1.5, 2.0),
    bodyMedium: style(18, FontWeight.w400, 1.5, 2.0, AppColors.inkMuted),
    bodySmall: style(18, FontWeight.w400, 1.45, 1.95, AppColors.inkMuted),
    labelLarge: style(18, FontWeight.w600, 1.25, 1.7),
    labelMedium: style(18, FontWeight.w600, 1.25, 1.7),
    labelSmall: style(18, FontWeight.w500, 1.25, 1.7),
  );
}

ThemeData buildTheme(AppLanguage lang) {
  final text = _textTheme(lang);
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    onPrimary: Colors.white,
    primaryContainer: AppColors.primarySoft,
    onPrimaryContainer: AppColors.primaryDark,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.inkMuted,
    surfaceContainerHighest: AppColors.surfaceAlt,
    outline: AppColors.border,
    outlineVariant: AppColors.border,
    error: AppColors.red,
  );

  const buttonPadding = EdgeInsets.symmetric(horizontal: Gap.xl, vertical: Gap.lg);
  final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md));
  const minTap = Size(56, 56); // NFR-03 tap targets

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    textTheme: text,
    fontFamily: lang.isRtl ? _urduFamily : 'Roboto',
    scaffoldBackgroundColor: AppColors.surface,
    splashFactory: InkSparkle.splashFactory,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: AppColors.border,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
      iconTheme: const IconThemeData(color: AppColors.ink, size: 26),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: minTap,
        padding: buttonPadding,
        shape: buttonShape,
        textStyle: text.labelLarge,
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: minTap,
        padding: buttonPadding,
        shape: buttonShape,
        textStyle: text.labelLarge,
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.border, width: 1.5),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: minTap,
        padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
        shape: buttonShape,
        textStyle: text.labelLarge,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(minimumSize: minTap)),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceAlt,
      contentPadding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.lg),
      hintStyle: text.bodyMedium,
      labelStyle: text.bodyMedium,
      floatingLabelStyle: text.titleSmall?.copyWith(color: AppColors.primary),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.sm), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.sm), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.sm),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.sm),
        borderSide: const BorderSide(color: AppColors.red, width: 1.5),
      ),
      errorStyle: text.bodySmall?.copyWith(color: AppColors.red),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        minimumSize: minTap,
        textStyle: text.labelLarge,
        selectedBackgroundColor: AppColors.primarySoft,
        selectedForegroundColor: AppColors.primaryDark,
        side: const BorderSide(color: AppColors.border, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.md),
      ),
    ),
    chipTheme: ChipThemeData(
      labelStyle: text.labelLarge,
      padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.sm),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sm)),
      side: const BorderSide(color: AppColors.border, width: 1.5),
      backgroundColor: AppColors.surface,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: AppColors.border,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.xl)),
      titleTextStyle: text.titleLarge,
      contentTextStyle: text.bodyLarge,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      contentTextStyle: text.bodyLarge?.copyWith(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sm)),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1, space: 1),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
      linearTrackColor: AppColors.primarySoft,
    ),
    tooltipTheme: TooltipThemeData(textStyle: text.bodyMedium?.copyWith(color: Colors.white)),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      textStyle: text.bodyLarge,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
    ),
  );
}
