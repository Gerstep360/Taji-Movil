import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

abstract class ReportVoice {
  Future<void> listen(
    void Function(String) onText,
    void Function() onEnd,
    void Function(String) onError,
  );
  Future<void> speak(String text);
  Future<void> stop();
  Future<void> stopSpeaking();
}

class NativeReportVoice implements ReportVoice {
  SpeechToText? _speech;
  FlutterTts? _tts;
  int _listenGeneration = 0;
  int _speakGeneration = 0;
  @override
  Future<void> listen(
    void Function(String) onText,
    void Function() onEnd,
    void Function(String) onError,
  ) async {
    final generation = ++_listenGeneration;
    final speech = _speech ??= SpeechToText();
    final available = await speech.initialize(
      onStatus: (status) {
        if (generation == _listenGeneration && status != 'listening') onEnd();
      },
      onError: (_) {
        if (generation != _listenGeneration) return;
        onEnd();
        onError(
          'No pudimos usar el micrófono. Revisa los permisos o escribe la consulta.',
        );
      },
    );
    if (generation != _listenGeneration) return;
    if (!available) {
      throw StateError(
        'Dictado no disponible. Revisa el permiso del micrófono o escribe la consulta.',
      );
    }
    final locales = await speech.locales();
    if (generation != _listenGeneration) return;
    final spanish = locales
        .where((locale) => locale.localeId.toLowerCase().startsWith('es'))
        .toList();
    if (spanish.isEmpty) {
      throw StateError(
        'Instala el reconocimiento de voz en español o escribe la consulta.',
      );
    }
    await speech.listen(
      localeId: spanish.first.localeId,
      onResult: (result) {
        if (generation != _listenGeneration) return;
        onText(
          result.recognizedWords.length > 500
              ? result.recognizedWords.substring(0, 500)
              : result.recognizedWords,
        );
      },
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
      ),
    );
  }

  @override
  Future<void> speak(String text) async {
    final generation = ++_speakGeneration;
    final tts = _tts ??= FlutterTts();
    await tts.setLanguage('es-ES');
    if (generation != _speakGeneration) return;
    await tts.setSpeechRate(.5);
    if (generation != _speakGeneration) return;
    await tts.stop();
    if (generation != _speakGeneration) return;
    await tts.speak(text);
  }

  @override
  Future<void> stop() async {
    _listenGeneration++;
    await _speech?.cancel();
  }

  @override
  Future<void> stopSpeaking() async {
    _speakGeneration++;
    await _tts?.stop();
  }
}
