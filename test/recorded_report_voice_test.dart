import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:taji/paquetes/paquete6_reportes_analitica/cu31_reportes/recorded_report_voice.dart';

class _Recorder extends Fake implements AudioRecorder {
  final stream = StreamController<Uint8List>();
  final ready = Completer<void>();
  bool permission = true, disposed = false;
  @override
  Future<bool> hasPermission({bool request = true}) async => permission;
  @override
  Future<Stream<Uint8List>> startStream(RecordConfig config) async {
    expect(config.encoder, AudioEncoder.pcm16bits);
    expect(config.sampleRate, 16000);
    expect(config.numChannels, 1);
    ready.complete();
    return stream.stream;
  }

  @override
  Future<String?> stop() async => null;
  @override
  Future<void> dispose() async {
    disposed = true;
    unawaited(stream.close());
  }
}

void main() {
  test('WAV válido PCM16 mono sin archivos ni modelos locales', () {
    final pcm = Uint8List(8000), wav = reportWav(Uint8List(8000));
    final header = ByteData.sublistView(wav);
    expect(String.fromCharCodes(wav.take(4)), 'RIFF');
    expect(header.getUint32(24, Endian.little), 16000);
    expect(header.getUint16(22, Endian.little), 1);
    expect(header.getUint16(34, Endian.little), 16);
    expect(header.getUint32(40, Endian.little), pcm.length);
  });
  for (final cancel in [false, true]) {
    test(
      cancel
          ? 'Cancelar no transcribe ni consulta'
          : 'Terminar transcribe una vez y entrega texto antes del fin',
      () async {
        final recorder = _Recorder(), events = <String>[];
        var requests = 0;
        final voice = RecordedReportVoice(
          recorderFactory: () => recorder,
          transcribe: (wav) async {
            requests++;
            expect(wav.length, 8044);
            return 'Incidencias pendientes';
          },
        );
        final active = voice.listen(
          events.add,
          () => events.add('fin'),
          (e) => fail(e),
        );
        await recorder.ready.future;
        recorder.stream.add(Uint8List(8000));
        await Future<void>.delayed(Duration.zero);
        if (cancel) {
          await voice.stop();
        } else {
          await voice.finishRecording();
          await voice.finishRecording();
        }
        await active;
        expect(requests, cancel ? 0 : 1);
        expect(events, cancel ? isEmpty : ['Incidencias pendientes', 'fin']);
        expect(recorder.disposed, isTrue);
      },
    );
  }
  test('Permiso denegado explica el problema sin culpar a Google', () async {
    final recorder = _Recorder()..permission = false;
    final errors = <String>[];
    await RecordedReportVoice(
      recorderFactory: () => recorder,
      transcribe: (_) async => throw StateError('No debe enviarse'),
    ).listen((_) => fail('No hay texto'), () {}, errors.add);
    expect(errors.single, contains('Permite el micrófono'));
    expect(recorder.disposed, isTrue);
  });
  test('Fallo del servidor no inventa texto y libera el micrófono', () async {
    final recorder = _Recorder(), errors = <String>[];
    final voice = RecordedReportVoice(
      recorderFactory: () => recorder,
      transcribe: (_) async => throw StateError('Sin conexión'),
    );
    final active = voice.listen((_) => fail('No inventar'), () {}, errors.add);
    await recorder.ready.future;
    recorder.stream.add(Uint8List(8000));
    await Future<void>.delayed(Duration.zero);
    await voice.finishRecording();
    await active;
    expect(errors.single, contains('Sin conexión'));
    expect(recorder.disposed, isTrue);
  });
}
