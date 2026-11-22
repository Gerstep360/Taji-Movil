import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:taji/core/network/api_client.dart';
import 'package:taji/features/incidents/incident_report.dart';
import 'package:taji/features/incidents/incident_report_screen.dart';
import 'package:taji/features/auth/models/taji_user.dart';

Map<String, dynamic> optionsJson() => {
  'categories': [
    {'id': 1, 'code': 'PLUMBING', 'name': 'Plomería'},
  ],
  'sectors': [
    {'id': 1, 'code': 'A', 'name': 'Torre A', 'parent': null},
    {'id': 2, 'code': 'P1', 'name': 'Piso 1', 'parent': 1},
    {'id': 3, 'code': 'B', 'name': 'Torre B', 'parent': null},
  ],
  'units': [
    {'id': 1, 'code': 'A-101', 'sector': 2},
    {'id': 2, 'code': 'B-201', 'sector': 3},
  ],
  'assets': [],
  'evidence_rules': {
    'max_files': 2,
    'max_file_size_bytes': 1024,
    'allowed_extensions': ['jpg', 'png'],
  },
};

class NoNetwork extends Fake implements ApiClient {}

class Repository extends IncidentReportRepository {
  Repository() : super(NoNetwork());
  int calls = 0;
  Map<String, dynamic>? fields;
  Completer<String>? pending;
  bool fail = false;
  @override
  Future<IncidentReportOptions> options() async =>
      IncidentReportOptions.fromJson(optionsJson());
  @override
  Future<String> create(Map<String, dynamic> fields, List<XFile> files) async {
    calls++;
    this.fields = fields;
    if (fail) {
      throw DioException(requestOptions: RequestOptions(path: '/incidents/'));
    }
    return pending != null ? pending!.future : 'INC-1-000018';
  }
}

void complete(IncidentReportController controller) {
  controller.description = 'Agua en el techo del pasillo.';
  controller.category = 1;
  controller.sector = 1;
}

void main() {
  test(
    'filtra unidades descendientes y limpia referencias al cambiar ubicación',
    () async {
      final controller = IncidentReportController(Repository());
      addTearDown(controller.dispose);
      await controller.load();
      controller.selectSector(1);
      expect(controller.units.map((u) => u.code), ['A-101']);
      controller.unit = 1;
      controller.asset = 9;
      controller.selectSector(3);
      expect(controller.unit, isNull);
      expect(controller.asset, isNull);
      expect(controller.units.single.code, 'B-201');
    },
  );
  test(
    'valida campos y evita duplicados mientras envía y después de confirmar',
    () async {
      final repository = Repository()..pending = Completer<String>();
      final controller = IncidentReportController(repository);
      addTearDown(controller.dispose);
      await controller.submit();
      expect(repository.calls, 0);
      complete(controller);
      final sending = controller.submit();
      await controller.submit();
      expect(repository.calls, 1);
      repository.pending!.complete('INC-1-000018');
      await sending;
      await controller.submit();
      expect(repository.calls, 1);
      expect(controller.code, 'INC-1-000018');
      expect(repository.fields!.containsKey('priority'), false);
      expect(repository.fields!.containsKey('reporter'), false);
    },
  );
  test('conserva datos cuando no hay conexión', () async {
    final controller = IncidentReportController(Repository()..fail = true);
    addTearDown(controller.dispose);
    complete(controller);
    await controller.submit();
    expect(controller.code, isNull);
    expect(controller.description, 'Agua en el techo del pasillo.');
    expect(controller.error, isNotNull);
  });
  test(
    'rechaza fotos grandes, extensiones inválidas y exceso de archivos',
    () async {
      final controller = IncidentReportController(Repository());
      addTearDown(controller.dispose);
      await controller.load();
      await controller.addPhotos([
        XFile.fromData(Uint8List(4), path: 'malware.exe'),
      ]);
      expect(controller.files, isEmpty);
      await controller.addPhotos([
        XFile.fromData(Uint8List(1025), path: 'grande.png'),
      ]);
      expect(controller.files, isEmpty);
      await controller.addPhotos([
        XFile.fromData(Uint8List(4), path: 'uno.png'),
        XFile.fromData(Uint8List(4), path: 'dos.png'),
      ]);
      expect(controller.files.length, 2);
      await controller.addPhotos([
        XFile.fromData(Uint8List(4), path: 'tres.png'),
      ]);
      expect(controller.files.length, 2);
    },
  );
  test('lee el superusuario real y permisos para habilitar el registro', () {
    final user = TajiUser.fromJson({'id': 1, 'is_superuser': true});
    expect(user.canReportIncidents, true);
    expect(TajiUser.fromJson(user.toJson()).canReportIncidents, true);
    expect(TajiUser.fromJson({'id': 2}).canReportIncidents, false);
  });
  testWidgets('formulario y confirmación se muestran sin desbordes a 390px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = IncidentReportController(Repository());
    addTearDown(controller.dispose);
    await controller.load();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: const MaterialApp(home: IncidentReportView()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cuéntanos qué pasó'), findsOneWidget);
    expect(tester.takeException(), isNull);
    complete(controller);
    await controller.submit();
    await tester.pumpAndSettle();
    expect(find.text('Reporte recibido'), findsOneWidget);
    expect(find.text('INC-1-000018'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
