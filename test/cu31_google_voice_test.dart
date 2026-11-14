import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taji/paquetes/paquete6_reportes_analitica/cu31_reportes/report_voice.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('taji/reports_voice');
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  test(
    'Android solicita Google y entrega el texto antes de terminar',
    () async {
      final calls = <String>[], events = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            return call.method == 'listenGoogle'
                ? 'Incidencias pendientes'
                : null;
          });
      final voice = NativeReportVoice();
      await voice.listen(
        events.add,
        () => events.add('fin'),
        (error) => fail(error),
      );
      expect(events, ['Incidencias pendientes', 'fin']);
      await voice.stop();
      expect(calls, ['listenGoogle', 'cancelGoogle']);
    },
  );
  test('Google no disponible informa el motivo sin inventar texto', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(
            code: 'google_unavailable',
            message: 'Habilita Google.',
          );
        });
    final errors = <String>[];
    await NativeReportVoice().listen(
      (_) => fail('No debe transcribir'),
      () {},
      errors.add,
    );
    expect(errors, ['Habilita Google.']);
  });
}
