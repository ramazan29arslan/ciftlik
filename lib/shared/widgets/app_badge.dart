import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class AppBadge extends StatelessWidget {
  final String label;
  final Color? color;
  final Color? textColor;
  final bool small;

  const AppBadge({
    super.key,
    required this.label,
    this.color,
    this.textColor,
    this.small = false,
  });

  factory AppBadge.success(String label) => AppBadge(
        label: label,
        color: AppColors.successLight,
        textColor: AppColors.success,
      );

  factory AppBadge.warning(String label) => AppBadge(
        label: label,
        color: AppColors.warningLight,
        textColor: AppColors.warning,
      );

  factory AppBadge.error(String label) => AppBadge(
        label: label,
        color: AppColors.errorLight,
        textColor: AppColors.error,
      );

  factory AppBadge.info(String label) => AppBadge(
        label: label,
        color: AppColors.infoLight,
        textColor: AppColors.info,
      );

  factory AppBadge.primary(String label) => AppBadge(
        label: label,
        color: AppColors.primarySurface,
        textColor: AppColors.primary,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 10,
        vertical: small ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color ?? AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          
          fontSize: small ? 10 : 12,
          fontWeight: FontWeight.w600,
          color: textColor ?? AppColors.textSecondary,
        ),
      ),
    );
  }
}

class AppStatusDot extends StatelessWidget {
  final Color color;
  final double size;

  const AppStatusDot({
    super.key,
    required this.color,
    this.size = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
