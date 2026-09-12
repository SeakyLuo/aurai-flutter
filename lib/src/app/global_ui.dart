import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 全局视觉配置：品牌色及 Material 组件样式统一在此维护。
abstract final class GlobalUI {
  static const Color primary = Color(0xffafa9ee);
  static const Color primaryLight = Color(0xffddc5f7);
  static const Color primaryBackground = Color(0xfff4effb);
  static const Color onPrimaryBackground = Color(0xff493365);
  static const Color onPrimary = Color(0xff493365);
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryLight, Color(0xffc8b7f4), primary],
  );

  static const LinearGradient frostedHighlight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x40ffffff), Color(0x12ffffff), Color(0x08ffffff)],
    stops: [0, 0.55, 1],
  );
  static const Color frostedBorder = Color(0x70ffffff);
  static const Color buttonShadow = Color(0x307969b5);

  static const LinearGradient liquidGlassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x80ddc5f7), Color(0x66c8b7f4), Color(0x99afa9ee)],
  );
  static const LinearGradient darkLiquidGlassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xcc504568), Color(0xb338304b), Color(0xcc484061)],
  );
  static const double liquidGlassBlur = 5;

  static ThemeData get theme => _theme(Brightness.light);
  static ThemeData get darkTheme => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final colors = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: dark ? const Color(0xff343047) : primaryBackground,
      onPrimaryContainer: dark ? const Color(0xffe6dcfa) : onPrimaryBackground,
      surface: dark ? const Color(0xff18181b) : Colors.white,
      onSurface: dark ? const Color(0xffeeeeF2) : const Color(0xff171717),
      onSurfaceVariant: dark
          ? const Color(0xffaaa8b3)
          : const Color(0xff737580),
      surfaceContainerHighest: dark
          ? const Color(0xff2a292f)
          : const Color(0xfff5f5f8),
      outlineVariant: dark ? const Color(0xff39383f) : const Color(0xffe9e9f0),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colors,
      scaffoldBackgroundColor: colors.surface,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: dark ? Colors.white : Colors.black,
        selectionHandleColor: dark ? Colors.white : Colors.black,
      ),
      scrollbarTheme: ScrollbarThemeData(
        radius: const Radius.circular(99),
        thickness: const WidgetStatePropertyAll(3),
        thumbColor: WidgetStatePropertyAll(
          colors.onSurfaceVariant.withValues(alpha: 0.45),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.outlineVariant,
        thickness: 1,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: const StadiumBorder(),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        showDragHandle: true,
        surfaceTintColor: Colors.transparent,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        systemOverlayStyle: dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 64,
        titleSpacing: 16,
        titleTextStyle: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w600,
          color: colors.onSurface,
        ),
        iconTheme: IconThemeData(size: 24, color: colors.onSurface),
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
