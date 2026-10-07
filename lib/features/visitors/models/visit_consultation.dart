class VisitConsultationItem {
  const VisitConsultationItem({required this.name, required this.document, required this.unit,
    required this.status, this.from, this.until, this.enteredAt});
  final String name;
  final String document;
  final String unit;
  final String status;
  final DateTime? from;
  final DateTime? until;
  final DateTime? enteredAt;

  factory VisitConsultationItem.fromJson(Map<String, dynamic> json) => VisitConsultationItem(
    name: json['visitor_name'] as String? ?? '',
    document: json['visitor_document_number'] as String? ?? '',
    unit: json['unit_code'] as String? ?? '',
    status: json['status_display'] as String? ?? '',
    from: DateTime.tryParse(json['valid_from'] as String? ?? ''),
    until: DateTime.tryParse(json['valid_until'] as String? ?? ''),
    enteredAt: DateTime.tryParse(json['entered_at'] as String? ?? ''),
  );
}
