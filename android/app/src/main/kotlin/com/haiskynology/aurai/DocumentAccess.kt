package com.haiskynology.aurai

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract as Docs
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class DocumentAccess(private val context: Context) {
    private val folders = DocumentFolders(context)
    private val worker = DocumentWorker(context)
    private var pickerTaskId: String? = null
    private var pickerReply: MethodChannel.Result? = null
    private var projectFilesReply: MethodChannel.Result? = null
    private var projectFilesRoot: String? = null
    private val projectExecutor = java.util.concurrent.Executors.newSingleThreadExecutor()
    private val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())

    fun handle(call: MethodCall, result: MethodChannel.Result): Boolean {
        return try { handleCall(call, result) }
        catch (_: android.content.ActivityNotFoundException) {
            result.error("no_file_app", "手机上没有支持打开文件夹的应用", null); true
        } catch (error: SecurityException) {
            result.error("folder_access", "文件夹授权已失效，请重新选择文件夹", null); true
        } catch (error: IllegalArgumentException) {
            result.error("folder_input", error.message ?: "文件信息无效，请重新选择", null); true
        }
    }

    private fun handleCall(call: MethodCall, result: MethodChannel.Result): Boolean {
        when (call.method) {
            "getDocumentFolders" -> result.success(mapOf("folders" to folders.list()))
            "shareFile" -> share(call, result)
            "requestDocumentFolder" -> request(call.argument<String>("uri"), call.argument<String>("callId"), result)
            "createManagedProject" -> result.success(ManagedWorkspace.create(
                context,
                call.argument<String>("id")!!,
                call.argument<String>("name")!!
            ))
            "removeManagedProject" -> {
                ManagedWorkspace.remove(context, call.argument<String>("id")!!)
                result.success(null)
            }
            "listProjectFiles" -> result.success(mapOf(
                "files" to ProjectFileAccess.list(context, call.argument<String>("uri")!!)
            ))
            "importProjectFiles" -> requestProjectFiles(call.argument<String>("uri")!!, result)
            "getGitConfiguration" -> result.success(GitConfiguration.read(context))
            "setGitConfiguration" -> result.success(
                GitConfiguration.write(context, call.argument<Map<String, Any?>>("configuration")!!)
            )
            "projectDevelopmentOperation" -> projectDevelopment(call, result)
            "cancelProjectDevelopmentOperation" -> {
                ProjectDevelopment.cancel(call.argument<String>("callId")!!)
                result.success(null)
            }
            "openProjectFolder" -> {
                val uri = call.argument<String>("uri")!!
                if (uri.startsWith("aurai://")) {
                    ProjectFileAccess.open(context, uri)
                    result.success(null)
                } else {
                    openFolder(uri, result)
                }
            }
            "removeDocumentFolder" -> { folders.remove(call.argument<String>("uri")!!); result.success(null) }
            "renameDocumentFolder" -> { folders.rename(call.argument<String>("uri")!!, call.argument<String>("name")!!); result.success(null) }
            "openDocumentFolder" -> openFolder(call.argument<String>("uri")!!, result)
            "documentOperation" -> {
                val args = call.argument<Map<String, Any?>>("arguments")!!
                worker.execute(call.argument<String>("callId")!!, call.argument<String>("operation")!!, args, result::success)
            }
            "cancelDocumentPicker" -> {
                if (pickerTaskId == call.argument<String>("callId")) cancelPicker()
                result.success(null)
            }
            "cancelDocumentOperation" -> { worker.cancel(call.argument<String>("callId")!!); result.success(null) }
            else -> return false
        }
        return true
    }

    private fun projectDevelopment(call: MethodCall, result: MethodChannel.Result) {
        val projectId = call.argument<String>("projectId")!!
        val operation = call.argument<String>("operation")!!
        val callId = call.argument<String>("callId") ?: "$projectId:$operation"
        val arguments = call.argument<Map<String, Any?>>("arguments")!!
        projectExecutor.execute {
            try {
                val output = ProjectDevelopment.execute(context, callId, projectId, operation, arguments)
                mainHandler.post { result.success(output) }
            } catch (error: Exception) {
                mainHandler.post {
                    result.error("project_development", error.message ?: "项目操作失败", null)
                }
            }
        }
    }

    private fun openFolder(value: String, result: MethodChannel.Result) {
        val uri = DocumentUris.authorized(context, value)
        worker.execute("open-folder", "describeDocument", mapOf("uri" to value)) { output ->
            if (output.containsKey("error")) {
                if (output["missing"] == true) folders.invalidate(value)
                result.error("folder_open", output["error"] as String, null)
            } else try {
                context.startActivity(Intent(Intent.ACTION_VIEW).setDataAndType(uri, Docs.Document.MIME_TYPE_DIR)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION))
                result.success(null)
            } catch (_: android.content.ActivityNotFoundException) {
                result.error("no_file_app", "手机上没有支持打开文件夹的应用", null)
            } catch (_: SecurityException) {
                result.error("folder_open", "无法打开此文件夹，请重新授权", null)
            }
        }
    }

    private fun requestProjectFiles(root: String, result: MethodChannel.Result) {
        if (projectFilesReply != null) { result.error("busy", "正在选择项目资料", null); return }
        val activity = MainActivity.current
        if (activity == null || !MainActivity.isResumed) { result.error("foreground_required", "请回到 Aurai 后添加项目资料", null); return }
        projectFilesReply = result
        projectFilesRoot = root
        projectFilesPicker = this
        activity.startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            type = "*/*"
            addCategory(Intent.CATEGORY_OPENABLE)
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }, PROJECT_FILES_REQUEST)
    }

    fun selectedProjectFiles(data: Intent?) {
        val reply = projectFilesReply ?: return
        projectFilesReply = null
        projectFilesPicker = null
        val root = projectFilesRoot!!
        projectFilesRoot = null
        if (data == null) { reply.success(mapOf("cancelled" to true)); return }
        val uris = data.clipData?.let { clip ->
            (0 until clip.itemCount).map { clip.getItemAt(it).uri }
        } ?: listOfNotNull(data.data)
        try {
            reply.success(mapOf("files" to ProjectFileAccess.importFiles(context, root, uris)))
        } catch (error: Exception) {
            reply.error("project_files", error.message ?: "无法添加项目资料", null)
        }
    }

    fun cancelTasks() {
        worker.cancelActive()
        if (pickerTaskId != null) cancelPicker()
    }

    private fun share(call: MethodCall, result: MethodChannel.Result) {
        if (!MainActivity.isResumed) {
            result.error("foreground_required", "请回到 Aurai 后分享文件", null); return
        }
        val value = call.argument<String>("uri")!!
        DocumentUris.authorized(context, value)
        worker.execute(call.argument<String>("callId")!!, "describeDocument", mapOf("uri" to value)) { output ->
            if (output.containsKey("error")) {
                result.success(output)
            } else {
                val info = JSONObject(output["json"] as String)
                val activity = MainActivity.current
                if (info.getBoolean("directory")) {
                    result.error("share_directory", "请选择文件，不能直接分享文件夹", null)
                } else if (activity == null || !MainActivity.isResumed) {
                    result.error("foreground_required", "请回到 Aurai 后分享文件", null)
                } else try {
                    val uri = DocumentUris.authorized(context, info.getString("url"))
                    val title = info.getString("title")
                    val send = Intent(Intent.ACTION_SEND).apply {
                        type = info.getString("mimeType")
                        putExtra(Intent.EXTRA_STREAM, uri)
                        putExtra(Intent.EXTRA_TITLE, title)
                        clipData = android.content.ClipData.newRawUri(title, uri)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    activity.startActivity(Intent.createChooser(send, "分享 $title"))
                    result.success(mapOf("chooserOpened" to true, "title" to title,
                        "notice" to "分享面板已打开，等待用户选择目标；尚未确认发送。"))
                } catch (_: android.content.ActivityNotFoundException) {
                    result.error("share_unavailable", "手机上没有可用的文件分享应用", null)
                } catch (_: SecurityException) {
                    result.error("share_denied", "无法分享此文件，请检查文件访问授权", null)
                }
            }
        }
    }

    private fun cancelPicker() {
        pickerReply?.success(mapOf("cancelled" to true))
        pickerReply = null
        pickerTaskId = null
        picker = null
    }

    private fun request(existing: String?, callId: String?, result: MethodChannel.Result) {
        if (existing != null && folders.list().any { it["uri"] == existing && it["readable"] == true }) {
            result.success(mapOf("folders" to folders.list(), "alreadyAuthorized" to true))
            return
        }
        val activity = MainActivity.current
        if (activity == null || !MainActivity.isResumed) { result.error("foreground_required", "请回到 Aurai 后选择文件夹", null); return }
        if (pickerReply != null) { result.error("busy", "正在等待选择文件夹", null); return }
        if (existing == null && folders.list().size >= 16) { result.error("folder_limit", "最多授权 16 个文件夹，请先移除不再使用的授权", null); return }
        pickerTaskId = callId
        pickerReply = result
        picker = this
        try {
            activity.startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
                if (existing != null && android.os.Build.VERSION.SDK_INT >= 26) putExtra(Docs.EXTRA_INITIAL_URI, Uri.parse(existing))
            }, REQUEST)
        } catch (error: Exception) {
            pickerReply = null; pickerTaskId = null; picker = null
            result.error("picker_failed", "无法打开文件夹选择器", null)
        }
    }

    fun selected(data: Intent?) {
        val reply = pickerReply ?: return
        pickerReply = null; pickerTaskId = null; picker = null
        if (data?.data == null) { reply.success(mapOf("cancelled" to true)); return }
        val uri = data.data!!
        val prior = context.contentResolver.persistedUriPermissions.any { it.uri == uri }
        if (folders.list().none { it["uri"] == uri.toString() } && folders.list().size >= 16) {
            reply.error("folder_limit", "最多授权 16 个文件夹，请先移除不再使用的授权", null)
            return
        }
        try {
            val flags = data.flags and (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            context.contentResolver.takePersistableUriPermission(uri, flags)
            worker.execute("selected-folder", "describeDocument", mapOf("uri" to uri.toString())) { output ->
                if (output.containsKey("error")) {
                    if (!prior) context.contentResolver.releasePersistableUriPermission(uri, flags)
                    reply.error("folder_failed", output["error"] as String, null)
                } else {
                    val info = JSONObject(output["json"] as String)
                    folders.remember(uri, info.getString("title"))
                    reply.success(mapOf("folders" to folders.list(), "selectedUri" to uri.toString()))
                }
            }
        } catch (_: SecurityException) { reply.error("folder_access", "此文件夹不能保留访问授权，请选择其他文件夹", null) }
    }

    companion object {
        const val REQUEST = 1501
        const val PROJECT_FILES_REQUEST = 1502
        var picker: DocumentAccess? = null
            private set
        var projectFilesPicker: DocumentAccess? = null
            private set
    }
}
