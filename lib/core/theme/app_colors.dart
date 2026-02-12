import 'package:flutter/material.dart';

abstract final class AppColors {
  // Primary - Deep Forest Green (Wimbledon-inspired)
  static const Color primary = Color(0xFF1B4332);
  static const Color primaryLight = Color(0xFF2D6A4F);
  static const Color primaryDark = Color(0xFF0B2B1E);
  static const Color primarySurface = Color(0xFFE8F0EC);

  // Secondary - Champagne Gold
  static const Color secondary = Color(0xFFC9A84C);
  static const Color secondaryLight = Color(0xFFDFC77A);
  static const Color secondaryDark = Color(0xFFA38A30);
  static const Color secondarySurface = Color(0xFFFBF7EC);

  // Backgrounds & Surfaces
  static const Color background = Color(0xFFFAF8F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF5F2ED);
  static const Color surfaceDim = Color(0xFFEDE9E3);

  // Text
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onSecondary = Color(0xFF2C2C2C);
  static const Color onBackground = Color(0xFF2C2C2C);
  static const Color onBackgroundMedium = Color(0xFF5C5C5C);
  static const Color onBackgroundLight = Color(0xFF8A8A8A);
  static const Color onSurface = Color(0xFF2C2C2C);

  // Status
  static const Color success = Color(0xFF2E7D4E);
  static const Color warning = Color(0xFFD4A017);
  static const Color error = Color(0xFFC0392B);
  static const Color info = Color(0xFF2874A6);

  // Ranking
  static const Color rankUp = Color(0xFF2E7D4E);
  static const Color rankDown = Color(0xFFC0392B);
  static const Color rankSame = Color(0xFF8A8A8A);
  static const Color gold = Color(0xFFD4AF37);
  static const Color silver = Color(0xFFA8A8A8);
  static const Color bronze = Color(0xFFB87333);

  // Challenge status
  static const Color challengePending = Color(0xFFD4A017);
  static const Color challengeScheduled = Color(0xFF2874A6);
  static const Color challengeCompleted = Color(0xFF2E7D4E);
  static const Color challengeWo = Color(0xFFC0392B);

  // Ambulance
  static const Color ambulanceActive = Color(0xFFC0392B);
  static const Color ambulanceProtection = Color(0xFF6C3483);

  // Decorative
  static const Color divider = Color(0xFFE0DCD5);
  static const Color border = Color(0xFFD5D0C8);

  // ─── Gradients ───
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2D6A4F), Color(0xFF1B4332), Color(0xFF0B2B1E)],
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFDFC77A), Color(0xFFC9A84C), Color(0xFFA38A30)],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1B4332), Color(0xFF2D6A4F)],
  );

  // ─── Shadows (tinted) ───
  static Color get shadowColor => const Color(0xFF1B4332).withAlpha(18);
  static Color get shadowColorMedium => const Color(0xFF1B4332).withAlpha(35);

  // ─── Glass / Navbar ───
  static Color get glassBackground => Colors.white.withAlpha(204); // 80%
  static Color get glassBorder => Colors.white.withAlpha(153); // 60%
}
