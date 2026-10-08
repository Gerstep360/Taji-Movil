import 'package:flutter/foundation.dart';

import '../../../core/network/api_failure.dart';
import '../data/qr_scan_history_repository.dart';
import '../models/qr_scan_history.dart';

/// Estado de la pantalla de bitácora de escaneos.
///
/// Guarda la última consulta recibida junto con un identificador de petición,
/// para que una respuesta lenta que llegue después de un "actualizar" no pise
/// los datos frescos.
class QrScanHistoryController extends ChangeNotifier {
  QrScanHistoryController(this._repository);

  final QrScanHistoryDataSource _repository;

  QrScanHistoryPage _page = const QrScanHistoryPage();
  QrScanFilters _filters = const QrScanFilters();
  List<QrScanGuardOption> _guards = const [];

  bool loading = false;
  bool disposed = false;
  String? error;

  /// Identificador de la petición en curso. Solo se aplica la respuesta de la
  /// última.
  int _request = 0;

  QrScanHistoryPage get page => _page;
  List<QrScanEntry> get entries => _page.entries;
  QrScanSummary get summary => _page.summary;
  List<QrScanGuardOption> get guards => _guards;
  QrScanFilters get filters => _filters;
  bool get hasPrevious => _page.hasPrevious;
  bool get hasNext => _page.hasNext;
  bool get hasActiveFilters => _filters.hasActiveFilters;

  /// Rango mostrado en el pie, para el texto "1-20 de 137".
  int get rangeStart => _page.count == 0 ? 0 : (_page.page - 1) * _filters.pageSize + 1;
  int get rangeEnd {
    final end = _page.page * _filters.pageSize;
    return end > _page.count ? _page.count : end;
  }

  Future<void> load({QrScanFilters? filters}) async {
    if (filters != null) _filters = filters;

    final token = ++_request;
    loading = true;
    error = null;
    _safeNotify();

    try {
      final result = await _repository.history(_filters);
      if (disposed || token != _request) return;
      _page = result;
    } on ApiFailure catch (failure) {
      if (disposed || token != _request) return;
      error = failure.displayMessage;
      _page = const QrScanHistoryPage();
    } finally {
      // La petición identificadora decide también quién apaga el spinner: una
      // respuesta obsoleta no debe dejar la pantalla en "cargando".
      if (!disposed && token == _request) {
        loading = false;
        _safeNotify();
      }
    }
  }

  /// Aplica filtros y vuelve a la primera página.
  Future<void> applyFilters({
    QrScanResult? result,
    int? guardStaffId,
    int? days,
    String? search,
  }) {
    return load(
      filters: QrScanFilters(
        result: result,
        guardStaffId: guardStaffId,
        days: days ?? _filters.days,
        search: search,
        page: 1,
        pageSize: _filters.pageSize,
      ),
    );
  }

  Future<void> clearFilters() {
    return load(
      filters: QrScanFilters(page: 1, pageSize: _filters.pageSize),
    );
  }

  Future<void> goToPage(int page) {
    if (page < 1 || (page > _page.totalPages && _page.totalPages > 0)) {
      return Future.value();
    }
    return load(filters: _filters.copyWith(page: page));
  }

  /// Los guardias son una comodidad: si fallan, el resto de la pantalla debe
  /// seguir funcionando, así que el error se descarta.
  Future<void> loadGuards() async {
    try {
      _guards = await _repository.guards();
    } on ApiFailure {
      _guards = const [];
    }
    _safeNotify();
  }

  void _safeNotify() {
    if (!disposed) notifyListeners();
  }

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}
