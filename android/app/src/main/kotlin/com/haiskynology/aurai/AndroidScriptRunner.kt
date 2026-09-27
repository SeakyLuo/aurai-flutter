package com.haiskynology.aurai

import android.content.*
import android.os.*
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

class AndroidScriptRunner(private val context: Context) {
    private val handler = Handler(Looper.getMainLooper())
    private var active: Run? = null
    private val worker = Executors.newSingleThreadExecutor()

    fun execute(id: String, script: String, conversationId: String, timeoutSeconds: Int, result: MethodChannel.Result) {
        if (timeoutSeconds !in 1..600) {
            result.success(mapOf("success" to false, "error" to "timeoutSeconds must be between 1 and 600"))
            return
        }
        if (script.isBlank() || script.length > 65536) {
            result.success(mapOf("success" to false, "error" to "Script must contain 1–65536 characters"))
            return
        }
        if (active != null) {
            result.success(mapOf("success" to false, "error" to "Another device script is running"))
            return
        }
        val run = Run(id, script, conversationId, timeoutSeconds, result)
        active = run
        worker.execute {
            try {
                run.changes = WorkspaceChanges(File(ScriptWorkspace(context, conversationId).getDirectory()))
                run.before = run.changes.snapshot()
                handler.post {
                    if (!run.finished) {
                        run.bound = context.bindService(
                            Intent(context, AndroidScriptService::class.java), run, Context.BIND_AUTO_CREATE,
                        )
                        if (!run.bound) run.finish(mapOf("success" to false, "error" to "Cannot start script process"))
                        else handler.postDelayed(run.timeout, timeoutSeconds * 1000L)
                    }
                }
            } catch (error: Exception) {
                handler.post { run.failSnapshot(error) }
            }
        }
    }

    fun cancel(id: String) {
        active?.takeIf { it.id == id }?.finish(mapOf(
            "success" to false, "cancelled" to true,
            "error" to "Script cancelled. Earlier side effects are not rolled back; observe before retrying.",
        ))
    }

    private inner class Run(
        val id: String,
        val script: String,
        val conversationId: String,
        val timeoutSeconds: Int,
        val result: MethodChannel.Result,
    ) : ServiceConnection {
        var bound = false
        var pid: Int? = null
        var finished = false
        lateinit var changes: WorkspaceChanges
        var before: WorkspaceChanges.Snapshot? = null
        val timeout = Runnable { finish(mapOf(
            "success" to false,
            "error" to "Script timed out after $timeoutSeconds seconds. Earlier side effects are not rolled back; observe before retrying.",
        )) }
        val reply = Messenger(Handler(Looper.getMainLooper()) { message ->
            when (message.what) {
                1 -> {
                    val processId = message.data.getInt("pid")
                    if (finished) Process.killProcess(processId) else pid = processId
                }
                2 -> {
                    val error = message.data.getString("error")
                    finish(if (error == null) mapOf(
                        "success" to true, "json" to message.data.getString("json"),
                        "executionIdentity" to "Aurai app UID",
                    ) else mapOf("success" to false, "error" to error))
                }
            }
            true
        })

        override fun onServiceConnected(name: ComponentName, service: IBinder) {
            if (finished) return
            try {
                Messenger(service).send(Message.obtain(null, 0).apply {
                    replyTo = reply
                    data = Bundle().apply {
                        putString("script", script)
                        putString("conversationId", conversationId)
                    }
                })
            } catch (error: RemoteException) {
                finish(mapOf("success" to false, "error" to "Script process disconnected"))
            }
        }
        override fun onServiceDisconnected(name: ComponentName) {
            finish(mapOf("success" to false, "error" to "Script process exited; verify any side effects before retrying"))
        }
        override fun onNullBinding(name: ComponentName) {
            finish(mapOf("success" to false, "error" to "Script service has no binder"))
        }
        override fun onBindingDied(name: ComponentName) = onServiceDisconnected(name)

        fun finish(output: Map<String, Any?>) {
            if (finished) return
            finished = true
            handler.removeCallbacks(timeout)
            if (bound) context.unbindService(this)
            pid?.let(Process::killProcess)
            worker.execute {
                try {
                    val initial = before
                    val after = if (initial != null) changes.snapshot() else null
                    val details = if (initial != null && after != null) mapOf(
                        "fileChanges" to changes.compare(initial, after),
                        "fileChangesComplete" to (initial.complete && after.complete),
                    ) else emptyMap()
                    handler.post {
                        active = null
                        result.success(output + details)
                    }
                } catch (error: Exception) {
                    handler.post {
                        active = null
                        result.success(output + mapOf("fileChangesComplete" to false, "fileChangesError" to error.toString()))
                    }
                }
            }
        }

        fun failSnapshot(error: Exception) {
            if (finished) return
            finished = true
            active = null
            result.error("workspace_snapshot", error.toString(), null)
        }
    }
}
