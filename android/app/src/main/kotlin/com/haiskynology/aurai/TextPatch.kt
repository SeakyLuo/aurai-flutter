package com.haiskynology.aurai

import android.content.Context
import android.net.Uri
import android.util.AtomicFile
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.charset.CodingErrorAction

class TextPatch(private val context: Context) {
    private val resolver = context.contentResolver

    private data class Change(
        val uri: Uri,
        val before: ByteArray,
        val after: ByteArray,
        val beforeRevision: String,
        val afterRevision: String,
    )

    fun apply(args: JSONObject): Map<String, Any?> {
        val files = args.getJSONArray("files")
        require(files.length() in 1..20) { "一次可以修改 1 到 20 个文件" }
        val changes = mutableListOf<Change>()
        val seen = mutableSetOf<String>()
        var totalBeforeBytes = 0
        var totalAfterBytes = 0
        for (index in 0 until files.length()) {
            val edit = files.getJSONObject(index)
            val uri = authorized(edit.getString("uri"))
            require(seen.add(uri.toString())) { "同一个文件不能在一个补丁中重复出现" }
            val before = read(uri)
            totalBeforeBytes += before.size
            require(totalBeforeBytes <= MAX_TOTAL_BYTES) { "补丁文件内容超过大小限制" }
            val expected = edit.getString("expectedRevision")
            DocumentRevision.require(before, expected)
            var text = decode(before)
            val replacements = edit.getJSONArray("replacements")
            require(replacements.length() in 1..100) { "每个文件需要 1 到 100 处修改" }
            for (replacementIndex in 0 until replacements.length()) {
                val replacement = replacements.getJSONObject(replacementIndex)
                val old = replacement.getString("oldText")
                require(old.isNotEmpty()) { "oldText 不能为空" }
                val first = text.indexOf(old)
                require(first >= 0) { "第 ${index + 1} 个文件没有找到第 ${replacementIndex + 1} 处旧内容" }
                require(text.indexOf(old, first + old.length) < 0) {
                    "第 ${index + 1} 个文件的第 ${replacementIndex + 1} 处旧内容不唯一，请提供更多上下文"
                }
                text = text.replaceRange(first, first + old.length, replacement.getString("newText"))
                require(text.length <= MAX_FILE_BYTES) { "补丁后的文件超过大小限制" }
            }
            val after = text.toByteArray(Charsets.UTF_8)
            require(after.size <= MAX_FILE_BYTES) { "补丁后的文件超过大小限制" }
            totalAfterBytes += after.size
            require(totalAfterBytes <= MAX_TOTAL_BYTES) { "补丁后的文件内容超过大小限制" }
            changes.add(Change(uri, before, after, expected, DocumentRevision.hash(after)))
        }

        for (change in changes) DocumentRevision.require(read(change.uri), change.beforeRevision)
        val attempted = mutableListOf<Change>()
        try {
            for (change in changes) {
                DocumentRevision.require(read(change.uri), change.beforeRevision)
                attempted.add(change)
                write(change.uri, change.after)
                DocumentRevision.require(read(change.uri), change.afterRevision)
            }
        } catch (error: Exception) {
            rollback(attempted, error)
            throw error
        }
        return mapOf(
            "applied" to true,
            "files" to changes.map { change -> mapOf(
                "uri" to change.uri.toString(),
                "beforeRevision" to change.beforeRevision,
                "revision" to change.afterRevision,
            ) },
        )
    }

    private fun rollback(attempted: List<Change>, cause: Exception) {
        var conflict = false
        for (change in attempted.asReversed()) {
            when (DocumentRevision.hash(read(change.uri))) {
                change.beforeRevision -> Unit
                change.afterRevision -> write(change.uri, change.before)
                else -> conflict = true
            }
        }
        if (conflict) {
            throw java.io.IOException("补丁失败，且回滚时发现文件又被修改；未覆盖并发内容", cause)
        }
    }

    private fun authorized(value: String): Uri {
        val uri = Uri.parse(value)
        return if (uri.scheme == "aurai") {
            ManagedWorkspace.file(context, value)
            uri
        } else {
            DocumentUris.authorized(context, value, write = true)
        }
    }

    private fun read(uri: Uri): ByteArray {
        val input = if (uri.scheme == "aurai") {
            ManagedWorkspace.file(context, uri.toString()).inputStream()
        } else {
            resolver.openInputStream(uri)!!
        }
        return input.use { source ->
            val output = ByteArrayOutputStream()
            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
            while (true) {
                val count = source.read(buffer)
                if (count < 0) break
                require(output.size() + count <= MAX_FILE_BYTES) { "补丁文件内容超过大小限制" }
                output.write(buffer, 0, count)
            }
            output.toByteArray()
        }
    }

    private fun write(uri: Uri, bytes: ByteArray) {
        if (uri.scheme == "aurai") {
            val atomicFile = AtomicFile(ManagedWorkspace.file(context, uri.toString()))
            val output = atomicFile.startWrite()
            try {
                output.write(bytes)
                atomicFile.finishWrite(output)
            } catch (error: Exception) {
                atomicFile.failWrite(output)
                throw error
            }
        } else {
            resolver.openOutputStream(uri, "wt")!!.use { it.write(bytes) }
        }
    }

    private fun decode(bytes: ByteArray): String {
        val decoder = Charsets.UTF_8.newDecoder()
            .onMalformedInput(CodingErrorAction.REPORT)
            .onUnmappableCharacter(CodingErrorAction.REPORT)
        return decoder.decode(ByteBuffer.wrap(bytes)).toString()
    }

    companion object {
        private const val MAX_FILE_BYTES = 5 * 1024 * 1024
        private const val MAX_TOTAL_BYTES = 20 * 1024 * 1024
    }
}
