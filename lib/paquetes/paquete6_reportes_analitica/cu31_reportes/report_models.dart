Map<String, dynamic> reportMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
int reportInt(Object? value) => int.tryParse('$value') ?? 0;
String reportMimeType(String format) =>
    const {
      'pdf': 'application/pdf',
      'xlsx':
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'csv': 'text/csv',
      'html': 'text/html',
    }[format] ??
    'application/octet-stream';
const reportOperatorLabels = {
  'eq': 'Es igual a',
  'ne': 'Es diferente de',
  'gte': 'Desde / mayor o igual',
  'lte': 'Hasta / menor o igual',
  'contains': 'Contiene',
  'is_empty': 'Está vacío',
  'not_empty': 'Tiene un valor',
};
bool emptyReportOperator(String value) =>
    value == 'is_empty' || value == 'not_empty';

class ReportColumn {
  ReportColumn.fromJson(Map<String, dynamic> json)
    : key = '${json['key']}',
      label = '${json['label']}',
      type = '${json['type']}',
      operators = List<String>.from(json['operators'] as List? ?? []),
      choices = (json['choices'] as List? ?? [])
          .map((v) => reportMap(v))
          .toList();
  final String key, label, type;
  final List<String> operators;
  final List<Map<String, dynamic>> choices;
}

class ReportSource {
  ReportSource.fromJson(Map<String, dynamic> json)
    : key = '${json['key']}',
      label = '${json['label']}',
      description = '${json['description'] ?? ''}',
      columns = (json['columns'] as List? ?? [])
          .map((v) => ReportColumn.fromJson(reportMap(v)))
          .toList(),
      defaults = List<String>.from(json['default_columns'] as List? ?? []),
      ordering = (json['default_ordering'] as List? ?? [])
          .map(reportMap)
          .toList();
  final String key, label, description;
  final List<ReportColumn> columns;
  final List<String> defaults;
  final List<Map<String, dynamic>> ordering;
}

class ReportCatalog {
  ReportCatalog.fromJson(Map<String, dynamic> json)
    : tenant =
          '${reportMap(json['condominium'])['name'] ?? 'Condominio activo'}',
      limit = reportInt(json['export_limit']),
      voice = json['voice_enabled'] == true,
      formats = List<String>.from(json['formats'] as List? ?? []),
      suggestions = List<String>.from(json['voice_suggestions'] as List? ?? []),
      sources = (json['sources'] as List? ?? [])
          .map((v) => ReportSource.fromJson(reportMap(v)))
          .toList();
  final String tenant;
  final int limit;
  final bool voice;
  final List<String> formats, suggestions;
  final List<ReportSource> sources;
}

class ReportFilter {
  ReportFilter(this.field, this.operator, [this.value = '']);
  factory ReportFilter.fromJson(Map<String, dynamic> json) => ReportFilter(
    '${json['field']}',
    '${json['operator']}',
    '${json['value'] ?? ''}',
  );
  String field, operator, value;
  ReportFilter copy() => ReportFilter(field, operator, value);
  Map<String, dynamic> toJson() => {
    'field': field,
    'operator': operator,
    'value': emptyReportOperator(operator) ? '' : value.trim(),
  };
}

class ReportQuery {
  ReportQuery({
    required this.source,
    required this.columns,
    required this.filters,
    required this.ordering,
    this.title = '',
    this.page = 1,
    this.pageSize = 25,
  });
  factory ReportQuery.fromJson(Map<String, dynamic> json) => ReportQuery(
    source: '${json['source']}',
    columns: List<String>.from(json['columns'] as List? ?? []),
    filters: (json['filters'] as List? ?? [])
        .map((v) => ReportFilter.fromJson(reportMap(v)))
        .toList(),
    ordering: (json['ordering'] as List? ?? []).map(reportMap).toList(),
    title: '${json['title'] ?? ''}',
    page: reportInt(json['page']) == 0 ? 1 : reportInt(json['page']),
    pageSize: reportInt(json['page_size']) == 0
        ? 25
        : reportInt(json['page_size']),
  );
  final String source, title;
  final List<String> columns;
  final List<ReportFilter> filters;
  final List<Map<String, dynamic>> ordering;
  final int page, pageSize;
  Map<String, dynamic> toJson() => {
    'source': source,
    'title': title,
    'columns': List.of(columns),
    'filters': filters.map((f) => f.toJson()).toList(),
    'ordering': ordering,
    'page': page,
    'page_size': pageSize,
  };
  ReportQuery atPage(int value) =>
      ReportQuery.fromJson({...toJson(), 'page': value});
}

class ReportPreview {
  ReportPreview.fromJson(Map<String, dynamic> json)
    : source = '${json['source']}',
      title = '${json['title']}',
      columns = (json['columns'] as List? ?? [])
          .map((v) => ReportColumn.fromJson(reportMap(v)))
          .toList(),
      rows = (json['rows'] as List? ?? [])
          .map((row) => (row as List).map((v) => v?.toString() ?? '').toList())
          .toList(),
      page = reportInt(reportMap(json['pagination'])['page']),
      pages = reportInt(reportMap(json['pagination'])['pages']),
      total = reportInt(reportMap(json['pagination'])['total']),
      canExport = json['can_export'] == true;
  final String source, title;
  final List<ReportColumn> columns;
  final List<List<String>> rows;
  final int page, pages, total;
  final bool canExport;
}
