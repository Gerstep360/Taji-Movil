import 'package:flutter/material.dart';

import '../../core/theme/taji_theme.dart';

class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.message,
    this.success = false,
    this.info = false,
  });
  final String message;
  final bool success;
  final bool info;

  @override
  Widget build(BuildContext context) {
    if (message.isEmpty) return const SizedBox.shrink();
    final color = success
        ? TajiColors.success
        : info
        ? TajiColors.primaryStrong
        : TajiColors.danger;
    final background = success
        ? const Color(0xFFEAFBF3)
        : info
        ? TajiColors.primarySoft
        : const Color(0xFFFFF1F2);
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: .18)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              success ? Icons.check_circle_outline : Icons.info_outline,
              color: color,
              size: 20,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: color, fontSize: 13, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PasswordMeter extends StatelessWidget {
  const PasswordMeter({super.key, required this.password});
  final String password;

  int get score {
    var value = 0;
    if (password.length >= 10) value++;
    if (RegExp(r'[a-z]').hasMatch(password) &&
        RegExp(r'[A-Z]').hasMatch(password)) {
      value++;
    }
    if (RegExp(r'\d').hasMatch(password)) value++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) value++;
    return value;
  }

  @override
  Widget build(BuildContext context) {
    const labels = [
      'Usa al menos 10 caracteres',
      'Básica',
      'Buena',
      'Fuerte',
      'Muy fuerte',
    ];
    const colors = [
      Color(0xFFCBD5E1),
      Color(0xFFEF4444),
      Color(0xFFF59E0B),
      TajiColors.success,
      TajiColors.primary,
    ];
    return Row(
      children: [
        Expanded(
          child: Row(
            children: List.generate(
              4,
              (index) => Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: index == 3 ? 0 : 4),
                  decoration: BoxDecoration(
                    color: score > index ? colors[score] : TajiColors.border,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          labels[score],
          style: const TextStyle(color: TajiColors.muted, fontSize: 11),
        ),
      ],
    );
  }
}
