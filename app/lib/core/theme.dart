import 'package:flutter/material.dart';

import '../data/models/finding.dart';
import 'i18n.dart';

/// Colour tokens. One brand colour; status colours appear only on small
/// indicators. Text colours pass WCAG AA on white and on [canvas].
class AppColors {
  static const primary = Color(0xFF0A5C8E);
  static const primaryDark = Color(0xFF07466D);
  static const primarySoft = Color(0xFFE6EFF5);

  static const ink = Color(0xFF16202A);
  static const inkMuted = Color(0xFF56616C);
  static const inkSubtle = Color(0xFF7D8791);

  /// Page background; [surface] sections sit on it.
  static const canvas = Color(0xFFF2F4F6);
  static const surface = Colors.white;
  static const border = Color(0xFFE2E6EA);
  static const borderStrong = Color(0xFFCDD3D9);

  static const green = Color(0xFF1F7A4A);
  static const greenSoft = Color(0xFFE6F2EB);
  static const greenInk = Color(0xFF17603A);

  static const amber = Color(0xFFC98A00);
  static const amberSoft = Color(0xFFFBF2DC);
  static const amberInk = Color(0xFF7A4B00);

  static const red = Color(0xFFC0362C);
  static const redSoft = Color(0xFFFAE8E6);
  static const redInk = Color(0xFF9A2A22);
}

/// Spacing scale (4-point grid).
class Gap {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const page = 16.0;
}

class Radii {
  static const xs = 6.0;
  static const sm = 10.0;
  static const md = 12.0;
  static const lg = 16.0;
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

/// Numbers (amounts, units) in a plain Latin font with even-width digits in
/// both languages, so Western digits read clearly and line up (NFR-02).
TextStyle numberStyle(
  double size, {
  Color color = AppColors.ink,
  FontWeight weight = FontWeight.w600,
  double letterSpacing = 0,
}) =>
    TextStyle(
      fontFamily: 'Roboto',
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: 1.15,
      letterSpacing: letterSpacing,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

const _urduFamily = 'NotoNastaliqUrdu';

TextTheme _textTheme(AppLanguage lang) {
  final urdu = lang.isRtl;
  TextStyle style(
    double size,
    FontWeight weight,
    double height,
    double urduHeight, {
    Color color = AppColors.ink,
    double letterSpacing = 0,
  }) =>
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
        letterSpacing: urdu ? 0 : letterSpacing,
      );

  // Standard Android sizes; Settings → Text size → Large scales them up.
  return TextTheme(
    displaySmall: style(28, FontWeight.w700, 1.15, 1.6, letterSpacing: -0.4),
    headlineMedium: style(24, FontWeight.w700, 1.2, 1.7, letterSpacing: -0.3),
    headlineSmall: style(20, FontWeight.w600, 1.25, 1.75, letterSpacing: -0.2),
    titleLarge: style(18, FontWeight.w600, 1.3, 1.8),
    titleMedium: style(16, FontWeight.w600, 1.35, 1.85),
    titleSmall: style(14.5, FontWeight.w600, 1.35, 1.9),
    bodyLarge: style(15.5, FontWeight.w400, 1.45, 2.0),
    bodyMedium: style(14.5, FontWeight.w400, 1.45, 2.0, color: AppColors.inkMuted),
    bodySmall: style(13, FontWeight.w400, 1.4, 1.95, color: AppColors.inkMuted),
    labelLarge: style(15, FontWeight.w600, 1.25, 1.7),
    labelMedium: style(13.5, FontWeight.w600, 1.25, 1.7),
    // Section headings: small, muted, tracked.
    labelSmall: style(12.5, FontWeight.w600, 1.25, 1.7, color: AppColors.inkMuted, letterSpacing: 0.4),
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
    secondaryContainer: AppColors.primarySoft,
    onSecondaryContainer: AppColors.primaryDark,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.inkMuted,
    surfaceContainerHighest: AppColors.canvas,
    surfaceContainerLow: AppColors.surface,
    outline: AppColors.borderStrong,
    outlineVariant: AppColors.border,
    error: AppColors.red,
  );

  const buttonPadding = EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md);
  final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sm));
  const minTap = Size(48, 48); // Android minimum tap target
  OutlineInputBorder inputBorder(Color color, [double width = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.sm),
        borderSide: BorderSide(color: color, width: width),
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    textTheme: text,
    fontFamily: lang.isRtl ? _urduFamily : 'Roboto',
    scaffoldBackgroundColor: AppColors.canvas,
    splashFactory: InkRipple.splashFactory,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.canvas,
      foregroundColor: AppColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      shadowColor: AppColors.borderStrong,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
      iconTheme: const IconThemeData(color: AppColors.ink, size: 24),
      actionsIconTheme: const IconThemeData(color: AppColors.inkMuted, size: 24),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: minTap,
        padding: buttonPadding,
        shape: buttonShape,
        textStyle: text.labelLarge,
        elevation: 0,
        disabledBackgroundColor: AppColors.border,
        disabledForegroundColor: AppColors.inkSubtle,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: minTap,
        padding: buttonPadding,
        shape: buttonShape,
        textStyle: text.labelLarge,
        foregroundColor: AppColors.ink,
        backgroundColor: AppColors.surface,
        side: const BorderSide(color: AppColors.borderStrong),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: minTap,
        padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.sm),
        shape: buttonShape,
        textStyle: text.labelLarge,
        foregroundColor: AppColors.primary,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(minimumSize: minTap)),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: AppColors.inkMuted,
      titleTextStyle: text.titleSmall,
      subtitleTextStyle: text.bodySmall,
      contentPadding: const EdgeInsets.symmetric(horizontal: Gap.lg),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md + 2),
      hintStyle: text.bodyMedium?.copyWith(color: AppColors.inkSubtle),
      labelStyle: text.bodyMedium,
      floatingLabelStyle: text.bodyMedium?.copyWith(color: AppColors.primary),
      border: inputBorder(AppColors.borderStrong),
      enabledBorder: inputBorder(AppColors.borderStrong),
      disabledBorder: inputBorder(AppColors.border),
      focusedBorder: inputBorder(AppColors.primary, 1.5),
      errorBorder: inputBorder(AppColors.red),
      focusedErrorBorder: inputBorder(AppColors.red, 1.5),
      errorStyle: text.bodySmall?.copyWith(color: AppColors.red),
      errorMaxLines: 3,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        minimumSize: minTap,
        textStyle: text.labelLarge,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.inkMuted,
        selectedBackgroundColor: AppColors.primarySoft,
        selectedForegroundColor: AppColors.primaryDark,
        side: const BorderSide(color: AppColors.borderStrong),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sm)),
        padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.sm),
      ),
    ),
    chipTheme: ChipThemeData(
      labelStyle: text.labelMedium,
      padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: Gap.xs + 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sm)),
      side: const BorderSide(color: AppColors.borderStrong),
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.primarySoft,
      showCheckmark: false,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: AppColors.borderStrong,
      dragHandleSize: Size(36, 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg)),
      titleTextStyle: text.titleLarge,
      contentTextStyle: text.bodyLarge,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
      actionTextColor: const Color(0xFF9CCBEA),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sm)),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1, space: 1),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
      linearTrackColor: AppColors.primarySoft,
    ),
    tooltipTheme: TooltipThemeData(
      textStyle: text.bodySmall?.copyWith(color: Colors.white),
      decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(Radii.xs)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      textStyle: text.bodyLarge,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
    ),
  );
}
