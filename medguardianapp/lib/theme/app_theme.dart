import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Central ThemeData builder for MedGuardian.
class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      secondary: AppColors.accent,
      error: AppColors.danger,
      surface: AppColors.surface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Roboto',
      splashFactory: InkRipple.splashFactory,
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.8, height: 1.15),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.6),
        headlineLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.4),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        titleLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        titleSmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.textPrimary, height: 1.5),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textPrimary, height: 1.45),
        bodySmall: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w400, color: AppColors.textSecondary, height: 1.4),
        labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.2),
        labelMedium: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textFaint, letterSpacing: 0.3),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(56),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size.fromHeight(56),
          side: const BorderSide(color: AppColors.primary, width: 1.6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: const TextStyle(color: AppColors.textFaint, fontSize: 15),
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w600),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: AppColors.line, width: 1.4)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: AppColors.line, width: 1.4)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: const BorderSide(color: AppColors.line)),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.primaryDark,
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        showDragHandle: true,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceMuted,
        selectedColor: AppColors.primary,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: AppColors.line)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.surfaceMuted,
        circularTrackColor: AppColors.surfaceMuted,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
    );
  }
}
