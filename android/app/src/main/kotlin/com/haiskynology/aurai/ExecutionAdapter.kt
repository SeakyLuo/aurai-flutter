package com.haiskynology.aurai

import java.io.File
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

enum class ExecutionIdentity { APP_UID, SHIZUKU, ADB }

interface ExecutionAdapter {
    val identity: ExecutionIdentity
    val available: Boolean
    val reason: String
    fun execute(command: String): Map<String, Any?>
    fun cancel()
}

class AppUidExecutionAdapter(private val workingDirectory: File) : ExecutionAdapter {
    override val identity = ExecutionIdentity.APP_UID
    override val available = true
    override val reason = "Commands run only with the Aurai app UID"
    private val activeProcess = AtomicReference<Process?>()
    private val cancelled = java.util.concurrent.atomic.AtomicBoolean(false)

    override fun execute(command: String): Map<String, Any?> {
        val started = System.nanoTime()
        workingDirectory.mkdirs()
        val stdoutFile = File.createTempFile("stdout-", ".tmp", workingDirectory)
        val stderrFile = File.createTempFile("stderr-", ".tmp", workingDirectory)
        try {
            if (cancelled.get()) return mapOf("cancelled" to true)
            val process = ProcessBuilder("/system/bin/sh", "-c", command)
                .directory(workingDirectory)
                .redirectOutput(stdoutFile)
                .redirectError(stderrFile)
                .start()
            activeProcess.set(process)
            if (cancelled.get()) process.destroyForcibly()
            val finished = process.waitFor(TIMEOUT_SECONDS, TimeUnit.SECONDS)
            if (!finished) {
                process.destroyForcibly()
                activeProcess.set(null)
                return mapOf("timedOut" to true, "durationMs" to elapsedMs(started))
            }
            val stdout = stdoutFile.inputStream().use { it.readNBytes(MAX_OUTPUT_BYTES) }.toString(Charsets.UTF_8)
            val stderr = stderrFile.inputStream().use { it.readNBytes(MAX_OUTPUT_BYTES) }.toString(Charsets.UTF_8)
            activeProcess.set(null)
            return mapOf(
                "cancelled" to cancelled.get(),
                "exitCode" to process.exitValue(),
                "stdout" to stdout,
                "stderr" to stderr,
                "outputTruncated" to (stdoutFile.length() > MAX_OUTPUT_BYTES || stderrFile.length() > MAX_OUTPUT_BYTES),
                "durationMs" to elapsedMs(started),
                "executionIdentity" to "Aurai app UID",
            )
        } finally {
            activeProcess.getAndSet(null)?.destroyForcibly()
            stdoutFile.delete()
            stderrFile.delete()
        }
    }

    override fun cancel() {
        cancelled.set(true)
        activeProcess.getAndSet(null)?.destroyForcibly()
    }

    private fun elapsedMs(started: Long) = (System.nanoTime() - started) / 1_000_000

    companion object {
        private const val TIMEOUT_SECONDS = 15L
        private const val MAX_OUTPUT_BYTES = 65_536
    }
}

class UnavailableExecutionAdapter(
    override val identity: ExecutionIdentity,
    override val reason: String,
) : ExecutionAdapter {
    override val available = false
    override fun execute(command: String): Map<String, Any?> = error(reason)
    override fun cancel() = Unit
}
