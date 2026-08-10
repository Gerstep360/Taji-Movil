import 'model_parsers.dart';

class CondominiumModel {
  const CondominiumModel({
    required this.id,
    required this.name,
    required this.legalName,
    required this.address,
    required this.phone,
    required this.email,
    required this.timezone,
    required this.logo,
    required this.rulesSummary,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final String legalName;
  final String address;
  final String phone;
  final String email;
  final String timezone;
  final String logo;
  final String rulesSummary;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory CondominiumModel.fromJson(Map<String, dynamic> json) =>
      CondominiumModel(
        id: readInt(json['id']),
        name: readString(json['name']),
        legalName: readString(json['legal_name']),
        address: readString(json['address']),
        phone: readString(json['phone']),
        email: readString(json['email']),
        timezone: readString(json['timezone']),
        logo: readString(json['logo']),
        rulesSummary: readString(json['rules_summary']),
        isActive: readBool(json['is_active']),
        createdAt: readDateTime(json['created_at']),
        updatedAt: readDateTime(json['updated_at']),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'legal_name': legalName,
    'address': address,
    'phone': phone,
    'email': email,
    'timezone': timezone,
    'logo': logo,
    'rules_summary': rulesSummary,
    'is_active': isActive,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}

class SectorModel {
  const SectorModel({
    required this.id,
    required this.condominiumId,
    required this.parentId,
    required this.code,
    required this.name,
    required this.sectorType,
    required this.description,
    required this.isActive,
    required this.createdAt,
  });

  final int id;
  final int condominiumId;
  final int? parentId;
  final String code;
  final String name;
  final String sectorType;
  final String description;
  final bool isActive;
  final DateTime createdAt;

  factory SectorModel.fromJson(Map<String, dynamic> json) => SectorModel(
    id: readInt(json['id']),
    condominiumId: readInt(json['condominium_id']),
    parentId: readNullableInt(json['parent_id']),
    code: readString(json['code']),
    name: readString(json['name']),
    sectorType: readString(json['sector_type']),
    description: readString(json['description']),
    isActive: readBool(json['is_active']),
    createdAt: readDateTime(json['created_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'condominium_id': condominiumId,
    'parent_id': parentId,
    'code': code,
    'name': name,
    'sector_type': sectorType,
    'description': description,
    'is_active': isActive,
    'created_at': createdAt.toIso8601String(),
  };
}

class UnitModel {
  const UnitModel({
    required this.id,
    required this.sectorId,
    required this.code,
    required this.unitType,
    required this.floorLabel,
    required this.description,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int? sectorId;
  final String code;
  final String unitType;
  final String floorLabel;
  final String description;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory UnitModel.fromJson(Map<String, dynamic> json) => UnitModel(
    id: readInt(json['id']),
    sectorId: readNullableInt(json['sector_id']),
    code: readString(json['code']),
    unitType: readString(json['unit_type']),
    floorLabel: readString(json['floor_label']),
    description: readString(json['description']),
    status: readString(json['status']),
    createdAt: readDateTime(json['created_at']),
    updatedAt: readDateTime(json['updated_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'sector_id': sectorId,
    'code': code,
    'unit_type': unitType,
    'floor_label': floorLabel,
    'description': description,
    'status': status,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}

class ResidentModel {
  const ResidentModel({
    required this.id,
    required this.personId,
    required this.status,
    required this.notes,
    required this.registeredAt,
    required this.deactivatedAt,
  });

  final int id;
  final int personId;
  final String status;
  final String notes;
  final DateTime registeredAt;
  final DateTime? deactivatedAt;

  factory ResidentModel.fromJson(Map<String, dynamic> json) => ResidentModel(
    id: readInt(json['id']),
    personId: readInt(json['person_id']),
    status: readString(json['status']),
    notes: readString(json['notes']),
    registeredAt: readDateTime(json['registered_at']),
    deactivatedAt: readNullableDateTime(json['deactivated_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'person_id': personId,
    'status': status,
    'notes': notes,
    'registered_at': registeredAt.toIso8601String(),
    'deactivated_at': deactivatedAt?.toIso8601String(),
  };
}

class ResidentUnitModel {
  const ResidentUnitModel({
    required this.id,
    required this.residentId,
    required this.unitId,
    required this.relationType,
    required this.isPrimary,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
  });

  final int id;
  final int residentId;
  final int unitId;
  final String relationType;
  final bool isPrimary;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime createdAt;

  factory ResidentUnitModel.fromJson(Map<String, dynamic> json) =>
      ResidentUnitModel(
        id: readInt(json['id']),
        residentId: readInt(json['resident_id']),
        unitId: readInt(json['unit_id']),
        relationType: readString(json['relation_type']),
        isPrimary: readBool(json['is_primary']),
        startDate: readDateTime(json['start_date']),
        endDate: readNullableDateTime(json['end_date']),
        createdAt: readDateTime(json['created_at']),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'resident_id': residentId,
    'unit_id': unitId,
    'relation_type': relationType,
    'is_primary': isPrimary,
    'start_date': startDate.toIso8601String(),
    'end_date': endDate?.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };
}

class StaffModel {
  const StaffModel({
    required this.id,
    required this.personId,
    required this.employeeCode,
    required this.staffType,
    required this.hireDate,
    required this.endDate,
    required this.status,
    required this.notes,
  });

  final int id;
  final int personId;
  final String? employeeCode;
  final String staffType;
  final DateTime? hireDate;
  final DateTime? endDate;
  final String status;
  final String notes;

  factory StaffModel.fromJson(Map<String, dynamic> json) => StaffModel(
    id: readInt(json['id']),
    personId: readInt(json['person_id']),
    employeeCode: readNullableString(json['employee_code']),
    staffType: readString(json['staff_type']),
    hireDate: readNullableDateTime(json['hire_date']),
    endDate: readNullableDateTime(json['end_date']),
    status: readString(json['status']),
    notes: readString(json['notes']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'person_id': personId,
    'employee_code': employeeCode,
    'staff_type': staffType,
    'hire_date': hireDate?.toIso8601String(),
    'end_date': endDate?.toIso8601String(),
    'status': status,
    'notes': notes,
  };
}
