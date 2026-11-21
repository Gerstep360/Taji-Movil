package com.taji.taji

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.Activity
import android.content.Intent
import android.speech.RecognizerIntent

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
                                setPackage("com.google.android.googlequicksearchbox")
                                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                                putExtra(RecognizerIntent.EXTRA_LANGUAGE, "es-BO")
                                putExtra(RecognizerIntent.EXTRA_PROMPT, "Describe la consulta de tu reporte")
                                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
                            }
                            if (intent.resolveActivity(packageManager) == null) {
                                result.error("google_unavailable", "Instala o habilita la aplicación Google para usar su dictado. También puedes escribir la consulta.", null)
                            } else {
                                voiceResult = result
                                try {
                                    startActivityForResult(intent, voiceRequest)
                                } catch (error: Exception) {
                                    voiceResult = null
                                    result.error("google_failed", "No se pudo abrir Google. Revisa que esté actualizado y habilitado.", null)
                                }
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
        val text = if (resultCode == Activity.RESULT_OK)
            data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)?.firstOrNull()
        else null
        pending.success(text)
    }

    override fun onDestroy() {
        voiceResult?.success(null)
        voiceResult = null
        super.onDestroy()
    }
}
