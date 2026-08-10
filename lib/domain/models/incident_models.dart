import 'model_parsers.dart';

class IncidentCategoryModel {
  const IncidentCategoryModel({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.defaultStaffType,
    required this.isActive,
  });

  final int id;
  final String code;
  final String name;
  final String description;
  final String? defaultStaffType;
  final bool isActive;

  factory IncidentCategoryModel.fromJson(Map<String, dynamic> json) =>
      IncidentCategoryModel(
        id: readInt(json['id']),
        code: readString(json['code']),
        name: readString(json['name']),
        description: readString(json['description']),
        defaultStaffType: readNullableString(json['default_staff_type']),
        isActive: readBool(json['is_active']),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'name': name,
    'description': description,
    'default_staff_type': defaultStaffType,
    'is_active': isActive,
  };
}

class PriorityLevelModel {
  const PriorityLevelModel({
    required this.id,
    required this.code,
    required this.name,
    required this.rank,
    required this.minScore,
    required this.maxScore,
    required this.targetMinutes,
    required this.isActive,
  });

  final int id;
  final String code;
  final String name;
  final int rank;
  final String? minScore;
  final String? maxScore;
  final int? targetMinutes;
  final bool isActive;

  factory PriorityLevelModel.fromJson(Map<String, dynamic> json) =>
      PriorityLevelModel(
        id: readInt(json['id']),
        code: readString(json['code']),
        name: readString(json['name']),
        rank: readInt(json['rank']),
        minScore: readNullableString(json['min_score']),
        maxScore: readNullableString(json['max_score']),
        targetMinutes: readNullableInt(json['target_minutes']),
        isActive: readBool(json['is_active']),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'name': name,
    'rank': rank,
    'min_score': minScore,
    'max_score': maxScore,
    'target_minutes': targetMinutes,
    'is_active': isActive,
  };
}

class IncidentModel {
  const IncidentModel({
    required this.id,
    required this.publicCode,
    required this.reporterUserId,
    required this.reporterResidentId,
    required this.sectorId,
    required this.unitId,
    required this.assetId,
    required this.categoryId,
    required this.priorityId,
    required this.currentAssigneeStaffId,
    required this.title,
    required this.description,
    required this.status,
    required this.dueAt,
    required this.resolvedAt,
    required this.closedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String publicCode;
  final int? reporterUserId;
  final int? reporterResidentId;
  final int? sectorId;
  final int? unitId;
  final int? assetId;
  final int? categoryId;
  final int? priorityId;
  final int? currentAssigneeStaffId;
  final String title;
  final String description;
  final String status;
  final DateTime? dueAt;
  final DateTime? resolvedAt;
  final DateTime? closedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory IncidentModel.fromJson(Map<String, dynamic> json) => IncidentModel(
    id: readInt(json['id']),
    publicCode: readString(json['public_code']),
    reporterUserId: readNullableInt(json['reporter_user_id']),
    reporterResidentId: readNullableInt(json['reporter_resident_id']),
    sectorId: readNullableInt(json['sector_id']),
    unitId: readNullableInt(json['unit_id']),
    assetId: readNullableInt(json['asset_id']),
    categoryId: readNullableInt(json['category_id']),
    priorityId: readNullableInt(json['priority_id']),
    currentAssigneeStaffId: readNullableInt(json['current_assignee_staff_id']),
    title: readString(json['title']),
    description: readString(json['description']),
    status: readString(json['status']),
    dueAt: readNullableDateTime(json['due_at']),
    resolvedAt: readNullableDateTime(json['resolved_at']),
    closedAt: readNullableDateTime(json['closed_at']),
    createdAt: readDateTime(json['created_at']),
    updatedAt: readDateTime(json['updated_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'public_code': publicCode,
    'reporter_user_id': reporterUserId,
    'reporter_resident_id': reporterResidentId,
    'sector_id': sectorId,
    'unit_id': unitId,
    'asset_id': assetId,
    'category_id': categoryId,
    'priority_id': priorityId,
    'current_assignee_staff_id': currentAssigneeStaffId,
    'title': title,
    'description': description,
    'status': status,
    'due_at': dueAt?.toIso8601String(),
    'resolved_at': resolvedAt?.toIso8601String(),
    'closed_at': closedAt?.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}

class IncidentAttachmentModel {
  const IncidentAttachmentModel({
    required this.id,
    required this.incidentId,
    required this.uploadedByUserId,
    required this.filePath,
    required this.fileType,
    required this.caption,
    required this.createdAt,
  });

  final int id;
  final int incidentId;
  final int? uploadedByUserId;
  final String filePath;
  final String fileType;
  final String caption;
  final DateTime createdAt;

  factory IncidentAttachmentModel.fromJson(Map<String, dynamic> json) =>
      IncidentAttachmentModel(
        id: readInt(json['id']),
        incidentId: readInt(json['incident_id']),
        uploadedByUserId: readNullableInt(json['uploaded_by_user_id']),
        filePath: readString(json['file_path']),
        fileType: readString(json['file_type']),
        caption: readString(json['caption']),
        createdAt: readDateTime(json['created_at']),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'incident_id': incidentId,
    'uploaded_by_user_id': uploadedByUserId,
    'file_path': filePath,
    'file_type': fileType,
    'caption': caption,
    'created_at': createdAt.toIso8601String(),
  };
}

class IncidentAssignmentModel {
  const IncidentAssignmentModel({
    required this.id,
    required this.incidentId,
    required this.assignedToStaffId,
    required this.assignedByUserId,
    required this.assignedAt,
    required this.endedAt,
    required this.reason,
  });

  final int id;
  final int incidentId;
  final int assignedToStaffId;
  final int? assignedByUserId;
  final DateTime assignedAt;
  final DateTime? endedAt;
  final String reason;

  factory IncidentAssignmentModel.fromJson(Map<String, dynamic> json) =>
      IncidentAssignmentModel(
        id: readInt(json['id']),
        incidentId: readInt(json['incident_id']),
        assignedToStaffId: readInt(json['assigned_to_staff_id']),
        assignedByUserId: readNullableInt(json['assigned_by_user_id']),
        assignedAt: readDateTime(json['assigned_at']),
        endedAt: readNullableDateTime(json['ended_at']),
        reason: readString(json['reason']),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'incident_id': incidentId,
    'assigned_to_staff_id': assignedToStaffId,
    'assigned_by_user_id': assignedByUserId,
    'assigned_at': assignedAt.toIso8601String(),
    'ended_at': endedAt?.toIso8601String(),
    'reason': reason,
  };
}

class IncidentStatusHistoryModel {
  const IncidentStatusHistoryModel({
    required this.id,
    required this.incidentId,
    required this.changedByUserId,
    required this.fromStatus,
    required this.toStatus,
    required this.comment,
    required this.changedAt,
  });

  final int id;
  final int incidentId;
  final int? changedByUserId;
  final String? fromStatus;
  final String toStatus;
  final String comment;
  final DateTime changedAt;

  factory IncidentStatusHistoryModel.fromJson(Map<String, dynamic> json) =>
      IncidentStatusHistoryModel(
        id: readInt(json['id']),
        incidentId: readInt(json['incident_id']),
        changedByUserId: readNullableInt(json['changed_by_user_id']),
        fromStatus: readNullableString(json['from_status']),
        toStatus: readString(json['to_status']),
        comment: readString(json['comment']),
        changedAt: readDateTime(json['changed_at']),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'incident_id': incidentId,
    'changed_by_user_id': changedByUserId,
    'from_status': fromStatus,
    'to_status': toStatus,
    'comment': comment,
    'changed_at': changedAt.toIso8601String(),
  };
}

class IncidentCommentModel {
  const IncidentCommentModel({
    required this.id,
    required this.incidentId,
    required this.authorUserId,
    required this.body,
    required this.visibility,
    required this.createdAt,
  });

  final int id;
  final int incidentId;
  final int? authorUserId;
  final String body;
  final String visibility;
  final DateTime createdAt;

  factory IncidentCommentModel.fromJson(Map<String, dynamic> json) =>
      IncidentCommentModel(
        id: readInt(json['id']),
        incidentId: readInt(json['incident_id']),
        authorUserId: readNullableInt(json['author_user_id']),
        body: readString(json['body']),
        visibility: readString(json['visibility']),
        createdAt: readDateTime(json['created_at']),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'incident_id': incidentId,
    'author_user_id': authorUserId,
    'body': body,
    'visibility': visibility,
    'created_at': createdAt.toIso8601String(),
  };
}

class RiskRuleModel {
  const RiskRuleModel({
    required this.id,
    required this.code,
    required this.name,
    required this.entityType,
    required this.conditions,
    required this.weight,
    required this.description,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String code;
  final String name;
  final String entityType;
  final Map<String, dynamic> conditions;
  final String weight;
  final String description;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory RiskRuleModel.fromJson(Map<String, dynamic> json) => RiskRuleModel(
    id: readInt(json['id']),
    code: readString(json['code']),
    name: readString(json['name']),
    entityType: readString(json['entity_type']),
    conditions: readJsonMap(json['conditions']),
    weight: readString(json['weight']),
    description: readString(json['description']),
    isActive: readBool(json['is_active']),
    createdAt: readDateTime(json['created_at']),
    updatedAt: readDateTime(json['updated_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'name': name,
    'entity_type': entityType,
    'conditions': conditions,
    'weight': weight,
    'description': description,
    'is_active': isActive,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}

class IncidentAiAnalysisModel {
  const IncidentAiAnalysisModel({
    required this.id,
    required this.incidentId,
    required this.modelName,
    required this.modelVersion,
    required this.textHash,
    required this.suggestedCategoryId,
    required this.suggestedPriorityId,
    required this.riskScore,
    required this.confidence,
    required this.suggestedStaffType,
    required this.suggestedAction,
    required this.rawOutput,
    required this.reviewedByUserId,
    required this.reviewStatus,
    required this.reviewedAt,
    required this.createdAt,
  });

  final int id;
  final int incidentId;
  final String modelName;
  final String modelVersion;
  final String textHash;
  final int? suggestedCategoryId;
  final int? suggestedPriorityId;
  final String? riskScore;
  final String? confidence;
  final String? suggestedStaffType;
  final String suggestedAction;
  final Map<String, dynamic> rawOutput;
  final int? reviewedByUserId;
  final String reviewStatus;
  final DateTime? reviewedAt;
  final DateTime createdAt;

  factory IncidentAiAnalysisModel.fromJson(Map<String, dynamic> json) =>
      IncidentAiAnalysisModel(
        id: readInt(json['id']),
        incidentId: readInt(json['incident_id']),
        modelName: readString(json['model_name']),
        modelVersion: readString(json['model_version']),
        textHash: readString(json['text_hash']),
        suggestedCategoryId: readNullableInt(json['suggested_category_id']),
        suggestedPriorityId: readNullableInt(json['suggested_priority_id']),
        riskScore: readNullableString(json['risk_score']),
        confidence: readNullableString(json['confidence']),
        suggestedStaffType: readNullableString(json['suggested_staff_type']),
        suggestedAction: readString(json['suggested_action']),
        rawOutput: readJsonMap(json['raw_output']),
        reviewedByUserId: readNullableInt(json['reviewed_by_user_id']),
        reviewStatus: readString(json['review_status']),
        reviewedAt: readNullableDateTime(json['reviewed_at']),
        createdAt: readDateTime(json['created_at']),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'incident_id': incidentId,
    'model_name': modelName,
    'model_version': modelVersion,
    'text_hash': textHash,
    'suggested_category_id': suggestedCategoryId,
    'suggested_priority_id': suggestedPriorityId,
    'risk_score': riskScore,
    'confidence': confidence,
    'suggested_staff_type': suggestedStaffType,
    'suggested_action': suggestedAction,
    'raw_output': rawOutput,
    'reviewed_by_user_id': reviewedByUserId,
    'review_status': reviewStatus,
    'reviewed_at': reviewedAt?.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };
}

class IncidentAiEntityModel {
  const IncidentAiEntityModel({
    required this.id,
    required this.analysisId,
    required this.entityType,
    required this.textValue,
    required this.normalizedValue,
    required this.confidence,
    required this.appliedWeight,
    required this.riskRuleId,
  });

  final int id;
  final int analysisId;
  final String entityType;
  final String textValue;
  final String normalizedValue;
  final String? confidence;
  final String appliedWeight;
  final int? riskRuleId;

  factory IncidentAiEntityModel.fromJson(Map<String, dynamic> json) =>
      IncidentAiEntityModel(
        id: readInt(json['id']),
        analysisId: readInt(json['analysis_id']),
        entityType: readString(json['entity_type']),
        textValue: readString(json['text_value']),
        normalizedValue: readString(json['normalized_value']),
        confidence: readNullableString(json['confidence']),
        appliedWeight: readString(json['applied_weight']),
        riskRuleId: readNullableInt(json['risk_rule_id']),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'analysis_id': analysisId,
    'entity_type': entityType,
    'text_value': textValue,
    'normalized_value': normalizedValue,
    'confidence': confidence,
    'applied_weight': appliedWeight,
    'risk_rule_id': riskRuleId,
  };
}
