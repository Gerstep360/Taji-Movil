import 'dart:typed_data';

/// CU18 / RF-18: catálogo y contrato para registrar una incidencia.
///
/// Los modelos de `domain/models/incident_models.dart` describen las tablas del
/// backend (ids planos, campos de IA). El contrato HTTP de CU18 devuelve
/// objetos anidados y un catálogo propio, por eso esta feature tiene sus
/// modelos de frontera.

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed != null) return parsed;
  }
  throw const FormatException('Se esperaba un identificador numérico.');
}

/// El backend puede enviar la relación como id o como objeto `{id, ...}`.
int? _relationId(Object? value) {
  if (value == null) return null;
  if (value is Map) return _int(value['id']);
  return _int(value);
}

String _string(Object? value) => value?.toString() ?? '';

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

List<Map<String, dynamic>> _list(Object? value) => value is List
    ? value.whereType<Map>().map(Map<String, dynamic>.from).toList()
    : const [];

class IncidentCategoryOption {
  const IncidentCategoryOption({
    required this.id,
    required this.code,
    required this.name,
    this.description = '',
    this.defaultPriorityName = '',
  });

  final int id;
  final String code;
  final String name;
  final String description;

  /// Solo informativo: la prioridad real la asigna el servidor.
  final String defaultPriorityName;

  factory IncidentCategoryOption.fromJson(Map<String, dynamic> json) =>
      IncidentCategoryOption(
        id: _int(json['id']),
        code: _string(json['code']),
        name: _string(json['name']),
        description: _string(json['description']),
        defaultPriorityName: _string(_map(json['default_priority'])['name']),
      );
}

class IncidentSectorOption {
  const IncidentSectorOption({
    required this.id,
    required this.code,
    required this.name,
    this.sectorType = '',
    this.parentId,
  });

  final int id;
  final String code;
  final String name;
  final String sectorType;
  final int? parentId;

  factory IncidentSectorOption.fromJson(Map<String, dynamic> json) =>
      IncidentSectorOption(
        id: _int(json['id']),
        code: _string(json['code']),
        name: _string(json['name']),
        sectorType: _string(json['sector_type']),
        parentId: _relationId(json['parent']),
      );
}

class IncidentUnitOption {
  const IncidentUnitOption({
    required this.id,
    required this.code,
    this.unitType = '',
    this.sectorId,
  });

  final int id;
  final String code;
  final String unitType;
  final int? sectorId;

  factory IncidentUnitOption.fromJson(Map<String, dynamic> json) =>
      IncidentUnitOption(
        id: _int(json['id']),
        code: _string(json['code']),
        unitType: _string(json['unit_type']),
        sectorId: _relationId(json['sector']),
      );
}

class IncidentAssetOption {
  const IncidentAssetOption({
    required this.id,
    required this.code,
    required this.name,
    this.sectorId,
  });

  final int id;
  final String code;
  final String name;
  final int? sectorId;

  String get label => name.isEmpty ? code : '$name ($code)';

  factory IncidentAssetOption.fromJson(Map<String, dynamic> json) =>
      IncidentAssetOption(
        id: _int(json['id']),
        code: _string(json['code']),
        name: _string(json['name']),
        sectorId: _relationId(json['sector']),
      );
}

/// Reglas de evidencia publicadas por el servidor. La app las aplica solo
/// para dar aviso temprano; el servidor sigue siendo la autoridad.
class EvidenceRules {
  const EvidenceRules({
    this.fieldName = 'evidences',
    this.maxFiles = 5,
    this.maxFileSizeBytes = 5 * 1024 * 1024,
    this.allowedExtensions = const ['jpeg', 'jpg', 'pdf', 'png', 'webp'],
    this.allowedMimeTypes = const [],
  });

  final String fieldName;
  final int maxFiles;
  final int maxFileSizeBytes;
  final List<String> allowedExtensions;
  final List<String> allowedMimeTypes;

  String get maxSizeLabel {
    final mb = maxFileSizeBytes / (1024 * 1024);
    return mb == mb.roundToDouble()
        ? '${mb.toInt()} MB'
        : '${mb.toStringAsFixed(1)} MB';
  }

  String get extensionsLabel =>
      allowedExtensions.map((ext) => ext.toUpperCase()).join(', ');

  factory EvidenceRules.fromJson(Map<String, dynamic> json) {
    const defaults = EvidenceRules();
    final extensions = (json['allowed_extensions'] as List? ?? const [])
        .map((ext) => ext.toString().toLowerCase())
        .toList();
    return EvidenceRules(
      fieldName: _string(json['field_name']).isEmpty
          ? defaults.fieldName
          : _string(json['field_name']),
      maxFiles: json['max_files'] == null
          ? defaults.maxFiles
          : _int(json['max_files']),
      maxFileSizeBytes: json['max_file_size_bytes'] == null
          ? defaults.maxFileSizeBytes
          : _int(json['max_file_size_bytes']),
      allowedExtensions: extensions.isEmpty
          ? defaults.allowedExtensions
          : extensions,
      allowedMimeTypes: (json['allowed_mime_types'] as List? ?? const [])
          .map((type) => type.toString())
          .toList(),
    );
  }
}

class IncidentOptions {
  const IncidentOptions({
    required this.categories,
    required this.sectors,
    required this.units,
    required this.assets,
    this.evidenceRules = const EvidenceRules(),
  });

  final List<IncidentCategoryOption> categories;
  final List<IncidentSectorOption> sectors;
  final List<IncidentUnitOption> units;
  final List<IncidentAssetOption> assets;
  final EvidenceRules evidenceRules;

  List<IncidentUnitOption> unitsForSector(int? sectorId) => sectorId == null
      ? const []
      : units.where((unit) => unit.sectorId == sectorId).toList();

  /// Activos del sector elegido, más los que no están ligados a ninguno.
  List<IncidentAssetOption> assetsForSector(int? sectorId) => sectorId == null
      ? const []
      : assets
            .where((asset) => asset.sectorId == null || asset.sectorId == sectorId)
            .toList();

  factory IncidentOptions.fromJson(Map<String, dynamic> json) {
    if (json['categories'] is! List || json['sectors'] is! List) {
      throw const FormatException('Catálogo de incidencias incompleto.');
    }
    return IncidentOptions(
      categories: _list(json['categories'])
          .map(IncidentCategoryOption.fromJson)
          .toList(),
      sectors: _list(json['sectors']).map(IncidentSectorOption.fromJson).toList(),
      units: _list(json['units']).map(IncidentUnitOption.fromJson).toList(),
      assets: _list(json['assets']).map(IncidentAssetOption.fromJson).toList(),
      evidenceRules: json['evidence_rules'] is Map
          ? EvidenceRules.fromJson(_map(json['evidence_rules']))
          : const EvidenceRules(),
    );
  }
}

/// Archivo de evidencia ya leído en memoria. Usar bytes en vez de rutas
/// permite enviar igual desde Android, iOS y web.
class EvidenceFile {
  const EvidenceFile({required this.name, required this.bytes, this.mimeType});

  final String name;
  final Uint8List bytes;
  final String? mimeType;

  int get size => bytes.lengthInBytes;

  String get extension {
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  }

  bool get isImage => resolvedMimeType.startsWith('image/');

  String get resolvedMimeType {
    final explicit = mimeType;
    if (explicit != null && explicit.contains('/')) return explicit;
    return switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'pdf' => 'application/pdf',
      _ => 'application/octet-stream',
    };
  }
}

/// Lo que el usuario envía. Nunca incluye prioridad, estado, reportante ni
/// condominio: los decide el servidor.
class IncidentDraft {
  const IncidentDraft({
    required this.description,
    required this.categoryId,
    required this.sectorId,
    this.title = '',
    this.unitId,
    this.assetId,
    this.evidences = const [],
  });

  final String description;
  final String title;
  final int categoryId;
  final int sectorId;
  final int? unitId;
  final int? assetId;
  final List<EvidenceFile> evidences;
}

/// Respuesta 201 de `POST /incidents/`.
class ReportedIncident {
  const ReportedIncident({
    required this.id,
    required this.publicCode,
    required this.status,
    required this.statusDisplay,
    required this.title,
    required this.description,
    required this.categoryName,
    required this.priorityName,
    required this.sectorName,
    this.unitCode,
    this.assetName,
    this.evidenceCount = 0,
    this.createdAt,
  });

  final int id;
  final String publicCode;
  final String status;
  final String statusDisplay;
  final String title;
  final String description;
  final String categoryName;
  final String priorityName;
  final String sectorName;
  final String? unitCode;
  final String? assetName;
  final int evidenceCount;
  final DateTime? createdAt;

  factory ReportedIncident.fromJson(Map<String, dynamic> json) {
    final code = _string(json['public_code']);
    if (json['id'] == null || code.isEmpty) {
      throw const FormatException('Respuesta de incidencia incompleta.');
    }
    final unit = json['unit'];
    final asset = json['asset'];
    return ReportedIncident(
      id: _int(json['id']),
      publicCode: code,
      status: _string(json['status']),
      statusDisplay: _string(json['status_display']),
      title: _string(json['title']),
      description: _string(json['description']),
      categoryName: _string(_map(json['category'])['name']),
      priorityName: _string(_map(json['priority'])['name']),
      sectorName: _string(_map(json['sector'])['name']),
      unitCode: unit is Map ? _string(unit['code']) : null,
      assetName: asset is Map ? _string(asset['name']) : null,
      evidenceCount: (json['evidences'] as List? ?? const []).length,
      createdAt: DateTime.tryParse(_string(json['created_at'])),
    );
  }
}
