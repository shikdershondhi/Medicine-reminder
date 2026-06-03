import 'package:flutter/material.dart';
import '../services/database_service.dart';

class AppColors {
  // Light Mode Colors
  static const Color lightPrimary = Color(0xFF005E53);
  static const Color lightPrimaryContainer = Color(0xFF00796B);
  static const Color lightOnPrimaryContainer = Color(0xFFA1FEEC);
  static const Color lightSecondary = Color(0xFF632CE5);
  static const Color lightSecondaryContainer = Color(0xFF7C4DFF);
  static const Color lightOnSecondaryContainer = Color(0xFFFCF6FF);
  static const Color lightTertiary = Color(0xFF9A2A00);
  static const Color lightTertiaryContainer = Color(0xFFBD4117);
  static const Color lightOnTertiaryContainer = Color(0xFFFFE8E2);
  static const Color lightError = Color(0xFFBA1A1A);
  static const Color lightErrorContainer = Color(0xFFFFDAD6);
  static const Color lightOnErrorContainer = Color(0xFF93000A);
  
  static const Color background = Color(0xFFF8FAFA);
  static const Color onBackground = Color(0xFF191C1D);
  static const Color surface = Color(0xFFF8FAFA);
  static const Color onSurface = Color(0xFF191C1D);
  static const Color onSurfaceVariant = Color(0xFF3E4946);
  static const Color surfaceVariant = Color(0xFFE1E3E3);
  
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF2F4F4);
  static const Color surfaceContainer = Color(0xFFECEEEE);
  static const Color surfaceContainerHigh = Color(0xFFE6E8E8);
  static const Color surfaceContainerHighest = Color(0xFFE1E3E3);
  
  static const Color outline = Color(0xFF6E7A76);
  static const Color outlineVariant = Color(0xFFBDC9C5);

  // Dark Mode Colors
  static const Color darkPrimary = Color(0xFF2DD4BF); // Vibrant Slate Teal (Teal 400)
  static const Color darkPrimaryContainer = Color(0xFF0F766E); // Deep Teal (Teal 700)
  static const Color darkOnPrimaryContainer = Color(0xFFF0FDFA);
  static const Color darkSecondary = Color(0xFFC084FC); // Purple 400
  static const Color darkSecondaryContainer = Color(0xFF7C3AED); // Violet 600
  static const Color darkOnSecondaryContainer = Color(0xFFFAF5FF);
  static const Color darkTertiary = Color(0xFFFB7185); // Rose 400
  static const Color darkTertiaryContainer = Color(0xFFBE123C); // Rose 700
  static const Color darkOnTertiaryContainer = Color(0xFFFFF1F2);
  static const Color darkError = Color(0xFFF87171); // Red 400
  static const Color darkErrorContainer = Color(0xFF7F1D1D); // Red 900
  static const Color darkOnErrorContainer = Color(0xFFFEE2E2);

  static const Color darkBackground = Color(0xFF090D16); // Deep space slate
  static const Color darkOnBackground = Color(0xFFF8FAFC); // Slate 50
  static const Color darkSurface = Color(0xFF090D16);
  static const Color darkOnSurface = Color(0xFFF8FAFC);
  static const Color darkOnSurfaceVariant = Color(0xFF94A3B8); // Slate 400
  static const Color darkSurfaceVariant = Color(0xFF1E293B); // Slate 800

  static const Color darkSurfaceContainerLowest = Color(0xFF020617);
  static const Color darkSurfaceContainerLow = Color(0xFF0F172A); // Slate 900
  static const Color darkSurfaceContainer = Color(0xFF1E293B); // Slate 800
  static const Color darkSurfaceContainerHigh = Color(0xFF334155); // Slate 700
  static const Color darkSurfaceContainerHighest = Color(0xFF475569);

  static const Color darkOutline = Color(0xFF334155); // Slate 700
  static const Color darkOutlineVariant = Color(0xFF1E293B);

  // Dynamic Getters for screen widgets referencing AppColors directly
  static Color get primary => DatabaseService().isDarkMode() ? darkPrimary : lightPrimary;
  static Color get primaryContainer => DatabaseService().isDarkMode() ? darkPrimaryContainer : lightPrimaryContainer;
  static Color get onPrimaryContainer => DatabaseService().isDarkMode() ? darkOnPrimaryContainer : lightOnPrimaryContainer;
  static Color get secondary => DatabaseService().isDarkMode() ? darkSecondary : lightSecondary;
  static Color get secondaryContainer => DatabaseService().isDarkMode() ? darkSecondaryContainer : lightSecondaryContainer;
  static Color get onSecondaryContainer => DatabaseService().isDarkMode() ? darkOnSecondaryContainer : lightOnSecondaryContainer;
  static Color get tertiary => DatabaseService().isDarkMode() ? darkTertiary : lightTertiary;
  static Color get tertiaryContainer => DatabaseService().isDarkMode() ? darkTertiaryContainer : lightTertiaryContainer;
  static Color get onTertiaryContainer => DatabaseService().isDarkMode() ? darkOnTertiaryContainer : lightOnTertiaryContainer;
  static Color get error => DatabaseService().isDarkMode() ? darkError : lightError;
  static Color get errorContainer => DatabaseService().isDarkMode() ? darkErrorContainer : lightErrorContainer;
  static Color get onErrorContainer => DatabaseService().isDarkMode() ? darkOnErrorContainer : lightOnErrorContainer;
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.lightPrimary,
      colorScheme: const ColorScheme.light(
        primary: AppColors.lightPrimary,
        primaryContainer: AppColors.lightPrimaryContainer,
        onPrimaryContainer: AppColors.lightOnPrimaryContainer,
        secondary: AppColors.lightSecondary,
        secondaryContainer: AppColors.lightSecondaryContainer,
        onSecondaryContainer: AppColors.lightOnSecondaryContainer,
        tertiary: AppColors.lightTertiary,
        tertiaryContainer: AppColors.lightTertiaryContainer,
        onTertiaryContainer: AppColors.lightOnTertiaryContainer,
        error: AppColors.lightError,
        errorContainer: AppColors.lightErrorContainer,
        onErrorContainer: AppColors.lightOnErrorContainer,
        background: AppColors.background,
        onBackground: AppColors.onBackground,
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
        surfaceVariant: AppColors.surfaceVariant,
        onSurfaceVariant: AppColors.onSurfaceVariant,
        outline: AppColors.outline,
        outlineVariant: AppColors.outlineVariant,
      ),
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Inter',
      cardTheme: CardThemeData(
        color: AppColors.surfaceContainerLowest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
          side: const BorderSide(color: AppColors.outlineVariant, width: 1.0),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: AppColors.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: AppColors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: AppColors.lightPrimary, width: 2.0),
        ),
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.onSurfaceVariant),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.lightSecondaryContainer,
          foregroundColor: AppColors.onSecondaryContainer,
          elevation: 2,
          padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 24.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.01,
          ),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.02),
        headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w400, height: 1.5),
        bodyMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.01),
        labelSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.04),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.background,
        selectedItemColor: AppColors.lightPrimary,
        unselectedItemColor: AppColors.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.darkPrimary,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.darkPrimary,
        primaryContainer: AppColors.darkPrimaryContainer,
        onPrimaryContainer: AppColors.darkOnPrimaryContainer,
        secondary: AppColors.darkSecondary,
        secondaryContainer: AppColors.darkSecondaryContainer,
        onSecondaryContainer: AppColors.darkOnSecondaryContainer,
        tertiary: AppColors.darkTertiary,
        tertiaryContainer: AppColors.darkTertiaryContainer,
        onTertiaryContainer: AppColors.darkOnTertiaryContainer,
        error: AppColors.darkError,
        errorContainer: AppColors.darkErrorContainer,
        onErrorContainer: AppColors.darkOnErrorContainer,
        background: AppColors.darkBackground,
        onBackground: AppColors.darkOnBackground,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkOnSurface,
        surfaceVariant: AppColors.darkSurfaceVariant,
        onSurfaceVariant: AppColors.darkOnSurfaceVariant,
        outline: AppColors.darkOutline,
        outlineVariant: AppColors.darkOutlineVariant,
      ),
      scaffoldBackgroundColor: AppColors.darkBackground,
      fontFamily: 'Inter',
      cardTheme: CardThemeData(
        color: AppColors.darkSurfaceContainerLow,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
          side: const BorderSide(color: AppColors.darkOutline, width: 1.0),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: AppColors.darkOutline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: AppColors.darkOutline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: AppColors.darkPrimary, width: 2.0),
        ),
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.darkOnSurfaceVariant),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.darkSecondaryContainer,
          foregroundColor: AppColors.darkOnSecondaryContainer,
          elevation: 2,
          padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 24.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.01,
          ),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.02, color: AppColors.darkOnSurface),
        headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.darkOnSurface),
        headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.darkOnSurface),
        bodyLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w400, height: 1.5, color: AppColors.darkOnSurface),
        bodyMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5, color: AppColors.darkOnSurface),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.01, color: AppColors.darkOnSurface),
        labelSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.04, color: AppColors.darkOnSurfaceVariant),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkSurfaceContainerLow,
        selectedItemColor: AppColors.darkPrimary,
        unselectedItemColor: AppColors.darkOnSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}
