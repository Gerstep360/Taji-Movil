import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_to_text.dart';
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
  test(
    'Sin ventana Google usa RecognitionService sin culpar la instalación',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'cancelGoogle') return null;
            throw PlatformException(
              code: 'google_unavailable',
              message: 'Habilita Google.',
            );
          });
      final errors = <String>[];
      final speech = _ServiceSpeech();
      final voice = NativeReportVoice(speech: speech);
      var ended = false;
      await voice.listen(
        (_) => fail('No debe transcribir'),
        () => ended = true,
        errors.add,
      );
      expect(errors, isEmpty);
      expect(speech.listening, isTrue);
      expect(ended, isFalse);
      await voice.stop();
      expect(speech.cancelled, isTrue);
    },
  );
  test(
    'Resultado vacío intenta el servicio y no inventa una transcripción',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => null);
      final speech = _ServiceSpeech();
      final errors = <String>[];
      await NativeReportVoice(
        speech: speech,
      ).listen((_) => fail('No hay texto'), () {}, errors.add);
      expect(speech.listening, isTrue);
      expect(errors, isEmpty);
    },
  );
  test('Cancelar no muestra error ni inicia otro dictado', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          throw PlatformException(code: 'cancelled');
        });
    final speech = _ServiceSpeech();
    var ended = 0;
    await NativeReportVoice(speech: speech).listen(
      (_) => fail('No debe haber texto'),
      () => ended++,
      (error) => fail(error),
    );
    expect(ended, 1);
    expect(speech.listening, isFalse);
  });
}

class _ServiceSpeech extends Fake implements SpeechToText {
  bool listening = false, cancelled = false;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    switch (invocation.memberName) {
      case #initialize:
        return Future<bool>.value(true);
      case #locales:
        return Future<List<LocaleName>>.value([LocaleName('es_ES', 'Español')]);
      case #listen:
        listening = true;
        return Future<void>.value();
      case #cancel:
        cancelled = true;
        return Future<void>.value();
      default:
        return null;
    }
  }
}
