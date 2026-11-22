import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';
import 'report_voice.dart';

/// Solo captura audio: la transcripción se hace en el Backend, no en Google.
class RecordedReportVoice extends NativeReportVoice {
  RecordedReportVoice({
    required this.transcribe,
    this.onProcessing,
    AudioRecorder Function()? recorderFactory,
  }) : recorderFactory = recorderFactory ?? AudioRecorder.new;
  final Future<String> Function(Uint8List) transcribe;
  final void Function(bool)? onProcessing;
  final AudioRecorder Function() recorderFactory;
  Completer<bool>? _recording;
  int _generation = 0;

  Future<void> finishRecording() async {
    final recording = _recording;
    if (recording != null && !recording.isCompleted) recording.complete(true);
  }

  @override
  Future<void> listen(
    void Function(String) onText,
    void Function() onEnd,
    void Function(String) onError,
  ) async {
    await stop();
    final generation = ++_generation;
    final recording = Completer<bool>();
    _recording = recording;
    final recorder = recorderFactory();
    final bytes = BytesBuilder(copy: false);
    StreamSubscription<Uint8List>? subscription;
    Timer? timer;
    var started = false;
    try {
      if (!await recorder.hasPermission()) {
        throw StateError(
          'Permite el micrófono para dictar. También puedes escribir.',
        );
      }
      if (generation != _generation) return;
      final stream = await recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
          autoGain: true,
          echoCancel: true,
          noiseSuppress: true,
        ),
      );
      started = true;
      final start = DateTime.now();
      DateTime? lastSpeech;
      subscription = stream.listen(
        (chunk) {
          if (generation != _generation || recording.isCompleted) return;
          final remaining = 960000 - bytes.length; // 30 s PCM16 mono; <1 MB.
          final count =
              (chunk.length < remaining ? chunk.length : remaining) & ~1;
          if (count > 0) bytes.add(Uint8List.sublistView(chunk, 0, count));
          final samples = ByteData.sublistView(chunk);
          var amplitude = 0;
          for (var i = 0; i + 1 < chunk.length; i += 2) {
            amplitude += samples.getInt16(i, Endian.little).abs();
          }
          if (chunk.length > 1 && amplitude / (chunk.length ~/ 2) > 450) {
            lastSpeech = DateTime.now();
          }
          if (bytes.length >= 960000) recording.complete(true);
        },
        onError: (Object error) {
          if (!recording.isCompleted) {
            recording.completeError(
              StateError('No se pudo leer el micrófono. Vuelve a intentarlo.'),
            );
          }
        },
        onDone: () {
          if (!recording.isCompleted) recording.complete(true);
        },
      );
      timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (recording.isCompleted) return;
        final now = DateTime.now();
        if (now.difference(start).inSeconds >= 30 ||
            (lastSpeech != null &&
                now.difference(lastSpeech!).inMilliseconds >= 1800)) {
          recording.complete(true);
        }
      });
      final send = await recording.future;
      timer.cancel();
      await recorder.stop();
      started = false;
      await subscription.cancel();
      if (!send || generation != _generation) return;
      if (bytes.length < 8000) {
        throw StateError(
          'La grabación fue muy corta. Habla un poco más y vuelve a intentar.',
        );
      }
      onProcessing?.call(true);
      final text = await transcribe(reportWav(bytes.takeBytes()));
      if (generation != _generation) return;
      onText(text);
      onEnd();
    } catch (error) {
      if (generation == _generation) {
        onError(error.toString().replaceFirst('Bad state: ', ''));
        onEnd();
      }
    } finally {
      timer?.cancel();
      await subscription?.cancel();
      if (started) await recorder.stop();
      await recorder.dispose();
      if (identical(_recording, recording)) {
        _recording = null;
        onProcessing?.call(false);
      }
    }
  }

  @override
  Future<void> stop() async {
    _generation++;
    final recording = _recording;
    if (recording != null && !recording.isCompleted) recording.complete(false);
  }
}

Uint8List reportWav(Uint8List pcm) {
  final wav = Uint8List(44 + pcm.length);
  final header = ByteData.sublistView(wav);
  wav.setAll(0, 'RIFF'.codeUnits);
  header.setUint32(4, 36 + pcm.length, Endian.little);
  wav.setAll(8, 'WAVEfmt '.codeUnits);
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, 1, Endian.little);
  header.setUint32(24, 16000, Endian.little);
  header.setUint32(28, 32000, Endian.little);
  header.setUint16(32, 2, Endian.little);
  header.setUint16(34, 16, Endian.little);
  wav.setAll(36, 'data'.codeUnits);
  header.setUint32(40, pcm.length, Endian.little);
  wav.setAll(44, pcm);
  return wav;
}
