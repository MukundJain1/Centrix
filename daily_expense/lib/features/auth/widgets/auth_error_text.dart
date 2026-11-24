import 'package:flutter/material.dart';

import 'auth_scale.dart';

/// Animated inline error. Collapses to nothing when [message] is null.
class AuthErrorText extends StatelessWidget {
  const AuthErrorText({super.key, required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final sc = AuthScale.of(context);

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      alignment: Alignment.topCenter,
      child: message == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: EdgeInsets.only(top: sc.gap(18)),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 16,
                    color: Colors.redAccent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      message!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
