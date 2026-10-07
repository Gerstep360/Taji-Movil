import 'package:flutter/material.dart';

import '../../../core/theme/taji_theme.dart';
import '../../../core/utils/visit_datetime.dart';

/// Cuenta regresiva de vigencia de un QR (RF-09).
///
/// Cambia de color según lo que queda: verde con margen, ámbar al acercarse al
/// límite y rojo al vencer, para que el estado se lea de un vistazo sin
/// tener que interpretar el reloj.
class QrExpiryPanel extends StatelessWidget {
  const QrExpiryPanel({
    super.key,
    required this.remainingSeconds,
    required this.progress,
    required this.isExpired,
    this.isNotIssued = false,
  });

  /// Segundos que quedan hasta que el QR deja de ser utilizable.
  final int remainingSeconds;

  /// Fracción de vigencia restante, entre 0 y 1.
  final double progress;

  final bool isExpired;

  /// Todavía no se emitió ningún QR para esta autorización.
  final bool isNotIssued;

  /// Por debajo de este margen el código ya no debería compartirse.
  static const warningThreshold = 900; // 15 minutos

  @override
  Widget build(BuildContext context) {
    if (isNotIssued) {
      return _panel(
        context,
        icon: Icons.qr_code_2_outlined,
        title: 'QR sin emitir',
        subtitle: 'Genera el código para compartirlo con el visitante.',
        color: TajiColors.muted,
        background: const Color(0xFFF4F7FB),
        showClock: false,
      );
    }

    final isWarning = !isExpired && remainingSeconds <= warningThreshold;
    final color = isExpired
        ? TajiColors.danger
        : isWarning
        ? TajiColors.warning
        : TajiColors.success;
    final background = isExpired
        ? TajiColors.dangerSoft
        : isWarning
        ? TajiColors.warningSoft
        : TajiColors.successSoft;

    return _panel(
      context,
      icon: isExpired
          ? Icons.timer_off_outlined
          : isWarning
          ? Icons.timer_outlined
          : Icons.timer,
      title: isExpired
          ? 'QR vencido'
          : isWarning
          ? 'Vence pronto'
          : 'QR vigente',
      subtitle: isExpired
          ? 'Este código ya no autoriza el ingreso. Genera uno nuevo.'
          : 'Vigencia restante: ${formatDuration(remainingSeconds)}',
      color: color,
      background: background,
      showClock: true,
      progress: isExpired ? 0 : progress,
    );
  }

  Widget _panel(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color background,
    required bool showClock,
    double? progress,
  }) => Semantics(
    liveRegion: true,
    label: '$title. $subtitle',
    child: Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: .22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: TajiColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (showClock) ...[
                const SizedBox(width: 10),
                Text(
                  formatClock(remainingSeconds),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 19,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 13),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress.clamp(0, 1),
                minHeight: 6,
                backgroundColor: color.withValues(alpha: .16),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
