import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taji/core/network/api_client.dart';
import 'package:taji/paquetes/paquete6_reportes_analitica/cu31_reportes/report_repository.dart';

class _Api extends Fake implements ApiClient {
  @override
  final dio = Dio(BaseOptions(baseUrl: 'https://taji.test/api/v1'));
}

class _Adapter implements HttpClientAdapter {
  String response = '{"text":"Incidencias pendientes"}';
  int status = 200;
  RequestOptions? request;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      response,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'Audio usa endpoint real, multipart y timeout independiente del resto',
    () async {
      final api = _Api(), adapter = _Adapter();
      api.dio.httpClientAdapter = adapter;
      addTearDown(api.dio.close);
      final text = await ReportsRepository(api).transcribe(Uint8List(8044));
      expect(text, 'Incidencias pendientes');
      expect(adapter.request!.path, '/cu31/transcribe/');
      expect(adapter.request!.receiveTimeout, const Duration(seconds: 45));
      expect(api.dio.options.receiveTimeout, isNull);
      final file = (adapter.request!.data as FormData).files.single;
      expect(file.key, 'audio_file');
      expect(file.value.filename, 'consulta.wav');
    },
  );
  test('503 produce un mensaje útil, no detalles técnicos de Dio', () async {
    final api = _Api(),
        adapter = _Adapter()
          ..status = 503
          ..response =
              '{"error":{"message":"Transcripción temporalmente no disponible"}}';
    api.dio.httpClientAdapter = adapter;
    addTearDown(api.dio.close);
    await expectLater(
      ReportsRepository(api).transcribe(Uint8List(8044)),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'mensaje',
          contains('temporalmente no disponible'),
        ),
      ),
    );
  });
}
