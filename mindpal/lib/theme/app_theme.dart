import 'package:flutter/material.dart';

import 'app_sizes.dart';

/// Every colour in the app lives here.
///
/// They are hard-coded constants rather than computed with withOpacity() so
/// that text/background contrast is predictable — important when the user may
/// have age-related vision loss.
class AppColors {
  const AppColors._();

  static const Color primary = Color(0xFF00695C); // deep teal
  static const Color primaryDark = Color(0xFF00382F);
  static const Color primarySoft = Color(0xFFD6E7E3); // selected-tab tint
  static const Color onPrimary = Color(0xFFFFFFFF);

  static const Color background = Color(0xFFF3F6F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFCFDBD8);

  static const Color textPrimary = Color(0xFF14201D); // very high contrast
  static const Color textSecondary = Color(0xFF44534F);

  // Category accents. Each is dark enough to carry white icons on top.
  static const Color activity = Color(0xFF1565C0);
  static const Color reminder = Color(0xFF8F5000);
  static const Color memory = Color(0xFF5E35B1);

  static const Color error = Color(0xFFB3261E);
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.error,
    );

    // Deliberately larger than Material defaults.
    // Material's bodyLarge is 16sp; ours is 20sp.
    const textTheme = TextTheme(
      displaySmall: TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      headlineSmall: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titleLarge: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      bodyLarge: TextStyle(
        fontSize: 20,
        height: 1.45,
        color: AppColors.textPrimary,
      ),
      bodyMedium: TextStyle(
        fontSize: 18,
        height: 1.45,
        color: AppColors.textSecondary,
      ),
      labelLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme,

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: AppColors.onPrimary,
        ),
      ),

      navigationBarTheme: const NavigationBarThemeData(
        height: 88,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primarySoft,
        // Our users should never have to guess what an icon means,
        // so labels are always visible.
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        iconTheme: WidgetStatePropertyAll(
          IconThemeData(size: 30, color: AppColors.textSecondary),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          textStyle: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryDark,
          minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
          side: const BorderSide(color: AppColors.primary, width: 2),
          textStyle: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 20,
        ),
        hintStyle: const TextStyle(
          fontSize: 19,
          color: AppColors.textSecondary,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 2.5),
        ),
      ),

      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        contentTextStyle: TextStyle(fontSize: 19, color: Colors.white),
      ),

      dividerTheme: const DividerThemeData(color: AppColors.border, space: 1),
    );
  }
}
