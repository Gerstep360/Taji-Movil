import '../../../domain/models/model_parsers.dart'
    show readDateOrNull, readIntOr;

/// Bitácora de escaneos de portería (CU10 / RF-10).
///
/// El lector de la app solo conserva los últimos escaneos de la sesión, en
/// memoria. Estos modelos representan el registro real que vive en el
/// servidor, que es el único que sobrevive a cerrar la aplicación y el único
/// que distingue "QR desconocido" de "QR denegado".

/// Resultado con el que el backend clasifica un escaneo.
enum QrScanResult {
  valid('VALID', 'Válido'),
  rejected('REJECTED', 'Denegado'),
  notFound('NOT_FOUND', 'QR no registrado');

  const QrScanResult(this.value, this.label);

  final String value;
  final String label;

  static QrScanResult fromValue(String? value) {
    switch (value?.toUpperCase()) {
      case 'VALID':
        return QrScanResult.valid;
      case 'REJECTED':
        return QrScanResult.rejected;
      case 'NOT_FOUND':
        return QrScanResult.notFound;
      default:
        return QrScanResult.rejected;
    }
  }
}

/// Traducción de los códigos de motivo a texto legible.
///
/// El backend los manda como códigos estables para que la app no dependa de
/// literales del servidor; el guardia necesita leer un motivo, no un
/// `VISIT_WINDOW_ENDED`.
const Map<String, String> kScanReasonLabels = {
  'VALID': 'Vigente',
  'NOT_FOUND': 'QR no registrado',
  'QR_ROTATED': 'QR reemplazado',
  'QR_NOT_ISSUED': 'QR no emitido',
  'QR_EXPIRED': 'QR vencido',
  'VISIT_NOT_YET_VALID': 'Visita aún no vigente',
  'VISIT_WINDOW_ENDED': 'Ventana de visita concluida',
  'VISIT_CANCELLED': 'Visita cancelada',
  'VISIT_FINISHED': 'Visita finalizada',
  'VISIT_EXPIRED': 'Autorización vencida',
  'STATUS_NOT_ALLOWED': 'Estado no permite ingreso',
};

String scanReasonLabel(String reason) =>
    kScanReasonLabels[reason] ?? reason;

/// Un escaneo registrado, tal como lo devuelve el backend.
class QrScanEntry {
  const QrScanEntry({
    required this.id,
    required this.result,
    required this.resultLabel,
    required this.reason,
    required this.message,
    required this.occurredAt,
    required this.authorizationId,
    required this.visitorName,
    required this.visitorDocumentNumber,
    required this.unitCode,
    required this.guardName,
    required this.deviceId,
  });

  final int id;
  final QrScanResult result;
  final String resultLabel;
  final String reason;
  final String message;
  final DateTime? occurredAt;
  final int? authorizationId;
  final String visitorName;
  final String visitorDocumentNumber;
  final String unitCode;
  final String guardName;
  final String deviceId;

  /// Texto legible del motivo, con el catálogo local como respaldo.
  String get reasonLabel => scanReasonLabel(reason);

  bool get approved => result == QrScanResult.valid;

  factory QrScanEntry.fromJson(Map<String, dynamic> json) {
    final guard = json['guard_staff'];
    return QrScanEntry(
      id: readIntOr(json['id']),
      result: QrScanResult.fromValue(json['result'] as String?),
      resultLabel: (json['result_display'] as String?) ?? '',
      reason: (json['reason'] as String?) ?? '',
      message: (json['message'] as String?) ?? '',
      occurredAt: readDateOrNull(json['occurred_at']),
      authorizationId: json['authorization_id'] == null
          ? null
          : readIntOr(json['authorization_id']),
      visitorName: (json['visitor_name'] as String?) ?? '',
      visitorDocumentNumber: (json['visitor_document_number'] as String?) ?? '',
      unitCode: (json['unit_code'] as String?) ?? '',
      guardName: guard is Map<String, dynamic>
          ? ((guard['full_name'] as String?) ?? '')
          : '',
      deviceId: (json['device_id'] as String?) ?? '',
    );
  }
}

/// Totales de la ventana consultada, para los contadores del encabezado.
class QrScanSummary {
  const QrScanSummary({
    this.total = 0,
    this.approved = 0,
    this.rejected = 0,
    this.notFound = 0,
    this.failed = 0,
    this.successRate = 0,
  });

  final int total;
  final int approved;
  final int rejected;
  final int notFound;

  /// Denegados más QR no registrados: todo lo que no autorizó el ingreso.
  final int failed;
  final double successRate;

  factory QrScanSummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const QrScanSummary();
    return QrScanSummary(
      total: readIntOr(json['total']),
      approved: readIntOr(json['approved']),
      rejected: readIntOr(json['rejected']),
      notFound: readIntOr(json['not_found']),
      failed: readIntOr(json['failed']),
      successRate: (json['success_rate'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Una página de la bitácora.
///
/// El sobre de `visit-qr/scans/` es `{count, page, page_size, total_pages,
/// summary, results}`, distinto del `{results, pagination}` de CU12, así que
/// se mapea explícitamente en lugar de reutilizar otro modelo.
class QrScanHistoryPage {
  const QrScanHistoryPage({
    this.entries = const [],
    this.summary = const QrScanSummary(),
    this.count = 0,
    this.page = 1,
    this.totalPages = 1,
  });

  final List<QrScanEntry> entries;
  final QrScanSummary summary;
  final int count;
  final int page;
  final int totalPages;

  bool get hasPrevious => page > 1;
  bool get hasNext => page < totalPages;

  factory QrScanHistoryPage.fromJson(Map<String, dynamic> json) {
    final rawResults = json['results'];
    final rows = rawResults is List
        ? rawResults
            .whereType<Map<String, dynamic>>()
            .map(QrScanEntry.fromJson)
            .toList()
        : <QrScanEntry>[];

    final summary = json['summary'];
    return QrScanHistoryPage(
      entries: rows,
      summary: QrScanSummary.fromJson(
        summary is Map<String, dynamic> ? summary : null,
      ),
      count: readIntOr(json['count']),
      page: readIntOr(json['page'], 1),
      totalPages: readIntOr(json['total_pages'], 1),
    );
  }
}

/// Filtros del historial de escaneos.
class QrScanFilters {
  const QrScanFilters({
    this.result,
    this.guardStaffId,
    this.days = 7,
    this.search,
    this.page = 1,
    this.pageSize = 20,
  });

  final QrScanResult? result;
  final int? guardStaffId;
  final int days;
  final String? search;
  final int page;
  final int pageSize;

  /// Copia con otra página, para paginar sin mutar los filtros que el usuario
  /// controla con los selectores.
  QrScanFilters copyWith({int? page}) => QrScanFilters(
        result: result,
        guardStaffId: guardStaffId,
        days: days,
        search: search,
        page: page ?? this.page,
        pageSize: pageSize,
      );

  Map<String, dynamic> toQuery() {
    final trimmedSearch = search?.trim();
    return {
      if (result != null) 'result': result!.value,
      if (guardStaffId != null) 'guard_staff_id': guardStaffId,
      'days': days,
      if (trimmedSearch != null && trimmedSearch.isNotEmpty) 'search': trimmedSearch,
      'page': page,
      'page_size': pageSize,
    };
  }

  bool get hasActiveFilters =>
      result != null ||
      guardStaffId != null ||
      days != 7 ||
      (search?.trim().isNotEmpty ?? false);
}
