import 'package:flutter/foundation.dart';

import '../../../core/network/api_failure.dart';
import '../data/assemblies_repository.dart';
import '../models/assembly_models.dart';

class AssembliesController extends ChangeNotifier {
  AssembliesController(this.repository);
  final AssembliesRepository repository;

  List<AssemblyItem> items = [];
  String status = '';
  String? error;
  bool loading = false;
  int page = 1;
  int pages = 1;
  bool _disposed = false;
  int _request = 0;

  /// Los residentes solo ven asambleas programadas; no tiene sentido filtrar.
  bool get canFilter => items.isEmpty || items.any((item) => item.hasFullAccess);

  Future<void> load({String? selectedStatus, int? selectedPage}) async {
    final request = ++_request;
    if (selectedStatus != null) {
      status = selectedStatus;
      items = [];
    }
    final target = selectedPage ?? (selectedStatus != null ? 1 : page);
    loading = true;
    error = null;
    notifyListeners();
    try {
      final response = await repository.list(page: target, status: status);
      if (_disposed || request != _request) return;
      items = response.items;
      pages = response.pages;
      page = target;
    } on ApiFailure catch (failure) {
      if (_disposed || request != _request) return;
      items = [];
      error = failure.displayMessage;
    } catch (_) {
      if (_disposed || request != _request) return;
      items = [];
      error = 'No pudimos consultar las asambleas.';
    } finally {
      if (!_disposed && request == _request) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class AssemblyDetailController extends ChangeNotifier {
  AssemblyDetailController(this.repository, this.assembly);
  final AssembliesRepository repository;
  final AssemblyItem assembly;

  List<AgreementItem> agreements = [];
  String? error;
  bool loading = false;
  bool _disposed = false;

  Future<void> load() async {
    if (!assembly.hasFullAccess) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final rows = await repository.agreements(assembly.id);
      if (_disposed) return;
      agreements = rows;
    } on ApiFailure catch (failure) {
      if (_disposed) return;
      agreements = [];
      error = failure.displayMessage;
    } catch (_) {
      if (_disposed) return;
      agreements = [];
      error = 'No pudimos consultar los acuerdos.';
    } finally {
      if (!_disposed) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
