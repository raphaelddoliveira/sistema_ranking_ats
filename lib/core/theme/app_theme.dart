import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static const double _radiusSm = 12.0;
  static const double _radiusMd = 16.0;
  static const double _radiusLg = 24.0;
  static const double _radiusXl = 28.0;

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          onPrimary: AppColors.onPrimary,
          primaryContainer: AppColors.primarySurface,
          onPrimaryContainer: AppColors.primaryDark,
          secondary: AppColors.secondary,
          onSecondary: AppColors.onSecondary,
          secondaryContainer: AppColors.secondarySurface,
          onSecondaryContainer: AppColors.secondaryDark,
          surface: AppColors.surface,
          onSurface: AppColors.onSurface,
          surfaceContainerHighest: AppColors.surfaceVariant,
          error: AppColors.error,
          onError: Colors.white,
          outline: AppColors.border,
          outlineVariant: AppColors.divider,
        ),
        textTheme: AppTypography.textTheme,
        scaffoldBackgroundColor: AppColors.background,

        // AppBar
        appBarTheme: AppBarTheme(
          centerTitle: true,
          elevation: 2,
          scrolledUnderElevation: 3,
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: AppTypography.textTheme.titleLarge?.copyWith(
            color: AppColors.onPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
          iconTheme: const IconThemeData(
            color: AppColors.onPrimary,
            size: 22,
          ),
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
        ),

        // TabBar
        tabBarTheme: TabBarThemeData(
          labelColor: AppColors.onPrimary,
          unselectedLabelColor: AppColors.onPrimary.withAlpha(178),
          indicatorColor: AppColors.secondary,
          indicatorSize: TabBarIndicatorSize.tab,
          labelStyle: AppTypography.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
          unselectedLabelStyle: AppTypography.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w400,
            letterSpacing: 0.5,
          ),
          dividerColor: Colors.transparent,
        ),

        // Cards - modern: no border, subtle shadow with tint
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          color: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          shadowColor: AppColors.shadowColor,
          margin: EdgeInsets.zero,
        ),

        // Elevated Buttons - modern: bigger radius, shadow, bolder
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            disabledBackgroundColor: AppColors.surfaceDim,
            disabledForegroundColor: AppColors.onBackgroundLight,
            minimumSize: const Size(double.infinity, 56),
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_radiusMd),
            ),
            elevation: 2,
            shadowColor: AppColors.shadowColorMedium,
            textStyle: AppTypography.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),

        // Outlined Buttons
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            minimumSize: const Size(double.infinity, 56),
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_radiusMd),
            ),
            side: const BorderSide(color: AppColors.primary, width: 1.5),
            textStyle: AppTypography.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),

        // Text Buttons
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            textStyle: AppTypography.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // Input Fields - modern: no border on normal, only on focus
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceVariant,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_radiusMd),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_radiusMd),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_radiusMd),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_radiusMd),
            borderSide:
                const BorderSide(color: AppColors.error, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_radiusMd),
            borderSide:
                const BorderSide(color: AppColors.error, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          hintStyle: AppTypography.textTheme.bodyMedium?.copyWith(
            color: AppColors.onBackgroundLight,
          ),
          prefixIconColor: AppColors.onBackgroundMedium,
          suffixIconColor: AppColors.onBackgroundMedium,
        ),

        // Bottom Navigation
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.onBackgroundLight,
          selectedLabelStyle: AppTypography.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
          unselectedLabelStyle:
              AppTypography.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w400,
            color: AppColors.onBackgroundLight,
          ),
          elevation: 0,
        ),

        // Divider
        dividerTheme: const DividerThemeData(
          color: AppColors.divider,
          thickness: 1,
          space: 1,
        ),

        // FAB
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: AppColors.secondary,
          foregroundColor: AppColors.onSecondary,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radiusMd),
          ),
        ),

        // Dialog
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radiusXl),
          ),
          titleTextStyle: AppTypography.textTheme.headlineSmall?.copyWith(
            fontSize: 20,
          ),
        ),

        // Chips
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.surfaceVariant,
          labelStyle: AppTypography.textTheme.labelMedium,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.divider),
          ),
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),

        // SnackBar
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radiusLg),
          ),
        ),

        // ListTile
        listTileTheme: ListTileThemeData(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radiusMd),
          ),
        ),

        // ProgressIndicator
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AppColors.primary,
          linearTrackColor: AppColors.primarySurface,
          circularTrackColor: AppColors.primarySurface,
        ),

        // PopupMenu
        popupMenuTheme: PopupMenuThemeData(
          color: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radiusSm),
            side: const BorderSide(color: AppColors.divider),
          ),
        ),
      );
}
