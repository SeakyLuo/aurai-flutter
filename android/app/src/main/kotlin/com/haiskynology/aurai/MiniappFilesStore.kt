package com.haiskynology.aurai

import android.content.Context
import android.util.AtomicFile
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.InputStream
import java.io.ByteArrayOutputStream
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.zip.ZipInputStream

/** App-scoped libraries: small JSON metadata and streamed media, never base64 photos. */
object MiniappFilesStore {
    private val running = ConcurrentHashMap<String, JSONObject>()
    private val indexes = ConcurrentHashMap<String, Pair<String, JSONObject>>()
    private val mediaName = Regex("media/[A-Za-z0-9_-]+\\.(jpg|jpeg|png|webp|gif)")
    private const val MAX_INDEX = 16 * 1024 * 1024

    fun root(context: Context, appId: String): File {
        require(appId.matches(Regex("[A-Za-z0-9][A-Za-z0-9:._-]*"))) { "Invalid miniapp identifier" }
        return File(context.filesDir, "miniapp-libraries/$appId")
    }

    private fun atomic(file: File, value: JSONObject) {
        file.parentFile!!.mkdirs()
        val target = AtomicFile(file)
        val output = target.startWrite()
        try {
            output.write(value.toString().toByteArray(Charsets.UTF_8))
            target.finishWrite(output)
        } catch (error: Exception) {
            target.failWrite(output)
            throw error
        }
    }

    fun generation(context: Context, appId: String): String? {
        val pointer = File(root(context, appId), "current.json")
        return if (pointer.exists()) JSONObject(AtomicFile(pointer).openRead().bufferedReader().use { it.readText() }).getString("generation") else null
    }

    fun index(context: Context, appId: String): JSONObject? {
        val version = generation(context, appId) ?: return null
        indexes[appId]?.let { if (it.first == version) return it.second }
        val data = JSONObject(File(root(context, appId), "$version/library.json").readText())
        indexes[appId] = version to data
        return data
    }

    fun status(context: Context, appId: String): JSONObject {
        running[appId]?.let { return snapshot(it) }
        val saved = File(root(context, appId), "import.json")
        if (!saved.exists()) return JSONObject().put("phase", "idle")
        val state = JSONObject(AtomicFile(saved).openRead().bufferedReader().use { it.readText() })
        if (state.getString("phase") in listOf("extracting", "validating")) {
            if (generation(context, appId) == state.getString("jobId")) state.put("phase", "completed")
            else state.put("phase", "failed").put("error", "Import interrupted: Aurai process stopped before commit")
            atomic(saved, state)
        }
        return state
    }

    fun begin(context: Context, appId: String): JSONObject {
        val previous = status(context, appId)
        val state = JSONObject().put("phase", "extracting").put("jobId", UUID.randomUUID().toString())
            .put("files", 0).put("bytes", 0L)
        if (previous.getString("phase") == "failed") state.put("interruptedStaging", previous.getString("jobId"))
        check(running.putIfAbsent(appId, state) == null) { "An import is already running" }
        atomic(File(root(context, appId), "import.json"), state)
        return snapshot(state)
    }

    /** This is the execution boundary: errors are returned verbatim and old data stays active. */
    fun importArchive(context: Context, appId: String, source: InputStream) {
        val state = running[appId]!!
        val folder = File(root(context, appId), state.getString("jobId"))
        try {
            if (state.has("interruptedStaging")) {
                val old = state.getString("interruptedStaging")
                if (old != generation(context, appId)) File(root(context, appId), old).deleteRecursively()
            }
            folder.mkdirs()
            ZipInputStream(source.buffered(65536)).use { zip ->
                val first = zip.nextEntry
                require(first != null && first.name == "library.json") { "library.json must be the first ZIP entry" }
                val metadata = ByteArrayOutputStream()
                val metadataBuffer = ByteArray(65536)
                while (true) {
                    val count = zip.read(metadataBuffer)
                    if (count == -1) break
                    require(metadata.size() + count <= MAX_INDEX) { "Library metadata exceeds 16 MiB" }
                    metadata.write(metadataBuffer, 0, count)
                }
                val manifest = metadata.toByteArray()
                val data = JSONObject(String(manifest, Charsets.UTF_8))
                require(data.getString("format") == "aurai-library-v1") { "Unsupported library format" }
                val expected = validate(data)
                val total = expected.values.sum()
                require(folder.usableSpace > total + manifest.size) { "Not enough free storage: need $total bytes plus metadata" }
                synchronized(state) { state.put("totalFiles", expected.size).put("totalBytes", total) }
                File(folder, "library.json").writeBytes(manifest)
                val received = HashSet<String>()
                val buffer = ByteArray(65536)
                while (true) {
                    val entry = zip.nextEntry ?: break
                    val name = entry.name
                    require(!entry.isDirectory && expected.containsKey(name) && received.add(name)) { "Unexpected or duplicate archive entry: $name" }
                    val file = File(folder, name)
                    file.parentFile!!.mkdirs()
                    var bytes = 0L
                    file.outputStream().use { output ->
                        while (true) {
                            val count = zip.read(buffer)
                            if (count == -1) break
                            bytes += count
                            require(bytes <= expected.getValue(name)) { "File exceeds declared length: $name" }
                            output.write(buffer, 0, count)
                            synchronized(state) { state.put("bytes", state.getLong("bytes") + count) }
                        }
                    }
                    require(bytes == expected.getValue(name)) { "Truncated archive file: $name" }
                    synchronized(state) { state.put("files", received.size) }
                    if (received.size % 32 == 0) atomic(File(root(context, appId), "import.json"), snapshot(state))
                }
                require(received == expected.keys) { "Archive is missing referenced media" }
                synchronized(state) { state.put("phase", "validating") }
                atomic(File(root(context, appId), "import.json"), snapshot(state))
            }
            // Close and verify the stream before atomically switching the visible library.
            File(folder, ".ready").writeText("aurai-library-v1")
            atomic(File(root(context, appId), "current.json"), JSONObject().put("generation", folder.name))
            indexes.remove(appId)
            synchronized(state) { state.put("phase", "completed") }
        } catch (error: Exception) {
            folder.deleteRecursively()
            synchronized(state) { state.put("phase", "failed").put("error", error.toString()) }
        } finally {
            atomic(File(root(context, appId), "import.json"), snapshot(state))
            running.remove(appId)
        }
    }

    fun fail(context: Context, appId: String, error: Exception) {
        val state = running[appId]!!
        synchronized(state) { state.put("phase", "failed").put("error", error.toString()) }
        atomic(File(root(context, appId), "import.json"), snapshot(state))
        running.remove(appId)
    }

    private fun snapshot(state: JSONObject) = synchronized(state) { JSONObject(state.toString()) }

    private fun validate(data: JSONObject): Map<String, Long> {
        val media = data.getJSONArray("media")
        val expected = LinkedHashMap<String, Long>()
        for (i in 0 until media.length()) {
            val row = media.getJSONObject(i)
            val name = row.getString("path")
            val bytes = row.getLong("bytes")
            require(mediaName.matches(name) && bytes >= 0 && expected.put(name, bytes) == null) { "Invalid media declaration: $name" }
        }
        val collections = data.getJSONObject("collections")
        for (name in collections.keys()) {
            require(name.matches(Regex("[a-z][a-z0-9_-]{0,39}"))) { "Invalid collection: $name" }
            val rows = collections.getJSONArray(name)
            val keys = HashSet<String>()
            for (i in 0 until rows.length()) {
                val row = rows.getJSONObject(i)
                require(keys.add(row.getString("key"))) { "Duplicate record in $name" }
                row.getString("title")
                row.getString("subtitle")
                row.getString("search")
                row.getBoolean("favorite")
                val images = row.getJSONArray("images")
                for (j in 0 until images.length()) require(expected.containsKey(images.getString(j))) { "Record references missing media" }
            }
        }
        val documents = data.getJSONObject("documents")
        for (name in documents.keys()) {
            require(name.matches(Regex("[A-Za-z0-9][A-Za-z0-9_-]{0,79}\\.json"))) { "Invalid document name: $name" }
            validateReferences(documents.getJSONObject(name), expected.keys)
        }
        return expected
    }

    private fun validateReferences(value: Any, media: Set<String>) {
        when (value) {
            is JSONObject -> for (key in value.keys()) validateReferences(value.get(key), media)
            is JSONArray -> for (i in 0 until value.length()) validateReferences(value.get(i), media)
            is String -> if (value.startsWith("aurai-media:")) {
                require(media.contains(value.removePrefix("aurai-media:"))) { "Document references undeclared media: $value" }
            }
        }
    }

    fun query(context: Context, appId: String, args: JSONObject): JSONObject {
        val data = index(context, appId) ?: return JSONObject().put("items", JSONArray()).put("total", 0).put("hasMore", false)
        val collection = data.getJSONObject("collections").getJSONArray(args.getString("collection"))
        val offset = args.getInt("offset")
        val limit = args.getInt("limit")
        val query = args.getString("query")
        val favorite = args.optBoolean("favorite", false)
        require(offset >= 0 && limit in 1..50) { "Invalid page range" }
        val matched = ArrayList<JSONObject>()
        for (i in 0 until collection.length()) {
            val row = collection.getJSONObject(i)
            if ((!favorite || row.getBoolean("favorite")) && row.getString("search").contains(query, ignoreCase = true)) matched.add(row)
        }
        val items = JSONArray()
        matched.drop(offset).take(limit).forEach { row ->
            items.put(JSONObject().put("key", row.getString("key")).put("title", row.getString("title"))
                .put("subtitle", row.getString("subtitle")).put("favorite", row.getBoolean("favorite"))
                .put("image", row.getJSONArray("images").optString(0, "")))
        }
        return JSONObject().put("items", items).put("total", matched.size).put("hasMore", offset + limit < matched.size)
            .put("generation", generation(context, appId))
    }

    fun record(context: Context, appId: String, collection: String, key: String): JSONObject {
        val rows = index(context, appId)!!.getJSONObject("collections").getJSONArray(collection)
        for (i in 0 until rows.length()) if (rows.getJSONObject(i).getString("key") == key) return rows.getJSONObject(i)
        error("Record does not exist")
    }

    fun info(context: Context, appId: String): JSONObject {
        val data = index(context, appId)
        val counts = JSONObject()
        data?.getJSONObject("collections")?.let { collections ->
            for (key in collections.keys()) counts.put(key, collections.getJSONArray(key).length())
        }
        return JSONObject().put("available", data != null).put("generation", generation(context, appId))
            .put("counts", counts).put("import", status(context, appId))
    }

    fun document(context: Context, appId: String, name: String): JSONObject {
        val version = generation(context, appId)!!
        val value = index(context, appId)!!.getJSONObject("documents").getJSONObject(name)
        return resolveMedia(value, version) as JSONObject
    }

    private fun resolveMedia(value: Any, version: String): Any = when (value) {
        is JSONObject -> JSONObject().also { result ->
            for (key in value.keys()) result.put(key, resolveMedia(value.get(key), version))
        }
        is JSONArray -> JSONArray().also { result ->
            for (i in 0 until value.length()) result.put(resolveMedia(value.get(i), version))
        }
        is String -> if (value.startsWith("aurai-media:")) {
            val name = value.removePrefix("aurai-media:")
            require(mediaName.matches(name)) { "Invalid document media reference" }
            "https://aurai-game.invalid/app-files/$version/$name"
        } else value
        else -> value
    }

    fun response(context: Context, appId: String, request: WebResourceRequest): WebResourceResponse? {
        val uri = request.url
        if (uri.scheme != "https" || uri.host != "aurai-game.invalid" || !uri.path.orEmpty().startsWith("/app-files/")) return null
        return try {
            require(request.method == "GET") { "Only GET is supported" }
            val segments = uri.pathSegments
            require(segments.size == 4 && segments[1].matches(Regex("[a-f0-9-]{36}"))) { "Invalid library generation" }
            require(File(root(context, appId), "${segments[1]}/.ready").isFile) { "Library is not committed" }
            val relative = segments.drop(2).joinToString("/")
            require(mediaName.matches(relative)) { "Invalid media path" }
            val file = File(root(context, appId), "${segments[1]}/$relative")
            val mime = when (file.extension) { "png" -> "image/png"; "webp" -> "image/webp"; "gif" -> "image/gif"; else -> "image/jpeg" }
            WebResourceResponse(mime, null, 200, "OK", mapOf("Cache-Control" to "private, max-age=31536000, immutable", "X-Content-Type-Options" to "nosniff"), file.inputStream())
        } catch (error: Exception) {
            WebResourceResponse("text/plain", "UTF-8", 404, "Not Found", emptyMap(), error.toString().byteInputStream())
        }
    }
}
