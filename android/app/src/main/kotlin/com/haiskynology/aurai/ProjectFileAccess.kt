package com.haiskynology.aurai

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import java.io.File

object ProjectFileAccess {
    fun list(context: Context, root: String): List<Map<String, Any?>> = if (root.startsWith("aurai://")) {
        ManagedWorkspace.root(context, Uri.parse(root).pathSegments.first()).listFiles()!!
            .sortedWith(compareBy<File>({ !it.isDirectory }, { it.name.lowercase() }))
            .map { mapOf("name" to it.name, "directory" to it.isDirectory, "size" to if (it.isFile) it.length() else null) }
    } else {
        val tree = Uri.parse(root)
        val children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))
        context.contentResolver.query(children, arrayOf(
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
            DocumentsContract.Document.COLUMN_SIZE,
        ), null, null, null)!!.use { cursor ->
            val output = mutableListOf<Map<String, Any?>>()
            while (cursor.moveToNext()) output.add(mapOf(
                "name" to cursor.getString(0),
                "directory" to (cursor.getString(1) == DocumentsContract.Document.MIME_TYPE_DIR),
                "size" to if (cursor.isNull(2)) null else cursor.getLong(2),
            ))
            output.sortedWith(compareBy({ it["directory"] != true }, { (it["name"] as String).lowercase() }))
        }
    }

    fun importFiles(context: Context, root: String, uris: List<Uri>): List<String> {
        val names = mutableListOf<String>()
        for (source in uris) {
            var name = source.lastPathSegment ?: "项目资料"
            var size: Long? = null
            context.contentResolver.query(source, arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE), null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    name = cursor.getString(0)
                    if (!cursor.isNull(1)) size = cursor.getLong(1)
                }
            }
            require(size == null || size!! <= 100L * 1024 * 1024) { "$name 超过 100 MB" }
            val mime = context.contentResolver.getType(source) ?: "application/octet-stream"
            context.contentResolver.openInputStream(source)!!.use { input ->
                if (root.startsWith("aurai://")) {
                    val folder = ManagedWorkspace.root(context, Uri.parse(root).pathSegments.first())
                    val target = uniqueFile(folder, name)
                    target.outputStream().use { output -> input.copyTo(output) }
                    name = target.name
                } else {
                    val tree = Uri.parse(root)
                    val parent = DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))
                    val target = DocumentsContract.createDocument(context.contentResolver, parent, mime, name)
                        ?: error("无法添加 $name")
                    context.contentResolver.openOutputStream(target)!!.use { output -> input.copyTo(output) }
                }
            }
            names.add(name)
        }
        return names
    }

    fun open(context: Context, root: String) {
        if (!root.startsWith("aurai://")) return
        val folder = ManagedWorkspace.file(context, root)
        val relative = folder.canonicalFile.relativeTo(File(context.filesDir, "projects").canonicalFile).invariantSeparatorsPath
        val documentId = "${ManagedWorkspaceDocumentsProvider.ROOT_ID}/$relative"
        val uri = DocumentsContract.buildDocumentUri("${context.packageName}.managed_workspaces", documentId)
        context.startActivity(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            setClassName("com.android.documentsui", "com.android.documentsui.picker.PickActivity")
            type = "*/*"
            addCategory(Intent.CATEGORY_OPENABLE)
            putExtra(DocumentsContract.EXTRA_INITIAL_URI, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        })
    }

    private fun uniqueFile(folder: File, original: String): File {
        val stem = original.substringBeforeLast('.', original)
        val extension = original.substringAfterLast('.', "").let { if (it.isEmpty()) "" else ".$it" }
        var target = File(folder, original)
        var index = 2
        while (target.exists()) target = File(folder, "$stem ($index)$extension").also { index++ }
        return target
    }
}
