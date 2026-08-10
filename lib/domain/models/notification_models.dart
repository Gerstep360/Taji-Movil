import 'model_parsers.dart';

class AnnouncementModel {
  const AnnouncementModel({
    required this.id,
    required this.createdByUserId,
    required this.title,
    required this.body,
    required this.audience,
    required this.priority,
    required this.publishedAt,
    required this.expiresAt,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int? createdByUserId;
  final String title;
  final String body;
  final String audience;
  final String priority;
  final DateTime? publishedAt;
  final DateTime? expiresAt;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) =>
      AnnouncementModel(
        id: readInt(json['id']),
        createdByUserId: readNullableInt(json['created_by_user_id']),
        title: readString(json['title']),
        body: readString(json['body']),
        audience: readString(json['audience']),
        priority: readString(json['priority']),
        publishedAt: readNullableDateTime(json['published_at']),
        expiresAt: readNullableDateTime(json['expires_at']),
        status: readString(json['status']),
        createdAt: readDateTime(json['created_at']),
        updatedAt: readDateTime(json['updated_at']),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'created_by_user_id': createdByUserId,
    'title': title,
    'body': body,
    'audience': audience,
    'priority': priority,
    'published_at': publishedAt?.toIso8601String(),
    'expires_at': expiresAt?.toIso8601String(),
    'status': status,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}

class DeviceTokenModel {
  const DeviceTokenModel({
    required this.id,
    required this.userId,
    required this.token,
    required this.platform,
    required this.isActive,
    required this.lastSeenAt,
    required this.createdAt,
  });

  final int id;
  final int userId;
  final String token;
  final String platform;
  final bool isActive;
  final DateTime lastSeenAt;
  final DateTime createdAt;

  factory DeviceTokenModel.fromJson(Map<String, dynamic> json) =>
      DeviceTokenModel(
        id: readInt(json['id']),
        userId: readInt(json['user_id']),
        token: readString(json['token']),
        platform: readString(json['platform']),
        isActive: readBool(json['is_active']),
        lastSeenAt: readDateTime(json['last_seen_at']),
        createdAt: readDateTime(json['created_at']),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'token': token,
    'platform': platform,
    'is_active': isActive,
    'last_seen_at': lastSeenAt.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };
}

class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.userId,
    required this.notificationType,
    required this.title,
    required this.message,
    required this.resourceType,
    required this.resourceId,
    required this.sentAt,
    required this.readAt,
    required this.createdAt,
  });

  final int id;
  final int userId;
  final String notificationType;
  final String title;
  final String message;
  final String? resourceType;
  final String? resourceId;
  final DateTime? sentAt;
  final DateTime? readAt;
  final DateTime createdAt;

  factory NotificationModel.fromJson(Map<String, dynamic> json) =>
      NotificationModel(
        id: readInt(json['id']),
        userId: readInt(json['user_id']),
        notificationType: readString(json['notification_type']),
        title: readString(json['title']),
        message: readString(json['message']),
        resourceType: readNullableString(json['resource_type']),
        resourceId: readNullableString(json['resource_id']),
        sentAt: readNullableDateTime(json['sent_at']),
        readAt: readNullableDateTime(json['read_at']),
        createdAt: readDateTime(json['created_at']),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'notification_type': notificationType,
    'title': title,
    'message': message,
    'resource_type': resourceType,
    'resource_id': resourceId,
    'sent_at': sentAt?.toIso8601String(),
    'read_at': readAt?.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };
}
