import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
  NativeReportVoice({SpeechToText? speech}) : _speech = speech;
  SpeechToText? _speech;
  FlutterTts? _tts;
  int _listenGeneration = 0;
  int _speakGeneration = 0;
  static const _googleVoice = MethodChannel('taji/reports_voice');
  @override
  Future<void> listen(
    void Function(String) onText,
    void Function() onEnd,
    void Function(String) onError,
  ) async {
    final generation = ++_listenGeneration;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      var useService = false;
      try {
        final text = await _googleVoice.invokeMethod<String>('listenGoogle');
        if (generation != _listenGeneration) return;
        if (text != null && text.trim().isNotEmpty) {
          onText(text.length > 500 ? text.substring(0, 500) : text);
        } else {
          useService = true;
        }
      } on PlatformException catch (error) {
        useService = [
          'google_unavailable',
          'google_failed',
          'recognizer_empty_result',
        ].contains(error.code);
        if (!useService &&
            error.code != 'cancelled' &&
            generation == _listenGeneration) {
          onError(error.message ?? 'No se pudo abrir el dictado de Google.');
        }
      } on MissingPluginException {
        useService = true;
      } finally {
        if (!useService && generation == _listenGeneration) onEnd();
      }
      if (!useService || generation != _listenGeneration) return;
    }
    final speech = _speech ??= SpeechToText();
    var ended = false;
    void finish() {
      if (ended || generation != _listenGeneration) return;
      ended = true;
      onEnd();
    }

    // initialize conserva los primeros callbacks; actualizar los listeners en cada sesión.
    speech.statusListener = (status) {
      if (generation == _listenGeneration && status == 'done') {
        // Android puede avisar "done" antes del resultado final. No consumirlo:
        // cerrar el indicador, pero permitir entregar y consultar el texto final.
        onEnd();
      }
    };
    speech.errorListener = (error) {
      if (generation != _listenGeneration) return;
      onError(
        'El servicio de voz no pudo transcribir (${error.errorMsg}). Revisa permisos, conexión e idioma español.',
      );
      finish();
    };
    final available = await speech.initialize(
      onStatus: speech.statusListener,
      onError: speech.errorListener,
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
        if (generation != _listenGeneration || !result.finalResult) return;
        onText(
          result.recognizedWords.length > 500
              ? result.recognizedWords.substring(0, 500)
              : result.recognizedWords,
        );
        finish();
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
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _googleVoice.invokeMethod<void>('cancelGoogle');
      } on MissingPluginException {
        // Puede haberse usado directamente RecognitionService.
      }
    }
    await _speech?.cancel();
  }

  @override
  Future<void> stopSpeaking() async {
    _speakGeneration++;
    await _tts?.stop();
  }
}
