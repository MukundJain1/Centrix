import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';

/// Shows a 3D-styled floating SnackBar for 3 seconds, scoped to the auth flow.
void showAuth3dSnackBar(
  BuildContext context, {
  required String message,
  required bool isError,
  IconData? icon,
  Duration duration = const Duration(seconds: 3),
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        duration: duration,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        padding: EdgeInsets.zero,
        content: _Auth3dSnackBarCard(
          message: message,
          isError: isError,
          icon: icon ??
              (isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_rounded),
        ),
      ),
    );
}

class _Auth3dSnackBarCard extends StatelessWidget {
  const _Auth3dSnackBarCard({
    required this.message,
    required this.isError,
    required this.icon,
  });

  final String message;
  final bool isError;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final accent = isError ? const Color(0xFFFF5252) : const Color(0xFF00E676);
    final deepLip = isError ? const Color(0xFF8E1919) : const Color(0xFF0A6E3B);
    final topTint = isError ? const Color(0xFF33191D) : const Color(0xFF142E24);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        // Thick bottom edge gives the raised 3D card depth.
        color: deepLip,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: accent.withValues(alpha: 0.22),
            blurRadius: 20,
            spreadRadius: -2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.only(bottom: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                topTint,
                AppColors.inputSurface,
              ],
            ),
            // Uniform border color required whenever borderRadius is set.
            border: Border.all(
              color: accent.withValues(alpha: 0.45),
              width: 1,
            ),
          ),
          child: Stack(
            children: [
              // Subtle top specular highlight rim for 3D depth.
              Positioned(
                top: 0,
                left: 16,
                right: 16,
                child: Container(
                  height: 1.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.white.withValues(alpha: 0.32),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                child: Row(
                  children: [
                    // Raised 3D icon badge.
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(11),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            accent.withValues(alpha: 0.28),
                            accent.withValues(alpha: 0.12),
                          ],
                        ),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.55),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(icon, color: accent, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        message,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}