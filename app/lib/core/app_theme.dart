import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'tokens.dart';

/// Тема ЭлPay: светлая и тёмная, построены на одних и тех же токенах бренда.
class AppTheme {
  static const _font = 'Montserrat';

  static ThemeData light() => _base(
        Brightness.light,
        const ColorScheme.light(
          primary: Brand.primary,
          onPrimary: Brand.onPrimary,
          secondary: Brand.p700,
          surface: Brand.bg,
          onSurface: Brand.ink,
          error: Brand.danger,
        ),
        AppColors.light,
        Brand.soft,
      );

  static ThemeData dark() => _base(
        Brightness.dark,
        const ColorScheme.dark(
          primary: Brand.primary,
          onPrimary: Brand.onPrimary,
          secondary: Brand.dP700,
          surface: Brand.dBg,
          onSurface: Brand.dInk,
          error: Brand.danger,
        ),
        AppColors.dark,
        Brand.dSoft,
      );

  static ThemeData _base(
    Brightness brightness,
    ColorScheme scheme,
    AppColors colors,
    Color scaffold,
  ) {
    final ink = scheme.onSurface;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: _font,
      scaffoldBackgroundColor: scaffold,
      splashFactory: InkSparkle.splashFactory,
      extensions: [colors],
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: _font,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
        iconTheme: IconThemeData(color: ink),
        systemOverlayStyle: brightness == Brightness.light
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
      ),
      textTheme: TextTheme(
        displaySmall: TextStyle(
            fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -.6, color: ink),
        headlineMedium: TextStyle(
            fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -.56, height: 1.15, color: ink),
        headlineSmall: TextStyle(
            fontSize: 21, fontWeight: FontWeight.w700, letterSpacing: -.2, color: ink),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ink),
        titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: ink),
        bodyLarge: TextStyle(fontSize: 15, height: 1.45, color: ink),
        bodyMedium: TextStyle(fontSize: 14, height: 1.45, color: ink),
        bodySmall: TextStyle(fontSize: 13, height: 1.35, color: colors.muted),
        labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ink),
        labelMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.ink3),
        labelSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.muted),
      ),
      dividerTheme: DividerThemeData(color: colors.line2, thickness: 1, space: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          backgroundColor: Brand.primary,
          foregroundColor: Brand.onPrimary,
          disabledBackgroundColor: Brand.primary.withValues(alpha: .4),
          disabledForegroundColor: Brand.onPrimary.withValues(alpha: .6),
          textStyle: const TextStyle(
              fontFamily: _font, fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.accent,
          textStyle: const TextStyle(
              fontFamily: _font, fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: TextStyle(color: colors.muted2, fontWeight: FontWeight.w500),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.line, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Brand.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Brand.danger, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Brand.danger, width: 1.5),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        showDragHandle: true,
        dragHandleColor: colors.line,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: brightness == Brightness.light ? Brand.ink : const Color(0xFF0B1114),
        contentTextStyle: const TextStyle(
            fontFamily: _font, fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? Colors.white : Colors.white),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? Brand.primary : colors.line),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
    );
  }
}
