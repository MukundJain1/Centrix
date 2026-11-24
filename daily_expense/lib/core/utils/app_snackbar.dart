import 'package:flutter/material.dart';

import '../theme/colors.dart';

enum AppSnackType { error, warning, success, info }

/// Rounded, dark floating message that matches the app theme.
///
///   AppSnackbar.error(context, 'Wrong PIN. 3 attempts left.');
///   AppSnackbar.success(context, 'Saved');
class AppSnackbar {
  AppSnackbar._();

  static void error(BuildContext context, String message, {IconData? icon}) =>
      _show(context, message, AppSnackType.error, icon);

  static void warning(BuildContext context, String message, {IconData? icon}) =>
      _show(context, message, AppSnackType.warning, icon);

  static void success(BuildContext context, String message, {IconData? icon}) =>
      _show(context, message, AppSnackType.success, icon);

  static void info(BuildContext context, String message, {IconData? icon}) =>
      _show(context, message, AppSnackType.info, icon);

  static void _show(
    BuildContext context,
    String message,
    AppSnackType type,
    IconData? icon,
  ) {
    final (Color color, IconData defaultIcon) = switch (type) {
      AppSnackType.error => (Colors.redAccent, Icons.error_outline_rounded),
      AppSnackType.warning => (Colors.amber, Icons.warning_amber_rounded),
      AppSnackType.success => (const Color(0xFF5BAA77), Icons.check_circle_outline_rounded),
      AppSnackType.info => (AppColors.primaryAccent, Icons.info_outline_rounded),
    };

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          padding: EdgeInsets.zero,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          duration: const Duration(seconds: 3),
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.inputSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.5)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon ?? defaultIcon, size: 20, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }
}
