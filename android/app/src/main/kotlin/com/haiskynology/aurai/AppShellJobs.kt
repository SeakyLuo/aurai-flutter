package com.haiskynology.aurai

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/** Each command owns its process and reply; cancellation never targets a peer. */
class AppShellJobs(context: Context) {
    private val directory = File(context.filesDir, "agent-shell")
    private val worker = Executors.newCachedThreadPool()
    private val main = Handler(Looper.getMainLooper())
    private val jobs = mutableMapOf<String, AppUidExecutionAdapter>()

    fun execute(id: String, command: String, result: MethodChannel.Result) {
        val adapter = AppUidExecutionAdapter(directory)
        jobs[id] = adapter
        worker.execute {
            try {
                val output = adapter.execute(command)
                main.post {
                    jobs.remove(id)
                    result.success(output)
                }
            } catch (error: Exception) {
                main.post {
                    jobs.remove(id)
                    result.error("shell_error", error.message ?: error.javaClass.simpleName, null)
                }
            }
        }
    }

    fun cancel(id: String) {
        jobs[id]?.cancel()
    }
}
