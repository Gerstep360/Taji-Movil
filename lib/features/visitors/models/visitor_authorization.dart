import 'package:flutter/foundation.dart';

@immutable
class ResidentUnit {
  const ResidentUnit({required this.id, required this.code, this.label = ''});

  factory ResidentUnit.fromJson(Map<String, dynamic> json) => ResidentUnit(
    id: json['unit_id'] as int? ?? json['id'] as int? ?? 0,
    code: json['unit_code'] as String? ?? json['code'] as String? ?? '',
    label: json['relation_type_display'] as String? ?? '',
  );

  final int id;
  final String code;
  final String label;
}

@immutable
class ActiveResident {
  const ActiveResident({
    required this.id,
    required this.fullName,
    this.documentNumber = '',
  });

  factory ActiveResident.fromJson(Map<String, dynamic> json) => ActiveResident(
    id: json['id'] as int,
    fullName: json['full_name'] as String? ?? '',
    documentNumber: json['document_number'] as String? ?? '',
  );

  final int id;
  final String fullName;
  final String documentNumber;
}

@immutable
class VisitorAuthorization {
  const VisitorAuthorization({
    required this.id,
    required this.visitorName,
    required this.documentId,
    required this.unitId,
    required this.unit,
    required this.reason,
    required this.validFrom,
    required this.validUntil,
    required this.status,
    this.cancelledAt,
  });

  factory VisitorAuthorization.fromJson(Map<String, dynamic> json) {
    final visitor = json['visitor'] as Map<String, dynamic>? ?? const {};
    final unit = json['unit_detail'] as Map<String, dynamic>? ?? const {};
    return VisitorAuthorization(
      id: json['id'] as int,
      visitorName:
          visitor['full_name'] as String? ??
          '${visitor['first_name'] ?? ''} ${visitor['last_name'] ?? ''}'.trim(),
      documentId: visitor['document_number'] as String? ?? '',
      unitId: json['unit'] as int? ?? unit['id'] as int? ?? 0,
      unit: unit['code'] as String? ?? '',
      reason: json['purpose'] as String? ?? '',
      validFrom: DateTime.parse(json['valid_from'] as String).toLocal(),
      validUntil: DateTime.parse(json['valid_until'] as String).toLocal(),
      status: json['status'] as String? ?? 'AUTHORIZED',
      cancelledAt: json['cancelled_at'] == null
          ? null
          : DateTime.parse(json['cancelled_at'] as String).toLocal(),
    );
  }

  final int id;
  final String visitorName;
  final String documentId;
  final int unitId;
  final String unit;
  final String reason;
  final DateTime validFrom;
  final DateTime validUntil;
  final String status;
  final DateTime? cancelledAt;

  bool get isCancelled => status == 'CANCELLED';
  bool get isActive => !isCancelled && DateTime.now().isBefore(validUntil);
}

@immutable
class VisitorAuthorizationInput {
  const VisitorAuthorizationInput({
    required this.visitorFirstName,
    required this.visitorLastName,
    required this.documentType,
    required this.documentId,
    required this.phone,
    required this.unitId,
    this.authorizedByResidentId,
    required this.reason,
    required this.validFrom,
    required this.validUntil,
    this.notes,
  });

  final String visitorFirstName;
  final String visitorLastName;
  final String documentType;
  final String documentId;
  final String phone;
  final int unitId;
  final int? authorizedByResidentId;
  final String reason;
  final DateTime validFrom;
  final DateTime validUntil;
  final String? notes;

  Map<String, dynamic> toJson() => {
    'visitor_first_name': visitorFirstName.trim(),
    'visitor_last_name': visitorLastName.trim(),
    'visitor_document_type': documentType,
    'visitor_document_number': documentId.trim(),
    'visitor_phone': phone.trim(),
    'unit_id': unitId,
    if (authorizedByResidentId != null)
      'authorized_by_resident_id': authorizedByResidentId,
    'purpose': reason.trim(),
    'valid_from': validFrom.toUtc().toIso8601String(),
    'valid_until': validUntil.toUtc().toIso8601String(),
    if (notes?.trim().isNotEmpty == true) 'notes': notes!.trim(),
  };
}
