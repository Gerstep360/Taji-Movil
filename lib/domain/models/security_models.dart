import 'model_parsers.dart';

class VisitAuthorizationModel {
  const VisitAuthorizationModel({
    required this.id,
    required this.visitorPersonId,
    required this.authorizedByResidentId,
    required this.unitId,
    required this.createdByUserId,
    required this.purpose,
    required this.validFrom,
    required this.validUntil,
    required this.status,
    required this.qrUuid,
    required this.qrExpiresAt,
    required this.cancelledAt,
    required this.notes,
    required this.createdAt,
  });

  final int id;
  final int visitorPersonId;
  final int authorizedByResidentId;
  final int unitId;
  final int? createdByUserId;
  final String purpose;
  final DateTime validFrom;
  final DateTime validUntil;
  final String status;
  final String qrUuid;
  final DateTime qrExpiresAt;
  final DateTime? cancelledAt;
  final String notes;
  final DateTime createdAt;

  factory VisitAuthorizationModel.fromJson(Map<String, dynamic> json) =>
      VisitAuthorizationModel(
        id: readInt(json['id']),
        visitorPersonId: readInt(json['visitor_person_id']),
        authorizedByResidentId: readInt(json['authorized_by_resident_id']),
        unitId: readInt(json['unit_id']),
        createdByUserId: readNullableInt(json['created_by_user_id']),
        purpose: readString(json['purpose']),
        validFrom: readDateTime(json['valid_from']),
        validUntil: readDateTime(json['valid_until']),
        status: readString(json['status']),
        qrUuid: readString(json['qr_uuid']),
        qrExpiresAt: readDateTime(json['qr_expires_at']),
        cancelledAt: readNullableDateTime(json['cancelled_at']),
        notes: readString(json['notes']),
        createdAt: readDateTime(json['created_at']),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'visitor_person_id': visitorPersonId,
    'authorized_by_resident_id': authorizedByResidentId,
    'unit_id': unitId,
    'created_by_user_id': createdByUserId,
    'purpose': purpose,
    'valid_from': validFrom.toIso8601String(),
    'valid_until': validUntil.toIso8601String(),
    'status': status,
    'qr_uuid': qrUuid,
    'qr_expires_at': qrExpiresAt.toIso8601String(),
    'cancelled_at': cancelledAt?.toIso8601String(),
    'notes': notes,
    'created_at': createdAt.toIso8601String(),
  };
}

class AccessEventModel {
  const AccessEventModel({
    required this.id,
    required this.authorizationId,
    required this.personId,
    required this.guardStaffId,
    required this.eventType,
    required this.validationMethod,
    required this.validationResult,
    required this.occurredAt,
    required this.notes,
  });

  final int id;
  final int? authorizationId;
  final int? personId;
  final int? guardStaffId;
  final String eventType;
  final String validationMethod;
  final String validationResult;
  final DateTime occurredAt;
  final String notes;

  factory AccessEventModel.fromJson(Map<String, dynamic> json) =>
      AccessEventModel(
        id: readInt(json['id']),
        authorizationId: readNullableInt(json['authorization_id']),
        personId: readNullableInt(json['person_id']),
        guardStaffId: readNullableInt(json['guard_staff_id']),
        eventType: readString(json['event_type']),
        validationMethod: readString(json['validation_method']),
        validationResult: readString(json['validation_result']),
        occurredAt: readDateTime(json['occurred_at']),
        notes: readString(json['notes']),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'authorization_id': authorizationId,
    'person_id': personId,
    'guard_staff_id': guardStaffId,
    'event_type': eventType,
    'validation_method': validationMethod,
    'validation_result': validationResult,
    'occurred_at': occurredAt.toIso8601String(),
    'notes': notes,
  };
}

class SecurityShiftModel {
  const SecurityShiftModel({
    required this.id,
    required this.guardStaffId,
    required this.scheduledStart,
    required this.scheduledEnd,
    required this.openedAt,
    required this.closedAt,
    required this.status,
    required this.openingNotes,
    required this.closingNotes,
    required this.createdAt,
    this.guardName = '',
    this.guardEmployeeCode = '',
    this.condominiumName = '',
    this.observation = '',
    this.serverTime,
    this.allowedStartAt,
    this.otherOpenShiftId,
  });

  final int id;
  final int guardStaffId;
  final DateTime scheduledStart;
  final DateTime scheduledEnd;
  final DateTime? openedAt;
  final DateTime? closedAt;
  final String status;
  final String openingNotes;
  final String closingNotes;
  final DateTime createdAt;
  final String guardName;
  final String guardEmployeeCode;
  final String condominiumName;
  final String observation;
  final DateTime? serverTime;
  final DateTime? allowedStartAt;
  final int? otherOpenShiftId;

  DateTime get startAllowedAt =>
      allowedStartAt ?? scheduledStart.subtract(const Duration(minutes: 15));

  String get statusLabel => switch (status) {
    'SCHEDULED' => 'Programado',
    'OPEN' => 'En curso',
    'CLOSED' => 'Finalizado',
    'CANCELLED' => 'Cancelado',
    _ => status,
  };

  String startBlockReason(DateTime now) {
    if (status != 'SCHEDULED') {
      return 'Solo puedes iniciar un turno programado.';
    }
    if (!now.isBefore(scheduledEnd)) {
      return 'El horario finalizó: turno sin iniciar.';
    }
    if (now.isBefore(startAllowedAt)) {
      return 'El inicio se habilita 15 minutos antes del horario programado.';
    }
    if (otherOpenShiftId != null) {
      return 'Debes cerrar tu otro turno abierto antes de iniciar este.';
    }
    return '';
  }

  bool closeReasonRequired(DateTime now) =>
      status == 'OPEN' && !now.isAtSameMomentAs(scheduledEnd);

  String timingNotice(DateTime now) {
    if (status == 'SCHEDULED' && !now.isBefore(scheduledEnd)) {
      return 'Sin iniciar: el horario ya finalizó.';
    }
    if (status == 'OPEN' && !now.isBefore(scheduledEnd)) {
      return 'Horario finalizado, cierre pendiente.';
    }
    if (status == 'CLOSED' && closedAt != null) {
      if (closedAt!.isBefore(scheduledEnd)) return 'Cierre anticipado';
      if (closedAt!.isAfter(scheduledEnd)) return 'Cierre posterior al horario';
    }
    return '';
  }

  factory SecurityShiftModel.fromJson(Map<String, dynamic> json) =>
      SecurityShiftModel(
        id: readInt(json['id']),
        guardStaffId: readInt(json['guard_staff'] ?? json['guard_staff_id']),
        scheduledStart: readDateTime(json['scheduled_start']),
        scheduledEnd: readDateTime(json['scheduled_end']),
        openedAt: readNullableDateTime(json['opened_at']),
        closedAt: readNullableDateTime(json['closed_at']),
        status: readString(json['status']),
        openingNotes: readString(json['opening_notes']),
        closingNotes: readString(json['closing_notes']),
        createdAt: readDateTime(json['created_at']),
        guardName: readString(json['guard_name']),
        guardEmployeeCode: readString(json['guard_employee_code']),
        condominiumName: readString(json['condominium_name']),
        observation: readString(json['observation']),
        serverTime: readNullableDateTime(
          (json['timing'] as Map?)?['server_time'],
        ),
        allowedStartAt: readNullableDateTime(
          (json['timing'] as Map?)?['start_allowed_at'],
        ),
        otherOpenShiftId: readNullableInt(
          (json['timing'] as Map?)?['other_open_shift_id'],
        ),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'guard_staff_id': guardStaffId,
    'guard_staff': guardStaffId,
    'scheduled_start': scheduledStart.toIso8601String(),
    'scheduled_end': scheduledEnd.toIso8601String(),
    'opened_at': openedAt?.toIso8601String(),
    'closed_at': closedAt?.toIso8601String(),
    'status': status,
    'opening_notes': openingNotes,
    'closing_notes': closingNotes,
    'created_at': createdAt.toIso8601String(),
    'guard_name': guardName,
    'guard_employee_code': guardEmployeeCode,
    'condominium_name': condominiumName,
    'observation': observation,
    'timing': {
      'server_time': serverTime?.toIso8601String(),
      'start_allowed_at': startAllowedAt.toIso8601String(),
      'other_open_shift_id': otherOpenShiftId,
    },
  };
}

class ShiftLogEntryModel {
  const ShiftLogEntryModel({
    required this.id,
    required this.shiftId,
    required this.createdByUserId,
    required this.sectorId,
    required this.entryType,
    required this.severity,
    required this.title,
    required this.description,
    required this.occurredAt,
    required this.createdAt,
    this.guardName = '',
    this.condominiumName = '',
  });

  final int id;
  final int shiftId;
  final int? createdByUserId;
  final int? sectorId;
  final String guardName;
  final String condominiumName;
  final String entryType;
  final String severity;
  final String title;
  final String description;
  final DateTime occurredAt;
  final DateTime createdAt;

  static const types = {
    'NOTE': 'Novedad',
    'INCIDENT': 'Incidente',
    'ALERT': 'Alerta',
  };
  static const severities = {
    'INFO': 'Información',
    'LOW': 'Baja',
    'MEDIUM': 'Media',
    'HIGH': 'Alta',
    'CRITICAL': 'Crítica',
  };
  String get typeLabel => types[entryType] ?? entryType;
  String get severityLabel => severities[severity] ?? severity;

  factory ShiftLogEntryModel.fromJson(Map<String, dynamic> json) =>
      ShiftLogEntryModel(
        id: readInt(json['id']),
        shiftId: readInt(json['shift'] ?? json['shift_id']),
        createdByUserId: readNullableInt(
          json['created_by_user'] ?? json['created_by_user_id'],
        ),
        sectorId: readNullableInt(json['sector_id']),
        entryType: readString(json['entry_type']),
        severity: readString(json['severity']),
        title: readString(json['title']),
        description: readString(json['description']),
        occurredAt: readDateTime(json['occurred_at']),
        createdAt: readDateTime(json['created_at']),
        guardName: readString(json['guard_name']),
        condominiumName: readString(json['condominium_name']),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'shift_id': shiftId,
    'shift': shiftId,
    'created_by_user_id': createdByUserId,
    'sector_id': sectorId,
    'entry_type': entryType,
    'severity': severity,
    'title': title,
    'description': description,
    'occurred_at': occurredAt.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
    'guard_name': guardName,
    'condominium_name': condominiumName,
  };
}

class ShiftHandoverModel {
  const ShiftHandoverModel({
    required this.id,
    required this.outgoingShiftId,
    required this.incomingShiftId,
    required this.deliveredByUserId,
    required this.receivedByUserId,
    required this.summary,
    required this.deliveredAt,
    required this.receivedAt,
    required this.status,
    this.outgoingDetail,
    this.incomingDetail,
    this.logEntries = const [],
  });

  final int id;
  final int outgoingShiftId;
  final int? incomingShiftId;
  final int? deliveredByUserId;
  final int? receivedByUserId;
  final String summary;
  final DateTime deliveredAt;
  final DateTime? receivedAt;
  final String status;

  final SecurityShiftModel? outgoingDetail;
  final SecurityShiftModel? incomingDetail;
  final List<ShiftLogEntryModel> logEntries;
  String get statusLabel => switch (status) {
    'PENDING' => 'Pendiente de recepción',
    'RECEIVED' => 'Recibida',
    'REJECTED' => 'Rechazada',
    _ => status,
  };

  factory ShiftHandoverModel.fromJson(Map<String, dynamic> json) =>
      ShiftHandoverModel(
        id: readInt(json['id']),
        outgoingShiftId: readInt(
          json['outgoing_shift'] ?? json['outgoing_shift_id'],
        ),
        incomingShiftId: readNullableInt(
          json['incoming_shift'] ?? json['incoming_shift_id'],
        ),
        deliveredByUserId: readNullableInt(
          json['delivered_by_user'] ?? json['delivered_by_user_id'],
        ),
        receivedByUserId: readNullableInt(
          json['received_by_user'] ?? json['received_by_user_id'],
        ),
        summary: readString(json['summary']),
        deliveredAt: readDateTime(json['delivered_at']),
        receivedAt: readNullableDateTime(json['received_at']),
        status: readString(json['status']),
        outgoingDetail: json['outgoing_detail'] == null
            ? null
            : SecurityShiftModel.fromJson(
                Map<String, dynamic>.from(json['outgoing_detail'] as Map),
              ),
        incomingDetail: json['incoming_detail'] == null
            ? null
            : SecurityShiftModel.fromJson(
                Map<String, dynamic>.from(json['incoming_detail'] as Map),
              ),
        logEntries: (json['log_entries'] as List? ?? [])
            .map(
              (item) => ShiftLogEntryModel.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'outgoing_shift_id': outgoingShiftId,
    'outgoing_shift': outgoingShiftId,
    'incoming_shift_id': incomingShiftId,
    'delivered_by_user_id': deliveredByUserId,
    'received_by_user_id': receivedByUserId,
    'summary': summary,
    'delivered_at': deliveredAt.toIso8601String(),
    'received_at': receivedAt?.toIso8601String(),
    'status': status,
    'outgoing_detail': outgoingDetail?.toJson(),
    'incoming_detail': incomingDetail?.toJson(),
    'log_entries': logEntries.map((entry) => entry.toJson()).toList(),
  };
}

class BiometricReferenceModel {
  const BiometricReferenceModel({
    required this.id,
    required this.residentId,
    required this.referenceImage,
    required this.embedding,
    required this.embeddingDim,
    required this.modelName,
    required this.modelVersion,
    required this.isActive,
    required this.enrolledByUserId,
    required this.enrolledAt,
  });

  final int id;
  final int residentId;
  final String referenceImage;
  final String embedding;
  final int embeddingDim;
  final String modelName;
  final String modelVersion;
  final bool isActive;
  final int? enrolledByUserId;
  final DateTime enrolledAt;

  factory BiometricReferenceModel.fromJson(Map<String, dynamic> json) =>
      BiometricReferenceModel(
        id: readInt(json['id']),
        residentId: readInt(json['resident_id']),
        referenceImage: readString(json['reference_image']),
        embedding: readString(json['embedding']),
        embeddingDim: readInt(json['embedding_dim']),
        modelName: readString(json['model_name']),
        modelVersion: readString(json['model_version']),
        isActive: readBool(json['is_active']),
        enrolledByUserId: readNullableInt(json['enrolled_by_user_id']),
        enrolledAt: readDateTime(json['enrolled_at']),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'resident_id': residentId,
    'reference_image': referenceImage,
    'embedding': embedding,
    'embedding_dim': embeddingDim,
    'model_name': modelName,
    'model_version': modelVersion,
    'is_active': isActive,
    'enrolled_by_user_id': enrolledByUserId,
    'enrolled_at': enrolledAt.toIso8601String(),
  };
}

class FaceVerificationModel {
  const FaceVerificationModel({
    required this.id,
    required this.capturedImage,
    required this.matchedResidentId,
    required this.biometricReferenceId,
    required this.guardStaffId,
    required this.accessEventId,
    required this.similarityScore,
    required this.threshold,
    required this.modelName,
    required this.modelVersion,
    required this.result,
    required this.humanConfirmed,
    required this.confirmedByUserId,
    required this.verifiedAt,
  });

  final int id;
  final String capturedImage;
  final int? matchedResidentId;
  final int? biometricReferenceId;
  final int? guardStaffId;
  final int? accessEventId;
  final String? similarityScore;
  final String? threshold;
  final String modelName;
  final String modelVersion;
  final String result;
  final bool? humanConfirmed;
  final int? confirmedByUserId;
  final DateTime verifiedAt;

  factory FaceVerificationModel.fromJson(Map<String, dynamic> json) =>
      FaceVerificationModel(
        id: readInt(json['id']),
        capturedImage: readString(json['captured_image']),
        matchedResidentId: readNullableInt(json['matched_resident_id']),
        biometricReferenceId: readNullableInt(json['biometric_reference_id']),
        guardStaffId: readNullableInt(json['guard_staff_id']),
        accessEventId: readNullableInt(json['access_event_id']),
        similarityScore: readNullableString(json['similarity_score']),
        threshold: readNullableString(json['threshold']),
        modelName: readString(json['model_name']),
        modelVersion: readString(json['model_version']),
        result: readString(json['result']),
        humanConfirmed: readNullableBool(json['human_confirmed']),
        confirmedByUserId: readNullableInt(json['confirmed_by_user_id']),
        verifiedAt: readDateTime(json['verified_at']),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'captured_image': capturedImage,
    'matched_resident_id': matchedResidentId,
    'biometric_reference_id': biometricReferenceId,
    'guard_staff_id': guardStaffId,
    'access_event_id': accessEventId,
    'similarity_score': similarityScore,
    'threshold': threshold,
    'model_name': modelName,
    'model_version': modelVersion,
    'result': result,
    'human_confirmed': humanConfirmed,
    'confirmed_by_user_id': confirmedByUserId,
    'verified_at': verifiedAt.toIso8601String(),
  };
}

class FaceMatchCandidateModel {
  const FaceMatchCandidateModel({
    required this.id,
    required this.fullName,
    required this.documentNumber,
    required this.documentType,
    required this.phone,
    required this.status,
  });

  final int id;
  final String fullName;
  final String documentNumber;
  final String documentType;
  final String phone;
  final String status;

  factory FaceMatchCandidateModel.fromJson(Map<String, dynamic> json) =>
      FaceMatchCandidateModel(
        id: readInt(json['id']),
        fullName: readString(json['full_name']),
        documentNumber: readString(json['document_number']),
        documentType: readString(json['document_type']),
        phone: readString(json['phone']),
        status: readString(json['status']),
      );
}

class FaceMatchResultModel {
  const FaceMatchResultModel({
    required this.matchedResident,
    required this.biometricReferenceId,
    required this.similarityScore,
    required this.threshold,
    required this.result,
    required this.modelName,
    required this.modelVersion,
  });

  final FaceMatchCandidateModel? matchedResident;
  final int? biometricReferenceId;
  final double similarityScore;
  final double threshold;
  final String result;
  final String modelName;
  final String modelVersion;

  factory FaceMatchResultModel.fromJson(Map<String, dynamic> json) =>
      FaceMatchResultModel(
        matchedResident: json['matched_resident'] != null
            ? FaceMatchCandidateModel.fromJson(json['matched_resident'])
            : null,
        biometricReferenceId: readNullableInt(json['biometric_reference_id']),
        similarityScore: (json['similarity_score'] as num?)?.toDouble() ?? 0.0,
        threshold: (json['threshold'] as num?)?.toDouble() ?? 0.70,
        result: readString(json['result']),
        modelName: readString(json['model_name']),
        modelVersion: readString(json['model_version']),
      );
}
