package com.haiskynology.aurai

import android.database.Cursor
import android.database.MatrixCursor
import android.os.CancellationSignal
import android.os.ParcelFileDescriptor
import android.provider.DocumentsContract.Document
import android.provider.DocumentsContract.Root
import android.provider.DocumentsProvider
import android.webkit.MimeTypeMap
import java.io.File

class ManagedWorkspaceDocumentsProvider : DocumentsProvider() {
    override fun onCreate(): Boolean {
        val root = File(context!!.filesDir, "projects")
        return root.exists() || root.mkdirs()
    }

    override fun queryRoots(projection: Array<out String>?): Cursor {
        val columns = projection ?: ROOT_COLUMNS
        return MatrixCursor(columns).apply {
            val root = workspaceRoot()
            newRow().apply {
                add(Root.COLUMN_ROOT_ID, ROOT_ID)
                add(Root.COLUMN_DOCUMENT_ID, ROOT_ID)
                add(Root.COLUMN_TITLE, "Aurai 工作区")
                add(Root.COLUMN_SUMMARY, "项目与 Git 工作树")
                add(Root.COLUMN_FLAGS, Root.FLAG_LOCAL_ONLY or Root.FLAG_SUPPORTS_CREATE or Root.FLAG_SUPPORTS_IS_CHILD)
                add(Root.COLUMN_ICON, R.mipmap.ic_aurai_brand)
                add(Root.COLUMN_AVAILABLE_BYTES, root.usableSpace)
            }
        }
    }

    override fun queryDocument(documentId: String, projection: Array<out String>?): Cursor =
        MatrixCursor(projection ?: DOCUMENT_COLUMNS).apply { include(resolve(documentId)) }

    override fun queryChildDocuments(
        parentDocumentId: String,
        projection: Array<out String>?,
        sortOrder: String?,
    ): Cursor = MatrixCursor(projection ?: DOCUMENT_COLUMNS).apply {
        resolve(parentDocumentId).listFiles()!!
            .sortedWith(compareBy<File>({ !it.isDirectory }, { it.name.lowercase() }))
            .forEach { include(it) }
    }

    override fun openDocument(
        documentId: String,
        mode: String,
        signal: CancellationSignal?,
    ): ParcelFileDescriptor = ParcelFileDescriptor.open(resolve(documentId), ParcelFileDescriptor.parseMode(mode))

    override fun createDocument(parentDocumentId: String, mimeType: String, displayName: String): String {
        val parent = resolve(parentDocumentId)
        require(parent != workspaceRoot()) { "不能在工作区根目录创建文件" }
        val file = File(parent, displayName)
        require(if (mimeType == Document.MIME_TYPE_DIR) file.mkdir() else file.createNewFile()) { "无法创建文件" }
        return documentId(file)
    }

    override fun deleteDocument(documentId: String) {
        val file = resolve(documentId)
        require(file.parentFile != workspaceRoot()) { "不能删除项目目录" }
        require(if (file.isDirectory) file.deleteRecursively() else file.delete()) { "无法删除文件" }
    }

    override fun renameDocument(documentId: String, displayName: String): String {
        val file = resolve(documentId)
        require(file.parentFile != workspaceRoot()) { "不能重命名项目目录" }
        val target = File(file.parentFile, displayName)
        require(file.renameTo(target)) { "无法重命名文件" }
        return documentId(target)
    }

    override fun isChildDocument(parentDocumentId: String, documentId: String): Boolean {
        val parent = resolve(parentDocumentId)
        val child = resolve(documentId)
        return child != parent && child.path.startsWith(parent.path + File.separator)
    }

    override fun getDocumentType(documentId: String): String = mimeType(resolve(documentId))

    private fun MatrixCursor.include(file: File) {
        newRow().apply {
            add(Document.COLUMN_DOCUMENT_ID, documentId(file))
            add(Document.COLUMN_DISPLAY_NAME, if (file == workspaceRoot()) "Aurai 工作区" else file.name)
            add(Document.COLUMN_MIME_TYPE, mimeType(file))
            add(Document.COLUMN_LAST_MODIFIED, file.lastModified())
            add(Document.COLUMN_SIZE, if (file.isFile) file.length() else null)
            val flags = when {
                file == workspaceRoot() -> 0
                file.parentFile == workspaceRoot() -> Document.FLAG_DIR_SUPPORTS_CREATE
                file.isDirectory -> Document.FLAG_SUPPORTS_RENAME or Document.FLAG_SUPPORTS_DELETE or
                    Document.FLAG_DIR_SUPPORTS_CREATE
                else -> Document.FLAG_SUPPORTS_RENAME or Document.FLAG_SUPPORTS_DELETE or
                    Document.FLAG_SUPPORTS_WRITE
            }
            add(Document.COLUMN_FLAGS, flags)
        }
    }

    private fun mimeType(file: File): String = if (file.isDirectory) {
        Document.MIME_TYPE_DIR
    } else {
        MimeTypeMap.getSingleton().getMimeTypeFromExtension(file.extension.lowercase()) ?: "application/octet-stream"
    }

    private fun workspaceRoot(): File = File(providerContext().filesDir, "projects").canonicalFile

    private fun documentId(file: File): String {
        val relative = file.canonicalFile.relativeTo(workspaceRoot()).invariantSeparatorsPath
        return if (relative == ".") ROOT_ID else "$ROOT_ID/$relative"
    }

    private fun resolve(documentId: String): File {
        require(documentId == ROOT_ID || documentId.startsWith("$ROOT_ID/")) { "目录链接无效" }
        val root = workspaceRoot()
        val relative = documentId.removePrefix(ROOT_ID).removePrefix("/")
        val file = if (relative.isEmpty()) root else File(root, relative).canonicalFile
        require(file.path == root.path || file.path.startsWith(root.path + File.separator)) { "目录超出工作区" }
        require(file.exists()) { "目录已移动或删除" }
        return file
    }

    private fun providerContext() = context!!

    companion object {
        const val ROOT_ID = "projects"
        val ROOT_COLUMNS = arrayOf(
            Root.COLUMN_ROOT_ID,
            Root.COLUMN_DOCUMENT_ID,
            Root.COLUMN_TITLE,
            Root.COLUMN_SUMMARY,
            Root.COLUMN_FLAGS,
            Root.COLUMN_ICON,
            Root.COLUMN_AVAILABLE_BYTES,
        )
        val DOCUMENT_COLUMNS = arrayOf(
            Document.COLUMN_DOCUMENT_ID,
            Document.COLUMN_DISPLAY_NAME,
            Document.COLUMN_MIME_TYPE,
            Document.COLUMN_LAST_MODIFIED,
            Document.COLUMN_FLAGS,
            Document.COLUMN_SIZE,
        )
    }
}
