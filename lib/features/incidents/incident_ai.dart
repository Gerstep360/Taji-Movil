class IncidentAIRisk {
  const IncidentAIRisk(
    this.name,
    this.evidence,
    this.context, {
    this.source = 'text',
    this.attachmentId,
  });
  factory IncidentAIRisk.fromJson(Map<String, dynamic> value) => IncidentAIRisk(
    value['name'] as String? ?? '',
    value['evidence'] as String? ?? '',
    value['context'] as String? ?? 'uncertain',
    source: value['source'] as String? ?? 'text',
    attachmentId: value['attachment_id'] as int?,
  );
  final String name, evidence, context;
  final String source;
  final int? attachmentId;
}

class IncidentAIResult {
  IncidentAIResult.fromJson(Map<String, dynamic> value)
    : status = value['execution_status'] as String? ?? 'FAILED',
      reviewed = value['review'] != null,
      category = (value['category'] as Map?)?['name'] as String?,
      priority = (value['priority'] as Map?)?['name'] as String?,
      summary = value['summary'] as String? ?? '',
      confidence = double.tryParse('${value['confidence']}'),
      score = double.tryParse('${value['risk_score']}'),
      risks = ((value['risks'] as List?) ?? [])
          .map(
            (row) =>
                IncidentAIRisk.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .toList(),
      recommendations = ((value['recommendations'] as List?) ?? [])
          .whereType<String>()
          .toList();
  final String status, summary;
  final bool reviewed;
  final String? category, priority;
  final double? confidence, score;
  final List<IncidentAIRisk> risks;
  final List<String> recommendations;
  bool get pending => status == 'QUEUED' || status == 'RUNNING';
}
