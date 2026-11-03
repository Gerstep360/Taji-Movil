class Asset {
  Asset({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    required this.assetTypeName,
    this.sectorName,
    required this.status,
    required this.qrUuid,
    required this.createdAt,
    this.brand,
    this.model,
    this.serialNumber,
  });

  final int id;
  final String code;
  final String name;
  final String? description;
  final String assetTypeName;
  final String? sectorName;
  final String status;
  final String qrUuid;
  final DateTime createdAt;
  final String? brand;
  final String? model;
  final String? serialNumber;

  factory Asset.fromJson(Map<String, dynamic> json) => Asset(
    id: json['id'] as int,
    code: json['code'] as String,
    name: json['name'] as String,
    description: json['description'] as String?,
    assetTypeName: json['asset_type_name'] as String,
    sectorName: json['sector_name'] as String?,
    status: json['status'] as String,
    qrUuid: json['qr_uuid'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    brand: json['brand'] as String?,
    model: json['model'] as String?,
    serialNumber: json['serial_number'] as String?,
  );
}

class AssetHistory {
  AssetHistory({
    required this.assetId,
    this.incidents = const [],
    this.workOrders = const [],
    this.maintenancePlans = const [],
  });

  final int assetId;
  final List<Incident> incidents;
  final List<WorkOrder> workOrders;
  final List<MaintenancePlan> maintenancePlans;

  factory AssetHistory.fromJson(Map<String, dynamic> json) => AssetHistory(
    assetId: json['asset_id'] as int,
    incidents: (json['incidents'] as List<dynamic>?)
        ?.map((e) => Incident.fromJson(e as Map<String, dynamic>))
        .toList() ?? [],
    workOrders: (json['work_orders'] as List<dynamic>?)
        ?.map((e) => WorkOrder.fromJson(e as Map<String, dynamic>))
        .toList() ?? [],
    maintenancePlans: (json['maintenance_plans'] as List<dynamic>?)
        ?.map((e) => MaintenancePlan.fromJson(e as Map<String, dynamic>))
        .toList() ?? [],
  );
}

class Incident {
  Incident({
    required this.id,
    required this.publicCode,
    required this.title,
    required this.status,
    required this.createdAt,
  });

  final int id;
  final String publicCode;
  final String title;
  final String status;
  final DateTime createdAt;

  factory Incident.fromJson(Map<String, dynamic> json) => Incident(
    id: json['id'] as int,
    publicCode: json['public_code'] as String,
    title: json['title'] as String,
    status: json['status'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

class WorkOrder {
  WorkOrder({
    required this.id,
    required this.publicCode,
    required this.title,
    required this.workType,
    required this.status,
    this.scheduledFor,
    this.completedAt,
    required this.createdAt,
  });

  final int id;
  final String publicCode;
  final String title;
  final String workType;
  final String status;
  final DateTime? scheduledFor;
  final DateTime? completedAt;
  final DateTime createdAt;

  factory WorkOrder.fromJson(Map<String, dynamic> json) => WorkOrder(
    id: json['id'] as int,
    publicCode: json['public_code'] as String,
    title: json['title'] as String,
    workType: json['work_type'] as String,
    status: json['status'] as String,
    scheduledFor: json['scheduled_for'] != null
        ? DateTime.parse(json['scheduled_for'] as String)
        : null,
    completedAt: json['completed_at'] != null
        ? DateTime.parse(json['completed_at'] as String)
        : null,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

class MaintenancePlan {
  MaintenancePlan({
    required this.id,
    required this.name,
    required this.frequencyDays,
    this.lastCompletedAt,
    required this.nextDueAt,
    required this.isActive,
  });

  final int id;
  final String name;
  final int frequencyDays;
  final DateTime? lastCompletedAt;
  final DateTime nextDueAt;
  final bool isActive;

  factory MaintenancePlan.fromJson(Map<String, dynamic> json) => MaintenancePlan(
    id: json['id'] as int,
    name: json['name'] as String,
    frequencyDays: json['frequency_days'] as int,
    lastCompletedAt: json['last_completed_at'] != null
        ? DateTime.parse(json['last_completed_at'] as String)
        : null,
    nextDueAt: DateTime.parse(json['next_due_at'] as String),
    isActive: json['is_active'] as bool,
  );
}
