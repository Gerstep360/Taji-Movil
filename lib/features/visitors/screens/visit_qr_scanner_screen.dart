import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/taji_theme.dart';
import '../../../core/utils/camera_permission.dart';
import '../../../core/utils/visit_datetime.dart';
import '../../../shared/widgets/status_banner.dart';
import '../../../shared/widgets/taji_text_field.dart';
import 'package:permission_handler/permission_handler.dart';
import '../data/visit_qr_repository.dart';
import '../models/visit_qr.dart';
import '../state/visit_qr_validation_controller.dart';

/// T106 / CU10 / RF-10: lector de QR del personal de seguridad.
///
/// Escanea el QR de una visita y muestra el veredicto del backend con la
/// validez, la vigencia, el estado, el visitante y la unidad autorizante antes
/// de permitir el ingreso.
///
/// El backend responde `200 OK` tanto para un ingreso aprobado como para uno
/// denegado, así que la pantalla se guía por `valid` y nunca por el código HTTP.
class VisitQrScannerScreen extends StatefulWidget {
  const VisitQrScannerScreen({super.key});

  @override
  State<VisitQrScannerScreen> createState() => _VisitQrScannerScreenState();
}

class _VisitQrScannerScreenState extends State<VisitQrScannerScreen>
    with WidgetsBindingObserver {
  late final VisitQrValidationController _controller;
  late final MobileScannerController _camera;
  final _manualToken = TextEditingController();
  bool _cameraMounted = true;
  bool _permissionDenied = false;
  bool _torchOn = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = VisitQrValidationController(
      context.read<VisitQrDataSource>(),
    );
    _camera = MobileScannerController(
      autoStart: false,
      formats: const [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
    _controller.loadReasons();
    _checkPermissionOnStart();
  }

  Future<void> _checkPermissionOnStart() async {
    final granted = await CameraPermissionHelper.ensureCameraPermission(context);
    if (!mounted) return;
    if (granted) {
      setState(() {
        _permissionDenied = false;
        _cameraMounted = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_camera.start());
      });
    } else {
      setState(() {
        _permissionDenied = true;
        _cameraMounted = false;
      });
    }
  }

  Future<void> _retryCamera() async {
    final granted = await CameraPermissionHelper.ensureCameraPermission(context);
    if (!mounted) return;
    if (granted) {
      setState(() {
        _permissionDenied = false;
        _cameraMounted = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_camera.start());
      });
    } else {
      setState(() {
        _permissionDenied = true;
        _cameraMounted = false;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _manualToken.dispose();
    _camera.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Sin esto la cámara sigue consumiendo en segundo plano al volver desde
    // otra aplicación.
    if (!mounted) return;
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(_camera.start());
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        unawaited(_camera.stop());
    }
  }

  /// Reengancha la cámara tras un frame, porque `MobileScannerController.start()`
  /// exige que el widget `MobileScanner` ya esté construido.
  void _startCameraAfterFrame() {
    if (!mounted) return;
    setState(() => _cameraMounted = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_camera.start());
    });
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_submitting || _controller.isPaused) return;
    final value = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .firstWhere(
          (value) => value != null && value.trim().isNotEmpty,
          orElse: () => null,
        );
    if (value == null) return;
    // Se detiene la cámara mientras se consulta para no encadenar eventos de
    // acceso por el mismo código.
    await _camera.stop();
    await _submit(value);
  }

  Future<void> _submit(String token, {String? notes}) async {
    setState(() => _submitting = true);
    final answered = await _controller.validate(token, notes: notes);
    if (!mounted) return;
    setState(() {
      _submitting = false;
      // Un veredicto aparta la cámara: la pantalla pasa a mostrar el resultado.
      _cameraMounted = !answered;
    });
    if (!answered) {
      HapticFeedback.heavyImpact();
      final message = _controller.error;
      if (message != null) _message(message);
    } else {
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> _scanAgain() async {
    _controller.scanAgain();
    _startCameraAfterFrame();
  }

  Future<void> _toggleTorch() async {
    await _camera.toggleTorch();
    if (mounted) setState(() => _torchOn = !_torchOn);
  }

  Future<void> _openManualEntry() async {
    _manualToken.clear();
    final value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          top: 22,
          bottom: MediaQuery.of(context).viewInsets.bottom + 22,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Ingresar código manualmente',
              style: TextStyle(
                color: TajiColors.ink,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Úsalo si la cámara no funciona o si el visitante no puede mostrar '
              'el QR en pantalla.',
            ),
            const SizedBox(height: 16),
            TajiTextField(
              controller: _manualToken,
              label: 'Código de la visita',
              hint: 'TAJI1.…',
              icon: Icons.qr_code_2,
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, _manualToken.text),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              icon: const Icon(Icons.search, size: 19),
              label: const Text('Validar'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || value == null || value.trim().isEmpty) return;
    await _camera.stop();
    await _submit(value.trim());
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// Ventana de escaneo: un cuadrado centrado en el tercio superior, con aire
  /// para el rótulo de arriba y el panel de resultados de abajo.
  static Rect _scanWindowFor(Size size) {
    final side = (size.width * .68).clamp(160.0, size.height * .5);
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height * .40),
      width: side,
      height: side,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final window = _scanWindowFor(size);
        return Stack(
          fit: StackFit.expand,
          children: [
            if (_cameraMounted && !_permissionDenied)
              MobileScanner(
                controller: _camera,
                onDetect: _onDetect,
                // Restringe la detección al recuadro: mejora la tasa de acierto
                // y evita leer códigos que quedan fuera de la mira del guardia.
                scanWindow: window,
                placeholderBuilder: (_) =>
                    const ColoredBox(color: Colors.black),
                errorBuilder: (context, error) => _CameraError(
                  error: error,
                  onRetry: _retryCamera,
                  onManualEntry: _openManualEntry,
                ),
              )
            else
              _CameraPermissionDeniedView(
                onRetry: _retryCamera,
                onManualEntry: _openManualEntry,
              ),
            IgnorePointer(
              child: CustomPaint(painter: _ScrimPainter(window: window)),
            ),
            _buildTopBar(),
            _buildBottomPanel(),
          ],
        );
      },
    ),
  );

  Widget _buildTopBar() => Positioned(
    top: 0,
    left: 0,
    right: 0,
    child: Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 6,
        left: 8,
        right: 8,
        bottom: 10,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xCC000000), Color(0x00000000)],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            tooltip: 'Volver',
          ),
          const Expanded(
            child: Text(
              'Validar QR de visita',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
          IconButton(
            onPressed: _cameraMounted ? _toggleTorch : null,
            icon: Icon(
              _torchOn ? Icons.flashlight_on : Icons.flashlight_off,
              color: _torchOn ? Colors.amberAccent : Colors.white,
            ),
            tooltip: 'Linterna',
          ),
          IconButton(
            onPressed: _cameraMounted
                ? () async {
                    await _camera.switchCamera();
                    if (mounted) setState(() {});
                  }
                : null,
            icon: const Icon(Icons.cameraswitch_outlined, color: Colors.white),
            tooltip: 'Cambiar cámara',
          ),
        ],
      ),
    ),
  );

  Widget _buildBottomPanel() {
    final bottom = MediaQuery.of(context).padding.bottom;
    final result = _controller.result;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(16, 18, 16, bottom + 18),
        decoration: const BoxDecoration(
          color: TajiColors.canvas,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_submitting)
                const _Scanning()
              else if (result != null)
                _Verdict(
                  validation: result,
                  detailMessage: _controller.messageFor(result.reason),
                  onScanAgain: _scanAgain,
                )
              else if (_controller.error != null)
                _ScanError(
                  message: _controller.error!,
                  onRetry: _startCameraAfterFrame,
                )
              else ...[
                const _ScanPrompt(),
                const SizedBox(height: 12),
                _SessionStats(
                  approved: _controller.approvedCount,
                  denied: _controller.deniedCount,
                ),
                const SizedBox(height: 12),
                _ManualEntryButton(onPressed: _openManualEntry),
                if (_controller.history.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _RecentScans(history: _controller.history),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Escurece el preview salvo en la ventana de escaneo y dibuja sus esquinas.
class _ScrimPainter extends CustomPainter {
  const _ScrimPainter({required this.window});
  final Rect window;

  @override
  void paint(Canvas canvas, Size size) {
    final scrim = Paint()..color = const Color(0x8C000000);
    final full = Path()..addRect(Offset.zero & size);
    final hole = Path()
      ..addRRect(RRect.fromRectAndRadius(window, const Radius.circular(22)));
    canvas.drawPath(Path.combine(PathOperation.difference, full, hole), scrim);

    final corner = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const length = 30.0;
    for (final entry in [
      (window.topLeft, const Offset(1, 1)),
      (window.topRight, const Offset(-1, 1)),
      (window.bottomLeft, const Offset(1, -1)),
      (window.bottomRight, const Offset(-1, -1)),
    ]) {
      canvas.drawLine(
        entry.$1,
        entry.$1.translate(entry.$2.dx * length, 0),
        corner,
      );
      canvas.drawLine(
        entry.$1,
        entry.$1.translate(0, entry.$2.dy * length),
        corner,
      );
    }
  }

  @override
  bool shouldRepaint(_ScrimPainter oldDelegate) => oldDelegate.window != window;
}

class _ScanPrompt extends StatelessWidget {
  const _ScanPrompt();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Icon(Icons.qr_code_scanner, size: 42, color: TajiColors.primary),
      const SizedBox(height: 10),
      const Text(
        'Apunta al QR de la visita',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: TajiColors.ink,
          fontWeight: FontWeight.w800,
          fontSize: 17,
        ),
      ),
      const SizedBox(height: 5),
      const Text(
        'Verificaremos la vigencia, el estado, el visitante y la unidad antes de permitir el ingreso.',
        textAlign: TextAlign.center,
        style: TextStyle(color: TajiColors.muted, fontSize: 12, height: 1.45),
      ),
    ],
  );
}

class _Scanning extends StatelessWidget {
  const _Scanning();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 26),
    child: Column(
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text(
          'Verificando la autorización…',
          style: TextStyle(
            color: TajiColors.ink,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ],
    ),
  );
}

class _ManualEntryButton extends StatelessWidget {
  const _ManualEntryButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(50),
      side: const BorderSide(color: TajiColors.border),
      foregroundColor: TajiColors.primaryStrong,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    icon: const Icon(Icons.keyboard_alt_outlined, size: 19),
    label: const Text('Ingresar código manualmente'),
  );
}

class _ScanError extends StatelessWidget {
  const _ScanError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      StatusBanner(message: message),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: onRetry,
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
        icon: const Icon(Icons.qr_code_scanner, size: 19),
        label: const Text('Volver a escanear'),
      ),
    ],
  );
}

/// Resultado de la validación: ingreso permitido o denegado (RF-10).
class _Verdict extends StatelessWidget {
  const _Verdict({
    required this.validation,
    required this.detailMessage,
    required this.onScanAgain,
  });

  final VisitQrValidation validation;
  final String detailMessage;
  final VoidCallback onScanAgain;

  @override
  Widget build(BuildContext context) {
    final allowed = validation.valid;
    final color = allowed ? TajiColors.success : TajiColors.danger;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: allowed ? TajiColors.successSoft : TajiColors.dangerSoft,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: .28)),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  allowed ? Icons.check_rounded : Icons.block,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      allowed ? 'Ingreso permitido' : 'Ingreso denegado',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 19,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      validation.reasonLabel,
                      style: const TextStyle(
                        color: TajiColors.ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        StatusBanner(
          message: detailMessage.isNotEmpty
              ? detailMessage
              : validation.message,
          success: allowed,
        ),
        if (!validation.hasAuthorization) ...[
          const SizedBox(height: 10),
          StatusBanner(
            message:
                'El código no corresponde a ninguna visita registrada. No '
                'permitas el ingreso por este QR.',
          ),
        ] else ...[
          const SizedBox(height: 12),
          _VerdictDetail(validation: validation),
          if (validation.requiresNewQr) ...[
            const SizedBox(height: 12),
            const StatusBanner(
              message:
                  'Pide al residente un QR nuevo antes de permitir el ingreso.',
              info: true,
            ),
          ],
          if (validation.accessEvent != null) ...[
            const SizedBox(height: 10),
            _EventStamp(event: validation.accessEvent!),
          ],
        ],
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: onScanAgain,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: allowed ? TajiColors.primary : TajiColors.danger,
          ),
          icon: const Icon(Icons.qr_code_scanner, size: 19),
          label: const Text('Escanear otro código'),
        ),
      ],
    );
  }
}

class _VerdictDetail extends StatelessWidget {
  const _VerdictDetail({required this.validation});
  final VisitQrValidation validation;

  @override
  Widget build(BuildContext context) {
    final data = validation.authorization!;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TajiColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            data.visitorName,
            style: const TextStyle(
              color: TajiColors.ink,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          if (data.visitorDocumentLabel.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              data.visitorDocumentLabel,
              style: const TextStyle(color: TajiColors.muted, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          _DetailRow(
            icon: Icons.apartment_outlined,
            label: 'Unidad',
            value: data.unitLabel,
          ),
          _DetailRow(
            icon: Icons.badge_outlined,
            label: 'Autoriza',
            value: data.residentName,
          ),
          if (data.purpose.isNotEmpty)
            _DetailRow(
              icon: Icons.notes_outlined,
              label: 'Motivo',
              value: data.purpose,
            ),
          _DetailRow(
            icon: Icons.schedule,
            label: 'Vigencia',
            value:
                '${formatVisitDateTime(data.validFrom)}\n${formatVisitDateTime(data.validUntil)}',
          ),
          _DetailRow(
            icon: Icons.flag_outlined,
            label: 'Estado',
            value: data.statusLabel.isEmpty
                ? data.status.label
                : data.statusLabel,
            last: true,
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(
      border: last
          ? null
          : const Border(bottom: BorderSide(color: Color(0xFFEDF1F5))),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: TajiColors.muted),
        const SizedBox(width: 9),
        SizedBox(
          width: 74,
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
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Rastro del evento de acceso que dejó registrado el escaneo.
class _EventStamp extends StatelessWidget {
  const _EventStamp({required this.event});
  final VisitAccessEvent event;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Icon(
        Icons.receipt_long_outlined,
        size: 13,
        color: TajiColors.muted,
      ),
      const SizedBox(width: 7),
      Expanded(
        child: Text(
          'Evento #${event.id} · ${event.eventLabel} · '
          '${event.validationMethod} · ${event.resultLabel} · '
          '${formatVisitDateTime(event.occurredAt)}',
          style: const TextStyle(color: TajiColors.muted, fontSize: 10),
        ),
      ),
    ],
  );
}

class _SessionStats extends StatelessWidget {
  const _SessionStats({required this.approved, required this.denied});
  final int approved;
  final int denied;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _StatChip(
          label: 'Permitidos',
          value: approved,
          color: TajiColors.success,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _StatChip(
          label: 'Denegados',
          value: denied,
          color: TajiColors.danger,
        ),
      ),
    ],
  );
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: TajiColors.border),
    ),
    child: Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 19,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: TajiColors.muted, fontSize: 11),
        ),
      ],
    ),
  );
}

class _RecentScans extends StatelessWidget {
  const _RecentScans({required this.history});
  final List<ScanLogEntry> history;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Escaneos de esta sesión',
        style: TextStyle(
          color: TajiColors.muted,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
      const SizedBox(height: 8),
      ...history
          .take(5)
          .map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    entry.validation.valid
                        ? Icons.check_circle_outline
                        : Icons.cancel_outlined,
                    size: 15,
                    color: entry.validation.valid
                        ? TajiColors.success
                        : TajiColors.danger,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.validation.visitorName.isNotEmpty
                          ? entry.validation.visitorName
                          : entry.validation.reasonLabel,
                      style: const TextStyle(
                        color: TajiColors.ink,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    formatVisitDateTime(entry.validation.checkedAt),
                    style: const TextStyle(
                      color: TajiColors.muted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
    ],
  );
}

/// Cámara no disponible: sin permiso, sin hardware o con un fallo del plugin.
class _CameraError extends StatelessWidget {
  const _CameraError({
    required this.error,
    required this.onRetry,
    required this.onManualEntry,
  });

  final MobileScannerException error;
  final VoidCallback onRetry;
  final VoidCallback onManualEntry;

  @override
  Widget build(BuildContext context) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: TajiColors.canvas,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 60, 26, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                denied
                    ? Icons.no_photography_outlined
                    : Icons.videocam_off_outlined,
                size: 44,
                color: TajiColors.muted,
              ),
              const SizedBox(height: 14),
              Text(
                denied
                    ? 'Necesitamos la cámara para leer el QR'
                    : 'No pudimos iniciar la cámara',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                denied
                    ? 'Habilita el permiso de cámara en los ajustes del sistema para escanear visitas.'
                    : 'Puedes ingresar el código manualmente mientras tanto.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: TajiColors.muted,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                icon: const Icon(Icons.refresh, size: 19),
                label: Text(denied ? 'Solicitar permiso de cámara' : 'Reintentar'),
              ),
              if (denied) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => openAppSettings(),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    side: const BorderSide(color: TajiColors.border),
                  ),
                  icon: const Icon(Icons.settings_outlined, size: 19),
                  label: const Text('Abrir Ajustes del Teléfono'),
                ),
              ],
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onManualEntry,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  side: const BorderSide(color: TajiColors.border),
                ),
                icon: const Icon(Icons.keyboard_alt_outlined, size: 19),
                label: const Text('Ingresar código manualmente'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CameraPermissionDeniedView extends StatelessWidget {
  const _CameraPermissionDeniedView({
    required this.onRetry,
    required this.onManualEntry,
  });

  final VoidCallback onRetry;
  final VoidCallback onManualEntry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: TajiColors.canvas,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 60, 26, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                size: 52,
                color: TajiColors.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Permiso de Cámara Requerido',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Para escanear pases QR de portería en tiempo real, se requiere acceso a la cámara del dispositivo.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: TajiColors.muted,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                icon: const Icon(Icons.camera_alt_outlined, size: 19),
                label: const Text('Conceder Permiso de Cámara'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => openAppSettings(),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  side: const BorderSide(color: TajiColors.border),
                ),
                icon: const Icon(Icons.settings_outlined, size: 19),
                label: const Text('Abrir Ajustes del Teléfono'),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: onManualEntry,
                icon: const Icon(Icons.keyboard_alt_outlined, size: 19),
                label: const Text('Ingresar código manualmente'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
