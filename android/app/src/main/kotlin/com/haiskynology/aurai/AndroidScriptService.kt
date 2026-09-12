package com.haiskynology.aurai

import android.app.Service
import android.content.Intent
import android.os.*
import org.mozilla.javascript.Context
import org.mozilla.javascript.ContextFactory
import org.mozilla.javascript.ScriptableObject

/** A disposable process: native calls as well as JS loops end when the host kills it. */
class AndroidScriptService : Service() {
    private val messenger = Messenger(Handler(Looper.getMainLooper()) { message ->
        val reply = message.replyTo
        reply.send(Message.obtain(null, 1).apply {
            data = Bundle().apply { putInt("pid", Process.myPid()) }
        })
        val script = message.data.getString("script")!!
        val conversationId = message.data.getString("conversationId")!!
        Thread({
            val output = Bundle()
            try {
                val factory = object : ContextFactory() {
                    override fun makeContext(): Context = super.makeContext().apply {
                        optimizationLevel = -1
                        languageVersion = Context.VERSION_ES6
                        instructionObserverThreshold = 10_000
                    }
                    override fun observeInstructionCount(cx: Context, count: Int) {
                        if (Thread.currentThread().isInterrupted) throw InterruptedException("Cancelled")
                    }
                }
                val json = factory.call<String> { cx ->
                    val scope = cx.initStandardObjects()
                    ScriptableObject.putProperty(scope, "app", Context.javaToJS(applicationContext, scope))
                    ScriptableObject.putProperty(scope, "conversationId", conversationId)
                    Context.toString(cx.evaluateString(
                        scope,
                        "JSON.stringify((function(){\n$script\n})())",
                        "device-script", 1, null,
                    ))
                }
                if (json == "undefined") {
                    output.putString("error", "Return a JSON-compatible value from the script.")
                } else if (json.length > 32768) {
                    output.putString("error", "Result exceeds 32768 characters. Return a smaller summary.")
                } else {
                    output.putString("json", json)
                }
            } catch (error: Exception) {
                output.putString("error", "${error.javaClass.simpleName}: ${error.message}".take(4000))
            }
            try {
                reply.send(Message.obtain(null, 2).apply { data = output })
            } catch (_: RemoteException) {
                Process.killProcess(Process.myPid())
            }
        }, "android-script").start()
        true
    })

    override fun onBind(intent: Intent) = messenger.binder
}
