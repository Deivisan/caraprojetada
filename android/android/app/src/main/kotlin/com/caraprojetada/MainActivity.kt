package com.caraprojetada

import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.annotation.NonNull
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import net.christianbeier.droidvnc_ng.MainService
import java.io.File
import java.io.FileWriter
import java.io.PrintWriter
import java.io.StringWriter
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val channel = "caraprojetada/vnc"
    private var vncRunning = false

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        installCrashHandler()
    }

    // Grava o stack trace de qualquer crash nao tratado em um arquivo legivel,
    // para que possamos diagnosticar o crash ao transmitir sem depender de logcat.
    private fun installCrashHandler() {
        val default = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            try {
                val dir = filesDir
                val ts = SimpleDateFormat("yyyy-MM-dd_HHmmss", Locale.US).format(Date())
                val file = File(dir, "crash_$ts.log")
                FileWriter(file).use { fw ->
                    fw.write("=== CaraProjetada crash @ $ts ===\n")
                    fw.write("thread=${thread.name}\n")
                    fw.write("android=${Build.VERSION.RELEASE} (sdk ${Build.VERSION.SDK_INT})\n")
                    fw.write("device=${Build.MANUFACTURER} ${Build.MODEL}\n\n")
                    val sw = StringWriter()
                    throwable.printStackTrace(PrintWriter(sw))
                    fw.write(sw.toString())
                }
                Log.e("VncEngine", "crash gravado em ${file.absolutePath}")
            } catch (e: Exception) {
                Log.e("VncEngine", "falha ao gravar crash", e)
            }
            default?.uncaughtException(thread, throwable)
        }
    }

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
        // cria defaults.json no filesDir (internal) antes de iniciar
        // IMPORTANTE: droidVNC-NG Defaults.kt lê de context.filesDir, NÃO de getExternalFilesDir!
        try {
            val dir = filesDir
            val defaults = JSONObject()
            defaults.put("port", port.toIntOrNull() ?: 5900)
            defaults.put("password", password)
            defaults.put("quality", 85)
            defaults.put("max_size", 0)   // 0 = sem limite, usa resolução nativa
            defaults.put("view_only", true)
            defaults.put("bind_interface", if (bindInterface) "0.0.0.0" else "")
            defaults.put("frame_interval", 0)
            defaults.put("use_video_codec", false)
            val f = File(dir, "defaults.json")
            FileWriter(f).use { it.write(defaults.toString(2)) }
            Log.i("VncEngine", "defaults.json criado em ${f.absolutePath}")
        } catch (e: Exception) {
            Log.e("VncEngine", "falha ao criar defaults.json", e)
        }

        val intent = Intent(this, MainService::class.java)
        intent.action = "net.christianbeier.droidvnc_ng.ACTION_START"
        intent.putExtra("net.christianbeier.droidvnc_ng.EXTRA_PASSWORD", password)
        intent.putExtra("net.christianbeier.droidvnc_ng.EXTRA_PORT", port.toIntOrNull() ?: 5900)
        intent.putExtra("net.christianbeier.droidvnc_ng.EXTRA_INTERFACE", if (bindInterface) "0.0.0.0" else "")
        // projetor: apenas espelha a tela (saída), não precisa de input nem
        // pointer injection -> evita o caminho arriscado de InputService.addClient
        intent.putExtra("net.christianbeier.droidvnc_ng.EXTRA_VIEW_ONLY", true)
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
