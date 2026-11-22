package com.taji.taji

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.Activity
import android.content.Intent
import android.content.ActivityNotFoundException
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import java.util.Locale

class MainActivity : FlutterActivity() {
    private var voiceResult: MethodChannel.Result? = null
    private val voiceRequest = 3107

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "taji/reports_voice")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "listenGoogle" -> {
                        if (voiceResult != null) {
                            result.error("busy", "Ya hay un dictado abierto.", null)
                        } else {
                            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                                val locale = Locale.getDefault()
                                putExtra(RecognizerIntent.EXTRA_LANGUAGE, if (locale.language == "es") locale.toLanguageTag() else "es-ES")
                                putExtra(RecognizerIntent.EXTRA_PROMPT, "Describe la consulta de tu reporte")
                                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
                            }
                            // Google puede ofrecer RecognitionService sin exportar una Activity.
                            // No confundir resolveActivity == null con aplicación no instalada.
                            voiceResult = result
                            var opened = false
                            for (provider in listOf("com.google.android.googlequicksearchbox", null)) {
                                try {
                                    startActivityForResult(Intent(intent).setPackage(provider), voiceRequest)
                                    opened = true
                                    break
                                } catch (_: ActivityNotFoundException) {
                                    // Probar el proveedor configurado por Android.
                                } catch (_: SecurityException) {
                                    // Si no exporta la Activity, probar el servicio nativo en Flutter.
                                }
                            }
                            if (!opened) {
                                voiceResult = null
                                result.error("google_unavailable", "No hay una ventana de dictado disponible; se intentará el servicio de voz del dispositivo.", null)
                            }
                        }
                    }
                    "cancelGoogle" -> {
                        if (voiceResult != null) {
                            finishActivity(voiceRequest)
                            voiceResult?.success(null)
                            voiceResult = null
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != voiceRequest) return
        val pending = voiceResult ?: return
        voiceResult = null
        // Algunos proveedores devuelven la clave de RecognitionService o un array,
        // y no todos mantienen RESULT_OK aunque adjunten una transcripción válida.
        val text = listOf(RecognizerIntent.EXTRA_RESULTS, SpeechRecognizer.RESULTS_RECOGNITION)
            .asSequence().flatMap { key ->
                when (val value = data?.extras?.get(key)) {
                    is List<*> -> value.asSequence()
                    is Array<*> -> value.asSequence()
                    is CharSequence -> sequenceOf(value)
                    else -> emptySequence()
                }
            }.filterIsInstance<CharSequence>().map { it.toString().trim() }
            .firstOrNull { it.isNotEmpty() }
        when {
            text != null -> pending.success(text)
            resultCode == Activity.RESULT_CANCELED -> pending.error("cancelled", "Dictado cancelado.", null)
            else -> pending.error("recognizer_empty_result", "El proveedor no devolvió la transcripción.", null)
        }
    }

    override fun onDestroy() {
        voiceResult?.success(null)
        voiceResult = null
        super.onDestroy()
    }
}
