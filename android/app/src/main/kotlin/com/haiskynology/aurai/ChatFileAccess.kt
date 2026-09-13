package com.haiskynology.aurai

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors

class ChatFileAccess(private val context: Context) {
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var reply: MethodChannel.Result? = null
    private var remaining = 0
    private var directory = ""

    fun handle(call: MethodCall, result: MethodChannel.Result): Boolean {
        when (call.method) {
            "pickChatFiles" -> {
                if (reply != null) { result.error("busy", "正在选择附件", null); return true }
                val activity = MainActivity.current
                if (activity == null || !MainActivity.isResumed) { result.error("foreground", "请回到应用后添加附件", null); return true }
                remaining = call.argument<Int>("remaining")!!
                directory = call.argument<String>("directory")!!
                reply = result; picker = this
                try {
                    activity.startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        type = "*/*"
                        addCategory(Intent.CATEGORY_OPENABLE)
                        putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }, REQUEST)
                } catch (error: Exception) {
                    reply = null; picker = null
                    result.error("picker", "无法打开文件选择器", null)
                }
            }
            "openChatFile" -> {
                try {
                    val file = attachment(call.argument<String>("path")!!)
                    val uri = FileProvider.getUriForFile(context, "${context.packageName}.source_files", file, call.argument<String>("name")!!)
                    context.startActivity(Intent(Intent.ACTION_VIEW).setDataAndType(uri, call.argument<String>("mimeType")!!)
                        .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK))
                    result.success(null)
                } catch (error: Exception) { result.error("open_file", "无法打开附件，请检查是否安装了支持此文件的应用", null) }
            }
            "readChatFile" -> worker.execute {
                try {
                    val output = ChatFileReader.read(context, attachment(call.argument<String>("path")!!),
                        call.argument<String>("name")!!, call.argument<String>("mimeType")!!,
                        call.argument<Int>("offset")!!, call.argument<Int>("maxCharacters")!!)
                    main.post { result.success(output) }
                } catch (error: Exception) { main.post { result.error("read_file", error.message ?: "附件读取失败", null) } }
            }
            else -> return false
        }
        return true
    }

    private fun attachment(path: String): File {
        val root = File(context.filesDir, "message_images").canonicalFile
        val file = File(path).canonicalFile
        require(file.parentFile == root) { "附件路径无效" }
        return file
    }

    fun selected(data: Intent?) {
        val result = reply ?: return
        if (data == null) { reply = null; picker = null; result.success(emptyList<Any>()); return }
        val uris = data.clipData?.let { clip -> (0 until clip.itemCount).map { clip.getItemAt(it).uri } }
            ?: listOfNotNull(data.data)
        val limit = remaining
        val folder = directory
        worker.execute {
            val copied = mutableListOf<File>()
            try {
                require(uris.size <= limit) { "每条消息最多添加 10 个文件，请重新选择" }
                val output = uris.map { uri ->
                    var name = uri.lastPathSegment ?: "附件"
                    context.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE), null, null, null)?.use { cursor ->
                        if (cursor.moveToFirst()) {
                            name = cursor.getString(0)
                            if (!cursor.isNull(1)) require(cursor.getLong(1) <= MAX_BYTES) { "$name 超过 100 MB" }
                        }
                    }
                    val suffix = name.substringAfterLast('.', "").takeIf { it.matches(Regex("[A-Za-z0-9]{1,12}")) }
                    val file = attachment("$folder/${UUID.randomUUID()}${suffix?.let { ".$it" } ?: ""}")
                    copied.add(file)
                    var size = 0L
                    val input = context.contentResolver.openInputStream(uri) ?: error("无法读取 $name")
                    input.use { source -> file.outputStream().use { destination ->
                        val buffer = ByteArray(65536)
                        while (true) {
                            val count = source.read(buffer)
                            if (count < 0) break
                            size += count
                            require(size <= MAX_BYTES) { "$name 超过 100 MB" }
                            destination.write(buffer, 0, count)
                        }
                    } }
                    mapOf("path" to file.path, "name" to name, "size" to size,
                        "mimeType" to (context.contentResolver.getType(uri) ?: "application/octet-stream"))
                }
                main.post { reply = null; picker = null; result.success(output) }
            } catch (error: Exception) {
                copied.forEach { it.delete() }
                main.post { reply = null; picker = null; result.error("attachment", error.message ?: "附件添加失败", null) }
            }
        }
    }

    companion object {
        const val REQUEST = 1404
        const val MAX_BYTES = 100L * 1024 * 1024
        var picker: ChatFileAccess? = null
    }
}
