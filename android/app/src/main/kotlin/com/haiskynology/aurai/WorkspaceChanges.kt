package com.haiskynology.aurai

import java.io.File
import java.io.ByteArrayOutputStream
import java.security.MessageDigest

/** Bounded content snapshots, independent of what a script claims it wrote. */
class WorkspaceChanges(private val directory: File) {
    data class FileState(val hash: String, val lines: List<String>?)
    data class Snapshot(val files: Map<String, FileState>, val complete: Boolean)

    fun snapshot(): Snapshot {
        val root = directory.canonicalFile
        val files = linkedMapOf<String, FileState>()
        var linesLeft = 8000
        var bytesLeft = 256L * 1024 * 1024
        var inspected = 0
        var complete = true
        for (file in root.walkTopDown().onEnter { it.canonicalFile == it.absoluteFile }) {
            if (++inspected > 2000) { complete = false; break }
            if (!file.isFile || file.canonicalFile != file.absoluteFile) continue
            if (file.length() > bytesLeft) { complete = false; continue }
            val digest = MessageDigest.getInstance("SHA-256")
            var textBytes = if (file.length() <= WorkspaceTextSnapshot.MAX_BYTES && linesLeft > 0)
                ByteArrayOutputStream() else null
            file.inputStream().use { input ->
                val buffer = ByteArray(65536)
                while (true) {
                    val count = input.read(buffer)
                    if (count < 0) break
                    bytesLeft -= count
                    if (bytesLeft < 0) { complete = false; break }
                    digest.update(buffer, 0, count)
                    textBytes?.let {
                        if (it.size() + count <= WorkspaceTextSnapshot.MAX_BYTES) it.write(buffer, 0, count)
                        else textBytes = null
                    }
                }
            }
            if (bytesLeft < 0) break
            val lines = textBytes?.let { WorkspaceTextSnapshot.lines(file.name, it.toByteArray(), minOf(linesLeft, 2000)) }
            linesLeft -= lines?.size ?: 0
            files[file.relativeTo(root).invariantSeparatorsPath] = FileState(
                digest.digest().joinToString("") { "%02x".format(it) }, lines,
            )
        }
        return Snapshot(files, complete)
    }

    fun compare(before: Snapshot, after: Snapshot): List<Map<String, Any?>> =
        (before.files.keys + after.files.keys).sorted().mapNotNull { path ->
            val old = before.files[path]
            val next = after.files[path]
            if (old?.hash == next?.hash || (old == null && !before.complete) || (next == null && !after.complete)) null
            else mapOf(
                "path" to path, "before" to old?.hash, "after" to next?.hash,
                "beforeLines" to if (old == null) emptyList<String>() else old.lines,
                "afterLines" to if (next == null) emptyList<String>() else next.lines,
            )
        }
}
