package com.haiskynology.aurai

import android.content.Context
import android.util.AtomicFile
import org.eclipse.jgit.diff.DiffEntry
import org.eclipse.jgit.diff.DiffFormatter
import org.eclipse.jgit.api.Git
import org.eclipse.jgit.dircache.DirCache
import org.eclipse.jgit.dircache.DirCacheEditor
import org.eclipse.jgit.dircache.DirCacheEntry
import org.eclipse.jgit.lib.CommitBuilder
import org.eclipse.jgit.lib.Constants
import org.eclipse.jgit.lib.FileMode
import org.eclipse.jgit.lib.ObjectId
import org.eclipse.jgit.lib.PersonIdent
import org.eclipse.jgit.lib.Repository
import org.eclipse.jgit.storage.file.FileRepositoryBuilder
import org.eclipse.jgit.treewalk.CanonicalTreeParser
import org.eclipse.jgit.treewalk.TreeWalk
import org.eclipse.jgit.util.io.DisabledOutputStream
import java.io.ByteArrayOutputStream
import java.io.File

/** Immutable Git snapshots for one AI run; refs never alter the user's branch or index. */
object ProjectGitTasks {
    fun execute(context: Context, workspaceId: String, operation: String, args: Map<String, Any?>): Map<String, Any?> {
        val root = ManagedWorkspace.root(context, workspaceId).canonicalFile
        if (!File(root, ".git").exists()) return mapOf("available" to false)
        return repository(root).use { repo ->
            val taskId = args["taskId"] as String
            require(taskId.matches(Regex("[A-Za-z0-9_-]{1,100}"))) { "任务标识无效" }
            when (operation) {
                "beginProjectGitTask" -> {
                    if (Git(repo).use { it.status().call().conflicting.isNotEmpty() }) {
                        return@use mapOf("available" to false, "reason" to "项目正在处理 Git 冲突")
                    }
                    capture(repo, root, taskId, "before")
                    mapOf("available" to true)
                }
                "rebaseProjectGitTask" -> {
                    requireSnapshot(repo, taskId, "before")
                    capture(repo, root, taskId, "before")
                    mapOf("rebased" to true)
                }
                "finishProjectGitTask" -> {
                    requireSnapshot(repo, taskId, "before")
                    if (Git(repo).use { it.status().call().conflicting.isNotEmpty() }) {
                        return@use mapOf("available" to false, "reason" to "任务结束时仍有 Git 冲突")
                    }
                    capture(repo, root, taskId, "after")
                    val result = changes(repo, root, taskId)
                    if ((result["changes"] as List<*>).isEmpty()) {
                        deleteSnapshots(repo, taskId)
                    } else {
                        deleteCompletedSnapshotsExcept(repo, taskId)
                    }
                    result
                }
                "abortProjectGitTask" -> {
                    deleteSnapshots(repo, taskId)
                    mapOf("aborted" to true)
                }
                "getProjectGitTaskChanges" -> {
                    if (hasSnapshot(repo, taskId, "after")) changes(repo, root, taskId)
                    else if (hasSnapshot(repo, taskId, "before")) {
                        capture(repo, root, taskId, "live")
                        changes(repo, root, taskId, "live")
                    } else mapOf("available" to false)
                }
                "getProjectGitTaskFileDiff" -> fileDiff(repo, taskId, args["path"] as String)
                "restoreProjectGitTaskFile" -> {
                    val path = args["path"] as String
                    val oldPath = args["oldPath"] as String?
                    val paths = listOfNotNull(path, oldPath).distinct()
                    requireRestorable(repo, root, taskId, paths)
                    restoreAll(repo, root, taskId, "before", paths)
                    mapOf("restored" to true)
                }
                "redoProjectGitTaskFile" -> {
                    val path = args["path"] as String
                    val oldPath = args["oldPath"] as String?
                    val paths = listOfNotNull(path, oldPath).distinct()
                    requirePhase(repo, root, taskId, "before", paths)
                    restoreAll(repo, root, taskId, "after", paths)
                    mapOf("restored" to true)
                }
                "discardProjectGitTaskChanges" -> {
                    val rows = diffEntries(repo, taskId)
                    val paths = rows.flatMap { listOf(it.oldPath, it.newPath) }
                        .filter { it != DiffEntry.DEV_NULL }.distinct()
                    val pending = paths.filterNot { matches(repo, root, taskId, "before", it) }
                    requireRestorable(repo, root, taskId, pending)
                    restoreAll(repo, root, taskId, "before", pending)
                    mapOf("discarded" to true)
                }
                "redoProjectGitTaskChanges" -> {
                    val rows = diffEntries(repo, taskId)
                    val paths = rows.flatMap { listOf(it.oldPath, it.newPath) }
                        .filter { it != DiffEntry.DEV_NULL }.distinct()
                    val reverted = paths.filter { matches(repo, root, taskId, "before", it) }
                    requirePhase(repo, root, taskId, "before", reverted)
                    restoreAll(repo, root, taskId, "after", reverted)
                    mapOf("restored" to true)
                }
                else -> error("不支持的 Git 任务操作")
            }
        }
    }

    private fun capture(repo: Repository, root: File, taskId: String, phase: String) {
        val inserter = repo.newObjectInserter()
        inserter.use {
            val index = repo.readDirCache()
            val entries = linkedMapOf<String, DirCacheEntry>()
            for (position in 0 until index.entryCount) {
                val entry = index.getEntry(position)
                require(entry.stage == DirCacheEntry.STAGE_0) { "Git 索引存在未解决的冲突" }
                entries[entry.pathString] = DirCacheEntry(entry)
            }
            val status = Git(repo).use { it.status().call() }
            for (path in status.missing) entries.remove(path)
            for (path in status.modified + status.untracked) {
                val file = validPath(root, path)
                require(file.isFile) { "Git 变更文件不存在" }
                val entry = entries[path] ?: DirCacheEntry(path)
                entry.fileMode = if (file.canExecute()) FileMode.EXECUTABLE_FILE else FileMode.REGULAR_FILE
                file.inputStream().use { input ->
                    entry.setObjectId(inserter.insert(Constants.OBJ_BLOB, file.length(), input))
                }
                entries[path] = entry
            }
            val worktree = DirCache.newInCore()
            val builder = worktree.builder()
            entries.toSortedMap().values.forEach(builder::add)
            builder.finish()
            val worktreeTree = worktree.writeTree(inserter)
            val indexTree = index.writeTree(inserter)
            val head = repo.resolve(Constants.HEAD)
            val worktreeCommit = commit(inserter, worktreeTree, head, taskId, phase)
            val indexCommit = commit(inserter, indexTree, head, taskId, phase)
            inserter.flush()
            update(repo, ref(taskId, "$phase-worktree"), worktreeCommit)
            update(repo, ref(taskId, "$phase-index"), indexCommit)
        }
    }

    private fun commit(
        inserter: org.eclipse.jgit.lib.ObjectInserter,
        tree: ObjectId,
        parent: ObjectId?,
        taskId: String,
        phase: String,
    ): ObjectId {
        val identity = PersonIdent("Aurai", "aurai@localhost")
        val builder = CommitBuilder().apply {
            setTreeId(tree)
            if (parent != null) setParentId(parent)
            author = identity
            committer = identity
            message = "Aurai task $taskId $phase"
        }
        return inserter.insert(builder)
    }

    private fun update(repo: Repository, name: String, objectId: ObjectId) {
        val result = repo.updateRef(name).apply {
            setNewObjectId(objectId)
            isForceUpdate = true
        }.update()
        require(result.name in setOf("NEW", "FAST_FORWARD", "FORCED", "NO_CHANGE")) { "Git 任务快照保存失败" }
    }

    private fun deleteSnapshots(repo: Repository, taskId: String) {
        for (phase in listOf("before-worktree", "before-index", "after-worktree", "after-index", "live-worktree", "live-index")) {
            val update = repo.updateRef(ref(taskId, phase))
            update.isForceUpdate = true
            val result = update.delete()
            require(result.name in setOf("NEW", "FORCED", "NO_CHANGE")) { "Git 任务快照清理失败" }
        }
    }

    private fun deleteCompletedSnapshotsExcept(repo: Repository, taskId: String) {
        val prefix = "refs/aurai/tasks/"
        val completed = repo.refDatabase.getRefsByPrefix(prefix)
            .mapNotNull { reference ->
                val suffix = reference.name.removePrefix(prefix)
                suffix.substringBefore('/').takeIf { suffix.endsWith("/after-worktree") }
            }
            .filter { it != taskId && it.substringBefore("__") == taskId.substringBefore("__") }
            .distinct()
        completed.forEach { deleteSnapshots(repo, it) }
    }

    private fun changes(repo: Repository, root: File, taskId: String, phase: String = "after"): Map<String, Any?> {
        requireSnapshot(repo, taskId, phase)
        val live = phase == "live"
        val rows = diffEntries(repo, taskId, phase).map { entry ->
            val counts = DiffFormatter(DisabledOutputStream.INSTANCE).use { formatter ->
                formatter.setRepository(repo)
                formatter.toFileHeader(entry).toEditList().fold(0 to 0) { total, edit ->
                    total.first + (edit.endB - edit.beginB) to total.second + (edit.endA - edit.beginA)
                }
            }
            val path = if (entry.changeType == DiffEntry.ChangeType.DELETE) entry.oldPath else entry.newPath
            val affected = listOf(entry.oldPath, entry.newPath).filter { it != DiffEntry.DEV_NULL }.distinct()
            val reverted = !live && affected.all { matches(repo, root, taskId, "before", it) }
            val restorable = live || affected.all { matches(repo, root, taskId, "after", it) }
            mapOf(
                "path" to path,
                "oldPath" to entry.oldPath.takeUnless { it == DiffEntry.DEV_NULL || it == entry.newPath },
                "status" to entry.changeType.name.lowercase(),
                "addedLines" to counts.first,
                "removedLines" to counts.second,
                "reverted" to reverted,
                "conflict" to (!reverted && !restorable),
            )
        }
        return mapOf(
            "available" to true,
            "live" to live,
            "taskId" to taskId,
            "changes" to rows,
            "addedLines" to rows.sumOf { it["addedLines"] as Int },
            "removedLines" to rows.sumOf { it["removedLines"] as Int },
        )
    }

    private fun fileDiff(repo: Repository, taskId: String, path: String): Map<String, Any?> {
        require(path.isNotEmpty()) { "文件路径无效" }
        val entry = diffEntries(repo, taskId).singleOrNull { it.oldPath == path || it.newPath == path }
            ?: error("文件不在本次任务改动中")
        val output = ByteArrayOutputStream()
        DiffFormatter(output).use { formatter ->
            formatter.setRepository(repo)
            formatter.setContext(3)
            formatter.format(entry)
        }
        val bytes = output.toByteArray()
        val shown = bytes.copyOfRange(0, minOf(bytes.size, MAX_OUTPUT_BYTES))
        return mapOf("path" to path, "diff" to shown.toString(Charsets.UTF_8),
            "truncated" to (bytes.size > shown.size))
    }

    private fun diffEntries(repo: Repository, taskId: String,
        phase: String = if (hasSnapshot(repo, taskId, "after")) "after" else "live"): List<DiffEntry> =
        repo.newObjectReader().use { reader ->
            DiffFormatter(DisabledOutputStream.INSTANCE).use { formatter ->
                formatter.setRepository(repo)
                formatter.isDetectRenames = true
                formatter.scan(
                    CanonicalTreeParser(null, reader, tree(repo, taskId, "before-worktree")),
                    CanonicalTreeParser(null, reader, tree(repo, taskId, "$phase-worktree")),
                )
            }
        }

    private fun requireRestorable(repo: Repository, root: File, taskId: String, paths: List<String>) {
        requirePhase(repo, root, taskId, "after", paths)
    }

    private fun requirePhase(
        repo: Repository,
        root: File,
        taskId: String,
        phase: String,
        paths: List<String>,
    ) {
        require(paths.all { matches(repo, root, taskId, phase, it) }) {
            "文件在本次任务后又被修改，请先处理后续改动"
        }
    }

    private fun matches(repo: Repository, root: File, taskId: String, phase: String, path: String): Boolean {
        val worktreeMatches = currentWorktreeEntry(repo, root, path) == treeEntry(repo, taskId, "$phase-worktree", path)
        val indexMatches = currentIndexEntry(repo, path) == treeEntry(repo, taskId, "$phase-index", path)
        return worktreeMatches && indexMatches
    }

    private fun restoreAll(
        repo: Repository,
        root: File,
        taskId: String,
        phase: String,
        paths: List<String>,
    ) {
        val rollback = if (phase == "before") "after" else "before"
        val attempted = mutableListOf<String>()
        try {
            for (path in paths) {
                attempted.add(path)
                restore(repo, root, taskId, phase, path)
            }
        } catch (error: Exception) {
            attempted.asReversed().forEach { restore(repo, root, taskId, rollback, it) }
            throw error
        }
    }

    private fun restore(repo: Repository, root: File, taskId: String, phase: String, path: String) {
        val file = validPath(root, path)
        val snapshotWorktree = treeEntry(repo, taskId, "$phase-worktree", path)
        if (snapshotWorktree == null) {
            if (file.exists()) {
                require(file.isFile && file.delete()) { "文件回退失败" }
            }
        } else {
            file.parentFile!!.mkdirs()
            val atomic = AtomicFile(file)
            val output = atomic.startWrite()
            try {
                repo.open(snapshotWorktree.second).openStream().use { input ->
                    input.copyTo(output)
                }
                atomic.finishWrite(output)
            } catch (error: Exception) {
                atomic.failWrite(output)
                throw error
            }
            file.setExecutable(snapshotWorktree.first == FileMode.EXECUTABLE_FILE, false)
        }
        val snapshotIndex = treeEntry(repo, taskId, "$phase-index", path)
        val cache = repo.lockDirCache()
        val editor = cache.editor()
        if (snapshotIndex == null) {
            editor.add(DirCacheEditor.DeletePath(path))
        } else {
            editor.add(object : DirCacheEditor.PathEdit(path) {
                override fun apply(entry: DirCacheEntry) {
                    entry.fileMode = snapshotIndex.first
                    entry.setObjectId(snapshotIndex.second)
                }
            })
        }
        require(editor.commit()) { "Git 索引回退失败" }
    }

    private fun currentWorktreeEntry(repo: Repository, root: File, path: String): Pair<FileMode, ObjectId>? {
        val file = validPath(root, path)
        if (!file.isFile) return null
        val objectId = repo.newObjectInserter().use { inserter ->
            file.inputStream().use { inserter.idFor(Constants.OBJ_BLOB, file.length(), it) }
        }
        val mode = if (file.canExecute()) FileMode.EXECUTABLE_FILE else FileMode.REGULAR_FILE
        return mode to objectId
    }

    private fun currentIndexEntry(repo: Repository, path: String): Pair<FileMode, ObjectId>? =
        repo.readDirCache().getEntry(path)?.let { it.fileMode to it.objectId }

    private fun treeEntry(repo: Repository, taskId: String, phase: String, path: String): Pair<FileMode, ObjectId>? {
        val walk = TreeWalk.forPath(repo, path, tree(repo, taskId, phase)) ?: return null
        return walk.use { it.getFileMode(0) to it.getObjectId(0) }
    }

    private fun tree(repo: Repository, taskId: String, phase: String): ObjectId =
        repo.resolve("${ref(taskId, phase)}^{tree}") ?: error("Git 任务快照不存在")

    private fun requireSnapshot(repo: Repository, taskId: String, phase: String) {
        require(hasSnapshot(repo, taskId, phase)) { "Git 任务快照不存在" }
    }

    private fun hasSnapshot(repo: Repository, taskId: String, phase: String): Boolean =
        repo.resolve(ref(taskId, "$phase-worktree")) != null &&
            repo.resolve(ref(taskId, "$phase-index")) != null

    private fun validPath(root: File, path: String): File {
        require(path.isNotEmpty() && path != ".git" && !path.startsWith(".git/") && !File(path).isAbsolute) {
            "文件路径无效"
        }
        val file = File(root, path).canonicalFile
        require(file.path.startsWith(root.canonicalPath + File.separator)) { "文件超出项目目录" }
        return file
    }

    private fun ref(taskId: String, phase: String) = "refs/aurai/tasks/$taskId/$phase"

    private fun repository(root: File) = FileRepositoryBuilder().setWorkTree(root)
        .findGitDir(root).setMustExist(true).build()

    private const val MAX_OUTPUT_BYTES = 200_000
}
