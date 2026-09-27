package com.haiskynology.aurai

import android.content.Context
import android.net.Uri
import android.provider.DocumentsContract as Docs
import android.webkit.MimeTypeMap
import org.json.JSONObject
import java.io.File

class DocumentTransfer(private val context: Context) {
    private val resolver = context.contentResolver

    fun execute(operation: String, args: JSONObject): Map<String, Any?> {
        val source = authorized(args.getString("uri"), write = operation == "moveDocument")
        val targetFolder = authorized(args.getString("targetFolderUri"), write = true)
        val sourceInfo = info(source)
        require(info(targetFolder).directory) { "目标位置不是文件夹" }
        require(!inside(source, targetFolder)) { "不能将文件夹复制或移动到自身内部" }
        if (operation == "moveDocument") require(!isRoot(source)) { "不能移动项目根目录" }
        val name = if (args.has("name")) validName(args.getString("name")) else sourceInfo.title
        if (operation == "moveDocument") {
            directMove(source, sourceInfo, targetFolder, name, args)?.let { destination ->
                return metadata(destination) + mapOf(
                    "moved" to true,
                    "sourceUrl" to source.toString(),
                )
            }
            require(args.getBoolean("allowCopyDelete")) {
                "当前位置不支持原生移动；未执行任何修改。若接受复制后删除源内容，请将 allowCopyDelete 设为 true"
            }
        }
        val destination = copy(source, sourceInfo, targetFolder, name)
        if (operation == "moveDocument") {
            try {
                delete(source)
            } catch (error: Exception) {
                try {
                    delete(destination)
                } catch (rollbackError: Exception) {
                    throw java.io.IOException(
                        "源文件删除失败，且无法删除目标副本；两处可能同时存在",
                        error,
                    ).apply { addSuppressed(rollbackError) }
                }
                throw error
            }
        }
        return metadata(destination) + mapOf(
            (if (operation == "moveDocument") "moved" else "copied") to true,
            "sourceUrl" to source.toString(),
        )
    }

    private fun directMove(
        source: Uri,
        sourceInfo: Info,
        targetFolder: Uri,
        name: String,
        args: JSONObject,
    ): Uri? {
        if (source.scheme == "aurai" && targetFolder.scheme == "aurai") {
            val sourceFile = ManagedWorkspace.file(context, source.toString())
            val parent = ManagedWorkspace.file(context, targetFolder.toString())
            val destination = File(parent, validName(name))
            require(!destination.exists()) { "目标位置已有同名文件或文件夹" }
            require(sourceFile.renameTo(destination)) { "无法移动文件" }
            return Uri.parse(ManagedWorkspace.url(context, destination))
        }
        if (source.scheme != "content" || targetFolder.scheme != "content" ||
            source.authority != targetFolder.authority ||
            android.os.Build.VERSION.SDK_INT < android.os.Build.VERSION_CODES.N ||
            !args.has("sourceParentUri")) return null
        val sourceParent = authorized(args.getString("sourceParentUri"), write = true)
        if (name != sourceInfo.title) return null
        val moved = try {
            Docs.moveDocument(resolver, source, sourceParent, targetFolder)
        } catch (_: UnsupportedOperationException) {
            null
        } ?: return null
        return moved
    }

    private data class Info(
        val title: String,
        val mimeType: String,
        val directory: Boolean,
    )

    private fun authorized(value: String, write: Boolean): Uri = Uri.parse(value).let { uri ->
        if (uri.scheme == "aurai") {
            ManagedWorkspace.file(context, value)
            uri
        } else {
            DocumentUris.authorized(context, value, write)
        }
    }

    private fun info(uri: Uri): Info {
        if (uri.scheme == "aurai") {
            val file = ManagedWorkspace.file(context, uri.toString())
            return Info(
                file.name,
                if (file.isDirectory) Docs.Document.MIME_TYPE_DIR else
                    (MimeTypeMap.getSingleton().getMimeTypeFromExtension(file.extension.lowercase())
                        ?: "application/octet-stream"),
                file.isDirectory,
            )
        }
        val projection = arrayOf(
            Docs.Document.COLUMN_DISPLAY_NAME,
            Docs.Document.COLUMN_MIME_TYPE,
        )
        return resolver.query(uri, projection, null, null, null)!!.use { cursor ->
            require(cursor.moveToFirst()) { "文件已移动、删除或无法访问" }
            val mime = cursor.getString(1)
            Info(cursor.getString(0), mime, mime == Docs.Document.MIME_TYPE_DIR)
        }
    }

    private fun copy(source: Uri, sourceInfo: Info, targetFolder: Uri, name: String): Uri {
        val destination = create(targetFolder, name, sourceInfo)
        try {
            if (sourceInfo.directory) {
                for (child in children(source)) {
                    val childInfo = info(child)
                    copy(child, childInfo, destination, childInfo.title)
                }
            } else {
                input(source).use { input ->
                    output(destination).use { output -> input.copyTo(output) }
                }
            }
            return destination
        } catch (error: Exception) {
            delete(destination)
            throw error
        }
    }

    private fun create(targetFolder: Uri, name: String, source: Info): Uri {
        if (targetFolder.scheme == "aurai") {
            val parent = ManagedWorkspace.file(context, targetFolder.toString())
            val target = File(parent, validName(name))
            require(!target.exists()) { "目标位置已有同名文件或文件夹" }
            require(if (source.directory) target.mkdir() else target.createNewFile()) { "无法创建目标文件" }
            return Uri.parse(ManagedWorkspace.url(context, target))
        }
        return Docs.createDocument(
            resolver,
            targetFolder,
            if (source.directory) Docs.Document.MIME_TYPE_DIR else source.mimeType,
            validName(name),
        ) ?: error("文件提供者无法创建目标文件")
    }

    private fun children(folder: Uri): List<Uri> {
        if (folder.scheme == "aurai") {
            return ManagedWorkspace.file(context, folder.toString()).listFiles()!!
                .map { Uri.parse(ManagedWorkspace.url(context, it)) }
        }
        val children = Docs.buildChildDocumentsUriUsingTree(folder, Docs.getDocumentId(folder))
        return resolver.query(
            children,
            arrayOf(Docs.Document.COLUMN_DOCUMENT_ID),
            null,
            null,
            null,
        )!!.use { cursor ->
            buildList {
                while (cursor.moveToNext()) {
                    add(Docs.buildDocumentUriUsingTree(folder, cursor.getString(0)))
                }
            }
        }
    }

    private fun input(uri: Uri) = if (uri.scheme == "aurai") {
        ManagedWorkspace.file(context, uri.toString()).inputStream()
    } else {
        resolver.openInputStream(uri)!!
    }

    private fun output(uri: Uri) = if (uri.scheme == "aurai") {
        ManagedWorkspace.file(context, uri.toString()).outputStream()
    } else {
        resolver.openOutputStream(uri, "w")!!
    }

    private fun delete(uri: Uri) {
        if (uri.scheme == "aurai") {
            val file = ManagedWorkspace.file(context, uri.toString())
            require(if (file.isDirectory) file.deleteRecursively() else file.delete()) { "无法删除文件" }
        } else {
            require(Docs.deleteDocument(resolver, uri)) { "文件提供者无法删除文件" }
        }
    }

    private fun metadata(uri: Uri): Map<String, Any?> = if (uri.scheme == "aurai") {
        ManagedWorkspace(context).execute(
            "describeDocument",
            JSONObject().put("uri", uri.toString()),
        )
    } else {
        DocumentOperations(context).metadata(uri)
    }

    private fun isRoot(uri: Uri): Boolean = if (uri.scheme == "aurai") {
        uri.pathSegments.size == 1
    } else {
        Docs.getDocumentId(uri) == Docs.getTreeDocumentId(uri)
    }

    private fun inside(source: Uri, target: Uri): Boolean {
        if (source.scheme != target.scheme || source.authority != target.authority) return false
        if (source.scheme == "aurai") {
            val sourceFile = ManagedWorkspace.file(context, source.toString()).canonicalFile
            val targetFile = ManagedWorkspace.file(context, target.toString()).canonicalFile
            return targetFile == sourceFile || targetFile.path.startsWith(sourceFile.path + File.separator)
        }
        if (Docs.getTreeDocumentId(source) != Docs.getTreeDocumentId(target)) return false
        val sourceId = Docs.getDocumentId(source)
        val targetId = Docs.getDocumentId(target)
        return targetId == sourceId || targetId.startsWith("$sourceId/")
    }

    private fun validName(value: String): String {
        require(value.isNotBlank() && value.length <= 120 && value !in setOf(".", "..") &&
            value.none { it == '/' || it == '\\' || it.code < 32 }) { "名称无效" }
        return value
    }
}
