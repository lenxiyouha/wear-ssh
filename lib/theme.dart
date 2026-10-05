import 'package:flutter/material.dart';

/// 全局配色：深空蓝黑 + 青色高亮，OLED 圆表省电友好
class AppColors {
  static const Color bg = Color(0xFF05080F);
  static const Color card = Color(0xFF0E1626);
  static const Color cardAlt = Color(0xFF162135);
  static const Color stroke = Color(0x33FFFFFF);
  static const Color primary = Color(0xFF22D3EE);
  static const Color onPrimary = Color(0xFF04202A);
  static const Color ok = Color(0xFF34D399);
  static const Color danger = Color(0xFFF87171);
  static const Color warn = Color(0xFFFBBF24);
  static const Color text = Color(0xFFE8EFF8);
  static const Color textDim = Color(0xFF93A6C0);
  static const Color termBg = Color(0xFF04070C);
  static const Color termFg = Color(0xFFCDEBD9);
}

/// 应用主题（Material 3 深色）
ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.dark,
  ).copyWith(
    primary: AppColors.primary,
    secondary: AppColors.ok,
    surface: AppColors.card,
    error: AppColors.danger,
    onPrimary: AppColors.onPrimary,
    onSurface: AppColors.text,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
  );

  final textTheme = base.textTheme
      .apply(bodyColor: AppColors.text, displayColor: AppColors.text)
      .copyWith(
        titleLarge: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.text,
          letterSpacing: .5,
        ),
        titleMedium: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
        ),
        bodyMedium: const TextStyle(fontSize: 12, color: AppColors.text),
        bodySmall: const TextStyle(fontSize: 11, color: AppColors.textDim),
        labelSmall: const TextStyle(fontSize: 10, color: AppColors.textDim),
      );

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    textTheme: textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.text,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF1B2942),
      contentTextStyle: textTheme.bodyMedium,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: AppColors.primary),
    dividerTheme: const DividerThemeData(
      color: AppColors.stroke,
      thickness: .6,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: const Color(0xFF0A1120),
      hintStyle: const TextStyle(fontSize: 11.5, color: AppColors.textDim),
      labelStyle: const TextStyle(fontSize: 11.5, color: AppColors.textDim),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.stroke),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.stroke),
      ),
    ),
  );
}
