package com.haiskynology.aurai

import android.content.Context
import android.net.Uri
import android.webkit.MimeTypeMap
import org.json.JSONObject
import java.io.File

class ManagedWorkspace(private val context: Context) {
    fun execute(operation: String, args: JSONObject): Map<String, Any?> {
        val file = resolve(Uri.parse(args.getString("uri")))
        return when (operation) {
            "describeDocument" -> metadata(file)
            "prepareTextFile" -> {
                require(file.isDirectory) { "请选择文件夹" }
                metadata(file) + mapOf("folderLabel" to file.name)
            }
            "listFiles", "searchFiles" -> list(file, args, operation == "searchFiles")
            "listProjectTree" -> tree(file, args)
            "searchProjectText" -> searchText(file, args)
            "readDocument" -> read(file, args)
            "createTextFile" -> createText(file, args)
            "writeTextFile" -> writeText(file, args)
            "replaceText" -> replaceText(file, args)
            "createFolder" -> createFolder(file, args)
            "renameDocument" -> rename(file, args)
            "deleteDocument" -> delete(file)
            else -> error("不支持的项目文件操作")
        }
    }

    private fun projectRoot(id: String): File {
        require(id.matches(Regex("[A-Za-z0-9_-]{1,80}"))) { "项目标识无效" }
        return File(context.filesDir, "projects/$id")
    }

    private fun resolve(uri: Uri): File {
        require(uri.scheme == "aurai" && uri.authority == "project") { "项目文件链接无效" }
        val parts = uri.pathSegments
        require(parts.isNotEmpty()) { "项目文件链接无效" }
        val root = projectRoot(parts.first()).canonicalFile
        val file = parts.drop(1).fold(root) { parent, name -> File(parent, name) }.canonicalFile
        require(file.path == root.path || file.path.startsWith(root.path + File.separator)) { "文件超出项目目录" }
        require(file.exists()) { "文件已移动或删除" }
        return file
    }

    private fun uri(file: File): String {
        val projects = File(context.filesDir, "projects").canonicalFile
        val relative = file.canonicalFile.relativeTo(projects).invariantSeparatorsPath.split('/')
        return Uri.Builder().scheme("aurai").authority("project").apply {
            relative.forEach { appendPath(it) }
        }.build().toString()
    }

    private fun metadata(file: File): Map<String, Any?> = mapOf(
        "url" to uri(file),
        "title" to file.name,
        "mimeType" to if (file.isDirectory) "vnd.android.document/directory" else
            (MimeTypeMap.getSingleton().getMimeTypeFromExtension(file.extension.lowercase()) ?: "application/octet-stream"),
        "directory" to file.isDirectory,
        "size" to if (file.isFile) file.length() else null,
        "modifiedAt" to file.lastModified(),
        "canCreate" to file.isDirectory,
    )

    private fun list(folder: File, args: JSONObject, search: Boolean): Map<String, Any?> {
        require(folder.isDirectory) { "请选择文件夹" }
        val offset = args.getInt("offset")
        val limit = args.getInt("limit")
        val query = if (search) args.getString("query") else ""
        val children = folder.listFiles()!!.sortedWith(compareBy<File>({ !it.isDirectory }, { it.name.lowercase() }))
            .filter { !search || it.name.contains(query, ignoreCase = true) }
        val page = children.drop(offset).take(limit)
        return mapOf(
            "results" to page.map { metadata(it) + mapOf("parentUrl" to uri(folder)) },
            "nextOffset" to if (offset + page.size < children.size) offset + page.size else null,
            "partial" to (offset + page.size < children.size),
            "scanLimitReached" to false,
            "scanned" to children.size,
            "scope" to "仅当前文件夹，不递归搜索子文件夹。",
        )
    }

    private fun tree(folder: File, args: JSONObject): Map<String, Any?> {
        require(folder.isDirectory) { "请选择文件夹" }
        val offset = args.getInt("offset")
        val limit = args.getInt("limit")
        val root = folder.canonicalFile
        val entries = root.walkTopDown().maxDepth(args.getInt("maxDepth"))
            .onEnter { it == root || it.name != ".git" }.drop(1)
            .take(MAX_TREE_ENTRIES + 1)
            .map { metadata(it) + mapOf("path" to it.relativeTo(root).invariantSeparatorsPath) }
            .toList()
        val page = entries.drop(offset).take(limit)
        val more = offset + page.size < entries.size
        return mapOf("results" to page,
            "nextOffset" to if (more && offset + page.size < MAX_TREE_ENTRIES) offset + page.size else null,
            "partial" to more, "scanLimitReached" to (entries.size > MAX_TREE_ENTRIES))
    }

    private fun searchText(folder: File, args: JSONObject): Map<String, Any?> {
        require(folder.isDirectory) { "请选择文件夹" }
        val query = args.getString("query")
        val offset = args.getInt("offset")
        val limit = args.getInt("limit")
        val matchCap = offset + limit + 1
        val root = folder.canonicalFile
        val matches = mutableListOf<Map<String, Any?>>()
        var scanned = 0
        root.walkTopDown().maxDepth(args.getInt("maxDepth"))
            .onEnter { it == root || it.name != ".git" }
            .filter { it.isFile && it.length() <= MAX_SEARCH_BYTES && searchable(it.name) }
            .take(MAX_SEARCH_FILES + 1).forEach { file ->
                scanned++
                if (scanned <= MAX_SEARCH_FILES) file.useLines(Charsets.UTF_8) { lines ->
                    lines.forEachIndexed { index, line -> if (matches.size < matchCap && line.contains(query, true)) {
                        matches.add(metadata(file) + mapOf("path" to file.relativeTo(root).invariantSeparatorsPath,
                            "line" to index + 1, "preview" to line.take(500)))
                    } }
                }
            }
        val page = matches.drop(offset).take(limit)
        val more = offset + page.size < matches.size
        return mapOf("results" to page, "nextOffset" to if (more) offset + page.size else null,
            "partial" to (more || scanned > MAX_SEARCH_FILES),
            "scanLimitReached" to (scanned > MAX_SEARCH_FILES),
            "scannedFiles" to minOf(scanned, MAX_SEARCH_FILES))
    }

    private fun searchable(name: String): Boolean = name.substringAfterLast('.', "").lowercase() in setOf(
        "txt", "md", "csv", "tsv", "log", "json", "yaml", "yml", "xml", "html", "css", "scss",
        "kt", "kts", "dart", "java", "py", "js", "jsx", "ts", "tsx", "c", "cc", "cpp", "h", "hpp",
        "swift", "gradle", "properties", "toml", "sh", "sql")

    private fun read(file: File, args: JSONObject): Map<String, Any?> {
        require(file.isFile && file.length() <= MAX_BYTES) { "暂时只支持读取 10 MB 以内的文件" }
        val text = file.readText(Charsets.UTF_8)
        val offset = args.getInt("offset")
        val limit = args.getInt("maxCharacters")
        require(offset <= text.length) { "读取位置超过文件末尾" }
        val end = minOf(text.length, offset + limit)
        return metadata(file) + mapOf(
            "text" to text.substring(offset, end),
            "offset" to offset,
            "nextOffset" to if (end < text.length) end else null,
            "partial" to (offset > 0 || end < text.length),
            "encoding" to "UTF-8",
            "sourceRead" to text.isNotBlank(),
        )
    }

    private fun createText(folder: File, args: JSONObject): Map<String, Any?> {
        require(folder.isDirectory) { "请选择文件夹" }
        val file = File(folder, validName(args.getString("fileName")))
        require(!file.exists()) { "同名文件已经存在" }
        return write(file, args.getString("content"), "created")
    }

    private fun writeText(file: File, args: JSONObject): Map<String, Any?> {
        require(file.isFile) { "请选择文件" }
        return write(file, args.getString("content"), "written")
    }

    private fun replaceText(file: File, args: JSONObject): Map<String, Any?> {
        require(file.isFile && file.length() <= MAX_BYTES) { "暂时只支持修改 10 MB 以内的文件" }
        val text = file.readText(Charsets.UTF_8)
        val old = args.getString("oldText")
        val first = text.indexOf(old)
        require(first >= 0) { "没有找到要替换的内容" }
        require(text.indexOf(old, first + old.length) < 0) { "要替换的内容出现了多次，请提供更多上下文" }
        return write(file, text.replaceRange(first, first + old.length, args.getString("newText")), "written")
    }

    private fun write(file: File, content: String, resultKey: String): Map<String, Any?> {
        require(content.length <= MAX_WRITE_CHARACTERS) { "单次最多写入 $MAX_WRITE_CHARACTERS 字" }
        file.writeText(content, Charsets.UTF_8)
        return metadata(file) + mapOf(resultKey to true, "encoding" to "UTF-8")
    }

    private fun createFolder(parent: File, args: JSONObject): Map<String, Any?> {
        require(parent.isDirectory) { "请选择文件夹" }
        val folder = File(parent, validName(args.getString("name")))
        require(folder.mkdir()) { "文件夹创建失败或同名文件夹已存在" }
        return metadata(folder) + mapOf("created" to true)
    }

    private fun rename(file: File, args: JSONObject): Map<String, Any?> {
        val id = Uri.parse(uri(file)).pathSegments.first()
        require(file.canonicalFile != projectRoot(id).canonicalFile) { "不能重命名项目根目录" }
        val target = File(file.parentFile, validName(args.getString("name")))
        require(!target.exists() && file.renameTo(target)) { "重命名失败或同名文件已存在" }
        return metadata(target) + mapOf("renamed" to true)
    }

    private fun delete(file: File): Map<String, Any?> {
        val id = Uri.parse(uri(file)).pathSegments.first()
        require(file.canonicalFile != projectRoot(id).canonicalFile) { "不能删除项目根目录" }
        require(if (file.isDirectory) file.deleteRecursively() else file.delete()) { "删除失败" }
        return mapOf("deleted" to true)
    }

    private fun validName(value: String): String {
        require(value.isNotBlank() && value.length <= 120 && value !in setOf(".", "..") &&
            value.none { it == '/' || it == '\\' || it.code < 32 }) { "名称无效" }
        return value
    }

    companion object {
        private const val MAX_BYTES = 10 * 1024 * 1024
        private const val MAX_WRITE_CHARACTERS = 500000
        private const val MAX_TREE_ENTRIES = 5000
        private const val MAX_SEARCH_FILES = 2000
        private const val MAX_SEARCH_BYTES = 2 * 1024 * 1024L

        fun create(context: Context, id: String, name: String): Map<String, Any?> {
            require(name.isNotBlank() && name.length <= 40) { "项目名称需要为 1–40 个字" }
            val folder = File(context.filesDir, "projects/$id")
            require(folder.mkdirs()) { "项目目录创建失败" }
            return mapOf(
                "uri" to Uri.Builder().scheme("aurai").authority("project").appendPath(id).build().toString(),
                "name" to name,
                "source" to "Aurai",
                "path" to name,
                "readable" to true,
                "writable" to true,
            )
        }

        fun root(context: Context, id: String): File {
            require(id.matches(Regex("[A-Za-z0-9_-]{1,80}"))) { "项目标识无效" }
            return File(context.filesDir, "projects/$id")
        }

        fun file(context: Context, value: String): File {
            val uri = Uri.parse(value)
            require(uri.scheme == "aurai" && uri.authority == "project") { "项目文件链接无效" }
            val parts = uri.pathSegments
            require(parts.isNotEmpty()) { "项目文件链接无效" }
            val root = root(context, parts.first()).canonicalFile
            val file = parts.drop(1).fold(root) { parent, name -> File(parent, name) }.canonicalFile
            require(file.path == root.path || file.path.startsWith(root.path + File.separator)) { "文件超出项目目录" }
            require(file.exists()) { "文件已移动或删除" }
            return file
        }

        fun url(context: Context, file: File): String {
            val projects = File(context.filesDir, "projects").canonicalFile
            val relative = file.canonicalFile.relativeTo(projects).invariantSeparatorsPath.split('/')
            return Uri.Builder().scheme("aurai").authority("project").apply {
                relative.forEach { appendPath(it) }
            }.build().toString()
        }

        fun remove(context: Context, id: String) {
            val folder = File(context.filesDir, "projects/$id")
            require(folder.deleteRecursively()) { "项目目录删除失败" }
        }
    }
}
