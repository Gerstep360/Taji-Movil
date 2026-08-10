import 'model_parsers.dart';

class PersonModel {
  const PersonModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.documentType,
    required this.documentNumber,
    required this.documentComplement,
    required this.phone,
    required this.contactEmail,
    required this.birthDate,
    required this.profilePhoto,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String firstName;
  final String lastName;
  final String documentType;
  final String? documentNumber;
  final String documentComplement;
  final String phone;
  final String contactEmail;
  final DateTime? birthDate;
  final String profilePhoto;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory PersonModel.fromJson(Map<String, dynamic> json) => PersonModel(
    id: readInt(json['id']),
    firstName: readString(json['first_name']),
    lastName: readString(json['last_name']),
    documentType: readString(json['document_type']),
    documentNumber: readNullableString(json['document_number']),
    documentComplement: readString(json['document_complement']),
    phone: readString(json['phone']),
    contactEmail: readString(json['contact_email']),
    birthDate: readNullableDateTime(json['birth_date']),
    profilePhoto: readString(json['profile_photo']),
    isActive: readBool(json['is_active']),
    createdAt: readDateTime(json['created_at']),
    updatedAt: readDateTime(json['updated_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'first_name': firstName,
    'last_name': lastName,
    'document_type': documentType,
    'document_number': documentNumber,
    'document_complement': documentComplement,
    'phone': phone,
    'contact_email': contactEmail,
    'birth_date': birthDate?.toIso8601String(),
    'profile_photo': profilePhoto,
    'is_active': isActive,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}

class SystemPermissionModel {
  const SystemPermissionModel({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.module,
    required this.isActive,
  });

  final int id;
  final String code;
  final String name;
  final String description;
  final String module;
  final bool isActive;

  factory SystemPermissionModel.fromJson(Map<String, dynamic> json) =>
      SystemPermissionModel(
        id: readInt(json['id']),
        code: readString(json['code']),
        name: readString(json['name']),
        description: readString(json['description']),
        module: readString(json['module']),
        isActive: readBool(json['is_active']),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'name': name,
    'description': description,
    'module': module,
    'is_active': isActive,
  };
}

class SystemRoleModel {
  const SystemRoleModel({
    required this.id,
    required this.slug,
    required this.name,
    required this.description,
    required this.isPublic,
    required this.isActive,
    required this.permissionIds,
  });

  final int id;
  final String slug;
  final String name;
  final String description;
  final bool isPublic;
  final bool isActive;
  final List<int> permissionIds;

  factory SystemRoleModel.fromJson(Map<String, dynamic> json) =>
      SystemRoleModel(
        id: readInt(json['id']),
        slug: readString(json['slug']),
        name: readString(json['name']),
        description: readString(json['description']),
        isPublic: readBool(json['is_public']),
        isActive: readBool(json['is_active']),
        permissionIds: readIntList(json['permission_ids']),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'slug': slug,
    'name': name,
    'description': description,
    'is_public': isPublic,
    'is_active': isActive,
    'permission_ids': permissionIds,
  };
}

class AppUserModel {
  const AppUserModel({
    required this.id,
    required this.personId,
    required this.roleId,
    required this.email,
    required this.isSuperuser,
    required this.isStaff,
    required this.isActive,
    required this.lastLogin,
    required this.dateJoined,
    required this.updatedAt,
  });

  final int id;
  final int? personId;
  final int? roleId;
  final String email;
  final bool isSuperuser;
  final bool isStaff;
  final bool isActive;
  final DateTime? lastLogin;
  final DateTime dateJoined;
  final DateTime updatedAt;

  factory AppUserModel.fromJson(Map<String, dynamic> json) => AppUserModel(
    id: readInt(json['id']),
    personId: readNullableInt(json['person_id']),
    roleId: readNullableInt(json['role_id']),
    email: readString(json['email']),
    isSuperuser: readBool(json['is_superuser']),
    isStaff: readBool(json['is_staff']),
    isActive: readBool(json['is_active']),
    lastLogin: readNullableDateTime(json['last_login']),
    dateJoined: readDateTime(json['date_joined']),
    updatedAt: readDateTime(json['updated_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'person_id': personId,
    'role_id': roleId,
    'email': email,
    'is_superuser': isSuperuser,
    'is_staff': isStaff,
    'is_active': isActive,
    'last_login': lastLogin?.toIso8601String(),
    'date_joined': dateJoined.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}

class RolePermissionModel {
  const RolePermissionModel({
    required this.id,
    required this.roleId,
    required this.permissionId,
  });

  final int id;
  final int roleId;
  final int permissionId;

  factory RolePermissionModel.fromJson(Map<String, dynamic> json) =>
      RolePermissionModel(
        id: readInt(json['id']),
        roleId: readInt(json['role_id']),
        permissionId: readInt(json['permission_id']),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'role_id': roleId,
    'permission_id': permissionId,
  };
}
