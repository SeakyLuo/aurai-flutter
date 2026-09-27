package com.haiskynology.aurai

import android.content.Context
import org.eclipse.jgit.api.Git
import org.eclipse.jgit.diff.DiffFormatter
import org.eclipse.jgit.dircache.DirCacheIterator
import org.eclipse.jgit.lib.Constants
import org.eclipse.jgit.storage.file.FileRepositoryBuilder
import org.eclipse.jgit.treewalk.CanonicalTreeParser
import org.eclipse.jgit.treewalk.EmptyTreeIterator
import org.eclipse.jgit.treewalk.FileTreeIterator
import java.io.ByteArrayOutputStream
import java.nio.charset.StandardCharsets
import java.util.concurrent.TimeUnit

object ProjectDevelopment {
    private val processes = java.util.concurrent.ConcurrentHashMap<String, Process>()

    fun execute(context: Context, callId: String, projectId: String, operation: String, arguments: Map<String, Any?>): Map<String, Any?> {
        val root = ManagedWorkspace.root(context, projectId).canonicalFile
        require(root.isDirectory) { "项目目录不存在" }
        return when (operation) {
            "runProjectCommand" -> runCommand(callId, root, arguments)
            "getProjectGitStatus" -> status(root)
            "getProjectGitDiff" -> diff(root)
            "initializeProjectGit" -> initialize(context, root)
            "setProjectGitRemote" -> setRemote(root, arguments["url"] as String)
            "commitProjectGit" -> commit(context, root, arguments["message"] as String)
            "pullProjectGit" -> pull(context, root)
            "pushProjectGit" -> push(context, root)
            else -> error("不支持的项目开发操作")
        }
    }

    fun cancel(callId: String) {
        processes.remove(callId)?.destroy()
    }

    private fun runCommand(callId: String, root: java.io.File, arguments: Map<String, Any?>): Map<String, Any?> {
        val command = arguments["command"] as String
        val timeout = (arguments["timeoutSeconds"] as Number).toLong()
        require(command.isNotBlank() && command.length <= 4000) { "命令内容无效" }
        val process = ProcessBuilder("/system/bin/sh", "-c", command)
            .directory(root)
            .redirectErrorStream(true)
            .start()
        processes[callId] = process
        val output = ByteArrayOutputStream()
        val reader = Thread { process.inputStream.use { it.copyTo(output, 8192) } }.apply { start() }
        val finished = process.waitFor(timeout, TimeUnit.SECONDS)
        if (!finished) process.destroy()
        reader.join(2000)
        processes.remove(callId)
        val bytes = output.toByteArray()
        val shown = bytes.copyOfRange(0, minOf(bytes.size, MAX_OUTPUT_BYTES))
        return mapOf(
            "exitCode" to if (finished) process.exitValue() else null,
            "timedOut" to !finished,
            "output" to String(shown, StandardCharsets.UTF_8),
            "truncated" to (bytes.size > shown.size),
        )
    }

    private fun repository(root: java.io.File) = FileRepositoryBuilder()
        .setWorkTree(root)
        .findGitDir(root)
        .build().also { require(it.directory.exists()) { "项目还不是 Git 仓库" } }

    private fun status(root: java.io.File): Map<String, Any?> = repository(root).use { repository ->
        Git(repository).use { git ->
            val status = git.status().call()
            mapOf(
                "branch" to repository.branch,
                "clean" to status.isClean,
                "added" to status.added.sorted(),
                "changed" to status.changed.sorted(),
                "modified" to status.modified.sorted(),
                "missing" to status.missing.sorted(),
                "removed" to status.removed.sorted(),
                "untracked" to status.untracked.sorted(),
                "conflicting" to status.conflicting.sorted(),
                "remote" to repository.config.getString("remote", "origin", "url"),
            )
        }
    }

    private fun diff(root: java.io.File): Map<String, Any?> = repository(root).use { repository ->
        val output = ByteArrayOutputStream()
        DiffFormatter(output).use { formatter ->
            formatter.setRepository(repository)
            formatter.setContext(3)
            val cache = repository.readDirCache()
            output.write("--- staged ---\n".toByteArray())
            val head = repository.resolve(Constants.HEAD + "^{tree}")
            if (head == null) {
                formatter.format(EmptyTreeIterator(), DirCacheIterator(cache))
            } else {
                repository.newObjectReader().use { reader ->
                    formatter.format(CanonicalTreeParser(null, reader, head), DirCacheIterator(cache))
                }
            }
            output.write("\n--- working tree ---\n".toByteArray())
            formatter.format(DirCacheIterator(cache), FileTreeIterator(repository))
        }
        val bytes = output.toByteArray()
        val shown = bytes.copyOfRange(0, minOf(bytes.size, MAX_OUTPUT_BYTES))
        mapOf(
            "diff" to String(shown, StandardCharsets.UTF_8),
            "truncated" to (bytes.size > shown.size),
        )
    }

    private fun initialize(context: Context, root: java.io.File): Map<String, Any?> {
        Git.init().setDirectory(root).setInitialBranch(GitConfiguration.defaultBranch(context)).call().use { git ->
            return mapOf("initialized" to true, "branch" to git.repository.branch)
        }
    }

    private fun commit(context: Context, root: java.io.File, message: String): Map<String, Any?> {
        val trimmed = message.trim()
        require(trimmed.isNotEmpty() && trimmed.length <= 500) { "提交说明需要 1–500 个字符" }
        val (name, email) = GitConfiguration.identity(context)
        return repository(root).use { repository ->
            Git(repository).use { git ->
                git.add().addFilepattern(".").call()
                git.add().setUpdate(true).addFilepattern(".").call()
                val commit = git.commit()
                    .setMessage(trimmed)
                    .setAuthor(name, email)
                    .setCommitter(name, email)
                    .call()
                mapOf(
                    "committed" to true,
                    "commit" to commit.name,
                    "shortCommit" to commit.abbreviate(8).name(),
                    "message" to commit.shortMessage,
                )
            }
        }
    }

    private fun pull(context: Context, root: java.io.File): Map<String, Any?> = repository(root).use { repository ->
        Git(repository).use { git ->
            val command = git.pull().setRemote("origin")
            GitConfiguration.credentials(context)?.let(command::setCredentialsProvider)
            val result = command.call()
            mapOf(
                "pulled" to result.isSuccessful,
                "mergeStatus" to result.mergeResult?.mergeStatus?.name,
                "fetchMessages" to result.fetchResult?.messages,
            )
        }
    }

    private fun push(context: Context, root: java.io.File): Map<String, Any?> = repository(root).use { repository ->
        Git(repository).use { git ->
            val command = git.push().setRemote("origin")
            GitConfiguration.credentials(context)?.let(command::setCredentialsProvider)
            val updates = command.call().flatMap { result ->
                result.remoteUpdates.map { update ->
                    mapOf(
                        "remoteName" to update.remoteName,
                        "status" to update.status.name,
                        "message" to update.message,
                    )
                }
            }
            mapOf("pushed" to updates.all { it["status"] == "OK" || it["status"] == "UP_TO_DATE" }, "updates" to updates)
        }
    }

    private fun setRemote(root: java.io.File, url: String): Map<String, Any?> = repository(root).use { repository ->
        require(url.isEmpty() || validRemote(url)) { "请输入 HTTPS 或 SSH Git 地址" }
        repository.config.apply {
            if (url.isEmpty()) {
                unsetSection("remote", "origin")
            } else {
                setString("remote", "origin", "url", url)
                setString("remote", "origin", "fetch", "+refs/heads/*:refs/remotes/origin/*")
            }
            save()
        }
        mapOf("updated" to true, "remote" to url.ifEmpty { null })
    }

    private fun validRemote(value: String): Boolean =
        value.startsWith("https://") || value.startsWith("ssh://") ||
            Regex("^[^@\\s]+@[^:\\s]+:.+$").matches(value)

    private const val MAX_OUTPUT_BYTES = 200_000
}
