import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/api_failure.dart';

class IncidentReportOption {
  IncidentReportOption.fromJson(Map<String, dynamic> json)
    : id = json['id'] as int,
      code = json['code'] as String? ?? '',
      name = json['name'] as String? ?? json['code'] as String? ?? '',
      sector = json['sector'] as int?,
      parent = json['parent'] as int?;
  final int id;
  final String code, name;
  final int? sector, parent;
}

class IncidentReportOptions {
  IncidentReportOptions.fromJson(Map<String, dynamic> json)
    : categories = _options(json['categories']),
      sectors = _options(json['sectors']),
      units = _options(json['units']),
      assets = _options(json['assets']),
      maxFiles = (json['evidence_rules'] as Map)['max_files'] as int,
      maxBytes = (json['evidence_rules'] as Map)['max_file_size_bytes'] as int,
      extensions = List<String>.from(
        (json['evidence_rules'] as Map)['allowed_extensions'] as List,
      );
  final List<IncidentReportOption> categories, sectors, units, assets;
  final int maxFiles, maxBytes;
  final List<String> extensions;
  static List<IncidentReportOption> _options(dynamic raw) => (raw as List)
      .map(
        (e) =>
            IncidentReportOption.fromJson(Map<String, dynamic>.from(e as Map)),
      )
      .toList();
  bool containsSector(int ancestor, int? child) {
    final visited = <int>{};
    while (child != null && visited.add(child)) {
      if (child == ancestor) return true;
      final matches = sectors.where((s) => s.id == child);
      child = matches.isEmpty ? null : matches.first.parent;
    }
    return false;
  }
}

class IncidentReportRepository {
  IncidentReportRepository(this.api);
  final ApiClient api;
  Future<IncidentReportOptions> options() async {
    final json = await api.get<Map<String, dynamic>>(
      '${ApiEndpoints.incidents}options/',
    );
    if (json == null) throw StateError('Respuesta vacía');
    return IncidentReportOptions.fromJson(json);
  }

  Future<String> create(Map<String, dynamic> fields, List<XFile> files) async {
    final body = FormData.fromMap(fields);
    for (final file in files) {
      final extension = file.name.split('.').last.toLowerCase();
      final type = extension == 'jpg' || extension == 'jpeg'
          ? 'image/jpeg'
          : 'image/$extension';
      body.files.add(
        MapEntry(
          'evidences',
          await MultipartFile.fromFile(
            file.path,
            filename: file.name,
            contentType: DioMediaType.parse(type),
          ),
        ),
      );
    }
    final result = await api.post<Map<String, dynamic>>(
      ApiEndpoints.incidents,
      data: body,
    );
    final code = result?['public_code'];
    if (code is! String || code.isEmpty) {
      throw StateError('Confirmación inválida');
    }
    return code;
  }
}

class IncidentReportController extends ChangeNotifier {
  IncidentReportController(this.repository);
  final IncidentReportRepository repository;
  IncidentReportOptions? options;
  bool loading = false, saving = false, _disposed = false;
  String? error, code;
  String title = '', description = '';
  int? category, sector, unit, asset;
  List<XFile> files = [];
  List<IncidentReportOption> get units => sector == null
      ? []
      : options!.units
            .where((u) => options!.containsSector(sector!, u.sector))
            .toList();
  List<IncidentReportOption> get assets => sector == null
      ? []
      : options!.assets
            .where((a) => options!.containsSector(sector!, a.sector))
            .toList();
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> load() async {
    if (loading) return;
    loading = true;
    error = null;
    _notify();
    try {
      options = await repository.options();
    } catch (failure) {
      error = _message(
        failure,
        'No pudimos cargar las categorías y ubicaciones.',
      );
    } finally {
      loading = false;
      _notify();
    }
  }

  void selectSector(int? value) {
    sector = value;
    unit = null;
    asset = null;
    _notify();
  }

  Future<void> addPhotos(List<XFile> selected) async {
    final rules = options;
    if (rules == null || saving) return;
    error = null;
    if (files.length + selected.length > rules.maxFiles) {
      error = 'Puedes adjuntar hasta ${rules.maxFiles} fotos.';
      _notify();
      return;
    }
    try {
      for (final file in selected) {
        final size = await file.length();
        if (!rules.extensions.contains(
              file.name.split('.').last.toLowerCase(),
            ) ||
            size <= 0 ||
            size > rules.maxBytes) {
          error =
              'La foto ${file.name} no tiene un formato permitido o supera ${(rules.maxBytes / 1048576).round()} MB.';
          _notify();
          return;
        }
      }
      if (!_disposed) files = [...files, ...selected];
    } catch (_) {
      error = 'No pudimos leer las fotos seleccionadas. Intenta nuevamente.';
    }
    _notify();
  }

  void removePhoto(int index) {
    files = [...files]..removeAt(index);
    error = null;
    _notify();
  }

  Future<void> submit() async {
    if (saving || code != null) return;
    if (description.trim().isEmpty || category == null || sector == null) {
      error = 'Completa la descripción, categoría y ubicación.';
      _notify();
      return;
    }
    saving = true;
    error = null;
    _notify();
    try {
      code = await repository.create({
        'title': title.trim(),
        'description': description.trim(),
        'category': category,
        'sector': sector,
        if (unit != null) 'unit': unit,
        if (asset != null) 'asset': asset,
      }, files);
      files = [];
    } catch (failure) {
      error = _message(
        failure,
        'No se pudo enviar el reporte. Tus datos se conservaron.',
      );
    } finally {
      saving = false;
      _notify();
    }
  }

  String _message(Object failure, String fallback) => failure is DioException
      ? ApiFailure.fromDio(failure, fallback: fallback).displayMessage
      : fallback;
}
