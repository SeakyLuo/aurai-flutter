package com.haiskynology.aurai

import android.content.Context
import org.eclipse.jgit.api.Git
import org.eclipse.jgit.api.ResetCommand
import org.eclipse.jgit.diff.DiffEntry
import org.eclipse.jgit.diff.DiffFormatter
import org.eclipse.jgit.diff.Edit
import org.eclipse.jgit.lib.Repository
import org.eclipse.jgit.lib.Constants
import org.eclipse.jgit.revwalk.RevCommit
import org.eclipse.jgit.revwalk.RevWalk
import org.eclipse.jgit.storage.file.FileRepositoryBuilder
import org.eclipse.jgit.treewalk.CanonicalTreeParser
import org.eclipse.jgit.treewalk.FileTreeIterator
import org.eclipse.jgit.treewalk.TreeWalk
import org.eclipse.jgit.util.io.DisabledOutputStream
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.UUID

/** Linked Git worktrees share objects/refs and have their own HEAD and index. */
object ProjectWorktrees {
    fun execute(context: Context, projectId: String, operation: String, args: Map<String, Any?>): Map<String, Any?> {
        val root = ManagedWorkspace.root(context, projectId).canonicalFile
        if (operation == "listProjectWorktrees" && !File(root, ".git").exists()) {
            return mapOf("available" to false, "worktrees" to emptyList<Any>(), "branches" to emptyList<Any>())
        }
        return repository(root).use { main ->
            require(main.directory.canonicalFile == main.commonDirectory.canonicalFile) { "请从项目主目录管理工作树" }
            val directory = File(main.commonDirectory, "worktrees")
            when (operation) {
                "listProjectWorktrees" -> {
                    val entries = directory.listFiles().orEmpty().filter { File(it, "aurai.json").isFile }
                    require(entries.size <= 64) { "工作树数量超过上限" }
                    mapOf("available" to true, "branch" to main.branch,
                        "branches" to main.refDatabase.getRefsByPrefix(Constants.R_HEADS).map { it.name.removePrefix(Constants.R_HEADS) },
                        "worktrees" to entries.map { entry ->
                            val info = JSONObject(File(entry, "aurai.json").readText())
                            mapOf("id" to info.getString("id"), "name" to info.getString("name"),
                                "branch" to info.getString("branch"), "baseBranch" to info.getString("baseBranch"))
                        })
                }
                "createProjectWorktree" -> {
                    val name = (args["name"] as String).trim()
                    require(name.isNotEmpty() && name.length <= 40) { "工作树名称需要为 1–40 个字" }
                    require(directory.listFiles().orEmpty().size < 64) { "最多创建 64 个工作树" }
                    val base = args["baseBranch"] as String
                    val ref = main.exactRef(Constants.R_HEADS + base) ?: error("起始分支不存在，请先创建一次提交")
                    val baseCommit = ref.objectId.name
                    val id = "wt-" + UUID.randomUUID().toString()
                    val branch = "aurai/" + name.replace(' ', '-')
                    require(org.eclipse.jgit.lib.Repository.isValidRefName(Constants.R_HEADS + branch)) { "名称不能包含 Git 分支不支持的符号" }
                    require(main.exactRef(Constants.R_HEADS + branch) == null) { "同名工作树分支已存在，请使用其他名称" }
                    val destination = ManagedWorkspace.root(context, id).canonicalFile
                    val admin = File(directory, id)
                    require(admin.mkdirs() && destination.mkdir()) { "无法创建工作树目录" }
                    var complete = false
                    try {
                        // Standard Git linked-worktree layout; never change the main HEAD/index.
                        File(admin, "commondir").writeText("../..\n")
                        File(admin, "gitdir").writeText(File(destination, ".git").path + "\n")
                        File(admin, "HEAD").writeText(ref.objectId.name + "\n")
                        File(destination, ".git").writeText("gitdir: ${admin.path}\n")
                        repository(destination).use { repo ->
                            Git(repo).use { git ->
                                git.reset().setMode(ResetCommand.ResetType.HARD).setRef(ref.objectId.name).call()
                                git.checkout().setCreateBranch(true).setName(branch).call()
                            }
                        }
                        File(admin, "aurai.json").writeText(JSONObject().put("id", id).put("name", name)
                            .put("branch", branch).put("baseBranch", base).put("baseCommit", baseCommit).toString())
                        complete = true
                        mapOf("id" to id, "name" to name, "branch" to branch, "baseBranch" to base)
                    } finally {
                        if (!complete) {
                            require(destination.deleteRecursively()) { "创建失败，工作目录清理失败" }
                            require(admin.deleteRecursively()) { "创建失败，工作树登记清理失败" }
                        }
                    }
                }
                "mergeProjectWorktree", "removeProjectWorktree", "getProjectWorktreeDiff",
                "getProjectWorktreeChanges", "getProjectWorktreeFileDiff",
                "restoreProjectWorktreeFile", "discardProjectWorktreeChanges" -> {
                    val id = args["worktreeId"] as String
                    require(id.matches(Regex("wt-[a-f0-9-]{36}"))) { "工作树无效" }
                    val admin = File(directory, id)
                    val info = JSONObject(File(admin, "aurai.json").readText())
                    require(info.getString("id") == id) { "工作树登记不一致" }
                    val baseCommit = info.getString("baseCommit")
                    val destination = ManagedWorkspace.root(context, id).canonicalFile
                    repository(destination).use { repo ->
                        require(repo.commonDirectory.canonicalFile == main.commonDirectory.canonicalFile) { "工作树不属于这个项目" }
                        if (operation == "getProjectWorktreeChanges") {
                            return@use changes(repo, baseCommit)
                        }
                        if (operation == "getProjectWorktreeFileDiff") {
                            return@use fileDiff(repo, baseCommit, args["path"] as String)
                        }
                        if (operation == "restoreProjectWorktreeFile") {
                            val path = args["path"] as String
                            val oldPath = args["oldPath"] as String?
                            restoreFile(repo, destination, baseCommit, path)
                            if (oldPath != null && oldPath != path) restoreFile(repo, destination, baseCommit, oldPath)
                            return@use mapOf("restored" to true)
                        }
                        if (operation == "discardProjectWorktreeChanges") {
                            Git(repo).use { git ->
                                git.reset().setMode(ResetCommand.ResetType.HARD).setRef(baseCommit).call()
                                git.clean().setCleanDirectories(true).setIgnore(false).call()
                            }
                            return@use mapOf("discarded" to true)
                        }
                        if (operation == "getProjectWorktreeDiff") {
                            val base = repo.resolve("$baseCommit^{tree}") ?: error("工作树基线不存在")
                            val output = ByteArrayOutputStream()
                            repo.newObjectReader().use { reader ->
                                DiffFormatter(output).use { formatter ->
                                    formatter.setRepository(repo)
                                    formatter.setContext(3)
                                    formatter.format(CanonicalTreeParser(null, reader, base), FileTreeIterator(repo))
                                }
                            }
                            val bytes = output.toByteArray()
                            return@use mapOf("diff" to String(bytes.take(200_000).toByteArray(), Charsets.UTF_8),
                                "truncated" to (bytes.size > 200_000))
                        }
                        Git(repo).use { git ->
                            require(git.status().call().isClean) { "工作树有未提交修改，请先让 AI 提交后再操作" }
                            require(repo.repositoryState.canCheckout()) { "请先完成工作树中的 Git 操作" }
                            val head = repo.resolve(Constants.HEAD)!!
                            if (operation == "mergeProjectWorktree") {
                                require(main.fullBranch == Constants.R_HEADS + info.getString("baseBranch")) { "请先将主目录切回起始分支" }
                                Git(main).use { target ->
                                    require(target.status().call().isClean) { "主目录有未提交修改，请先提交" }
                                    require(main.repositoryState.canCheckout()) { "请先完成主目录中的 Git 操作" }
                                    // FF-only never leaves the user's main directory in a conflict state.
                                    val result = target.merge().include(head)
                                        .setFastForward(org.eclipse.jgit.api.MergeCommand.FastForwardMode.FF_ONLY).call()
                                    require(result.mergeStatus.isSuccessful) { "主目录已有新提交，请先在工作树中合并主目录并处理冲突，再重试" }
                                    mapOf("merged" to true)
                                }
                            } else {
                                RevWalk(main).use { walk ->
                                    require(walk.isMergedInto(walk.parseCommit(head), walk.parseCommit(main.resolve(Constants.HEAD)))) {
                                        "工作树有尚未合并的提交，请先合并"
                                    }
                                }
                                mapOf("removed" to true)
                            }
                        }
                    }.also {
                        if (operation == "removeProjectWorktree") {
                            require(destination.deleteRecursively()) { "工作树目录删除失败" }
                            require(admin.deleteRecursively()) { "工作树登记删除失败" }
                        }
                    }
                }
                else -> error("不支持的工作树操作")
            }
        }
    }

    private fun repository(root: File) = FileRepositoryBuilder().setWorkTree(root)
        .findGitDir(root).setMustExist(true).build()

    private fun base(repo: Repository, revision: String): RevCommit = RevWalk(repo).use { walk ->
        walk.parseCommit(repo.resolve(revision) ?: error("工作树基线不存在"))
    }

    private fun entries(repo: Repository, revision: String): List<DiffEntry> {
        val commit = base(repo, revision)
        return repo.newObjectReader().use { reader ->
            DiffFormatter(DisabledOutputStream.INSTANCE).use { formatter ->
                formatter.setRepository(repo)
                formatter.isDetectRenames = true
                formatter.scan(CanonicalTreeParser(null, reader, commit.tree), FileTreeIterator(repo))
            }
        }
    }

    private fun changes(repo: Repository, revision: String): Map<String, Any?> {
        val rows = entries(repo, revision).map { entry ->
            val counts = DiffFormatter(DisabledOutputStream.INSTANCE).use { formatter ->
                formatter.setRepository(repo)
                formatter.toFileHeader(entry).toEditList().fold(0 to 0) { total, edit ->
                    total.first + (edit.endB - edit.beginB) to total.second + (edit.endA - edit.beginA)
                }
            }
            mapOf(
                "path" to if (entry.changeType == DiffEntry.ChangeType.DELETE) entry.oldPath else entry.newPath,
                "oldPath" to entry.oldPath.takeUnless { it == DiffEntry.DEV_NULL || it == entry.newPath },
                "status" to entry.changeType.name.lowercase(),
                "addedLines" to counts.first,
                "removedLines" to counts.second,
            )
        }.toMutableList()
        val included = rows.mapTo(mutableSetOf()) { it["path"] as String }
        Git(repo).use { git ->
            for (path in git.status().call().untracked.sorted()) if (included.add(path)) {
                rows.add(mapOf("path" to path, "oldPath" to null, "status" to "add",
                    "addedLines" to textLineCount(File(repo.workTree, path)), "removedLines" to 0))
            }
        }
        rows.sortBy { it["path"] as String }
        return mapOf(
            "baseCommit" to revision,
            "changes" to rows,
            "addedLines" to rows.sumOf { it["addedLines"] as Int },
            "removedLines" to rows.sumOf { it["removedLines"] as Int },
        )
    }

    private fun textLineCount(file: File): Int {
        if (!file.isFile || file.length() > MAX_DIFF_BYTES) return 0
        val bytes = file.readBytes()
        if (bytes.isEmpty() || bytes.any { it == 0.toByte() }) return 0
        return bytes.toString(Charsets.UTF_8).lineSequence().count()
    }

    private fun fileDiff(repo: Repository, revision: String, path: String): Map<String, Any?> {
        validPath(repo.workTree, path)
        val entry = entries(repo, revision).singleOrNull {
            it.oldPath == path || it.newPath == path
        }
        val output = ByteArrayOutputStream()
        if (entry != null) {
            DiffFormatter(output).use { formatter ->
                formatter.setRepository(repo)
                formatter.setContext(3)
                formatter.format(entry)
            }
        } else {
            val file = File(repo.workTree, path)
            require(Git(repo).use { it.status().call().untracked.contains(path) }) { "文件没有任务改动" }
            val bytes = file.readBytes()
            output.write("diff --git a/$path b/$path\nnew file mode 100644\n--- /dev/null\n+++ b/$path\n".toByteArray())
            if (bytes.size > MAX_DIFF_BYTES || bytes.any { it == 0.toByte() }) {
                output.write("Binary files /dev/null and b/$path differ\n".toByteArray())
            } else {
                val lines = bytes.toString(Charsets.UTF_8).lines()
                output.write("@@ -0,0 +1,${lines.size} @@\n".toByteArray())
                for (line in lines) output.write("+$line\n".toByteArray())
            }
        }
        val bytes = output.toByteArray()
        val shown = bytes.copyOfRange(0, minOf(bytes.size, MAX_OUTPUT_BYTES))
        return mapOf("path" to path, "diff" to shown.toString(Charsets.UTF_8),
            "truncated" to (bytes.size > shown.size))
    }

    private fun restoreFile(repo: Repository, root: File, revision: String, path: String) {
        val file = validPath(root, path)
        val commit = base(repo, revision)
        val existed = TreeWalk.forPath(repo, path, commit.tree)?.use { true } ?: false
        Git(repo).use { git ->
            if (existed) {
                git.checkout().setStartPoint(revision).addPath(path).call()
            } else {
                git.reset().setRef(revision).addPath(path).call()
                if (file.exists()) {
                    require(file.isFile && file.delete()) { "文件回退失败" }
                }
            }
        }
    }

    private fun validPath(root: File, path: String): File {
        require(path.isNotEmpty() && path != ".git" && !path.startsWith(".git/") && !File(path).isAbsolute) {
            "文件路径无效"
        }
        val file = File(root, path).canonicalFile
        require(file.path.startsWith(root.canonicalPath + File.separator)) { "文件超出工作树" }
        return file
    }

    private const val MAX_DIFF_BYTES = 5 * 1024 * 1024L
    private const val MAX_OUTPUT_BYTES = 200_000
}
