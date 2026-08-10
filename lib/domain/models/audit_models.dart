import 'model_parsers.dart';

class AuditEventModel {
  const AuditEventModel({
    required this.id,
    required this.actorUserId,
    required this.actionCode,
    required this.resourceType,
    required this.resourceId,
    required this.description,
    required this.beforeData,
    required this.afterData,
    required this.ipAddress,
    required this.userAgent,
    required this.requestId,
    required this.occurredAt,
  });

  final int id;
  final int? actorUserId;
  final String actionCode;
  final String resourceType;
  final String? resourceId;
  final String description;
  final Map<String, dynamic>? beforeData;
  final Map<String, dynamic>? afterData;
  final String? ipAddress;
  final String userAgent;
  final String? requestId;
  final DateTime occurredAt;

  factory AuditEventModel.fromJson(Map<String, dynamic> json) =>
      AuditEventModel(
        id: readInt(json['id']),
        actorUserId: readNullableInt(json['actor_user_id']),
        actionCode: readString(json['action_code']),
        resourceType: readString(json['resource_type']),
        resourceId: readNullableString(json['resource_id']),
        description: readString(json['description']),
        beforeData: readNullableJsonMap(json['before_data']),
        afterData: readNullableJsonMap(json['after_data']),
        ipAddress: readNullableString(json['ip_address']),
        userAgent: readString(json['user_agent']),
        requestId: readNullableString(json['request_id']),
        occurredAt: readDateTime(json['occurred_at']),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'actor_user_id': actorUserId,
    'action_code': actionCode,
    'resource_type': resourceType,
    'resource_id': resourceId,
    'description': description,
    'before_data': beforeData,
    'after_data': afterData,
    'ip_address': ipAddress,
    'user_agent': userAgent,
    'request_id': requestId,
    'occurred_at': occurredAt.toIso8601String(),
  };
}
