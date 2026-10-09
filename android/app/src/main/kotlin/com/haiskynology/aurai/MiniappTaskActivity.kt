package com.haiskynology.aurai

import android.app.ActivityManager
import android.content.Intent
import android.graphics.BitmapFactory
import android.net.Uri
import android.widget.Toast
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.util.UUID

/** Each document owns its UI engine; the application engine owns data and AI. */
class MiniappTaskActivity : FlutterActivity() {
    private val instance = UUID.randomUUID().toString()
    private lateinit var channel: MethodChannel

    override fun getDartEntrypointFunctionName() = "miniappMain"
    override fun shouldDestroyEngineWithHost() = true
    override fun getInitialRoute() = "/"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "aurai/html_game", HtmlViewFactory(MiniappTasks.hostMessenger),
        )
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MiniappTasks.CHANNEL)
        MiniappTasks.windows[instance] = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "request" -> {
                    val args = call.arguments as Map<*, *>
                    MiniappTasks.host.invokeMethod("request", mapOf(
                        "instance" to instance,
                        "launch" to intent.getStringExtra("launch"),
                        "method" to args["method"],
                        "arguments" to args["arguments"],
                    ), result)
                }
                "description" -> {
                    val args = call.arguments as Map<*, *>
                    val icon = (args["icon"] as ByteArray?)?.let {
                        BitmapFactory.decodeByteArray(it, 0, it.size)
                    }
                    @Suppress("DEPRECATION")
                    setTaskDescription(ActivityManager.TaskDescription(args["title"] as String, icon))
                    result.success(null)
                }
                "finish" -> { result.success(null); finishAndRemoveTask() }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    override fun onDestroy() {
        MiniappTasks.windows.remove(instance)
        // Dart UI disposal is not guaranteed when an engine is destroyed.
        // Release the host session even when the user swipes the task away.
        MiniappTasks.host.invokeMethod("request", mapOf(
            "instance" to instance, "method" to "close",
        ), object : MethodChannel.Result {
            override fun success(result: Any?) { HtmlGamePool.removeSurface("task:$instance") }
            override fun error(code: String, message: String?, details: Any?) {
                HtmlGamePool.removeSurface("task:$instance")
                Toast.makeText(applicationContext, "$code: $message\n$details", Toast.LENGTH_LONG).show()
            }
            override fun notImplemented() = error("not_implemented", "Miniapp task host unavailable", null)
        })
        super.onDestroy()
    }
}

object MiniappTasks {
    const val CHANNEL = "aurai/miniapp_tasks"
    lateinit var host: MethodChannel
    lateinit var hostMessenger: io.flutter.plugin.common.BinaryMessenger
    val windows = mutableMapOf<String, MethodChannel>()

    fun register(application: AuraiApplication, engine: FlutterEngine) {
        hostMessenger = engine.dartExecutor.binaryMessenger
        host = MethodChannel(hostMessenger, CHANNEL)
        host.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "open" -> {
                        val args = call.arguments as Map<*, *>
                        val launch = JSONObject(args)
                        val key = args["messageId"]?.let { "message:$it" } ?: "app:${args["appId"]}"
                        val intent = Intent(application, MiniappTaskActivity::class.java).apply {
                            data = Uri.Builder().scheme("aurai-miniapp").authority("task").appendPath(key).build()
                            putExtra("launch", launch.toString())
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NEW_DOCUMENT)
                        }
                        val existing = application.getSystemService(ActivityManager::class.java).appTasks
                            .firstOrNull { it.taskInfo.baseIntent.component == intent.component && it.taskInfo.baseIntent.data == intent.data }
                        if (existing == null) application.startActivity(intent)
                        else existing.moveToFront()
                        result.success(null)
                    }
                    "state" -> {
                        val args = call.arguments as Map<*, *>
                        windows[args["instance"]]?.invokeMethod("state", args["state"])
                        result.success(null)
                    }
                    "showMain" -> {
                        application.startActivity(Intent(application, MainActivity::class.java).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                        })
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error(error.javaClass.name, error.message, android.util.Log.getStackTraceString(error))
            }
        }
    }
}
