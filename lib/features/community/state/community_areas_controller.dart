import 'package:flutter/foundation.dart';

import '../../../core/network/api_failure.dart';
import '../../../domain/models/community_models.dart';
import '../data/community_repository.dart';

/// Área común enriquecida con su disponibilidad (CU26 / T121).
class AreaAvailability {
  const AreaAvailability({
    required this.area,
    this.schedules = const [],
    this.blocks = const [],
    this.detailsUnavailable = false,
  });

  final CommonAreaModel area;
  final List<CommonAreaScheduleModel> schedules;
  final List<CommonAreaBlockModel> blocks;

  /// `true` cuando no se pudieron cargar horarios y/o bloqueos para esta área.
  final bool detailsUnavailable;

  /// Horarios activos ordenados por día de la semana (0 = lunes).
  List<CommonAreaScheduleModel> get activeSchedules =>
      schedules.where((schedule) => schedule.isActive).toList(growable: false)
        ..sort((a, b) => a.weekday.compareTo(b.weekday));

  /// Bloqueo cuya ventana incluye el momento actual, si existe.
  CommonAreaBlockModel? get activeBlock {
    final now = DateTime.now();
    CommonAreaBlockModel? current;
    for (final block in blocks) {
      final from = block.blockedFrom.toLocal();
      final until = block.blockedUntil.toLocal();
      final isActive = !from.isAfter(now) && !now.isAfter(until);
      if (!isActive) continue;
      if (current == null || until.isAfter(current.blockedUntil.toLocal())) {
        current = block;
      }
    }
    return current;
  }

  /// Próximo bloqueo futuro (el más cercano), si existe.
  CommonAreaBlockModel? get upcomingBlock {
    final now = DateTime.now();
    CommonAreaBlockModel? next;
    for (final block in blocks) {
      if (!block.blockedFrom.toLocal().isAfter(now)) continue;
      if (next == null ||
          block.blockedFrom.isBefore(next.blockedFrom)) {
        next = block;
      }
    }
    return next;
  }
}

class CommunityAreasController extends ChangeNotifier {
  CommunityAreasController(this._repository);

  final CommunityDataSource _repository;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  bool loading = false;
  String? error;
  List<AreaAvailability> entries = const [];

  Future<void> refresh() async {
    if (_disposed || loading) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final areas = await _repository.listAreas();
      final availability = await Future.wait(areas.map(_loadDetails));
      if (_disposed) return;
      entries = availability;
    } on Object catch (failure) {
      if (_disposed) return;
      error = _message(
        failure,
        'No pudimos cargar las áreas comunes.',
      );
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Carga horarios y bloqueos de un área sin tumbar el listado completo:
  /// si falla, el área se muestra con un aviso en lugar de desaparecer.
  Future<AreaAvailability> _loadDetails(CommonAreaModel area) async {
    List<CommonAreaScheduleModel> schedules = const [];
    List<CommonAreaBlockModel> blocks = const [];
    var unavailable = false;
    try {
      schedules = await _repository.listSchedules(area.id);
    } on Object {
      unavailable = true;
    }
    try {
      blocks = await _repository.listBlocks(area.id);
    } on Object {
      unavailable = true;
    }
    return AreaAvailability(
      area: area,
      schedules: schedules,
      blocks: blocks,
      detailsUnavailable: unavailable,
    );
  }

  String _message(Object failure, String fallback) =>
      failure is ApiFailure ? failure.displayMessage : fallback;
}
