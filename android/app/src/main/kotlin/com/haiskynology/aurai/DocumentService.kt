package com.haiskynology.aurai

import android.app.Service
import android.content.Intent
import android.os.*
import org.json.JSONObject

/** Provider I/O and PDF parsing live outside the Flutter process and can be stopped. */
class DocumentService : Service() {
    private val messenger = Messenger(Handler(Looper.getMainLooper()) { message ->
        val reply = message.replyTo
        reply.send(Message.obtain(null, 1).apply { data = Bundle().apply { putInt("pid", Process.myPid()) } })
        val request = JSONObject(message.data.getString("request")!!)
        Thread({
            val output = Bundle()
            try {
                val value = DocumentOperations(this).execute(request.getString("operation"), request.getJSONObject("args")) { uri ->
                    reply.send(Message.obtain(null, 3).apply { data = Bundle().apply { putString("createdUri", uri) } })
                }
                output.putString("json", JSONObject(value).toString())
            } catch (error: Exception) {
                output.putString("error", when (error) {
                    is java.nio.charset.CharacterCodingException -> "无法按指定编码读取，请确认文件编码后重试"
                    is com.tom_roush.pdfbox.pdmodel.encryption.InvalidPasswordException -> "此 PDF 需要密码，暂时无法读取"
                    else -> error.message ?: "文件操作未完成"
                })
                output.putBoolean("missing", error is java.io.FileNotFoundException)
                output.putBoolean("accessDenied", error is SecurityException)
            }
            try { reply.send(Message.obtain(null, 2).apply { data = output }) }
            catch (_: RemoteException) { Process.killProcess(Process.myPid()) }
        }, "document-operation").start()
        true
    })
    override fun onBind(intent: Intent) = messenger.binder
}
