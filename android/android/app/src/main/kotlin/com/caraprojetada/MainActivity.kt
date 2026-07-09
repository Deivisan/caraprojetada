package com.caraprojetada

import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.annotation.NonNull
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import net.christianbeier.droidvnc_ng.MainService

class MainActivity : FlutterActivity() {
    private val channel = "caraprojetada/vnc"
    private var vncRunning = false

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            when (call.method) {
                "startVnc" -> {
                    val password = call.argument<String>("password") ?: "caraprojetada"
                    val port = call.argument<String>("port") ?: "5900"
                    val bindInterface = call.argument<Boolean>("bindInterface") ?: false
                    try {
                        startVncService(password, port, bindInterface)
                        vncRunning = true
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("VncEngine", "erro ao iniciar VNC", e)
                        result.error("VNC_ERROR", e.message, null)
                    }
                }
                "stopVnc" -> {
                    stopVncService()
                    vncRunning = false
                    result.success(null)
                }
                "isRunning" -> {
                    result.success(vncRunning)
                }
                else -> result.notImplemented()
            }
        }
    }

    // Inicia o backend VNC do droidVNC-NG (embutido neste APK) via MainService.
    // O próprio MainService solicita as permissões de captura (MediaProjection)
    // e sobe o servidor VNC na porta informada.
    private fun startVncService(password: String, port: String, bindInterface: Boolean) {
        val intent = Intent(this, MainService::class.java)
        intent.action = "net.christianbeier.droidvnc_ng.ACTION_START"
        intent.putExtra("net.christianbeier.droidvnc_ng.EXTRA_PASSWORD", password)
        intent.putExtra("net.christianbeier.droidvnc_ng.EXTRA_PORT", port.toIntOrNull() ?: 5900)
        intent.putExtra("net.christianbeier.droidvnc_ng.EXTRA_INTERFACE", if (bindInterface) "0.0.0.0" else "")
        ContextCompat.startForegroundService(this, intent)
        Log.i("VncEngine", "droidVNC-NG (embutido) iniciado na porta $port")
    }

    private fun stopVncService() {
        val intent = Intent(this, MainService::class.java)
        intent.action = "net.christianbeier.droidvnc_ng.ACTION_STOP"
        ContextCompat.startForegroundService(this, intent)
        Log.i("VncEngine", "droidVNC-NG (embutido) parado")
    }
}
