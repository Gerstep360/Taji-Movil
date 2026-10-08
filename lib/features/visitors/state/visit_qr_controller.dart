import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_failure.dart';
import '../data/visit_qr_repository.dart';
import '../models/visit_qr.dart';

/// Estado del QR temporal de una visita (CU09 / RF-09 / T105).
///
/// La vigencia se descuenta contra el reloj local a partir de `qr_expires_at`
/// que envía el backend en valor absoluto. Si el servidor no lo provee, se cae
/// a los segundos restantes que informa la propia respuesta.
class VisitQrController extends ChangeNotifier {
  VisitQrController(this._repository, {required this.authorizationId});

  final VisitQrDataSource _repository;
  final int authorizationId;

  VisitQrTicket? _ticket;

  /// Texto a codificar. Solo se conoce en la respuesta de emisión: el backend
  /// guarda únicamente el hash del token, así que no hay forma de recuperarlo
  /// consultando después.
  String? _payload;
  DateTime? _expiresAt;
  int _remainingSeconds = 0;

  /// Vigencia total en el momento de la emisión. Sirve de denominador para la
  /// barra de progreso; no vuelve a leerse del servidor en cada tick.
  int _totalSeconds = 0;
  bool loading = false;
  bool generating = false;
  String? error;
  Timer? _ticker;

  VisitQrTicket? get ticket => _ticket;
  VisitQrAuthorization? get authorization => _ticket?.authorization;

  /// Hay un QR emitido por este dispositivo y todavía vigente: se puede mostrar.
  String? get payload => _payload;

  bool get hasQrImage => (_payload ?? '').isNotEmpty;
  int get remainingSeconds => _remainingSeconds;
  int get totalSeconds => _totalSeconds;
  bool get isExpired => _remainingSeconds <= 0;

  /// Fracción de vigencia que queda, entre 0 y 1.
  double get progress {
    if (_totalSeconds <= 0) return 0;
    final ratio = _remainingSeconds / _totalSeconds;
    return ratio.clamp(0, 1);
  }

  /// El QR se puede compartir con el visitante sin que sirva de algo inútil.
  bool get isUsable => hasQrImage && !isExpired;

  /// El backend sabe que hay un QR vigente, pero su contenido no se puede
  /// recuperar porque nunca se almacena en claro. Hay que rotarlo para mostrarlo.
  bool get needsRotation =>
      !hasQrImage && (_ticket?.issued ?? false) && (_ticket?.active ?? false);

  /// La autorización está en un estado que impide emitir o usar un QR.
  bool get isBlockedByStatus => (authorization?.status.isTerminal ?? false);

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      _apply(await _repository.status(authorizationId));
      // Al abrir la pantalla se pide el QR directamente en vez de mostrar un
      // aviso de "generar". El `generate` sin `force` es idempotente en el
      // backend: si ya habia un QR vigente lo deja intacto y responde 200 sin
      // payload, de modo que no se invalida el codigo que ya se compartio.
      await _autoGenerateIfNeeded();
    } on ApiFailure catch (failure) {
      error = failure.displayMessage;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Emite el QR solo cuando de verdad hace falta: que no exista todavia o que
  /// el que hay haya caducado.
  ///
  /// No se emite cuando hay un QR vigente emitido desde otro dispositivo: su
  /// contenido no se puede recuperar porque el servidor solo guarda el hash, y
  /// rotarlo sin que el residente lo pida dejaria sin codigo al que ya
  /// compartio el QR anterior. En ese caso se mantiene el aviso de rotar.
  Future<void> _autoGenerateIfNeeded() async {
    if (isBlockedByStatus) return;

    final hasUsableQr = hasQrImage && !isExpired;
    if (hasUsableQr) return;
    if (needsRotation) return;
    if (generating) return;

    await generate();
  }

  /// Emite el QR. Devuelve `true` si hay una imagen lista para mostrar.
  ///
  /// `force` rota un QR todavía vigente, lo que inutiliza el código anterior.
  Future<bool> generate({bool force = false, int? ttlMinutes}) async {
    generating = true;
    error = null;
    notifyListeners();
    try {
      final issued = await _repository.generate(
        authorizationId,
        ttlMinutes: ttlMinutes,
        force: force,
      );
      _apply(issued);
      return hasQrImage;
    } on ApiFailure catch (failure) {
      error = failure.displayMessage;
      return false;
    } finally {
      generating = false;
      notifyListeners();
    }
  }

  void _apply(VisitQrTicket next) {
    _ticket = next;
    // El payload solo viene en la respuesta de emisión. Ante una respuesta
    // idempotente (200) llega `null` y se conserva el que ya teníamos en
    // memoria, porque sigue siendo el mismo QR vigente.
    if (next.hasPayload) {
      _payload = next.payload;
      _totalSeconds = next.expiresInSeconds;
      _expiresAt =
          next.authorization.qrExpiresAt ??
          DateTime.now().add(Duration(seconds: next.expiresInSeconds));
    } else if (_payload != null) {
      _totalSeconds = next.expiresInSeconds;
      _expiresAt ??=
          next.authorization.qrExpiresAt ??
          DateTime.now().add(Duration(seconds: next.expiresInSeconds));
    }
    _syncTicker();
  }

  void _syncTicker() {
    _ticker?.cancel();
    _ticker = null;
    _remainingSeconds = _computeRemaining();
    if (_remainingSeconds <= 0) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final remaining = _computeRemaining();
      if (remaining == _remainingSeconds) return;
      _remainingSeconds = remaining;
      if (remaining <= 0) _ticker?.cancel();
      notifyListeners();
    });
  }

  int _computeRemaining() {
    final deadline = _expiresAt;
    if (deadline == null) return 0;
    final remaining = deadline.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ticker = null;
    super.dispose();
  }
}
