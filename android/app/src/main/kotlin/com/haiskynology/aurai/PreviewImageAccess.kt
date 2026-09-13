package com.haiskynology.aurai

import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

class PreviewImageAccess(private val context: Context) {
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var pending: MethodChannel.Result? = null
    private var bytes: ByteArray? = null

    fun handle(call: MethodCall, result: MethodChannel.Result): Boolean {
        if (call.method != "previewImageAction") return false
        val activity = MainActivity.current
        if (activity == null || !MainActivity.isResumed) {
            result.error("foreground", "请回到应用后操作", null); return true
        }
        val data = call.argument<ByteArray>("bytes")!!
        val name = call.argument<String>("name")!!
        val mime = call.argument<String>("mimeType")!!
        if (call.argument<String>("action") == "save") {
            if (pending != null) { result.error("busy", "请先完成当前保存", null); return true }
            pending = result; bytes = data; picker = this
            try {
                activity.startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                    type = mime
                    addCategory(Intent.CATEGORY_OPENABLE)
                    putExtra(Intent.EXTRA_TITLE, name)
                }, REQUEST)
            } catch (error: Exception) {
                pending = null; bytes = null; picker = null
                result.error("save", "无法打开保存位置", null)
            }
        } else {
            worker.execute {
                try {
                    val folder = File(context.cacheDir, "image_shares").apply { mkdirs() }
                    val file = File(folder, name).apply { writeBytes(data) }
                    val uri = FileProvider.getUriForFile(context, "${context.packageName}.source_files", file)
                    main.post {
                        try {
                            activity.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).apply {
                                type = mime
                                putExtra(Intent.EXTRA_STREAM, uri)
                                clipData = ClipData.newRawUri(name, uri)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }, "转发图片"))
                            result.success(true)
                        } catch (error: Exception) { result.error("share", "无法打开分享面板", null) }
                    }
                } catch (error: Exception) { main.post { result.error("share", "无法准备图片", null) } }
            }
        }
        return true
    }

    fun selected(uri: Uri?) {
        val result = pending ?: return
        val data = bytes!!
        pending = null; bytes = null; picker = null
        if (uri == null) { result.success(false); return }
        worker.execute {
            try {
                context.contentResolver.openOutputStream(uri, "wt")!!.use { it.write(data) }
                main.post { result.success(true) }
            } catch (error: Exception) { main.post { result.error("save", "图片保存失败", null) } }
        }
    }
    companion object {
        const val REQUEST = 1476
        var picker: PreviewImageAccess? = null
    }
}
