import 'package:flutter/material.dart';

abstract final class AppColors {
  // Primary - Tennis green
  static const Color primary = Color(0xFF2E7D32);
  static const Color primaryLight = Color(0xFF60AD5E);
  static const Color primaryDark = Color(0xFF005005);

  // Secondary - Gold/Yellow for rankings
  static const Color secondary = Color(0xFFFFA000);
  static const Color secondaryLight = Color(0xFFFFD149);
  static const Color secondaryDark = Color(0xFFC67100);

  // Neutrals
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onSecondary = Color(0xFF000000);
  static const Color onBackground = Color(0xFF1C1B1F);
  static const Color onSurface = Color(0xFF1C1B1F);

  // Status colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFE53935);
  static const Color info = Color(0xFF2196F3);

  // Ranking specific
  static const Color rankUp = Color(0xFF4CAF50);
  static const Color rankDown = Color(0xFFE53935);
  static const Color rankSame = Color(0xFF9E9E9E);
  static const Color gold = Color(0xFFFFD700);
  static const Color silver = Color(0xFFC0C0C0);
  static const Color bronze = Color(0xFFCD7F32);

  // Challenge status
  static const Color challengePending = Color(0xFFFF9800);
  static const Color challengeScheduled = Color(0xFF2196F3);
  static const Color challengeCompleted = Color(0xFF4CAF50);
  static const Color challengeWo = Color(0xFFE53935);

  // Ambulance
  static const Color ambulanceActive = Color(0xFFE53935);
  static const Color ambulanceProtection = Color(0xFF9C27B0);
}
