package com.haiskynology.aurai

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import org.eclipse.jgit.transport.CredentialsProvider
import org.eclipse.jgit.transport.UsernamePasswordCredentialsProvider
import org.json.JSONObject

object GitConfiguration {
    fun read(context: Context): Map<String, Any?> {
        val values = load(context)
        return mapOf(
            "name" to values.optString("name"),
            "email" to values.optString("email"),
            "defaultBranch" to values.optString("defaultBranch", "main"),
            "httpsUsername" to values.optString("httpsUsername"),
            "httpsTokenConfigured" to values.optString("httpsToken").isNotEmpty(),
        )
    }

    fun write(context: Context, values: Map<String, Any?>): Map<String, Any?> {
        val name = (values["name"] as String).trim()
        val email = (values["email"] as String).trim()
        val branch = (values["defaultBranch"] as String).trim()
        val username = (values["httpsUsername"] as String).trim()
        val token = values["httpsToken"] as String?
        require(branch.matches(Regex("[A-Za-z0-9._/-]+"))) { "默认分支名称无效" }
        require(email.isEmpty() || email.matches(Regex("^[^@\\s]+@[^@\\s]+$"))) { "Git 邮箱格式无效" }
        val previous = load(context)
        val savedToken = when {
            values["clearHttpsToken"] == true -> ""
            !token.isNullOrEmpty() -> token
            else -> previous.optString("httpsToken")
        }
        save(
            context,
            JSONObject()
                .put("name", name)
                .put("email", email)
                .put("defaultBranch", branch)
                .put("httpsUsername", username)
                .put("httpsToken", savedToken),
        )
        return read(context)
    }

    fun identity(context: Context): Pair<String, String> {
        val values = load(context)
        val name = values.optString("name")
        val email = values.optString("email")
        require(name.isNotEmpty() && email.isNotEmpty()) { "请先在设置中配置 Git 用户名和邮箱" }
        return name to email
    }

    fun defaultBranch(context: Context): String =
        load(context).optString("defaultBranch", "main")

    fun credentials(context: Context): CredentialsProvider? {
        val values = load(context)
        val token = values.optString("httpsToken")
        if (token.isEmpty()) return null
        val username = values.optString("httpsUsername").ifEmpty { "oauth2" }
        return UsernamePasswordCredentialsProvider(username, token)
    }

    private fun load(context: Context): JSONObject {
        val file = context.getDatabasePath("aurai.sqlite")
        if (!file.exists()) return JSONObject().put("defaultBranch", "main")
        return SQLiteDatabase.openDatabase(file.path, null, SQLiteDatabase.OPEN_READONLY).use { database ->
            database.query("app_state", arrayOf("value"), "key = ?", arrayOf(KEY), null, null, null).use { rows ->
                if (rows.moveToFirst()) JSONObject(rows.getString(0))
                else JSONObject().put("defaultBranch", "main")
            }
        }
    }

    private fun save(context: Context, values: JSONObject) {
        SQLiteDatabase.openDatabase(
            context.getDatabasePath("aurai.sqlite").path,
            null,
            SQLiteDatabase.OPEN_READWRITE,
        ).use { database ->
            val row = ContentValues().apply {
                put("key", KEY)
                put("value", values.toString())
            }
            check(database.insertWithOnConflict("app_state", null, row, SQLiteDatabase.CONFLICT_REPLACE) != -1L) {
                "无法保存 Git 设置"
            }
        }
    }

    private const val KEY = "git_configuration_json"
}
