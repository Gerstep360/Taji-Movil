import 'package:flutter_test/flutter_test.dart';
import 'package:taji/core/network/api_client.dart';
import 'package:taji/features/incidents/incident_tracking.dart';

class TrackingApi extends Fake implements ApiClient {
  Object? response;
  String? path;
  Map<String, dynamic>? parameters;
  @override
  Future<T?> get<T>(String path, {Map<String, dynamic>? query}) async {
    this.path = path;
    parameters = query;
    return response as T?;
  }
}

void main() {
  test(
    'seguimiento interpreta responsable ausente y cronología sin fechas inventadas',
    () {
      final incident = TrackedIncident.fromJson({
        'public_code': 'INC-1-000021',
        'status_display': 'Reportada',
        'status_history': [
          {
            'to_status_display': 'Reportada',
            'changed_at': '2026-11-01T12:00:00Z',
            'comment': 'Registro',
          },
        ],
      });
      expect(incident.assignee, 'Por asignar');
      expect(incident.due, isNull);
      expect(incident.history.single.label, 'Reportada');
      expect(incident.history.single.at?.isUtc, isTrue);
    },
  );

  test('repositorio pagina y filtra contra el contrato CU21', () async {
    final api = TrackingApi()
      ..response = {
        'results': [],
        'pagination': {'total_pages': 3},
      };
    final response = await IncidentTrackingRepository(api).list('overdue', 2);
    expect(api.path, '/paquete3/incidents/');
    expect(api.parameters, {'page': 2, 'sla_status': 'overdue'});
    expect(response.pages, 3);
  });

  test(
    'una respuesta vacía produce error recuperable en lugar de ocultar datos',
    () async {
      final repository = IncidentTrackingRepository(TrackingApi());
      await expectLater(repository.list('', 1), throwsStateError);
      await expectLater(repository.detail('INC-1-000021'), throwsStateError);
    },
  );
}
