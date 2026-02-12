import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class GradientButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final LinearGradient? gradient;
  final double height;
  final double borderRadius;

  const GradientButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.gradient,
    this.height = 56,
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null;
    final effectiveGradient = gradient ?? AppColors.primaryGradient;

    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: isDisabled ? null : effectiveGradient,
        color: isDisabled ? AppColors.surfaceDim : null,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: isDisabled
            ? null
            : [
                BoxShadow(
                  color: AppColors.primary.withAlpha(50),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Center(
            child: DefaultTextStyle(
              style: TextStyle(
                color: isDisabled ? AppColors.onBackgroundLight : Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
                letterSpacing: 0,
              ),
              child: IconTheme(
                data: IconThemeData(
                  color: isDisabled ? AppColors.onBackgroundLight : Colors.white,
                  size: 20,
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
