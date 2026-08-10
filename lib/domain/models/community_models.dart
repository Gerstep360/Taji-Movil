import 'model_parsers.dart';

class CommonAreaModel {
  const CommonAreaModel({
    required this.id,
    required this.sectorId,
    required this.name,
    required this.description,
    required this.capacity,
    required this.requiresApproval,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int? sectorId;
  final String name;
  final String description;
  final int? capacity;
  final bool requiresApproval;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory CommonAreaModel.fromJson(Map<String, dynamic> json) =>
      CommonAreaModel(
        id: readInt(json['id']),
        sectorId: readNullableInt(json['sector_id']),
        name: readString(json['name']),
        description: readString(json['description']),
        capacity: readNullableInt(json['capacity']),
        requiresApproval: readBool(json['requires_approval']),
        status: readString(json['status']),
        createdAt: readDateTime(json['created_at']),
        updatedAt: readDateTime(json['updated_at']),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'sector_id': sectorId,
    'name': name,
    'description': description,
    'capacity': capacity,
    'requires_approval': requiresApproval,
    'status': status,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}

class CommonAreaScheduleModel {
  const CommonAreaScheduleModel({
    required this.id,
    required this.commonAreaId,
    required this.weekday,
    required this.opensAt,
    required this.closesAt,
    required this.isActive,
  });

  final int id;
  final int commonAreaId;
  final int weekday;
  final String opensAt;
  final String closesAt;
  final bool isActive;

  factory CommonAreaScheduleModel.fromJson(Map<String, dynamic> json) =>
      CommonAreaScheduleModel(
        id: readInt(json['id']),
        commonAreaId: readInt(json['common_area_id']),
        weekday: readInt(json['weekday']),
        opensAt: readString(json['opens_at']),
        closesAt: readString(json['closes_at']),
        isActive: readBool(json['is_active']),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'common_area_id': commonAreaId,
    'weekday': weekday,
    'opens_at': opensAt,
    'closes_at': closesAt,
    'is_active': isActive,
  };
}

class CommonAreaBlockModel {
  const CommonAreaBlockModel({
    required this.id,
    required this.commonAreaId,
    required this.workOrderId,
    required this.blockedFrom,
    required this.blockedUntil,
    required this.reason,
    required this.createdByUserId,
    required this.createdAt,
  });

  final int id;
  final int commonAreaId;
  final int? workOrderId;
  final DateTime blockedFrom;
  final DateTime blockedUntil;
  final String reason;
  final int? createdByUserId;
  final DateTime createdAt;

  factory CommonAreaBlockModel.fromJson(Map<String, dynamic> json) =>
      CommonAreaBlockModel(
        id: readInt(json['id']),
        commonAreaId: readInt(json['common_area_id']),
        workOrderId: readNullableInt(json['work_order_id']),
        blockedFrom: readDateTime(json['blocked_from']),
        blockedUntil: readDateTime(json['blocked_until']),
        reason: readString(json['reason']),
        createdByUserId: readNullableInt(json['created_by_user_id']),
        createdAt: readDateTime(json['created_at']),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'common_area_id': commonAreaId,
    'work_order_id': workOrderId,
    'blocked_from': blockedFrom.toIso8601String(),
    'blocked_until': blockedUntil.toIso8601String(),
    'reason': reason,
    'created_by_user_id': createdByUserId,
    'created_at': createdAt.toIso8601String(),
  };
}

class ReservationModel {
  const ReservationModel({
    required this.id,
    required this.commonAreaId,
    required this.residentId,
    required this.createdByUserId,
    required this.startAt,
    required this.endAt,
    required this.status,
    required this.purpose,
    required this.approvedByUserId,
    required this.approvedAt,
    required this.cancelledAt,
    required this.createdAt,
  });

  final int id;
  final int commonAreaId;
  final int residentId;
  final int? createdByUserId;
  final DateTime startAt;
  final DateTime endAt;
  final String status;
  final String purpose;
  final int? approvedByUserId;
  final DateTime? approvedAt;
  final DateTime? cancelledAt;
  final DateTime createdAt;

  factory ReservationModel.fromJson(Map<String, dynamic> json) =>
      ReservationModel(
        id: readInt(json['id']),
        commonAreaId: readInt(json['common_area_id']),
        residentId: readInt(json['resident_id']),
        createdByUserId: readNullableInt(json['created_by_user_id']),
        startAt: readDateTime(json['start_at']),
        endAt: readDateTime(json['end_at']),
        status: readString(json['status']),
        purpose: readString(json['purpose']),
        approvedByUserId: readNullableInt(json['approved_by_user_id']),
        approvedAt: readNullableDateTime(json['approved_at']),
        cancelledAt: readNullableDateTime(json['cancelled_at']),
        createdAt: readDateTime(json['created_at']),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'common_area_id': commonAreaId,
    'resident_id': residentId,
    'created_by_user_id': createdByUserId,
    'start_at': startAt.toIso8601String(),
    'end_at': endAt.toIso8601String(),
    'status': status,
    'purpose': purpose,
    'approved_by_user_id': approvedByUserId,
    'approved_at': approvedAt?.toIso8601String(),
    'cancelled_at': cancelledAt?.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };
}

class AssemblyModel {
  const AssemblyModel({
    required this.id,
    required this.createdByUserId,
    required this.title,
    required this.description,
    required this.scheduledAt,
    required this.location,
    required this.status,
    required this.minutesText,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int? createdByUserId;
  final String title;
  final String description;
  final DateTime scheduledAt;
  final String location;
  final String status;
  final String minutesText;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory AssemblyModel.fromJson(Map<String, dynamic> json) => AssemblyModel(
    id: readInt(json['id']),
    createdByUserId: readNullableInt(json['created_by_user_id']),
    title: readString(json['title']),
    description: readString(json['description']),
    scheduledAt: readDateTime(json['scheduled_at']),
    location: readString(json['location']),
    status: readString(json['status']),
    minutesText: readString(json['minutes_text']),
    createdAt: readDateTime(json['created_at']),
    updatedAt: readDateTime(json['updated_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'created_by_user_id': createdByUserId,
    'title': title,
    'description': description,
    'scheduled_at': scheduledAt.toIso8601String(),
    'location': location,
    'status': status,
    'minutes_text': minutesText,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}

class AgreementModel {
  const AgreementModel({
    required this.id,
    required this.assemblyId,
    required this.title,
    required this.description,
    required this.responsibleUserId,
    required this.dueAt,
    required this.estimatedBudget,
    required this.actualCost,
    required this.status,
    required this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int assemblyId;
  final String title;
  final String description;
  final int? responsibleUserId;
  final DateTime? dueAt;
  final String? estimatedBudget;
  final String? actualCost;
  final String status;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory AgreementModel.fromJson(Map<String, dynamic> json) => AgreementModel(
    id: readInt(json['id']),
    assemblyId: readInt(json['assembly_id']),
    title: readString(json['title']),
    description: readString(json['description']),
    responsibleUserId: readNullableInt(json['responsible_user_id']),
    dueAt: readNullableDateTime(json['due_at']),
    estimatedBudget: readNullableString(json['estimated_budget']),
    actualCost: readNullableString(json['actual_cost']),
    status: readString(json['status']),
    completedAt: readNullableDateTime(json['completed_at']),
    createdAt: readDateTime(json['created_at']),
    updatedAt: readDateTime(json['updated_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'assembly_id': assemblyId,
    'title': title,
    'description': description,
    'responsible_user_id': responsibleUserId,
    'due_at': dueAt?.toIso8601String(),
    'estimated_budget': estimatedBudget,
    'actual_cost': actualCost,
    'status': status,
    'completed_at': completedAt?.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}

class AgreementAttachmentModel {
  const AgreementAttachmentModel({
    required this.id,
    required this.agreementId,
    required this.uploadedByUserId,
    required this.filePath,
    required this.description,
    required this.createdAt,
  });

  final int id;
  final int agreementId;
  final int? uploadedByUserId;
  final String filePath;
  final String description;
  final DateTime createdAt;

  factory AgreementAttachmentModel.fromJson(Map<String, dynamic> json) =>
      AgreementAttachmentModel(
        id: readInt(json['id']),
        agreementId: readInt(json['agreement_id']),
        uploadedByUserId: readNullableInt(json['uploaded_by_user_id']),
        filePath: readString(json['file_path']),
        description: readString(json['description']),
        createdAt: readDateTime(json['created_at']),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'agreement_id': agreementId,
    'uploaded_by_user_id': uploadedByUserId,
    'file_path': filePath,
    'description': description,
    'created_at': createdAt.toIso8601String(),
  };
}
