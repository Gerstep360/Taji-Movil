import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taji/core/network/api_client.dart';
import 'package:taji/core/theme/taji_theme.dart';
import 'package:taji/paquetes/paquete6_reportes_analitica/cu31_reportes/report_models.dart';
import 'package:taji/paquetes/paquete6_reportes_analitica/cu31_reportes/report_repository.dart';
import 'package:taji/paquetes/paquete6_reportes_analitica/cu31_reportes/report_voice.dart';
import 'package:taji/paquetes/paquete6_reportes_analitica/cu31_reportes/reports_screen.dart';

final testColumns = [
  {
    'key': 'public_code',
    'label': 'Código',
    'type': 'text',
    'operators': ['eq', 'contains'],
    'choices': [],
  },
  {
    'key': 'status',
    'label': 'Estado',
    'type': 'choice',
    'operators': ['eq'],
    'choices': [
      {'value': 'REPORTED', 'label': 'Reportada'},
    ],
  },
];
Map<String, dynamic> catalogData() => {
  'condominium': {'id': 1, 'name': 'Condominio Taji'},
  'export_limit': 10000,
  'formats': ['xlsx', 'csv', 'html'],
  'voice_enabled': true,
  'voice_suggestions': ['Incidencias pendientes'],
  'sources': [
    {
      'key': 'incidents',
      'label': 'Incidencias',
      'description': 'Consulta estados y fechas del condominio.',
      'columns': testColumns,
      'default_columns': ['public_code', 'status'],
      'default_ordering': [
        {'field': 'public_code', 'direction': 'asc'},
      ],
    },
  ],
};
Map<String, dynamic> queryData() => {
  'source': 'incidents',
  'title': 'Incidencias pendientes',
  'columns': ['public_code', 'status'],
  'filters': [
    {'field': 'status', 'operator': 'eq', 'value': 'REPORTED'},
  ],
  'ordering': [
    {'field': 'status', 'direction': 'desc'},
  ],
  'page': 1,
  'page_size': 25,
};
Map<String, dynamic> previewData([int page = 1, int total = 26]) => {
  'source': 'incidents',
  'title': 'Incidencias pendientes',
  'columns': testColumns,
  'rows': [
    ['INC-$page', 'Reportada'],
  ],
  'pagination': {
    'page': page,
    'page_size': 25,
    'total': total,
    'pages': (total / 25).ceil().clamp(1, 9999),
  },
  'can_export': total <= 10000,
};

class ReportsTestApi extends Fake implements ApiClient {
  String? path;
  Object? body;
  Object? response;
  @override
  Future<T?> get<T>(String path, {Map<String, dynamic>? query}) async {
    this.path = path;
    return response as T?;
  }

  @override
  Future<T?> post<T>(String path, {Object? data}) async {
    this.path = path;
    body = data;
    return response as T?;
  }

  @override
  Future<Uint8List> postBytes(String path, {Object? data}) async {
    this.path = path;
    body = data;
    return response as Uint8List;
  }
}

class FakeVoice implements ReportVoice {
  String? spoken;
  bool stopped = false;
  @override
  Future<void> listen(
    void Function(String) onText,
    void Function() onEnd,
    void Function(String) onError,
  ) async {
    onText('Incidencias pendientes');
    onEnd();
  }

  @override
  Future<void> speak(String text) async => spoken = text;
  @override
  Future<void> stop() async {
    stopped = true;
  }

  @override
  Future<void> stopSpeaking() async {}
}

class FakeReports extends ReportsRepository {
  FakeReports() : super(ReportsTestApi());
  ReportQuery? lastQuery;
  int voiceCalls = 0, total = 26;
  bool fail = false;
  @override
  Future<ReportCatalog> catalog() async =>
      ReportCatalog.fromJson(catalogData());
  @override
  Future<ReportPreview> preview(ReportQuery query) async {
    lastQuery = query;
    if (fail) throw StateError('Servicio temporalmente no disponible.');
    return ReportPreview.fromJson(previewData(query.page, total));
  }

  @override
  Future<Map<String, dynamic>> voice(String text) async {
    voiceCalls++;
    return {
      'report_request': queryData(),
      'report_preview': previewData(),
      'spoken_summary': 'Hay 26 incidencias pendientes.',
      'understood_intent': {'detected_format': 'csv'},
    };
  }

  @override
  Future<String> narrate(ReportPreview preview) async =>
      'Hay ${preview.total} incidencias pendientes.';
}

void main() {
  test(
    'CU31 consulta y exportación usan cliente central y el mismo contrato',
    () async {
      final api = ReportsTestApi()..response = catalogData();
      final repo = ReportsRepository(api);
      expect((await repo.catalog()).sources.single.key, 'incidents');
      expect(api.path, '/cu31/catalog/');
      final query = ReportQuery.fromJson(queryData());
      api.response = previewData();
      await repo.preview(query.atPage(2));
      expect(api.path, '/cu31/preview/');
      expect((api.body as Map)['page'], 2);
      expect((api.body as Map)['ordering'], queryData()['ordering']);
      api.response = Uint8List.fromList([1, 2, 3]);
      expect(await repo.export(query, 'csv'), [1, 2, 3]);
      expect(api.path, '/cu31/export/');
      expect((api.body as Map)['filters'], queryData()['filters']);
      api.response = Uint8List(0);
      await expectLater(repo.export(query, 'xlsx'), throwsStateError);
    },
  );
  test('CU31 no inventa valores y no muta filtros al cambiar de página', () {
    final query = ReportQuery.fromJson(queryData());
    final next = query.atPage(2);
    next.filters.first.value = 'RESOLVED';
    expect(query.filters.first.value, 'REPORTED');
    expect(ReportFilter('title', 'is_empty', 'ignorar').toJson()['value'], '');
    final data = previewData()
      ..['rows'] = [
        [null, 0],
      ];
    expect(ReportPreview.fromJson(data).rows.single, ['', '0']);
  });
  testWidgets(
    'CU31 móvil: dictado revisable, paginación, lectura, errores y límites',
    (tester) async {
      final fontPath = Platform.environment['TAJI_PREVIEW_FONT'];
      if (fontPath != null) {
        await tester.runAsync(() async {
          final loader = FontLoader('Segoe UI')
            ..addFont(File(fontPath).readAsBytes().then(ByteData.sublistView));
          await loader.load();
          final icons = FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
          await icons.load();
        });
      }
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = FakeReports(), voice = FakeVoice(), boundary = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTajiTheme(),
          home: RepaintBoundary(
            key: boundary,
            child: Scaffold(
              appBar: AppBar(title: const Text('Reportes y consultas')),
              body: ReportsWorkspace(repository: repo, voice: voice),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Dictar'));
      await tester.pumpAndSettle();
      expect(
        repo.voiceCalls,
        0,
        reason: 'Dictar no debe enviar la consulta automáticamente',
      );
      await tester.tap(find.text('Consultar'));
      await tester.pumpAndSettle();
      expect(repo.voiceCalls, 1);
      if (fontPath != null) {
        await savePreview(
          tester,
          boundary,
          'docs/screenshots/CU31-flutter-query.png',
        );
      }
      await tester.ensureVisible(find.text('Siguiente'));
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      expect(repo.lastQuery?.page, 2);
      expect(repo.lastQuery?.toJson()['filters'], queryData()['filters']);
      expect(repo.lastQuery?.toJson()['ordering'], queryData()['ordering']);
      await tester.ensureVisible(find.text('Escuchar resumen'));
      await tester.tap(find.text('Escuchar resumen'));
      await tester.pumpAndSettle();
      expect(voice.spoken, 'Hay 26 incidencias pendientes.');
      await tester.ensureVisible(find.text('INC-2'));
      await tester.tap(find.text('INC-2'));
      await tester.pumpAndSettle();
      if (fontPath != null) {
        await savePreview(
          tester,
          boundary,
          'docs/screenshots/CU31-flutter-results.png',
        );
      }
      repo.fail = true;
      await tester.ensureVisible(find.text('Anterior'));
      await tester.tap(find.text('Anterior'));
      await tester.pumpAndSettle();
      expect(
        find.text('Servicio temporalmente no disponible.'),
        findsOneWidget,
      );
      repo.fail = false;
      repo.total = 10001;
      await tester.ensureVisible(find.text('Anterior'));
      await tester.tap(find.text('Anterior'));
      await tester.pumpAndSettle();
      final button = tester.widget<FilledButton>(
        find
            .ancestor(
              of: find.text('Compartir reporte'),
              matching: find.byWidgetPredicate(
                (widget) => widget is FilledButton,
              ),
            )
            .first,
      );
      expect(button.onPressed, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(voice.stopped, isTrue);
    },
  );
}

Future<void> savePreview(
  WidgetTester tester,
  GlobalKey key,
  String path,
) async {
  await tester.pumpAndSettle();
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
