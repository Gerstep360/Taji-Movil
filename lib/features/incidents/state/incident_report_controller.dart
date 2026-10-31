import 'package:flutter/foundation.dart';

import '../../../core/network/api_failure.dart';
import '../data/incident_repository.dart';
import '../models/incident_report.dart';

/// Estado del formulario "Nueva incidencia" (CU18).
///
/// Las validaciones locales solo adelantan el aviso; el servidor valida de
/// nuevo y sus errores de campo se muestran junto al campo afectado.
class IncidentReportController extends ChangeNotifier {
  IncidentReportController(this._source);

  final IncidentDataSource _source;
  bool _disposed = false;

  static const maxDescription = 5000;
  static const maxTitle = 160;

  /// Campos que el formulario muestra junto a su control.
  static const formFields = {
    'description',
    'title',
    'category',
    'sector',
    'unit',
    'asset',
    'evidences',
  };

  IncidentOptions? options;
  bool loadingOptions = false;
  String? optionsError;

  int? categoryId;
  int? sectorId;
  int? unitId;
  int? assetId;
  List<EvidenceFile> evidences = [];
  String? evidenceError;

  bool submitting = false;
  String? error;
  Map<String, String> fieldErrors = {};
  ReportedIncident? created;

  EvidenceRules get rules => options?.evidenceRules ?? const EvidenceRules();

  int get remainingEvidenceSlots =>
      (rules.maxFiles - evidences.length).clamp(0, rules.maxFiles);

  IncidentCategoryOption? get selectedCategory => options?.categories
      .where((category) => category.id == categoryId)
      .firstOrNull;

  List<IncidentUnitOption> get availableUnits =>
      options?.unitsForSector(sectorId) ?? const [];

  List<IncidentAssetOption> get availableAssets =>
      options?.assetsForSector(sectorId) ?? const [];

  Future<void> loadOptions() async {
    if (_disposed || loadingOptions) return;
    loadingOptions = true;
    optionsError = null;
    _notify();
    try {
      final loaded = await _source.options();
      if (_disposed) return;
      options = loaded;
    } on Object catch (failure) {
      optionsError = _message(failure);
    } finally {
      loadingOptions = false;
      _notify();
    }
  }

  void selectCategory(int? id) {
    categoryId = id;
    fieldErrors.remove('category');
    _notify();
  }

  void selectSector(int? id) {
    sectorId = id;
    if (!availableUnits.any((unit) => unit.id == unitId)) unitId = null;
    if (!availableAssets.any((asset) => asset.id == assetId)) assetId = null;
    fieldErrors.remove('sector');
    _notify();
  }

  void selectUnit(int? id) {
    unitId = id;
    fieldErrors.remove('unit');
    _notify();
  }

  void selectAsset(int? id) {
    assetId = id;
    fieldErrors.remove('asset');
    _notify();
  }

  void clearFieldError(String field) {
    if (fieldErrors.remove(field) != null) _notify();
  }

  /// Agrega las evidencias válidas y explica por qué se descartó el resto.
  void addEvidences(List<EvidenceFile> files) {
    final rejected = <String>[];
    var overflow = false;
    for (final file in files) {
      if (evidences.length >= rules.maxFiles) {
        overflow = true;
      } else if (!rules.allowedExtensions.contains(file.extension)) {
        rejected.add(
          '«${file.name}» no es un formato permitido (${rules.extensionsLabel}).',
        );
      } else if (file.size > rules.maxFileSizeBytes) {
        rejected.add('«${file.name}» supera el límite de ${rules.maxSizeLabel}.');
      } else if (file.size == 0) {
        rejected.add('«${file.name}» está vacío.');
      } else {
        evidences = [...evidences, file];
      }
    }
    if (overflow) {
      rejected.add('Puedes adjuntar hasta ${rules.maxFiles} archivos.');
    }
    evidenceError = rejected.isEmpty ? null : rejected.join(' ');
    fieldErrors.remove('evidences');
    _notify();
  }

  void reportEvidenceError(String message) {
    evidenceError = message;
    _notify();
  }

  void removeEvidence(int index) {
    if (index < 0 || index >= evidences.length) return;
    evidences = [...evidences]..removeAt(index);
    evidenceError = null;
    _notify();
  }

  Future<bool> submit({required String description, String title = ''}) async {
    if (_disposed || submitting) return false;
    final text = description.trim();
    final heading = title.trim();
    final problems = <String, String>{
      if (text.isEmpty) 'description': 'Cuéntanos qué pasó.',
      if (text.length > maxDescription)
        'description':
            'La descripción no puede superar $maxDescription caracteres.',
      if (heading.length > maxTitle)
        'title': 'El título no puede superar $maxTitle caracteres.',
      if (categoryId == null) 'category': 'Elige una categoría.',
      if (sectorId == null) 'sector': 'Indica dónde ocurrió.',
    };
    error = null;
    fieldErrors = problems;
    if (problems.isNotEmpty) {
      _notify();
      return false;
    }

    submitting = true;
    _notify();
    try {
      final result = await _source.report(
        IncidentDraft(
          description: text,
          title: heading,
          categoryId: categoryId!,
          sectorId: sectorId!,
          unitId: unitId,
          assetId: assetId,
          evidences: List.unmodifiable(evidences),
        ),
      );
      if (_disposed) return true;
      created = result;
      return true;
    } on Object catch (failure) {
      if (failure is ApiFailure && failure.fields.isNotEmpty) {
        fieldErrors = {
          for (final entry in failure.fields.entries)
            if (entry.value.isNotEmpty) entry.key: entry.value.first,
        };
      }
      error = _message(failure);
      return false;
    } finally {
      submitting = false;
      _notify();
    }
  }

  /// Limpia todo para registrar otra incidencia; conserva el catálogo.
  void startNew() {
    categoryId = null;
    sectorId = null;
    unitId = null;
    assetId = null;
    evidences = [];
    evidenceError = null;
    error = null;
    fieldErrors = {};
    created = null;
    _notify();
  }

  String _message(Object failure) {
    if (failure is! ApiFailure) {
      return 'No pudimos registrar la incidencia. Inténtalo nuevamente.';
    }
    final reference = failure.traceId == null
        ? ''
        : ' (ref. ${failure.traceId})';
    switch (failure.statusCode) {
      case 401:
        return 'Tu sesión expiró. Vuelve a iniciar sesión para continuar.';
      case 403:
        return 'No tienes permiso para registrar incidencias en este condominio. '
            'Consulta con la administración.';
      case 503:
        return 'El servicio de incidencias no está disponible en este momento. '
            'Inténtalo más tarde.$reference';
      case 400:
        final allShown =
            failure.fields.isNotEmpty &&
            failure.fields.keys.every(formFields.contains);
        return allShown ? 'Revisa los campos marcados.' : failure.displayMessage;
    }
    return failure.displayMessage;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
