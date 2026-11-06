package com.haiskynology.aurai

import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.util.concurrent.Executors

/** File selection and execution errors cross this boundary without losing native details. */
class MiniappFilesAccess(private val context: Context) {
    private val reads = Executors.newFixedThreadPool(2)
    private val imports = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var reply: MethodChannel.Result? = null
    private var appId = ""

    fun handle(call: MethodCall, result: MethodChannel.Result): Boolean {
        if (call.method != "miniappFiles") return false
        val args = JSONObject(call.arguments as String)
        val id = args.getString("appId")
        if (args.getString("action") == "import") {
            try {
                check(reply == null) { "A file picker is already open" }
                check(MiniappFilesStore.status(context, id).getString("phase") !in listOf("extracting", "validating")) { "An import is already running" }
                val activity = MiniappTaskActivity.current ?: MainActivity.current?.takeIf { MainActivity.isResumed }
                check(activity != null) { "Open Aurai before importing files" }
                appId = id
                reply = result
                picker = this
                activity.startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                    type = "application/zip"
                    addCategory(Intent.CATEGORY_OPENABLE)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }, REQUEST)
            } catch (error: Exception) {
                reply = null; picker = null
                result.error("miniapp_files", error.toString(), null)
            }
        } else reads.execute {
            try {
                val output = when (args.getString("action")) {
                    "info" -> MiniappFilesStore.info(context, id)
                    "status" -> MiniappFilesStore.status(context, id)
                    "query" -> MiniappFilesStore.query(context, id, args)
                    "record" -> MiniappFilesStore.record(context, id, args.getString("collection"), args.getString("key"))
                    "document" -> MiniappFilesStore.document(context, id, args.getString("name"))
                    else -> error("Unsupported file operation")
                }
                main.post { result.success(output.toString()) }
            } catch (error: Exception) { main.post { result.error("miniapp_files", error.toString(), null) } }
        }
        return true
    }

    fun selected(data: Intent?) {
        val result = reply ?: return
        reply = null; picker = null
        if (data == null) { result.success(JSONObject().put("cancelled", true).toString()); return }
        val id = appId
        try {
            val state = MiniappFilesStore.begin(context, id)
            imports.execute {
                try {
                    val source = context.contentResolver.openInputStream(data.data!!) ?: error("Unable to open selected archive")
                    MiniappFilesStore.importArchive(context, id, source)
                    main.post { HtmlGamePool.filesChanged(id) }
                } catch (error: Exception) { MiniappFilesStore.fail(context, id, error) }
            }
            result.success(state.toString())
        } catch (error: Exception) { result.error("miniapp_files", error.toString(), null) }
    }

    companion object {
        const val REQUEST = 1410
        var picker: MiniappFilesAccess? = null
    }
}
