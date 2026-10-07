import 'package:flutter/foundation.dart';
import '../../../core/network/api_failure.dart';
import '../data/visit_consultation_repository.dart';
import '../models/visit_consultation.dart';

class VisitConsultationController extends ChangeNotifier {
  VisitConsultationController(this.repository);
  final VisitConsultationRepository repository;
  List<VisitConsultationItem> items = [];
  String section = 'expected';
  String? error;
  bool loading = false;
  int page = 1;
  int pages = 1;
  bool _disposed = false;
  int _request = 0;

  Future<void> load({String? selectedSection, int? selectedPage}) async {
    final request = ++_request;
    if (selectedSection != null) { section = selectedSection; items = []; }
    final target = selectedPage ?? (selectedSection != null ? 1 : page);
    loading = true; error = null; notifyListeners();
    try {
      final response = await repository.list(section, target);
      if (_disposed || request != _request) return;
      items = response.items; pages = response.pages; page = target;
    } on ApiFailure catch (failure) {
      if (_disposed || request != _request) return;
      items = []; error = failure.displayMessage;
    } catch (_) {
      if (_disposed || request != _request) return;
      items = []; error = 'No pudimos consultar las visitas.';
    } finally {
      if (!_disposed && request == _request) { loading = false; notifyListeners(); }
    }
  }

  @override
  void dispose() { _disposed = true; super.dispose(); }
}
