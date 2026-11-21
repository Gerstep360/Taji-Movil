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
      try {
        final text = await _googleVoice.invokeMethod<String>('listenGoogle');
        if (generation != _listenGeneration) return;
        if (text != null && text.trim().isNotEmpty) {
          onText(text.length > 500 ? text.substring(0, 500) : text);
        } else {
          onError('No se reconocieron palabras. Vuelve a dictar.');
        }
      } on PlatformException catch (error) {
        if (generation == _listenGeneration) {
          onError(error.message ?? 'No se pudo abrir el dictado de Google.');
        }
      } on MissingPluginException {
        if (generation == _listenGeneration) {
          onError(
            'Esta instalación todavía no incluye el dictado de Google. Reinstala la app con la nueva versión; hot reload no actualiza código Android.',
          );
        }
      } finally {
        if (generation == _listenGeneration) onEnd();
      }
      return;
    }
    final speech = _speech ??= SpeechToText();
    // initialize conserva los primeros callbacks; actualizar los listeners en cada sesión.
    speech.statusListener = (status) {
      if (generation == _listenGeneration &&
          (status == 'done' || status == 'notListening')) {
        onEnd();
      }
    };
    speech.errorListener = (error) {
      if (generation != _listenGeneration) return;
      onEnd();
      onError(
        'El servicio de voz no pudo transcribir (${error.errorMsg}). Revisa permisos, conexión e idioma español.',
      );
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
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await _googleVoice.invokeMethod<void>('cancelGoogle');
    }
    await _speech?.cancel();
  }

  @override
  Future<void> stopSpeaking() async {
    _speakGeneration++;
    await _tts?.stop();
  }
}
