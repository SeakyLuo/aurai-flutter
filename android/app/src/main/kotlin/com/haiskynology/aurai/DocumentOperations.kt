package com.haiskynology.aurai

import android.content.Context
import android.net.Uri
import android.provider.DocumentsContract as Docs
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.text.PDFTextStripper
import org.json.JSONObject
import java.io.FileNotFoundException
import java.nio.charset.CodingErrorAction
import java.nio.charset.Charset

class DocumentOperations(private val context: Context) {
    private val resolver = context.contentResolver
    private val dates = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", java.util.Locale.ROOT)
        .apply { timeZone = java.util.TimeZone.getTimeZone("UTC") }
    private val projection = arrayOf(Docs.Document.COLUMN_DOCUMENT_ID, Docs.Document.COLUMN_DISPLAY_NAME,
        Docs.Document.COLUMN_MIME_TYPE, Docs.Document.COLUMN_SIZE, Docs.Document.COLUMN_LAST_MODIFIED,
        Docs.Document.COLUMN_FLAGS)

    fun metadata(uri: Uri): Map<String, Any?> = resolver.query(uri, projection, null, null, null)!!.use { cursor ->
        if (!cursor.moveToFirst()) throw FileNotFoundException("文件已移动、删除或无法访问")
        row(cursor, uri)
    }

    private fun row(cursor: android.database.Cursor, tree: Uri): Map<String, Any?> {
        val id = cursor.getString(0)
        return mapOf("url" to Docs.buildDocumentUriUsingTree(tree, id).toString(),
            "title" to cursor.getString(1), "mimeType" to cursor.getString(2),
            "directory" to (cursor.getString(2) == Docs.Document.MIME_TYPE_DIR),
            "size" to if (cursor.isNull(3)) null else cursor.getLong(3),
            "modifiedAt" to if (cursor.isNull(4) || cursor.getLong(4) == 0L) null
                else dates.format(java.util.Date(cursor.getLong(4))),
            "canCreate" to (cursor.getInt(5) and Docs.Document.FLAG_DIR_SUPPORTS_CREATE != 0))
    }

    fun execute(operation: String, args: JSONObject, created: (String) -> Unit): Map<String, Any?> {
        if (operation == "copyDocument" || operation == "moveDocument") {
            return DocumentTransfer(context).execute(operation, args)
        }
        if (args.getString("uri").startsWith("aurai://")) return ManagedWorkspace(context).execute(operation, args)
        val uri = DocumentUris.authorized(context, args.getString("uri"), operation in setOf(
            "createTextFile", "prepareTextFile", "writeTextFile", "replaceText", "createFolder", "renameDocument", "deleteDocument"))
        return when (operation) {
            "describeDocument" -> metadata(uri)
            "prepareTextFile" -> {
                validateFile(args)
                val info = metadata(uri)
                require(info["directory"] == true && info["canCreate"] == true) { "此文件夹不支持创建文件" }
                val root = DocumentUris.tree(uri).toString()
                val folder = DocumentFolders(context).list().single { it["uri"] == root }
                info + mapOf("folderLabel" to if (Docs.getDocumentId(uri) == Docs.getTreeDocumentId(uri))
                    folder["name"] else "${folder["name"]} / ${info["title"]}")
            }
            "listFiles", "searchFiles" -> list(uri, args, operation == "searchFiles")
            "listProjectTree" -> tree(uri, args)
            "searchProjectText" -> searchText(uri, args)
            "readDocument" -> read(uri, args)
            "createTextFile" -> write(uri, args, created)
            "writeTextFile" -> overwrite(uri, args)
            "replaceText" -> replaceText(uri, args)
            "createFolder" -> createFolder(uri, args)
            "renameDocument" -> rename(uri, args)
            "deleteDocument" -> delete(uri)
            else -> error("不支持的文件操作")
        }
    }

    private fun overwrite(uri: Uri, args: JSONObject): Map<String, Any?> {
        val info = metadata(uri)
        require(info["directory"] == false) { "请选择文件，不能覆盖文件夹" }
        val content = args.getString("content")
        require(content.length <= MAX_WRITE_CHARACTERS) { "单次最多写入 $MAX_WRITE_CHARACTERS 字" }
        resolver.openOutputStream(uri, "wt")!!.use { it.write(content.toByteArray(Charsets.UTF_8)) }
        return metadata(uri) + mapOf("written" to true, "encoding" to "UTF-8")
    }

    private fun replaceText(uri: Uri, args: JSONObject): Map<String, Any?> {
        val bytes = resolver.openInputStream(uri)!!.use { LimitedInput(it).readBytes() }
        val text = bytes.toString(Charsets.UTF_8)
        val old = args.getString("oldText")
        val first = text.indexOf(old)
        require(first >= 0) { "没有找到要替换的内容" }
        require(text.indexOf(old, first + old.length) < 0) { "要替换的内容出现了多次，请提供更多上下文" }
        val updated = text.replaceRange(first, first + old.length, args.getString("newText"))
        require(updated.length <= MAX_WRITE_CHARACTERS) { "修改后的文件超过单次写入上限" }
        resolver.openOutputStream(uri, "wt")!!.use { it.write(updated.toByteArray(Charsets.UTF_8)) }
        return metadata(uri) + mapOf("written" to true, "encoding" to "UTF-8")
    }

    private fun createFolder(uri: Uri, args: JSONObject): Map<String, Any?> {
        val folder = Docs.createDocument(resolver, uri, Docs.Document.MIME_TYPE_DIR, validName(args.getString("name")))
            ?: error("文件提供者未能创建文件夹")
        return metadata(folder) + mapOf("created" to true)
    }

    private fun rename(uri: Uri, args: JSONObject): Map<String, Any?> {
        val renamed = Docs.renameDocument(resolver, uri, validName(args.getString("name")))
            ?: error("文件提供者不支持重命名")
        return metadata(renamed) + mapOf("renamed" to true)
    }

    private fun delete(uri: Uri): Map<String, Any?> {
        require(Docs.getDocumentId(uri) != Docs.getTreeDocumentId(uri)) { "不能删除项目根目录" }
        require(Docs.deleteDocument(resolver, uri)) { "文件提供者未能删除此文件" }
        return mapOf("deleted" to true)
    }

    private fun validName(value: String): String {
        require(value.isNotBlank() && value.length <= 120 && value !in setOf(".", "..") &&
            value.none { it == '/' || it == '\\' || it.code < 32 }) { "名称无效" }
        return value
    }

    private fun list(uri: Uri, args: JSONObject, search: Boolean): Map<String, Any?> {
        val offset = args.getInt("offset")
        val limit = args.getInt("limit")
        require(offset in 0..100000 && limit in 1..100)
        val query = if (search) args.getString("query") else ""
        require(query.length <= 120)
        val children = Docs.buildChildDocumentsUriUsingTree(uri, Docs.getDocumentId(uri))
        val results = mutableListOf<Map<String, Any?>>()
        var scanned = 0
        var more: Boolean
        resolver.query(children, projection, null, null, null)!!.use { cursor ->
            cursor.moveToPosition(offset - 1)
            while (scanned < 2000 && results.size < limit && cursor.moveToNext()) {
                scanned++
                if (cursor.getString(1).contains(query, ignoreCase = true)) {
                    results.add(row(cursor, uri) + mapOf("parentUrl" to uri.toString()))
                }
            }
            more = cursor.moveToNext()
        }
        val scanLimitReached = more && offset + scanned > 100000
        return mapOf("results" to results,
            "nextOffset" to if (more && !scanLimitReached) offset + scanned else null,
            "partial" to more, "scanLimitReached" to scanLimitReached,
            "scanned" to scanned, "scope" to "仅当前文件夹，不递归搜索子文件夹。分页期间文件夹发生变化可能影响结果顺序。scanLimitReached 为 true 时已达扫描上限，不能继续分页，也不能认定已搜索全部文件。")
    }

    private data class WalkEntry(val uri: Uri, val path: String, val info: Map<String, Any?>, val depth: Int)

    private fun walk(root: Uri, maxDepth: Int, maxFiles: Int): Pair<List<WalkEntry>, Boolean> {
        val queue = java.util.ArrayDeque<WalkEntry>()
        queue.add(WalkEntry(root, "", metadata(root), 0))
        val results = mutableListOf<WalkEntry>()
        while (queue.isNotEmpty() && results.size <= maxFiles) {
            val folder = queue.removeFirst()
            val children = Docs.buildChildDocumentsUriUsingTree(folder.uri, Docs.getDocumentId(folder.uri))
            resolver.query(children, projection, null, null, null)!!.use { cursor ->
                while (cursor.moveToNext() && results.size <= maxFiles) {
                    val title = cursor.getString(1)
                    if (title == ".git") continue
                    val info = row(cursor, root)
                    val path = if (folder.path.isEmpty()) title else "${folder.path}/$title"
                    val entry = WalkEntry(Uri.parse(info["url"] as String), path, info, folder.depth + 1)
                    results.add(entry)
                    if (info["directory"] == true && entry.depth < maxDepth) queue.add(entry)
                }
            }
        }
        return results.take(maxFiles) to (results.size > maxFiles || queue.isNotEmpty())
    }

    private fun tree(uri: Uri, args: JSONObject): Map<String, Any?> {
        val offset = args.getInt("offset")
        val limit = args.getInt("limit")
        val (entries, limited) = walk(uri, args.getInt("maxDepth"), MAX_TREE_ENTRIES)
        val page = entries.drop(offset).take(limit).map { it.info + mapOf("path" to it.path) }
        val more = offset + page.size < entries.size
        return mapOf("results" to page, "nextOffset" to if (more) offset + page.size else null,
            "partial" to (more || limited), "scanLimitReached" to limited)
    }

    private fun searchText(uri: Uri, args: JSONObject): Map<String, Any?> {
        val query = args.getString("query")
        val offset = args.getInt("offset")
        val limit = args.getInt("limit")
        val matchCap = offset + limit + 1
        val (entries, limited) = walk(uri, args.getInt("maxDepth"), MAX_SEARCH_FILES)
        val matches = mutableListOf<Map<String, Any?>>()
        var scanned = 0
        for (entry in entries) {
            if (entry.info["directory"] == true || !searchable(entry.path)) continue
            val size = entry.info["size"] as Long?
            if (size != null && size > MAX_SEARCH_BYTES) continue
            scanned++
            resolver.openInputStream(entry.uri)!!.bufferedReader(Charsets.UTF_8).useLines { lines ->
                lines.forEachIndexed { index, line -> if (matches.size < matchCap && line.contains(query, true)) {
                    matches.add(entry.info + mapOf("path" to entry.path, "line" to index + 1,
                        "preview" to line.take(500)))
                } }
            }
        }
        val page = matches.drop(offset).take(limit)
        val more = offset + page.size < matches.size
        return mapOf("results" to page, "nextOffset" to if (more) offset + page.size else null,
            "partial" to (more || limited), "scanLimitReached" to limited, "scannedFiles" to scanned)
    }

    private fun searchable(name: String): Boolean = name.substringAfterLast('.', "").lowercase() in setOf(
        "txt", "md", "csv", "tsv", "log", "json", "yaml", "yml", "xml", "html", "css", "scss",
        "kt", "kts", "dart", "java", "py", "js", "jsx", "ts", "tsx", "c", "cc", "cpp", "h", "hpp",
        "swift", "gradle", "properties", "toml", "sh", "sql")

    private fun read(uri: Uri, args: JSONObject): Map<String, Any?> {
        val info = metadata(uri)
        require(info["directory"] == false) { "请选择文件；文件夹请使用 listFiles" }
        val size = info["size"] as Long?
        require(size == null || size <= MAX_BYTES) { "暂时只支持读取 10 MB 以内的文件" }
        val mime = info["mimeType"] as String
        return if (mime == "application/pdf" || (info["title"] as String).endsWith(".pdf", true)) {
            readPdf(uri, info, args)
        } else {
            val extension = (info["title"] as String).substringAfterLast('.', "").lowercase()
            require(mime.startsWith("text/") || mime in setOf("application/json", "application/xml") ||
                extension in setOf("txt", "md", "csv", "tsv", "log", "json", "yaml", "yml", "xml", "html", "kt", "kts", "dart", "java", "py", "js", "jsx", "ts", "tsx", "css", "scss", "c", "cc", "cpp", "h", "hpp", "swift", "gradle", "properties", "toml", "sh")) {
                "暂时支持文本文件和 PDF，不支持直接读取此格式"
            }
            val offset = args.getInt("offset")
            val limit = args.getInt("maxCharacters")
            require(offset in 0..MAX_BYTES && limit in 2..20000)
            val encoding = args.getString("encoding")
            require(encoding in setOf("UTF-8", "UTF-16LE", "UTF-16BE", "GB18030"))
            val decoder = Charset.forName(encoding).newDecoder().onMalformedInput(CodingErrorAction.REPORT)
                .onUnmappableCharacter(CodingErrorAction.REPORT)
            val text = StringBuilder()
            var skipped = 0
            resolver.openInputStream(uri)!!.use { raw ->
                java.io.InputStreamReader(LimitedInput(raw), decoder).use { reader ->
                    val buffer = CharArray(4096)
                    while (skipped < offset) {
                        val count = reader.read(buffer, 0, minOf(buffer.size, offset - skipped))
                        if (count < 0) break
                        skipped += count
                    }
                    while (text.length <= limit) {
                        val count = reader.read(buffer, 0, minOf(buffer.size, limit + 1 - text.length))
                        if (count < 0) break
                        text.append(buffer, 0, count)
                    }
                }
            }
            val more = text.length > limit
            val kept = if (more && text[limit - 1].isHighSurrogate()) limit - 1 else minOf(limit, text.length)
            info + mapOf("text" to text.take(kept).toString(), "offset" to offset,
                "nextOffset" to if (more) offset + kept else null, "partial" to (more || offset > 0),
                "encoding" to encoding, "sourceRead" to text.isNotBlank())
        }
    }

    private fun readPdf(uri: Uri, info: Map<String, Any?>, args: JSONObject): Map<String, Any?> {
        val start = args.getInt("startPage")
        val count = args.getInt("pageCount")
        val offset = args.getInt("offset")
        val limit = args.getInt("maxCharacters")
        require(start in 1..100000 && count in 1..10 && offset in 0..MAX_BYTES && limit in 2..20000)
        PDFBoxResourceLoader.init(context)
        val bytes = resolver.openInputStream(uri)!!.use { LimitedInput(it).readBytes() }
        PDDocument.load(bytes).use { document ->
            require(document.currentAccessPermission.canExtractContent()) { "此 PDF 不允许提取文字" }
            require(start <= document.numberOfPages) { "起始页超过 PDF 总页数" }
            val end = minOf(document.numberOfPages, start + count - 1)
            val writer = PageTextWriter(offset, limit)
            val stripper = PDFTextStripper().apply { startPage = start; endPage = end; sortByPosition = true }
            try { stripper.writeText(document, writer) } catch (_: TextLimitReached) { }
            if (writer.truncated && writer.text.lastOrNull()?.isHighSurrogate() == true) writer.text.setLength(writer.text.length - 1)
            return info + mapOf("text" to writer.text.toString(), "startPage" to start, "endPage" to end,
                "totalPages" to document.numberOfPages, "offset" to offset,
                "nextOffset" to if (writer.truncated) offset + writer.text.length else null,
                "nextPage" to if (!writer.truncated && end < document.numberOfPages) end + 1 else null,
                "partial" to (writer.truncated || end < document.numberOfPages || start > 1 || offset > 0),
                "sourceRead" to writer.text.isNotBlank(),
                "notice" to if (writer.text.isBlank()) "所选页段未提取到文字；可能是扫描页或已到文字末尾，不能据此推断文档内容。" else "仅提取所选页段的文字，不包含图片内容。")
        }
    }

    private fun write(uri: Uri, args: JSONObject, created: (String) -> Unit): Map<String, Any?> {
        val folder = metadata(uri)
        require(folder["directory"] == true && folder["canCreate"] == true) { "此文件夹不支持创建文件" }
        val mime = validateFile(args)
        val name = args.getString("fileName")
        val content = args.getString("content")
        val file = Docs.createDocument(resolver, uri, mime, name) ?: error("文件提供者未能创建文件")
        created(file.toString())
        try {
            resolver.openOutputStream(file, "w")!!.use { it.write(content.toByteArray(Charsets.UTF_8)) }
        } catch (error: Exception) {
            try { Docs.deleteDocument(resolver, file) } catch (_: Exception) {
                throw java.io.IOException("写入失败，可能留下不完整文件，请查看目标文件夹后再操作", error)
            }
            throw error
        }
        return metadata(file) + mapOf("created" to true, "encoding" to "UTF-8", "sourceRead" to false)
    }

    private fun validateFile(args: JSONObject): String {
        val name = args.getString("fileName")
        require(name.isNotBlank() && name.length <= 120 && name !in setOf(".", "..") &&
            name.none { it == '/' || it == '\\' || it.code < 32 }) { "请提供有效的文件名，不要包含路径" }
        val content = args.getString("content")
        require(content.length <= MAX_WRITE_CHARACTERS) { "单次最多保存 $MAX_WRITE_CHARACTERS 字" }
        return when (name.substringAfterLast('.', "").lowercase()) {
            "md" -> "text/markdown"; "csv" -> "text/csv"; "json" -> "application/json"
            "txt", "log", "yaml", "yml", "xml", "html", "tsv" -> "text/plain"
            else -> error("请选择 txt、md、csv、json、yaml、xml、html 或 tsv 等文本文件格式")
        }
    }

    private class LimitedInput(input: java.io.InputStream) : java.io.FilterInputStream(input) {
        private var count = 0L
        override fun read(): Int = super.read().also { if (it >= 0) checkSize(1) }
        override fun read(bytes: ByteArray, offset: Int, length: Int): Int = `in`.read(bytes, offset, minOf(length, (MAX_BYTES - count + 1).toInt()))
            .also { if (it > 0) checkSize(it) }
        private fun checkSize(size: Int) { count += size; require(count <= MAX_BYTES) { "文件超过 10 MB，暂时无法读取" } }
    }
    private class TextLimitReached : java.io.IOException()
    private class PageTextWriter(private val offset: Int, private val limit: Int) : java.io.Writer() {
        val text = StringBuilder()
        var truncated = false
        private var position = 0
        override fun write(chars: CharArray, start: Int, length: Int) {
            val skip = minOf(length, (offset - position).coerceAtLeast(0))
            position += length
            val take = minOf(length - skip, limit - text.length)
            text.append(chars, start + skip, take)
            if (take < length - skip) { truncated = true; throw TextLimitReached() }
        }
        override fun flush() = Unit
        override fun close() = Unit
    }
    companion object {
        private const val MAX_BYTES = 10 * 1024 * 1024
        private const val MAX_WRITE_CHARACTERS = 500000
        private const val MAX_TREE_ENTRIES = 5000
        private const val MAX_SEARCH_FILES = 2000
        private const val MAX_SEARCH_BYTES = 2 * 1024 * 1024L
    }
}
