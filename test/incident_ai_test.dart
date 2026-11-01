import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:taji/core/network/api_client.dart';
import 'package:taji/core/network/api_endpoints.dart';
import 'package:taji/features/incidents/incident_ai.dart';
import 'package:taji/features/incidents/incident_ai_panel.dart';

Map<String, dynamic> result(String status) => {
  'execution_status': status,
  'review': null,
  'category': {'name': 'Incendios y humo'},
  'priority': {'name': 'Alta'},
  'confidence': '0.9',
  'risk_score': '70',
  'summary': 'Los niños están lejos del incendio.',
  'risks': [
    {'name': 'Incendio', 'evidence': 'incendio', 'context': 'present'},
  ],
  'recommendations': ['Mantén distancia y avisa al equipo.'],
};

class AIClient extends Fake implements ApiClient {
  String status = 'SUCCEEDED';
  @override
  Future<T?> get<T>(String path, {Map<String, dynamic>? query}) async =>
      {
            'analyses': [result(status)],
          }
          as T;
}

Widget panel(ApiClient client) => Provider<ApiClient>.value(
  value: client,
  child: const MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(child: IncidentAIPanel(code: 'INC-1-22')),
    ),
  ),
);

void main() {
  test('interpreta decimales y conserva contexto de riesgos', () {
    final value = IncidentAIResult.fromJson(result('SUCCEEDED'));
    expect(value.confidence, .9);
    expect(value.score, 70);
    expect(value.reviewed, false);
    expect(value.risks.single.context, 'present');
    expect(value.pending, false);
    expect(
      ApiEndpoints.incidentAIFor('INC-1-22'),
      '/paquete3/incidents/INC-1-22/ai/',
    );
  });
  test('un fallo no inventa categoría ni prioridad', () {
    final value = IncidentAIResult.fromJson({'execution_status': 'FAILED'});
    expect(value.category, isNull);
    expect(value.priority, isNull);
    expect(value.risks, isEmpty);
  });
  testWidgets(
    'muestra categoría, prioridad y recomendaciones en ancho teléfono',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(panel(AIClient()));
      await tester.pumpAndSettle();
      expect(find.text('Incendios y humo'), findsOneWidget);
      expect(find.text('Prioridad: Alta'), findsOneWidget);
      expect(find.textContaining('Mantén distancia'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('NVIDIA fallido permite continuar con revisión manual', (
    tester,
  ) async {
    final client = AIClient()..status = 'FAILED';
    await tester.pumpWidget(panel(client));
    await tester.pumpAndSettle();
    expect(find.textContaining('revisión manual'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
