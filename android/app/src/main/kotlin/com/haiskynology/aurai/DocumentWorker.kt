package com.haiskynology.aurai

import android.content.*
import android.os.*
import org.json.JSONObject

class DocumentWorker(private val context: Context) {
    private val handler = Handler(Looper.getMainLooper())
    private var active: Run? = null
    fun execute(id: String, operation: String, args: Map<String, Any?>, reply: (Map<String, Any?>) -> Unit) {
        if (active != null) { reply(mapOf("error" to "已有文件操作正在进行")); return }
        val run = Run(id, operation, args, reply)
        active = run
        run.bound = context.bindService(Intent(context, DocumentService::class.java), run, Context.BIND_AUTO_CREATE)
        if (!run.bound) run.finish(mapOf("error" to "无法启动文件处理"))
        else handler.postDelayed(run.timeout, 30000)
    }
    fun cancel(id: String) { active?.takeIf { it.id == id }?.finish(mapOf("error" to "文件操作已取消", "cancelled" to true)) }

    fun cancelActive() { active?.let { cancel(it.id) } }

    private inner class Run(val id: String, val operation: String, val args: Map<String, Any?>,
        val callback: (Map<String, Any?>) -> Unit) : ServiceConnection {
        var bound = false
        var finished = false
        var pid: Int? = null
        var createdUri: String? = null
        val timeout = Runnable { finish(mapOf("error" to "文件处理超过 30 秒，已停止")) }
        val reply = Messenger(Handler(Looper.getMainLooper()) { message ->
            when (message.what) {
                1 -> {
                    val value = message.data.getInt("pid")
                    if (finished) Process.killProcess(value) else pid = value
                }
                2 -> {
                    if (message.data.containsKey("error")) {
                        if (message.data.getBoolean("accessDenied")) DocumentFolders(context).invalidate(args["uri"] as String)
                        finish(mapOf("error" to message.data.getString("error"), "missing" to message.data.getBoolean("missing")))
                    } else finish(mapOf("json" to message.data.getString("json")))
                }
                3 -> createdUri = message.data.getString("createdUri")
            }
            true
        })
        override fun onServiceConnected(name: ComponentName, binder: IBinder) {
            if (finished) return
            try { Messenger(binder).send(Message.obtain(null, 0).apply {
                replyTo = reply
                data = Bundle().apply { putString("request", JSONObject(mapOf("operation" to operation, "args" to args)).toString()) }
            }) } catch (_: RemoteException) { finish(mapOf("error" to "文件处理连接中断")) }
        }
        override fun onServiceDisconnected(name: ComponentName) { finish(mapOf("error" to "文件处理进程已退出")) }
        override fun onNullBinding(name: ComponentName) { finish(mapOf("error" to "无法连接文件处理服务")) }
        override fun onBindingDied(name: ComponentName) = onServiceDisconnected(name)
        fun finish(output: Map<String, Any?>) {
            if (finished) return
            finished = true
            handler.removeCallbacks(timeout)
            if (bound) context.unbindService(this)
            pid?.let(Process::killProcess)
            active = null
            callback(if (output.containsKey("error") && operation == "createTextFile") output + mapOf(
                "createdUri" to createdUri,
                "notice" to "操作可能已创建文件但未完整保存；请查看目标文件夹，不要自动重试创建。",
            ) else output)
        }
    }
}
