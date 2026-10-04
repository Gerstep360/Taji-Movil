import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/taji_theme.dart';
import '../../../core/utils/visit_datetime.dart';
import '../../../shared/widgets/status_banner.dart';
import '../data/visit_qr_repository.dart';
import '../models/visit_qr.dart';
import '../state/visit_qr_controller.dart';
import '../widgets/qr_expiry_panel.dart';

/// T105 / CU09 / RF-09: pantalla del QR temporal de una visita.
///
/// Muestra el código que el visitante enseña en portería, cuánto le queda de
/// vigencia y los datos de la visita. El contenido del QR solo existe mientras
/// se emite: el backend guarda únicamente su hash, así que esta pantalla emite
/// el código y lo mantiene en memoria mientras está abierta.
class VisitQrScreen extends StatefulWidget {
  const VisitQrScreen({
    super.key,
    required this.authorizationId,
    this.initialVisitorName = '',
    this.initialUnit = '',
  });

  final int authorizationId;

  /// Datos de respaldo para pintar la cabecera antes de que responda el backend.
  final String initialVisitorName;
  final String initialUnit;

  @override
  State<VisitQrScreen> createState() => _VisitQrScreenState();
}

class _VisitQrScreenState extends State<VisitQrScreen> {
  late final VisitQrController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VisitQrController(
      context.read<VisitQrDataSource>(),
      authorizationId: widget.authorizationId,
    );
    _initQr();
  }

  Future<void> _initQr() async {
    await _controller.load();
    if (!mounted) return;
    if (!_controller.hasQrImage && !_controller.isBlockedByStatus) {
      await _generate(force: true, silent: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _generate({bool force = false, bool silent = false}) async {
    final hasImage = await _controller.generate(force: force);
    if (!mounted) return;
    if (_controller.error != null) {
      _message(_controller.error!);
      return;
    }
    if (hasImage && !silent) {
      final rotated = _controller.ticket?.rotated ?? false;
      _message(
        rotated
            ? 'QR rotado. El código anterior ya no es válido.'
            : 'QR generado. Compártelo con el visitante.',
      );
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final visitorName =
        _controller.authorization?.visitorName.isNotEmpty == true
        ? _controller.authorization!.visitorName
        : widget.initialVisitorName;

    return Scaffold(
      appBar: AppBar(
        title: const Text('QR de la visita'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => RefreshIndicator(
            onRefresh: _controller.load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _Header(
                  visitorName: visitorName,
                  unitLabel:
                      _controller.authorization?.unitLabel.isNotEmpty == true
                      ? _controller.authorization!.unitLabel
                      : widget.initialUnit,
                ),
                const SizedBox(height: 16),
                if (_controller.loading && _controller.ticket == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_controller.error != null &&
                    _controller.ticket == null)
                  _LoadError(
                    message: _controller.error!,
                    onRetry: _controller.load,
                  )
                else if (_controller.isBlockedByStatus) ...[
                  _BlockedStatus(
                    authorization: _controller.authorization!,
                    onGenerate: () => _generate(force: true),
                    busy: _controller.generating,
                  ),
                ] else ...[
                  _QrCard(
                    controller: _controller,
                    onGenerate: () => _generate(force: true),
                  ),
                  const SizedBox(height: 14),
                  QrExpiryPanel(
                    remainingSeconds: _controller.remainingSeconds,
                    progress: _controller.progress,
                    isExpired: _controller.isExpired,
                    isNotIssued: !_controller.hasQrImage,
                  ),
                  if (_controller.needsRotation) ...[
                    const SizedBox(height: 12),
                    StatusBanner(
                      message:
                          'Ya existe un QR vigente emitido desde otro dispositivo y su contenido no se puede recuperar. Rota el QR para mostrar uno nuevo.',
                      info: true,
                    ),
                  ],
                  if (_controller.error != null) ...[
                    const SizedBox(height: 12),
                    StatusBanner(message: _controller.error!),
                  ],
                  const SizedBox(height: 18),
                  _Actions(
                    controller: _controller,
                    onGenerate: () => _generate(force: true),
                    onNew: () => _generate(force: true),
                    onRotate: () => _rotate(),
                  ),
                  const SizedBox(height: 22),
                  _VisitDetail(
                    authorization: _controller.authorization,
                    fallbackUnit: widget.initialUnit,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _rotate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Rotar el QR?'),
        content: const Text(
          'El código que el visitante ya tiene dejará de funcionar y se '
          'generará uno nuevo con la misma vigencia.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Rotar QR'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _generate(force: true);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.visitorName, required this.unitLabel});
  final String visitorName;
  final String unitLabel;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        visitorName.isEmpty ? 'Visita autorizada' : visitorName,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      if (unitLabel.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(
          unitLabel,
          style: const TextStyle(color: TajiColors.muted, fontSize: 13),
        ),
      ],
    ],
  );
}

class _QrCard extends StatelessWidget {
  const _QrCard({required this.controller, required this.onGenerate});
  final VisitQrController controller;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    if (controller.generating) {
      return Container(
        height: 280,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: TajiColors.border),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 14),
              Text(
                'Generando código QR temporal...',
                style: TextStyle(color: TajiColors.muted, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }
    if (!controller.hasQrImage) {
      return _QrPlaceholder(onGenerate: onGenerate);
    }
    final dimmed = controller.isExpired;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: dimmed
              ? TajiColors.danger.withValues(alpha: .3)
              : TajiColors.border,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F6FFF),
            blurRadius: 26,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          // El QR se dibuja con `QrImageView` a partir del payload en lugar de
          // decodificar la imagen que devuelve el backend: así se ve nítido en
          // cualquier densidad de pantalla y no llega un SVG por la red.
          Opacity(
            opacity: dimmed ? .28 : 1,
            child: QrImageView(
              data: controller.payload!,
              version: QrVersions.auto,
              size: 216,
              gapless: true,
              padding: EdgeInsets.zero,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: TajiColors.ink,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: TajiColors.ink,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            dimmed ? 'Código vencido' : 'Muestra este código en portería',
            style: TextStyle(
              color: dimmed ? TajiColors.danger : TajiColors.ink,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Al vencimiento el guardia no podrá permitir el ingreso.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: TajiColors.muted, fontSize: 11),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: TajiColors.border),
          const SizedBox(height: 12),
          const _CodeNotice(),
        ],
      ),
    );
  }
}

class _CodeNotice extends StatelessWidget {
  const _CodeNotice();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Icon(Icons.lock_outline, size: 14, color: TajiColors.muted),
      const SizedBox(width: 7),
      Expanded(
        child: Text(
          'El código es personal e intransferible. Taji no lo almacena en '
          'claro: solo se genera mientras esta pantalla está abierta.',
          style: const TextStyle(
            color: TajiColors.muted,
            fontSize: 10,
            height: 1.4,
          ),
        ),
      ),
    ],
  );
}

class _QrPlaceholder extends StatelessWidget {
  const _QrPlaceholder({this.onGenerate});
  final VoidCallback? onGenerate;

  @override
  Widget build(BuildContext context) => Container(
    height: 260,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: TajiColors.border),
    ),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.qr_code_2_rounded, size: 54, color: Color(0xFF0F6FFF)),
          const SizedBox(height: 12),
          const Text(
            'Código QR no generado',
            style: TextStyle(
              color: TajiColors.ink,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Presiona el botón para generar el pase de acceso seguro.',
            style: TextStyle(color: TajiColors.muted, fontSize: 12),
          ),
          if (onGenerate != null) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onGenerate,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0F6FFF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.flash_on_rounded, size: 18),
              label: const Text('Generar Pase QR', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    ),
  );
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.controller,
    required this.onGenerate,
    required this.onNew,
    required this.onRotate,
  });

  final VisitQrController controller;
  final VoidCallback onGenerate;

  /// Emisión de un código nuevo sobre uno ya vencido: no pide confirmación.
  final VoidCallback onNew;

  final VoidCallback onRotate;

  @override
  Widget build(BuildContext context) {
    final busy = controller.generating;
    if (!controller.hasQrImage) {
      return FilledButton.icon(
        onPressed: busy ? null : onGenerate,
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        icon: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.qr_code_2),
        label: Text(busy ? 'Generando...' : 'Generar QR'),
      );
    }
    // Un código vencido no se ofrece para compartir: copiarlo solo le haría
    // llegar al visitante un código que portería va a rechazar. Se rota sin
    // pedir confirmación porque el anterior ya no hace nada.
    if (!controller.isUsable) {
      return FilledButton.icon(
        onPressed: busy ? null : onNew,
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        icon: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.qr_code_2),
        label: Text(busy ? 'Generando...' : 'Generar QR nuevo'),
      );
    }
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: busy
                ? null
                : () async {
                    await Clipboard.setData(
                      ClipboardData(text: controller.payload!),
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Código copiado al portapapeles.'),
                      ),
                    );
                  },
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copiar'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: busy ? null : onRotate,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              foregroundColor: TajiColors.primaryStrong,
              side: const BorderSide(color: TajiColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.autorenew, size: 18),
            label: Text(busy ? 'Rotando...' : 'Rotar'),
          ),
        ),
      ],
    );
  }
}

class _VisitDetail extends StatelessWidget {
  const _VisitDetail({required this.authorization, required this.fallbackUnit});
  final VisitQrAuthorization? authorization;
  final String fallbackUnit;

  @override
  Widget build(BuildContext context) {
    final data = authorization;
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: TajiColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Datos de la visita',
            style: TextStyle(
              color: TajiColors.ink,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          if (data == null)
            Text(
              fallbackUnit.isEmpty ? 'Sin detalle disponible.' : fallbackUnit,
              style: const TextStyle(color: TajiColors.muted, fontSize: 12),
            )
          else ...[
            _Row(
              label: 'Estado',
              value: data.statusLabel.isEmpty
                  ? data.status.label
                  : data.statusLabel,
            ),
            _Row(label: 'Visitante', value: data.visitorName),
            if (data.visitorDocumentLabel.isNotEmpty)
              _Row(label: 'Documento', value: data.visitorDocumentLabel),
            _Row(label: 'Unidad', value: data.unitLabel),
            _Row(label: 'Autoriza', value: data.residentName),
            if (data.purpose.isNotEmpty)
              _Row(label: 'Motivo', value: data.purpose),
            _Row(label: 'Desde', value: formatVisitDateTime(data.validFrom)),
            _Row(
              label: 'Hasta',
              value: formatVisitDateTime(data.validUntil),
              last: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.last = false});
  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 9),
    decoration: BoxDecoration(
      border: last
          ? null
          : const Border(bottom: BorderSide(color: Color(0xFFEDF1F5))),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: const TextStyle(color: TajiColors.muted, fontSize: 11),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '—' : value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: TajiColors.ink,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _BlockedStatus extends StatelessWidget {
  const _BlockedStatus({
    required this.authorization,
    required this.onGenerate,
    required this.busy,
  });

  final VisitQrAuthorization authorization;
  final VoidCallback onGenerate;
  final bool busy;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      StatusBanner(
        message:
            'La visita está ${authorization.status.label.toLowerCase()}. No se '
            'puede emitir ni usar un QR.',
      ),
      const SizedBox(height: 14),
      QrExpiryPanel(remainingSeconds: 0, progress: 0, isExpired: true),
      const SizedBox(height: 18),
      OutlinedButton.icon(
        onPressed: busy ? null : onGenerate,
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        icon: const Icon(Icons.refresh, size: 18),
        label: const Text('Actualizar estado'),
      ),
    ],
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      StatusBanner(message: message),
      const SizedBox(height: 14),
      OutlinedButton.icon(
        onPressed: onRetry,
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        icon: const Icon(Icons.refresh, size: 18),
        label: const Text('Reintentar'),
      ),
    ],
  );
}
