package com.haiskynology.aurai

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.provider.DocumentsContract
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.Executors

class DataManagementAccess(private val context: Context, messenger: BinaryMessenger, private val loadModel: () -> String?) {
    private val archive = DataBackupArchive(context)
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var busy = false
    private var reply: MethodChannel.Result? = null
    private var operation = ""
    private var inspected = false

    init { MethodChannel(messenger, "com.haiskynology.aurai/data_management").setMethodCallHandler(::handle) }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (busy) { result.error("busy", "正在处理数据，请稍候", null); return }
        when (call.method) {
            "usage" -> run(result) { usage() }
            "clearCache" -> run(result) {
                for (file in context.cacheDir.listFiles().orEmpty()) check(file.deleteRecursively()) { "无法清理缓存：${file.name}" }
                usage()
            }
            "export", "inspectImport" -> {
                val activity = MainActivity.current
                if (activity == null || !MainActivity.isResumed) { result.error("foreground", "请回到 App 后操作", null); return }
                operation = call.method
                val export = operation == "export"
                busy = true; reply = result; picker = this
                try {
                    activity.startActivityForResult(Intent(if (export) Intent.ACTION_CREATE_DOCUMENT else Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = if (export) "application/octet-stream" else "*/*"
                        if (export) putExtra(Intent.EXTRA_TITLE, "Aurai-${SimpleDateFormat("yyyy-MM-dd-HHmmss", Locale.ROOT).format(Date())}.aurai")
                    }, REQUEST)
                } catch (error: Exception) { clearPicker(); fail(result, error) }
            }
            "discardImport" -> run(result) { inspected = false; archive.stage.deleteRecursively(); null }
            "commitImport" -> {
                if (!inspected) { result.error("import", "请先选择并校验备份", null); return }
                run(result, quit = true) {
                    // Data is replaced only in the next cold start, before SQLite or preferences open.
                    File(archive.stage, "READY").outputStream().use { it.write(1); it.fd.sync() }
                    null
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun usage(): Map<String, Any> {
        fun bytes(folder: File) = if (folder.exists()) folder.walkTopDown().filter { it.isFile }.sumOf { it.length() } else 0L
        val root = File(context.applicationInfo.dataDir)
        return mapOf("cacheBytes" to bytes(context.cacheDir),
            "dataBytes" to listOf("databases", "files", "shared_prefs", "app_flutter").sumOf { bytes(File(root, it)) },
            "lastExportAt" to context.getSharedPreferences("data_management", 0).getLong("last_export_at", 0))
    }

    private fun run(result: MethodChannel.Result, quit: Boolean = false, work: () -> Any?) {
        busy = true
        worker.execute {
            try {
                val value = work()
                main.post {
                    if (!quit) busy = false
                    result.success(value)
                    if (quit) {
                        MainActivity.current?.finishAffinity()
                        main.postDelayed({ Process.killProcess(Process.myPid()) }, 300)
                    }
                }
            } catch (error: Exception) { main.post { busy = false; fail(result, error) } }
        }
    }

    fun selected(uri: Uri?) {
        val result = reply ?: return
        val export = operation == "export"
        clearPicker()
        if (uri == null) { result.success(null); return }
        run(result) {
            if (export) {
                try {
                    val model = try { loadModel() } catch (error: Exception) {
                        throw IllegalStateException("无法读取当前模型密钥：${error.message ?: error.javaClass.simpleName}", error)
                    }
                    val output = context.contentResolver.openOutputStream(uri, "wt") ?: error("无法写入所选文件")
                    val details = output.use { archive.export(it, model) }
                    details
                } catch (error: Exception) {
                    try { DocumentsContract.deleteDocument(context.contentResolver, uri) } catch (cleanup: Exception) { error.addSuppressed(cleanup) }
                    throw error
                }.also {
                    check(context.getSharedPreferences("data_management", 0).edit().putLong("last_export_at", System.currentTimeMillis()).commit()) { "备份文件已保存，但无法记录导出时间" }
                }
            } else {
                inspected = false
                val input = context.contentResolver.openInputStream(uri) ?: error("无法读取所选备份")
                input.use { archive.inspect(it) }.also { inspected = true }
            }
        }
    }

    private fun clearPicker() { reply = null; picker = null; busy = false }
    private fun fail(result: MethodChannel.Result, error: Exception) {
        val message = when (error) {
            is java.io.EOFException -> "备份文件不完整，未修改当前数据"
            else -> error.message ?: error.javaClass.simpleName
        }
        result.error("data_management", message, null)
    }
    companion object {
        const val REQUEST = 1603
        var picker: DataManagementAccess? = null
    }
}
