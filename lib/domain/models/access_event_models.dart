import 'model_parsers.dart';

class AccessPersonUnitModel {
  const AccessPersonUnitModel({required this.id, required this.code});

  final int id;
  final String code;

  factory AccessPersonUnitModel.fromJson(Map<String, dynamic> json) =>
      AccessPersonUnitModel(
        id: readInt(json['id']),
        code: readString(json['code']),
      );
}

class AccessPersonOptionModel {
  const AccessPersonOptionModel({
    required this.id,
    required this.fullName,
    required this.documentNumber,
    required this.units,
  });

  final int id;
  final String fullName;
  final String documentNumber;
  final List<AccessPersonUnitModel> units;

  factory AccessPersonOptionModel.fromJson(Map<String, dynamic> json) =>
      AccessPersonOptionModel(
        id: readInt(json['id']),
        fullName: readString(json['full_name']),
        documentNumber: readString(json['document_number']),
        units: List.unmodifiable(
          (json['units'] as List? ?? const []).map((item) {
            if (item is! Map) throw const FormatException('Invalid person unit');
            return AccessPersonUnitModel.fromJson(
              Map<String, dynamic>.from(item),
            );
          }),
        ),
      );
}

class AccessUnitOptionModel {
  const AccessUnitOptionModel({
    required this.id,
    required this.code,
    required this.type,
    required this.sector,
  });

  final int id;
  final String code;
  final String type;
  final String sector;

  factory AccessUnitOptionModel.fromJson(Map<String, dynamic> json) =>
      AccessUnitOptionModel(
        id: readInt(json['id']),
        code: readString(json['code']),
        type: readString(json['unit_type']),
        sector: readString(json['sector']),
      );
}

class AccessEventItemModel {
  const AccessEventItemModel({
    required this.id,
    required this.personId,
    required this.personName,
    required this.visitorName,
    required this.visitorDocumentNumber,
    required this.unitId,
    required this.unitCode,
    required this.sectorName,
    required this.eventType,
    required this.eventTypeLabel,
    required this.validationMethod,
    required this.validationMethodLabel,
    required this.validationResult,
    required this.validationResultLabel,
    required this.occurredAt,
    required this.notes,
  });

  final int id;
  final int? personId;
  final String personName;
  final String visitorName;
  final String visitorDocumentNumber;
  final int? unitId;
  final String unitCode;
  final String sectorName;
  final String eventType;
  final String eventTypeLabel;
  final String validationMethod;
  final String validationMethodLabel;
  final String validationResult;
  final String validationResultLabel;
  final DateTime occurredAt;
  final String notes;

  String get displayName => personName.isNotEmpty
      ? personName
      : visitorName.isNotEmpty
      ? visitorName
      : 'Persona no identificada';

  String get destination => [unitCode, sectorName]
      .where((part) => part.isNotEmpty)
      .join(' · ');

  factory AccessEventItemModel.fromJson(Map<String, dynamic> json) {
    final person = readJsonMap(json['person']);
    final unit = readJsonMap(json['unit']);
    final eventType = readString(json['event_type']);
    final method = readString(json['validation_method']);
    final result = readString(json['validation_result']);
    return AccessEventItemModel(
      id: readInt(json['id']),
      personId: readNullableInt(json['person_id']),
      personName: readString(person['full_name']),
      visitorName: readString(json['visitor_name']),
      visitorDocumentNumber: readString(json['visitor_document_number']),
      unitId: readNullableInt(json['unit_id']),
      unitCode: readString(unit['code']),
      sectorName: readString(unit['sector_name']),
      eventType: eventType,
      eventTypeLabel: readString(json['event_type_display']).isNotEmpty
          ? readString(json['event_type_display'])
          : _eventLabels[eventType] ?? eventType,
      validationMethod: method,
      validationMethodLabel: readString(json['validation_method_display']).isNotEmpty
          ? readString(json['validation_method_display'])
          : _methodLabels[method] ?? method,
      validationResult: result,
      validationResultLabel: readString(json['validation_result_display']).isNotEmpty
          ? readString(json['validation_result_display'])
          : _resultLabels[result] ?? result,
      occurredAt: readDateTime(json['occurred_at']),
      notes: readString(json['notes']),
    );
  }

  static const _eventLabels = {
    'ENTRY': 'Entrada',
    'EXIT': 'Salida',
    'DENIED': 'Acceso denegado',
  };
  static const _methodLabels = {
    'MANUAL': 'Manual',
    'QR': 'QR',
    'FACE': 'Facial',
  };
  static const _resultLabels = {
    'APPROVED': 'Aprobado',
    'REJECTED': 'Rechazado',
    'MANUAL_REVIEW': 'Revisión manual',
  };
}