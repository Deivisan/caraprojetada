package com.caraprojetada

import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "caraprojetada/vnc"
    private lateinit var vncIntent: Intent

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            when (call.method) {
                "startVnc" -> {
                    val password = call.argument<String>("password") ?: ""
                    val port = call.argument<String>("port") ?: "5900"
                    val bindInterface = call.argument<Boolean>("bindInterface") ?: false
                    try {
                        startVncService(password, port, bindInterface)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("VncEngine", "erro ao iniciar VNC", e)
                        result.error("VNC_ERROR", e.message, null)
                    }
                }
                "stopVnc" -> {
                    stopVncService()
                    result.success(null)
                }
                "isRunning" -> {
                    val running = isVncRunning()
                    result.success(running)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startVncService(password: String, port: String, bindInterface: Boolean) {
        // intent para o droidVNC-NG — ajustar package para o apk real
        val intent = Intent()
        intent.setClassName(
            "net.christianbeier.droidvnc_ng",
            "net.christianbeier.droidvnc_ng.MainActivity"
        )
        intent.action = "net.christianbeier.droidvnc_ng.START_VNC"
        intent.putExtra("password", password)
        intent.putExtra("port", port.toIntOrNull() ?: 5900)
        intent.putExtra("bindInterface", bindInterface)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
        Log.i("VncEngine", "droidVNC-NG iniciado na porta $port")
    }

    private fun stopVncService() {
        val intent = Intent()
        intent.setClassName(
            "net.christianbeier.droidvnc_ng",
            "net.christianbeier.droidvnc_ng.MainActivity"
        )
        intent.action = "net.christianbeier.droidvnc_ng.STOP_VNC"
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
        Log.i("VncEngine", "droidVNC-NG parado")
    }

    private fun isVncRunning(): Boolean {
        val pm = getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
        return pm.getRunningServices(100).any { it.service.className.contains("vnc", true) }
    }
}
