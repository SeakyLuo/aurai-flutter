package com.haiskynology.aurai

import android.os.Bundle
import android.os.Process
import android.system.Os
import android.system.OsConstants
import java.util.concurrent.Executors
import java.io.InputStream
import java.io.ByteArrayOutputStream
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference
import kotlin.concurrent.thread

/** Runs only in the Shizuku user-service process, with its actual shell/root identity. */
class PrivilegedShellService : IPrivilegedShell.Stub() {
    private class Command(val process: java.lang.Process) {
        val group = java.util.concurrent.atomic.AtomicInteger(0)
        @Volatile var cancelled = false
        fun stop() {
            cancelled = true
            val pid = group.getAndSet(0)
            if (pid > 0) {
                try { Os.kill(-pid, OsConstants.SIGKILL) }
                catch (error: android.system.ErrnoException) {
                    if (error.errno != OsConstants.ESRCH) throw error
                }
            }
            process.destroy()
        }
    }
    private val active = AtomicReference<Command?>()
    private val timer = Executors.newSingleThreadScheduledExecutor()

    @Synchronized
    override fun execute(command: String, timeoutSeconds: Int): Bundle {
        require(timeoutSeconds in 1..120)
        require(command.isNotBlank() && command.length <= 32768)
        val process = ProcessBuilder("/system/bin/setsid", "/system/bin/sh", "-c",
            "echo \$\$; exec /system/bin/sh -c \"\$1\"", "aurai", command).start()
        val running = Command(process)
        active.set(running)
        val timedOut = java.util.concurrent.atomic.AtomicBoolean(false)
        val timeout = timer.schedule({ timedOut.set(true); running.stop() }, timeoutSeconds.toLong(), TimeUnit.SECONDS)
        try {
            process.outputStream.close()
            val pid = StringBuilder()
            while (true) {
                val byte = process.inputStream.read()
                if (byte == 10) break
                check(byte in 48..57 && pid.length < 10) { "Shizuku 命令进程启动失败" }
                pid.append(byte.toChar())
            }
            running.group.set(pid.toString().toInt())
            if (running.cancelled) running.stop()
            val stdout = BoundedOutput(process.inputStream)
            val stderr = BoundedOutput(process.errorStream)
            val outThread = thread(name = "shizuku-stdout") { stdout.drain() }
            val errThread = thread(name = "shizuku-stderr") { stderr.drain() }
            val exitCode = process.waitFor()
            timeout.cancel(false)
            val finished = !timedOut.get()
            outThread.join(1000)
            errThread.join(1000)
            return Bundle().apply {
                putInt("uid", Process.myUid())
                putString("executionIdentity", if (Process.myUid() == 0) "Shizuku root" else "Shizuku adb shell")
                putBoolean("timedOut", !finished)
                putInt("exitCode", if (finished) exitCode else -1)
                putString("stdout", stdout.text())
                putString("stderr", stderr.text())
                putBoolean("truncated", stdout.truncated || stderr.truncated)
            }
        } finally {
            timeout.cancel(false)
            active.compareAndSet(running, null)
            running.stop()
            process.inputStream.close()
            process.errorStream.close()
        }
    }

    override fun cancel() { active.get()?.stop() }
    override fun destroy() { cancel(); Process.killProcess(Process.myPid()) }

    private class BoundedOutput(private val input: InputStream) {
        private val bytes = ByteArrayOutputStream()
        @Volatile var truncated = false
        fun drain() {
            val buffer = ByteArray(4096)
            try {
                while (true) {
                    val count = input.read(buffer)
                    if (count < 0) break
                    synchronized(bytes) {
                        val keep = minOf(count, 65536 - bytes.size())
                        bytes.write(buffer, 0, keep)
                        if (keep < count) truncated = true
                    }
                }
            } catch (_: java.io.IOException) {
                // Cancellation closes the process pipes.
            }
        }
        fun text(): String = synchronized(bytes) { bytes.toString("UTF-8") }
    }
}
