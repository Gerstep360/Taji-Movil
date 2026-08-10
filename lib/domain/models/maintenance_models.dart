import 'model_parsers.dart';

class AssetTypeModel {
  const AssetTypeModel({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.isActive,
  });

  final int id;
  final String code;
  final String name;
  final String description;
  final bool isActive;

  factory AssetTypeModel.fromJson(Map<String, dynamic> json) => AssetTypeModel(
    id: readInt(json['id']),
    code: readString(json['code']),
    name: readString(json['name']),
    description: readString(json['description']),
    isActive: readBool(json['is_active']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'name': name,
    'description': description,
    'is_active': isActive,
  };
}

class AssetModel {
  const AssetModel({
    required this.id,
    required this.assetTypeId,
    required this.sectorId,
    required this.code,
    required this.name,
    required this.description,
    required this.brand,
    required this.model,
    required this.serialNumber,
    required this.installationDate,
    required this.status,
    required this.qrUuid,
    required this.extraData,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int assetTypeId;
  final int? sectorId;
  final String code;
  final String name;
  final String description;
  final String brand;
  final String model;
  final String serialNumber;
  final DateTime? installationDate;
  final String status;
  final String qrUuid;
  final Map<String, dynamic> extraData;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory AssetModel.fromJson(Map<String, dynamic> json) => AssetModel(
    id: readInt(json['id']),
    assetTypeId: readInt(json['asset_type_id']),
    sectorId: readNullableInt(json['sector_id']),
    code: readString(json['code']),
    name: readString(json['name']),
    description: readString(json['description']),
    brand: readString(json['brand']),
    model: readString(json['model']),
    serialNumber: readString(json['serial_number']),
    installationDate: readNullableDateTime(json['installation_date']),
    status: readString(json['status']),
    qrUuid: readString(json['qr_uuid']),
    extraData: readJsonMap(json['extra_data']),
    createdAt: readDateTime(json['created_at']),
    updatedAt: readDateTime(json['updated_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'asset_type_id': assetTypeId,
    'sector_id': sectorId,
    'code': code,
    'name': name,
    'description': description,
    'brand': brand,
    'model': model,
    'serial_number': serialNumber,
    'installation_date': installationDate?.toIso8601String(),
    'status': status,
    'qr_uuid': qrUuid,
    'extra_data': extraData,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}

class SupplierModel {
  const SupplierModel({
    required this.id,
    required this.name,
    required this.contactName,
    required this.phone,
    required this.email,
    required this.specialty,
    required this.status,
    required this.notes,
  });

  final int id;
  final String name;
  final String contactName;
  final String phone;
  final String email;
  final String specialty;
  final String status;
  final String notes;

  factory SupplierModel.fromJson(Map<String, dynamic> json) => SupplierModel(
    id: readInt(json['id']),
    name: readString(json['name']),
    contactName: readString(json['contact_name']),
    phone: readString(json['phone']),
    email: readString(json['email']),
    specialty: readString(json['specialty']),
    status: readString(json['status']),
    notes: readString(json['notes']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'contact_name': contactName,
    'phone': phone,
    'email': email,
    'specialty': specialty,
    'status': status,
    'notes': notes,
  };
}

class MaintenancePlanModel {
  const MaintenancePlanModel({
    required this.id,
    required this.assetId,
    required this.name,
    required this.description,
    required this.frequencyDays,
    required this.lastCompletedAt,
    required this.nextDueAt,
    required this.isActive,
    required this.createdAt,
  });

  final int id;
  final int assetId;
  final String name;
  final String description;
  final int frequencyDays;
  final DateTime? lastCompletedAt;
  final DateTime nextDueAt;
  final bool isActive;
  final DateTime createdAt;

  factory MaintenancePlanModel.fromJson(Map<String, dynamic> json) =>
      MaintenancePlanModel(
        id: readInt(json['id']),
        assetId: readInt(json['asset_id']),
        name: readString(json['name']),
        description: readString(json['description']),
        frequencyDays: readInt(json['frequency_days']),
        lastCompletedAt: readNullableDateTime(json['last_completed_at']),
        nextDueAt: readDateTime(json['next_due_at']),
        isActive: readBool(json['is_active']),
        createdAt: readDateTime(json['created_at']),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'asset_id': assetId,
    'name': name,
    'description': description,
    'frequency_days': frequencyDays,
    'last_completed_at': lastCompletedAt?.toIso8601String(),
    'next_due_at': nextDueAt.toIso8601String(),
    'is_active': isActive,
    'created_at': createdAt.toIso8601String(),
  };
}

class WorkOrderModel {
  const WorkOrderModel({
    required this.id,
    required this.publicCode,
    required this.incidentId,
    required this.assetId,
    required this.maintenancePlanId,
    required this.supplierId,
    required this.createdByUserId,
    required this.currentAssigneeStaffId,
    required this.workType,
    required this.priorityId,
    required this.title,
    required this.description,
    required this.status,
    required this.scheduledFor,
    required this.startedAt,
    required this.completedAt,
    required this.estimatedCost,
    required this.actualCost,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String publicCode;
  final int? incidentId;
  final int? assetId;
  final int? maintenancePlanId;
  final int? supplierId;
  final int? createdByUserId;
  final int? currentAssigneeStaffId;
  final String workType;
  final int? priorityId;
  final String title;
  final String description;
  final String status;
  final DateTime? scheduledFor;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? estimatedCost;
  final String? actualCost;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory WorkOrderModel.fromJson(Map<String, dynamic> json) => WorkOrderModel(
    id: readInt(json['id']),
    publicCode: readString(json['public_code']),
    incidentId: readNullableInt(json['incident_id']),
    assetId: readNullableInt(json['asset_id']),
    maintenancePlanId: readNullableInt(json['maintenance_plan_id']),
    supplierId: readNullableInt(json['supplier_id']),
    createdByUserId: readNullableInt(json['created_by_user_id']),
    currentAssigneeStaffId: readNullableInt(json['current_assignee_staff_id']),
    workType: readString(json['work_type']),
    priorityId: readNullableInt(json['priority_id']),
    title: readString(json['title']),
    description: readString(json['description']),
    status: readString(json['status']),
    scheduledFor: readNullableDateTime(json['scheduled_for']),
    startedAt: readNullableDateTime(json['started_at']),
    completedAt: readNullableDateTime(json['completed_at']),
    estimatedCost: readNullableString(json['estimated_cost']),
    actualCost: readNullableString(json['actual_cost']),
    createdAt: readDateTime(json['created_at']),
    updatedAt: readDateTime(json['updated_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'public_code': publicCode,
    'incident_id': incidentId,
    'asset_id': assetId,
    'maintenance_plan_id': maintenancePlanId,
    'supplier_id': supplierId,
    'created_by_user_id': createdByUserId,
    'current_assignee_staff_id': currentAssigneeStaffId,
    'work_type': workType,
    'priority_id': priorityId,
    'title': title,
    'description': description,
    'status': status,
    'scheduled_for': scheduledFor?.toIso8601String(),
    'started_at': startedAt?.toIso8601String(),
    'completed_at': completedAt?.toIso8601String(),
    'estimated_cost': estimatedCost,
    'actual_cost': actualCost,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}

class WorkOrderAssignmentModel {
  const WorkOrderAssignmentModel({
    required this.id,
    required this.workOrderId,
    required this.assignedToStaffId,
    required this.assignedByUserId,
    required this.assignedAt,
    required this.endedAt,
    required this.reason,
  });

  final int id;
  final int workOrderId;
  final int assignedToStaffId;
  final int? assignedByUserId;
  final DateTime assignedAt;
  final DateTime? endedAt;
  final String reason;

  factory WorkOrderAssignmentModel.fromJson(Map<String, dynamic> json) =>
      WorkOrderAssignmentModel(
        id: readInt(json['id']),
        workOrderId: readInt(json['work_order_id']),
        assignedToStaffId: readInt(json['assigned_to_staff_id']),
        assignedByUserId: readNullableInt(json['assigned_by_user_id']),
        assignedAt: readDateTime(json['assigned_at']),
        endedAt: readNullableDateTime(json['ended_at']),
        reason: readString(json['reason']),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'work_order_id': workOrderId,
    'assigned_to_staff_id': assignedToStaffId,
    'assigned_by_user_id': assignedByUserId,
    'assigned_at': assignedAt.toIso8601String(),
    'ended_at': endedAt?.toIso8601String(),
    'reason': reason,
  };
}

class WorkOrderAttachmentModel {
  const WorkOrderAttachmentModel({
    required this.id,
    required this.workOrderId,
    required this.uploadedByUserId,
    required this.filePath,
    required this.fileType,
    required this.caption,
    required this.createdAt,
  });

  final int id;
  final int workOrderId;
  final int? uploadedByUserId;
  final String filePath;
  final String fileType;
  final String caption;
  final DateTime createdAt;

  factory WorkOrderAttachmentModel.fromJson(Map<String, dynamic> json) =>
      WorkOrderAttachmentModel(
        id: readInt(json['id']),
        workOrderId: readInt(json['work_order_id']),
        uploadedByUserId: readNullableInt(json['uploaded_by_user_id']),
        filePath: readString(json['file_path']),
        fileType: readString(json['file_type']),
        caption: readString(json['caption']),
        createdAt: readDateTime(json['created_at']),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'work_order_id': workOrderId,
    'uploaded_by_user_id': uploadedByUserId,
    'file_path': filePath,
    'file_type': fileType,
    'caption': caption,
    'created_at': createdAt.toIso8601String(),
  };
}

class WorkOrderCostItemModel {
  const WorkOrderCostItemModel({
    required this.id,
    required this.workOrderId,
    required this.description,
    required this.quantity,
    required this.unitCost,
    required this.createdAt,
  });

  final int id;
  final int workOrderId;
  final String description;
  final String quantity;
  final String unitCost;
  final DateTime createdAt;

  factory WorkOrderCostItemModel.fromJson(Map<String, dynamic> json) =>
      WorkOrderCostItemModel(
        id: readInt(json['id']),
        workOrderId: readInt(json['work_order_id']),
        description: readString(json['description']),
        quantity: readString(json['quantity']),
        unitCost: readString(json['unit_cost']),
        createdAt: readDateTime(json['created_at']),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'work_order_id': workOrderId,
    'description': description,
    'quantity': quantity,
    'unit_cost': unitCost,
    'created_at': createdAt.toIso8601String(),
  };
}
