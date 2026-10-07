import 'package:flutter/foundation.dart';

/// Estados que el backend puede asignar a una autorización de visita.
///
/// Refleja `VisitAuthorization.Status` del backend. `authorized` y `active` son
/// los únicos estados que permiten el ingreso; el resto lo inutiliza.
enum VisitAuthorizationStatus {
  authorized('AUTHORIZED', 'Autorizada'),
  active('ACTIVE', 'Activa'),
  finished('FINISHED', 'Finalizada'),
  cancelled('CANCELLED', 'Cancelada'),
  expired('EXPIRED', 'Expirada'),
  unknown('', 'Desconocido');

  const VisitAuthorizationStatus(this.code, this.label);

  final String code;
  final String label;

  static VisitAuthorizationStatus fromCode(String? code) => values.firstWhere(
    (status) => status.code == (code ?? '').toUpperCase(),
    orElse: () => VisitAuthorizationStatus.unknown,
  );

  /// Estados terminales: el QR deja de ser utilizable aunque su vigencia no haya
  /// vencido. El backend comprueba la cancelación antes que el reloj.
  bool get isTerminal =>
      this == cancelled || this == finished || this == expired;

  /// Un ingreso solo se permite con la autorización vigente o ya activada.
  bool get allowsEntry => this == authorized || this == active;
}

/// Resumen de la autorización que consume el QR.
///
/// Es la proyección `VisitAuthorizationSummarySerializer` del backend. No
/// incluye `notes` ni `created_at`: el guardia solo necesita decidir sobre el
/// visitante, la unidad autorizante y la ventana de vigencia.
@immutable
class VisitQrAuthorization {
  const VisitQrAuthorization({
    required this.id,
    required this.status,
    required this.statusLabel,
    required this.purpose,
    required this.visitorName,
    required this.visitorDocumentType,
    required this.visitorDocumentNumber,
    required this.residentName,
    required this.residentDocumentNumber,
    required this.unitId,
    required this.unitCode,
    required this.sectorName,
    required this.floorLabel,
    required this.validFrom,
    required this.validUntil,
    required this.qrUuid,
    this.qrIssuedAt,
    this.qrExpiresAt,
  });

  factory VisitQrAuthorization.fromJson(Map<String, dynamic> json) {
    final visitor = json['visitor'] as Map<String, dynamic>? ?? const {};
    final resident = json['resident'] as Map<String, dynamic>? ?? const {};
    final unit = json['unit_detail'] as Map<String, dynamic>? ?? const {};
    final code = json['status'] as String? ?? '';
    return VisitQrAuthorization(
      id: _readInt(json['id']),
      status: VisitAuthorizationStatus.fromCode(code),
      statusLabel: json['status_display'] as String? ?? '',
      purpose: json['purpose'] as String? ?? '',
      visitorName:
          visitor['full_name'] as String? ??
          '${visitor['first_name'] ?? ''} ${visitor['last_name'] ?? ''}'.trim(),
      visitorDocumentType: visitor['document_type'] as String? ?? '',
      visitorDocumentNumber: visitor['document_number'] as String? ?? '',
      residentName: resident['full_name'] as String? ?? '',
      residentDocumentNumber: resident['document_number'] as String? ?? '',
      unitId: _readInt(unit['id']),
      unitCode: unit['code'] as String? ?? '',
      sectorName: unit['sector_name'] as String? ?? '',
      floorLabel: unit['floor_label'] as String? ?? '',
      validFrom: _readDate(json['valid_from']),
      validUntil: _readDate(json['valid_until']),
      qrUuid: json['qr_uuid'] as String? ?? '',
      qrIssuedAt: _readDate(json['qr_issued_at']),
      qrExpiresAt: _readDate(json['qr_expires_at']),
    );
  }

  final int id;
  final VisitAuthorizationStatus status;
  final String statusLabel;
  final String purpose;
  final String visitorName;
  final String visitorDocumentType;
  final String visitorDocumentNumber;
  final String residentName;
  final String residentDocumentNumber;
  final int unitId;
  final String unitCode;
  final String sectorName;
  final String floorLabel;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final String qrUuid;
  final DateTime? qrIssuedAt;
  final DateTime? qrExpiresAt;

  /// Unidad de destino legible: "Torre A · A-101 · Piso 3".
  String get unitLabel {
    final parts = [
      if (sectorName.isNotEmpty) sectorName,
      if (unitCode.isNotEmpty) unitCode,
      if (floorLabel.isNotEmpty) floorLabel,
    ];
    return parts.join(' · ');
  }

  String get visitorDocumentLabel {
    final number = visitorDocumentNumber.trim();
    if (number.isEmpty) return '';
    final type = visitorDocumentType.trim();
    return type.isEmpty ? number : '$type $number';
  }
}

/// Estado de vigencia del QR de una autorización.
///
/// Corresponde a `VisitQrSerializer`. Un detalle importante: `payload` solo viene
/// poblado en la respuesta de emisión. La consulta informa que existe un QR
/// vigente pero nunca revela su contenido, porque el token en claro solo existe
/// en el instante de emitirlo (en base de datos solo se guarda su SHA-256).
@immutable
class VisitQrTicket {
  const VisitQrTicket({
    required this.issued,
    required this.active,
    required this.expiresInSeconds,
    required this.authorization,
    this.payload,
    this.rotated = false,
  });

  factory VisitQrTicket.fromJson(Map<String, dynamic> json) {
    final authorization =
        json['authorization'] as Map<String, dynamic>? ?? const {};
    return VisitQrTicket(
      issued: json['issued'] as bool? ?? false,
      active: json['active'] as bool? ?? false,
      expiresInSeconds: _readInt(json['expires_in_seconds']),
      authorization: VisitQrAuthorization.fromJson(authorization),
      payload: json['payload'] as String?,
      rotated: json['rotated'] as bool? ?? false,
    );
  }

  /// Ya se emitió un QR con token vigente para esta autorización.
  final bool issued;

  /// El QR emitido es utilizable ahora mismo.
  final bool active;

  /// Segundos restantes de vigencia; el backend ya los acota a 0.
  final int expiresInSeconds;

  final VisitQrAuthorization authorization;

  /// Texto exacto a codificar en el QR. `null` fuera de la respuesta de emisión.
  final String? payload;

  /// `true` cuando esta emisión invalidó un QR anterior.
  final bool rotated;

  bool get hasPayload => (payload ?? '').isNotEmpty;

  /// Momento en que el QR deja de ser utilizable.
  DateTime? get expiresAt =>
      DateTime.now().add(Duration(seconds: expiresInSeconds));
}

/// Evento de acceso que dejó registrado un escaneo.
///
/// El backend solo expone estos cinco campos: nunca la ficha del guardia ni las
/// notas del escaneo.
@immutable
class VisitAccessEvent {
  const VisitAccessEvent({
    required this.id,
    required this.eventType,
    required this.validationMethod,
    required this.validationResult,
    required this.occurredAt,
  });

  factory VisitAccessEvent.fromJson(Map<String, dynamic> json) =>
      VisitAccessEvent(
        id: _readInt(json['id']),
        eventType: json['event_type'] as String? ?? '',
        validationMethod: json['validation_method'] as String? ?? '',
        validationResult: json['validation_result'] as String? ?? '',
        occurredAt: _readDate(json['occurred_at']),
      );

  final int id;
  final String eventType;
  final String validationMethod;
  final String validationResult;
  final DateTime? occurredAt;

  String get eventLabel => switch (eventType.toUpperCase()) {
    'ENTRY' => 'Entrada',
    'EXIT' => 'Salida',
    'DENIED' => 'Denegado',
    _ => eventType,
  };

  String get resultLabel => switch (validationResult.toUpperCase()) {
    'APPROVED' => 'Aprobado',
    'REJECTED' => 'Rechazado',
    'MANUAL_REVIEW' => 'Revisión manual',
    _ => validationResult,
  };
}

/// Veredicto de un escaneo realizado en portería (RF-10).
///
/// Importante: el backend responde `200 OK` tanto para un ingreso aprobado como
/// para un rechazo, porque un rechazo es un resultado de negocio válido y no un
/// fallo de la API. La app debe decidir sobre `valid`, nunca sobre el código HTTP.
@immutable
class VisitQrValidation {
  const VisitQrValidation({
    required this.valid,
    required this.reason,
    required this.message,
    required this.checkedAt,
    this.authorization,
    this.accessEvent,
  });

  factory VisitQrValidation.fromJson(Map<String, dynamic> json) {
    final authorization = json['authorization'] as Map<String, dynamic>?;
    final accessEvent = json['access_event'] as Map<String, dynamic>?;
    return VisitQrValidation(
      valid: json['valid'] as bool? ?? false,
      reason: json['reason'] as String? ?? '',
      message: json['message'] as String? ?? '',
      checkedAt: _readDate(json['checked_at']) ?? DateTime.now(),
      authorization: authorization == null
          ? null
          : VisitQrAuthorization.fromJson(authorization),
      accessEvent: accessEvent == null
          ? null
          : VisitAccessEvent.fromJson(accessEvent),
    );
  }

  /// `true` autoriza el ingreso del visitante.
  final bool valid;

  /// Código del motivo: `VALID`, `QR_EXPIRED`, `VISIT_CANCELLED`, `NOT_FOUND`…
  final String reason;

  /// Explicación en español del backend, apta para mostrarse al guardia.
  final String message;

  final DateTime checkedAt;

  /// `null` cuando el QR no corresponde a ninguna autorización conocida.
  final VisitQrAuthorization? authorization;

  /// `null` cuando el QR era desconocido: entonces no se registra ningún evento.
  final VisitAccessEvent? accessEvent;

  /// El guardia solo tiene los datos de la visita si el QR resolvió a una
  /// autorización real; si no, debe decidir el ingreso sin ese contexto.
  bool get hasAuthorization => authorization != null;

  String get visitorName => authorization?.visitorName ?? '';
  String get unitLabel => authorization?.unitLabel ?? '';
  String get residentName => authorization?.residentName ?? '';

  String get reasonLabel => switch (reason.toUpperCase()) {
    'VALID' => 'Vigente',
    'NOT_FOUND' => 'QR desconocido',
    'QR_ROTATED' => 'QR reemplazado',
    'QR_NOT_ISSUED' => 'QR no emitido',
    'QR_EXPIRED' => 'QR vencido',
    'VISIT_NOT_YET_VALID' => 'Visita aún no vigente',
    'VISIT_WINDOW_ENDED' => 'Ventana de visita concluida',
    'VISIT_CANCELLED' => 'Visita cancelada',
    'VISIT_FINISHED' => 'Visita finalizada',
    'VISIT_EXPIRED' => 'Visita vencida',
    'STATUS_NOT_ALLOWED' => 'Estado no permitido',
    _ => reason.isEmpty ? 'Sin motivo reportado' : reason,
  };

  /// Motivos que describen un código que nunca fue válido, frente a una visita
  /// que dejó de estarlo. Sirve para decidir si el guardia debe reimprimir.
  bool get requiresNewQr => switch (reason.toUpperCase()) {
    'QR_EXPIRED' || 'QR_ROTATED' || 'QR_NOT_ISSUED' => true,
    _ => false,
  };
}

/// Motivo de rechazo publicado por el backend en su catálogo.
///
/// La app lo descarga en lugar de codificar los textos, para que el texto que
/// lee el guardia sea siempre el mismo que el backend usa al registrar la auditoría.
@immutable
class VisitQrRejectionReason {
  const VisitQrRejectionReason({required this.value, required this.message});

  factory VisitQrRejectionReason.fromJson(Map<String, dynamic> json) =>
      VisitQrRejectionReason(
        value: json['value'] as String? ?? '',
        message: json['message'] as String? ?? '',
      );

  final String value;
  final String message;
}

int _readInt(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

/// Lee una fecha del backend tolerando `Z`, offsets y valores nulos.
///
/// El backend puede responder `2026-10-03T15:00:00Z` o con offset numérico según
/// la configuración de `USE_TZ`, así que no se asume un único formato.
DateTime? _readDate(Object? value) {
  final raw = value?.toString().trim();
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toLocal();
}
