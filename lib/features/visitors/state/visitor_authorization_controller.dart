import 'package:flutter/foundation.dart';

import '../../../core/network/api_failure.dart';
import '../data/visitor_authorization_repository.dart';
import '../models/visitor_authorization.dart';

class VisitorAuthorizationController extends ChangeNotifier {
  VisitorAuthorizationController(this._repository);

  final VisitorAuthorizationDataSource _repository;
  final List<VisitorAuthorization> _authorizations = [];
  final List<ResidentUnit> _units = [];
  final List<ActiveResident> _residents = [];
  bool loading = false;
  bool loadingUnits = false;
  bool loadingResidents = false;
  bool saving = false;
  int? cancellingId;
  String? error;

  List<VisitorAuthorization> get authorizations =>
      List.unmodifiable(_authorizations);
  bool get hasAuthorizations => _authorizations.isNotEmpty;
  List<ResidentUnit> get units => List.unmodifiable(_units);
  List<ActiveResident> get residents => List.unmodifiable(_residents);

  Future<void> loadResidents() async {
    loadingResidents = true;
    error = null;
    notifyListeners();
    try {
      final items = await _repository.listActiveResidents();
      _residents
        ..clear()
        ..addAll(items);
    } on ApiFailure catch (failure) {
      error = failure.displayMessage;
    } finally {
      loadingResidents = false;
      notifyListeners();
    }
  }

  Future<void> loadUnits({bool showError = true}) async {
    loadingUnits = true;
    if (showError) {
      error = null;
    }
    notifyListeners();
    try {
      final items = await _repository.listActiveUnits();
      _units
        ..clear()
        ..addAll(items);
    } on ApiFailure catch (failure) {
      if (showError) {
        error = failure.displayMessage;
      }
    } finally {
      loadingUnits = false;
      notifyListeners();
    }
  }

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final items = await _repository.list();
      _authorizations
        ..clear()
        ..addAll(items);
    } on ApiFailure catch (failure) {
      error = failure.displayMessage;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> add(VisitorAuthorizationInput input) async {
    _validate(input);
    saving = true;
    error = null;
    notifyListeners();
    try {
      final created = await _repository.create(input);
      _authorizations.insert(0, created);
      return true;
    } on ApiFailure catch (failure) {
      error = failure.displayMessage;
      return false;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<bool> cancel(int id) async {
    cancellingId = id;
    error = null;
    notifyListeners();
    try {
      final cancelled = await _repository.cancel(id);
      final index = _authorizations.indexWhere((item) => item.id == id);
      if (index >= 0) _authorizations[index] = cancelled;
      return true;
    } on ApiFailure catch (failure) {
      error = failure.displayMessage;
      return false;
    } finally {
      cancellingId = null;
      notifyListeners();
    }
  }

  void _validate(VisitorAuthorizationInput input) {
    if (input.visitorFirstName.trim().isEmpty ||
        input.visitorLastName.trim().isEmpty) {
      throw ArgumentError('Ingresa el nombre y apellido del visitante.');
    }
    if (input.unitId <= 0) throw ArgumentError('Selecciona una unidad.');
    if (input.reason.trim().isEmpty) {
      throw ArgumentError('Ingresa el motivo de la visita.');
    }
    if (!input.validUntil.isAfter(input.validFrom)) {
      throw ArgumentError(
        'La fecha final debe ser posterior a la fecha inicial.',
      );
    }
  }
}
