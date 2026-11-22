import '../../../domain/models/model_parsers.dart';

/// Asamblea tal como la expone `/api/v1/assemblies/`.
///
/// Los residentes reciben una vista reducida (solo convocatoria): sin acta ni
/// contadores. `hasFullAccess` distingue ambos casos.
class AssemblyItem {
  const AssemblyItem({
    required this.id,
    required this.title,
    required this.description,
    required this.scheduledAt,
    required this.location,
    required this.status,
    required this.statusDisplay,
    this.minutesText,
    this.createdByName = '',
    this.agreementsCount = 0,
    this.openAgreementsCount = 0,
  });

  final int id;
  final String title;
  final String description;
  final DateTime scheduledAt;
  final String location;
  final String status;
  final String statusDisplay;
  final String? minutesText;
  final String createdByName;
  final int agreementsCount;
  final int openAgreementsCount;

  bool get hasFullAccess => minutesText != null;

  factory AssemblyItem.fromJson(Map<String, dynamic> json) => AssemblyItem(
    id: readInt(json['id']),
    title: readString(json['title']),
    description: readString(json['description']),
    scheduledAt: readDateTime(json['scheduled_at']),
    location: readString(json['location']),
    status: readString(json['status']),
    statusDisplay: readString(json['status_display']),
    minutesText: json.containsKey('minutes_text')
        ? readString(json['minutes_text'])
        : null,
    createdByName: readString(json['created_by_name']),
    agreementsCount: readIntOr(json['agreements_count']),
    openAgreementsCount: readIntOr(json['open_agreements_count']),
  );
}

class AgreementItem {
  const AgreementItem({
    required this.id,
    required this.title,
    required this.description,
    required this.responsibleName,
    required this.dueAt,
    required this.estimatedBudget,
    required this.actualCost,
    required this.status,
    required this.statusDisplay,
    required this.isOverdue,
    required this.attachmentsCount,
  });

  final int id;
  final String title;
  final String description;
  final String responsibleName;
  final DateTime? dueAt;
  final String? estimatedBudget;
  final String? actualCost;
  final String status;
  final String statusDisplay;
  final bool isOverdue;
  final int attachmentsCount;

  factory AgreementItem.fromJson(Map<String, dynamic> json) => AgreementItem(
    id: readInt(json['id']),
    title: readString(json['title']),
    description: readString(json['description']),
    responsibleName: readString(json['responsible_name']),
    dueAt: readNullableDateTime(json['due_at']),
    estimatedBudget: readNullableString(json['estimated_budget']),
    actualCost: readNullableString(json['actual_cost']),
    status: readString(json['status']),
    statusDisplay: readString(json['status_display']),
    isOverdue: readBool(json['is_overdue']),
    attachmentsCount: readIntOr(json['attachments_count']),
  );
}

class AssembliesPageData {
  const AssembliesPageData(this.items, this.pages);
  final List<AssemblyItem> items;
  final int pages;
}
