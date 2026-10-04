import 'package:flutter/foundation.dart';

import '../../../core/network/api_failure.dart';
import '../data/visit_qr_repository.dart';
import '../models/visit_qr.dart';

/// Veredictos de los escaneos de la sesión actual, para que el guardia pueda
/// consultar lo que acaba de leer sin volver a apuntar la cámara.
@immutable
class ScanLogEntry {
  const ScanLogEntry({required this.validation, required this.rawToken});

  final VisitQrValidation validation;

  /// Texto tal como lo leyó la cámara. Se conserva para auditoría visual, no se
  /// vuelve a enviar al backend.
  final String rawToken;
}

/// Estado del lector de QR de portería (CU10 / RF-10 / T106).
///
/// El backend responde `200 OK` tanto para un ingreso aprobado como para un
/// rechazo, porque un rechazo es un resultado de negocio y no un fallo de la
/// API. Por eso este controlador distingue entre:
///
/// - [validating]: la consulta sigue en vuelo.
/// - [error]:      la consulta falló (red, sesión o permiso). No hay veredicto.
/// - [result]:     el backend respondió y hay veredicto, sea aprobado o no.
class VisitQrValidationController extends ChangeNotifier {
  VisitQrValidationController(this._repository);

  /// Cuántos escaneos se conservan en el historial de la sesión.
  static const historyLimit = 10;

  final VisitQrDataSource _repository;
  final _history = <ScanLogEntry>[];
  VisitQrValidation? _result;
  String? _lastToken;
  List<VisitQrRejectionReason> _reasons = const [];
  bool validating = false;
  bool loadingReasons = false;
  String? error;

  VisitQrValidation? get result => _result;
  List<ScanLogEntry> get history => List.unmodifiable(_history);
  List<VisitQrRejectionReason> get reasons => List.unmodifiable(_reasons);
  bool get hasResult => _result != null;

  /// Tras un veredicto el lector queda en pausa para que el guardia no genere
  /// eventos de acceso duplicados porNFC reiniciando el mismo código.
  bool get isPaused => _result != null;

  int get approvedCount => _history.where((e) => e.validation.valid).length;
  int get deniedCount => _history.where((e) => !e.validation.valid).length;

  /// Valida el texto capturado. Devuelve `true` si el backend dio veredicto.
  ///
  /// Repetir el mismo token sin haber pulsado "escanear otro" se ignora: el
  /// backend sí aceptaría el reescaneo y registraría un segundo evento.
  Future<bool> validate(String rawToken, {String? notes}) async {
    final token = rawToken.trim();
    if (token.isEmpty || validating) return false;
    if (isPaused && token == _lastToken) return false;

    validating = true;
    error = null;
    notifyListeners();
    try {
      final validation = await _repository.validate(token: token, notes: notes);
      _result = validation;
      _lastToken = token;
      _history.insert(0, ScanLogEntry(validation: validation, rawToken: token));
      if (_history.length > historyLimit) _history.removeLast();
      return true;
    } on ApiFailure catch (failure) {
      error = failure.displayMessage;
      return false;
    } finally {
      validating = false;
      notifyListeners();
    }
  }

  /// Descarta el veredicto actual y permite volver a apuntar la cámara.
  void scanAgain() {
    if (_result == null && error == null) return;
    _result = null;
    error = null;
    _lastToken = null;
    notifyListeners();
  }

  /// Carga el catálogo de motivos de rechazo del backend, para que el texto que
  /// ve el guardia sea exactamente el que la API usa al auditar.
  ///
  /// Es informativo: un fallo aquí no debe impedir escanear, así que el error se
  /// ignora y la pantalla sigue operando con `VisitQrValidation.reasonLabel`.
  Future<void> loadReasons() async {
    if (_reasons.isNotEmpty || loadingReasons) return;
    loadingReasons = true;
    notifyListeners();
    try {
      _reasons = await _repository.rejectionReasons();
    } on ApiFailure {
      _reasons = const [];
    } finally {
      loadingReasons = false;
      notifyListeners();
    }
  }

  /// Mensaje del backend para un motivo dado, o el texto local si no se pudo
  /// descargar el catálogo.
  String messageFor(String reason) {
    final code = reason.toUpperCase();
    for (final item in _reasons) {
      if (item.value.toUpperCase() == code) return item.message;
    }
    return _result?.message ?? '';
  }
}
