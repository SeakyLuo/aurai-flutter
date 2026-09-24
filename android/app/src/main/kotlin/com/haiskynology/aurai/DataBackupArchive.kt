package com.haiskynology.aurai

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import org.json.JSONObject
import org.json.JSONArray
import java.io.File
import java.io.InputStream
import java.io.OutputStream
import java.util.zip.ZipEntry
import java.util.zip.ZipInputStream
import java.util.zip.ZipOutputStream

class DataBackupArchive(private val context: Context) {
    private val root = File(context.applicationInfo.dataDir)
    val stage = File(root, "backup_import")
    private fun db(file: File) = SQLiteDatabase.openDatabase(file.path, null, SQLiteDatabase.OPEN_READONLY)
    private fun summary(file: File): JSONObject = db(file).use { database ->
        val result = JSONObject().put("databaseVersion", database.version)
        for ((key, table) in mapOf("conversations" to "conversations", "messages" to "messages", "friends" to "ai_profiles", "memories" to "user_memories", "skills" to "skills")) {
            database.rawQuery("SELECT count(*) FROM $table", null).use { it.moveToFirst(); result.put(key, it.getLong(0)) }
        }
        result
    }
    private fun containsKeys(config: String?): Boolean {
        if (config == null) return false
        val json = JSONObject(config)
        if (json.has("service")) return json.getString("apiKey").isNotEmpty()
        val profiles = json.getJSONObject("profiles")
        return profiles.keys().asSequence().any { profiles.getJSONObject(it).getString("apiKey").isNotEmpty() }
    }
    private fun missingAttachments(database: File, base: File): List<String> = db(database).use { connection ->
        connection.rawQuery("SELECT DISTINCT file_name FROM attachments", null).use { rows ->
            buildList { while (rows.moveToNext()) {
                val name = rows.getString(0)
                if (!File(base, "files/message_images/$name").isFile) add(name)
            } }
        }
    }
    fun export(output: OutputStream, legacyModelConfig: String?): Map<String, Any> {
        var modelConfig = legacyModelConfig
        val snapshot = File(context.cacheDir, "backup-snapshot.sqlite")
        snapshot.delete()
        try {
            SQLiteDatabase.openDatabase(context.getDatabasePath("aurai.sqlite").path, null, SQLiteDatabase.OPEN_READWRITE).use {
                it.execSQL("VACUUM INTO ?", arrayOf(snapshot.path))
            }
            // Device-bound ciphertext must not travel to another Android Keystore.
            SQLiteDatabase.openDatabase(snapshot.path, null, SQLiteDatabase.OPEN_READWRITE).use { db ->
                db.query("app_state", arrayOf("value"), "key = ?", arrayOf(ModelConfigPersistence.KEY), null, null, null).use {
                    if (it.moveToFirst()) modelConfig = it.getString(0)
                }
                db.delete("app_state", "key = ?", arrayOf(ModelConfigPersistence.LEGACY_KEY))
            }
            val snapshotModelConfig = modelConfig
            val manifest = summary(snapshot).put("format", 1).put("createdAt", System.currentTimeMillis())
                .put("hasModelKeys", containsKeys(snapshotModelConfig)).put("hasModelConfig", snapshotModelConfig != null)
                .put("missingAttachments", JSONArray(missingAttachments(snapshot, root)))
            val sources = mutableListOf("databases/aurai.sqlite" to snapshot)
            for (directory in listOf("files", "shared_prefs", "app_flutter")) {
                val folder = File(root, directory)
                if (!folder.exists()) continue
                folder.walkTopDown().onEnter { f -> f.relativeTo(root).invariantSeparatorsPath !in setOf("files/logs", "app_flutter/flutter_assets") }.filter { it.isFile }.forEach { file ->
                    val name = file.relativeTo(root).invariantSeparatorsPath
                    if (name != "shared_prefs/aurai.xml" && !name.endsWith(".bak") && file.name != "profileInstalled") sources.add(name to file)
                }
            }
            manifest.put("files", sources.size)
            ZipOutputStream(output).use { zip ->
                fun entry(name: String, bytes: ByteArray) { zip.putNextEntry(ZipEntry(name)); zip.write(bytes); zip.closeEntry() }
                entry("manifest.json", manifest.toString().toByteArray())
                if (snapshotModelConfig != null) entry("model-config.json", snapshotModelConfig.toByteArray())
                for ((name, file) in sources) {
                    zip.putNextEntry(ZipEntry(name)); file.inputStream().use { it.copyTo(zip) }; zip.closeEntry()
                }
            }
            return mapOf("missingFiles" to manifest.getJSONArray("missingAttachments").length())
        } finally { snapshot.delete() }
    }
    fun inspect(input: InputStream): Map<String, Any> {
        stage.deleteRecursively(); check(stage.mkdirs()) { "无法创建恢复目录" }
        try {
            val source = input.buffered()
            source.mark(8)
            val header = ByteArray(8)
            java.io.DataInputStream(source).readFully(header)
            require(!header.contentEquals("AURAI001".toByteArray(Charsets.US_ASCII))) { "这是旧版加密备份，请在原设备重新导出无密码备份" }
            require(header.take(4) == listOf<Byte>(80, 75, 3, 4)) { "不是支持的 Aurai 备份文件" }
            source.reset()
            val seen = mutableSetOf<String>()
            ZipInputStream(source).use { zip ->
                var total = 0L
                val limit = root.usableSpace - 32L * 1024 * 1024
                while (true) {
                    val entry = zip.nextEntry ?: break
                    val name = entry.name
                    require(name.split('/').none { it == ".." || it == "." || it.isEmpty() }) { "备份路径无效" }
                    require(!entry.isDirectory && seen.add(name)) { "备份包含重复或无效条目" }
                    require(name == "manifest.json" || name == "model-config.json" || name == "databases/aurai.sqlite" ||
                        name.startsWith("files/") || name.startsWith("shared_prefs/") || name.startsWith("app_flutter/")) { "备份包含不支持的文件" }
                    require(name != "shared_prefs/aurai.xml" && !name.endsWith(".bak")) { "备份密钥格式不支持跨安装恢复" }
                    val target = File(stage, name)
                    require(target.canonicalPath.startsWith(stage.canonicalPath + "/")) { "备份路径无效" }
                    target.parentFile!!.mkdirs()
                    target.outputStream().use { output ->
                        val buffer = ByteArray(65536)
                        while (true) {
                            val count = zip.read(buffer); if (count < 0) break
                            total += count; require(total < limit) { "存储空间不足，无法解压备份" }
                            output.write(buffer, 0, count)
                        }
                        output.fd.sync()
                    }
                }
            }
            val manifest = JSONObject(File(stage, "manifest.json").readText())
            require(manifest.getInt("format") == 1) { "不支持此备份版本" }
            val restored = File(stage, "databases/aurai.sqlite")
            db(restored).use { database ->
                database.rawQuery("PRAGMA integrity_check", null).use { require(it.moveToFirst() && it.getString(0) == "ok") { "备份数据库已损坏" } }
                database.rawQuery("PRAGMA foreign_key_check", null).use { require(!it.moveToFirst()) { "备份中的数据关联不完整" } }
                db(context.getDatabasePath("aurai.sqlite")).use { require(database.version <= it.version) { "备份来自更新版本，请先更新 App" } }

            }
            val missing = missingAttachments(restored, stage)
            val declared = manifest.getJSONArray("missingAttachments")
            val knownMissing = (0 until declared.length()).map { declared.getString(it) }.toSet()
            require(missing.all { it in knownMissing }) { "备份缺少未声明的图片或附件，未修改当前数据" }
            val modelFile = File(stage, "model-config.json")
            require(modelFile.exists() == manifest.getBoolean("hasModelConfig")) { "备份中的模型设置不完整" }
            val modelConfig = if (modelFile.exists()) modelFile.readText() else null
            require(containsKeys(modelConfig) == manifest.getBoolean("hasModelKeys")) { "备份中的模型密钥信息不一致" }
            val stats = summary(restored)
            return stats.keys().asSequence().associateWith { stats.get(it) } + mapOf(
                "missingFiles" to missing.size, "createdAt" to manifest.getLong("createdAt"), "hasModelKeys" to manifest.getBoolean("hasModelKeys"), "files" to manifest.getInt("files"))
        } catch (error: Exception) { stage.deleteRecursively(); throw error }
    }

    /** Apply before Flutter/SQLite/preferences are opened; keep rollback data until success. */
    fun applyPending() {
        val ready = File(stage, "READY")
        val previous = File(root, "backup_previous")
        val journal = File(root, "backup_restore_journal.json")
        val directories = listOf("databases", "files", "shared_prefs", "app_flutter")
        if (journal.exists()) {
            val moved = JSONObject(journal.readText()).getJSONArray("existing")
            for (name in directories) {
                val old = File(previous, name)
                if (old.exists()) { File(root, name).deleteRecursively(); check(old.renameTo(File(root, name))) }
                else if (!(0 until moved.length()).any { moved.getString(it) == name }) File(root, name).deleteRecursively()
            }
            journal.delete(); previous.deleteRecursively(); stage.deleteRecursively()
            File(root, "backup-status.txt").writeText("上次恢复未完成，已保留原数据")
            return
        }
        if (!ready.exists()) { stage.deleteRecursively(); return }
        try {
            val model = File(stage, "model-config.json")
            SQLiteDatabase.openDatabase(File(stage, "databases/aurai.sqlite").path, null, SQLiteDatabase.OPEN_READWRITE).use { database ->
                database.delete("app_state", "key = ?", arrayOf(ModelConfigPersistence.LEGACY_KEY))
                if (model.exists()) {
                    val values = android.content.ContentValues().apply {
                        put("key", ModelConfigPersistence.KEY)
                        put("value", model.readText())
                    }
                    check(database.insertWithOnConflict("app_state", null, values, SQLiteDatabase.CONFLICT_REPLACE) != -1L) { "无法恢复模型配置" }
                }
            }
            previous.deleteRecursively(); check(previous.mkdirs())
            val pendingJournal = File(root, "backup_restore_journal.pending")
            pendingJournal.outputStream().use {
                it.write(JSONObject().put("existing", JSONArray(directories.filter { File(root, it).exists() })).toString().toByteArray())
                it.fd.sync()
            }
            check(pendingJournal.renameTo(journal)) { "无法保存恢复进度" }
            for (name in directories) {
                val current = File(root, name)
                if (current.exists()) check(current.renameTo(File(previous, name))) { "无法暂存当前数据" }
                val incoming = File(stage, name)
                if (incoming.exists()) check(incoming.renameTo(current)) { "无法恢复数据文件" }
            }
            check(journal.delete()) { "无法完成恢复进度" }
        } catch (error: Exception) {
            // The same journal also recovers an interrupted previous cold start.
            if (journal.exists()) applyPending() else stage.deleteRecursively()
            File(root, "backup-status.txt").writeText("恢复失败，已保留原数据：${error.message}")
            return
        }
        previous.deleteRecursively(); stage.deleteRecursively()
        File(root, "backup-status.txt").writeText("数据恢复完成")
    }
}
