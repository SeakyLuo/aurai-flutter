package com.haiskynology.aurai

import android.content.Context
import android.media.MediaMetadataRetriever
import android.util.Xml
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.text.PDFTextStripper
import java.io.File
import java.nio.charset.CodingErrorAction
import java.util.zip.ZipFile
import org.xmlpull.v1.XmlPullParser

object ChatFileReader {
    fun read(context: Context, file: File, name: String, mime: String, offset: Int, limit: Int): Map<String, Any?> {
        require(offset >= 0 && limit in 1..20000)
        val extension = name.substringAfterLast('.', "").lowercase()
        if (mime.startsWith("audio/") || mime.startsWith("video/")) {
            val metadata = MediaMetadataRetriever()
            try {
                metadata.setDataSource(file.path)
                return mapOf("name" to name, "mimeType" to mime, "size" to file.length(),
                    "durationMs" to metadata.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION),
                    "width" to metadata.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH),
                    "height" to metadata.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT),
                    "contentRead" to false,
                    "limitation" to "Only container metadata was read. No audio transcription or video frames were analyzed. Do not claim to understand this recording.")
            } finally { metadata.release() }
        }
        if (mime == "application/pdf" || extension == "pdf") {
            PDFBoxResourceLoader.init(context)
            PDDocument.load(file).use { document ->
                require(offset < document.numberOfPages) { "页码超出 PDF 范围" }
                val text = PDFTextStripper().apply { startPage = offset + 1; endPage = offset + 1 }.getText(document)
                return mapOf("name" to name, "text" to text.take(limit), "page" to offset + 1,
                    "pages" to document.numberOfPages, "offsetUnit" to "page (zero-based)",
                    "nextOffset" to if (offset + 1 < document.numberOfPages) offset + 1 else null,
                    "truncated" to (text.length > limit), "contentRead" to text.isNotBlank(),
                    "limitation" to if (text.isBlank()) "This page has no extractable text; scanned images were not read." else null)
            }
        }
        val text = if (extension == "docx") {
            ZipFile(file).use { zip ->
                val entry = zip.getEntry("word/document.xml") ?: error("Word 文档内容缺失")
                require(entry.size in 0..(16L * 1024 * 1024)) { "文档解压后内容过大" }
                zip.getInputStream(entry).use { stream ->
                    val parser = Xml.newPullParser()
                    parser.setInput(stream, "UTF-8")
                    val output = StringBuilder()
                    var inText = false
                    while (parser.eventType != XmlPullParser.END_DOCUMENT && output.length <= offset + limit) {
                        when (parser.eventType) {
                            XmlPullParser.START_TAG -> if (parser.name == "t") inText = true
                            XmlPullParser.TEXT -> if (inText) output.append(parser.text)
                            XmlPullParser.END_TAG -> {
                                if (parser.name == "t") inText = false
                                if (parser.name == "p") output.append('\n')
                            }
                        }
                        parser.next()
                    }
                    output.toString()
                }
            }
        } else {
            val types = setOf("txt", "md", "csv", "tsv", "json", "xml", "yaml", "yml", "log", "html", "css", "js", "ts", "tsx", "jsx", "dart", "kt", "java", "py", "rs", "go", "c", "h", "cpp", "sh", "sql", "toml", "ini", "svg")
            if (!mime.startsWith("text/") && extension !in types) return mapOf("name" to name, "mimeType" to mime,
                "size" to file.length(), "contentRead" to false, "limitation" to "This format has been attached but cannot be decoded by the attachment reader. Do not claim to have read its contents.")
            val decoder = Charsets.UTF_8.newDecoder().onMalformedInput(CodingErrorAction.REPORT)
            java.io.InputStreamReader(file.inputStream(), decoder).use { reader ->
                var skipped = 0
                val buffer = CharArray(4096)
                while (skipped < offset) {
                    val count = reader.read(buffer, 0, minOf(buffer.size, offset - skipped))
                    if (count < 0) break
                    skipped += count
                }
                val output = StringBuilder()
                while (output.length <= limit) {
                    val count = reader.read(buffer, 0, minOf(buffer.size, limit + 1 - output.length))
                    if (count < 0) break
                    output.append(buffer, 0, count)
                }
                return mapOf("name" to name, "text" to output.take(limit).toString(), "offsetUnit" to "character",
                    "nextOffset" to if (output.length > limit) offset + limit else null, "contentRead" to true)
            }
        }
        val end = minOf(text.length, offset + limit)
        return mapOf("name" to name, "text" to if (offset < text.length) text.substring(offset, end) else "",
            "offsetUnit" to "character", "nextOffset" to if (text.length > end) end else null, "contentRead" to true)
    }
}
