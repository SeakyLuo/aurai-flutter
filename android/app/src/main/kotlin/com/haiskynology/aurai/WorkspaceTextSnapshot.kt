package com.haiskynology.aurai

import java.nio.ByteBuffer
import java.nio.CharBuffer
import java.nio.charset.StandardCharsets
import java.security.MessageDigest
import android.util.Base64

/** Persist line fingerprints rather than source text in task history. */
object WorkspaceTextSnapshot {
    const val MAX_BYTES = 128 * 1024
    private val binaryExtensions = setOf(
        "doc", "docx", "xls", "xlsx", "ppt", "pptx", "pdf", "zip", "gz", "7z", "rar",
        "png", "jpg", "jpeg", "gif", "webp", "ico", "mp3", "mp4", "wav", "ogg", "flac",
        "sqlite", "db", "apk", "jar", "class", "ttf", "woff", "woff2",
    )

    fun lines(name: String, bytes: ByteArray, limit: Int): List<String>? {
        if (name.substringAfterLast('.', "").lowercase() in binaryExtensions) return null
        val utf16 = bytes.size >= 2 &&
            ((bytes[0] == 0xff.toByte() && bytes[1] == 0xfe.toByte()) ||
                (bytes[0] == 0xfe.toByte() && bytes[1] == 0xff.toByte()))
        val decoder = (if (utf16) StandardCharsets.UTF_16 else StandardCharsets.UTF_8).newDecoder()
        val chars = CharBuffer.allocate(bytes.size + 1)
        if (decoder.decode(ByteBuffer.wrap(bytes), chars, true).isError) return null
        if (decoder.flush(chars).isError) return null
        chars.flip()
        val text = chars.toString().removePrefix("\uFEFF").replace("\r\n", "\n").replace('\r', '\n')
        if (text.any { it.code < 32 && it != '\n' && it != '\t' }) return null
        val lines = mutableListOf<String>()
        val digest = MessageDigest.getInstance("SHA-256")
        var start = 0
        while (start < text.length) {
            if (lines.size >= limit) return null
            val newline = text.indexOf('\n', start)
            val end = if (newline < 0) text.length else newline + 1
            lines.add(Base64.encodeToString(digest.digest(text.substring(start, end).toByteArray(Charsets.UTF_8)), Base64.NO_WRAP))
            start = end
        }
        return lines
    }
}
