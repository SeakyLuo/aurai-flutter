package com.haiskynology.aurai

import android.content.Context
import android.util.Base64
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

/** Persistent files for one conversation; the Rhino scope itself is disposable. */
class ScriptWorkspace(context: Context, conversationId: String) {
    private val root = File(context.filesDir, "agent-workspaces/" + Base64.encodeToString(
        conversationId.toByteArray(Charsets.UTF_8), Base64.URL_SAFE or Base64.NO_WRAP,
    )).canonicalFile.apply { mkdirs(); require(isDirectory) { "无法创建工作目录" } }

    fun getDirectory(): String = root.path

    fun path(relativePath: String): String = resolve(relativePath).path

    fun writeText(relativePath: String, text: String): String = write(relativePath) {
        it.writeText(text, Charsets.UTF_8)
    }

    fun writeBase64(relativePath: String, data: String): String = write(relativePath) {
        it.writeBytes(Base64.decode(data, Base64.DEFAULT))
    }

    fun readText(relativePath: String): String {
        val file = resolve(relativePath)
        require(file.length() <= 1024 * 1024) { "文件超过 1 MB，请使用 Java 文件流分段读取" }
        return file.readText(Charsets.UTF_8)
    }

    fun list(relativeDirectory: String, offset: Int, limit: Int): String {
        require(offset >= 0 && limit in 1..100) { "offset 必须非负，limit 必须为 1–100" }
        val directory = if (relativeDirectory.isEmpty()) root else resolve(relativeDirectory)
        require(directory.isDirectory) { "目录不存在" }
        val entries = directory.listFiles()!!.sortedBy { it.name }
        return JSONObject().put("files", JSONArray(entries.drop(offset).take(limit).map {
            JSONObject().put("name", it.name).put("path", it.relativeTo(root).invariantSeparatorsPath)
                .put("directory", it.isDirectory).put("size", if (it.isFile) it.length() else 0)
        })).put("nextOffset", if (offset + limit < entries.size) offset + limit else JSONObject.NULL).toString()
    }

    fun zip(relativePath: String, pathsJson: String): String {
        val paths = JSONArray(pathsJson)
        require(paths.length() in 1..100) { "每次压缩 1–100 个文件" }
        val files = (0 until paths.length()).map { resolve(paths.getString(it)) }
        val destination = resolve(relativePath)
        require(files.all { it.isFile && it != destination }) { "压缩项必须是文件且不能包含输出文件" }
        return write(relativePath) { output ->
            ZipOutputStream(output.outputStream()).use { zip ->
                files.forEach { file ->
                    zip.putNextEntry(ZipEntry(file.relativeTo(root).invariantSeparatorsPath))
                    file.inputStream().use { it.copyTo(zip) }
                    zip.closeEntry()
                }
            }
        }
    }

    fun docx(relativePath: String, documentJson: String): String = write(relativePath) {
        OfficeDocuments.word(it, JSONObject(documentJson))
    }

    fun xlsx(relativePath: String, workbookJson: String): String = write(relativePath) {
        OfficeDocuments.spreadsheet(it, JSONObject(workbookJson))
    }

    fun help(): String = """
        workspace is a persistent per-conversation directory, not a restricted sandbox.
        getDirectory() -> absolute path; path(relativePath) -> absolute path inside workspace.
        writeText(path, text): UTF-8; writeBase64(path, base64): arbitrary bytes.
        readText(path): UTF-8 up to 1 MB; use Java streams for larger/binary files.
        list(relativeDirectory, offset, limit): JSON string, limit 1..100, empty directory means root.
        zip(outputPath, JSON.stringify(["a.md", "b.csv"])): pack up to 100 individual workspace files.
        docx(outputPath, JSON.stringify({title:"Report",blocks:[
          {type:"heading",level:1,text:"Section"}, {type:"paragraph",text:"Body"},
          {type:"bullets",items:["First","Second"]},
          {type:"table",rows:[["Name","Value"],["A","1"]]}
        ]})): real DOCX, basic headings/paragraphs/bullets/tables, A4 layout.
        xlsx(outputPath, JSON.stringify({sheets:[{name:"Sheet1",rows:[
          ["Item","Amount"],["A",12],["B",{formula:"SUM(B2:B2)"}]
        ]}]})): real XLSX; cells accept strings, finite numbers, booleans, null, or {formula:"..."} (without =).
        Writers replace the workspace output atomically and return the absolute path.
        Use Java/Android APIs for other formats, images and PDF. No npm, Node.js or DOM.
        Return only path/name/summary, never the whole binary file. Then call deliverFile with
        the returned path (or a relative workspace path) and display name to send an immutable attachment in this conversation.
        A written file is not delivered until deliverFile succeeds. Existing sent attachments never change.
    """.trimIndent()

    private fun resolve(relativePath: String): File {
        require(relativePath.isNotBlank() && !File(relativePath).isAbsolute) { "请使用工作目录内的相对路径" }
        val file = File(root, relativePath).canonicalFile
        require(file.path.startsWith(root.path + File.separator)) { "路径超出工作目录" }
        return file
    }

    private fun write(relativePath: String, action: (File) -> Unit): String {
        val output = resolve(relativePath)
        output.parentFile!!.mkdirs()
        val temporary = File.createTempFile(".writing-", ".tmp", output.parentFile)
        try {
            action(temporary)
            require(temporary.renameTo(output)) { "保存文件失败" }
        } finally {
            temporary.delete()
        }
        return output.path
    }
}
