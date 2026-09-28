package com.haiskynology.aurai

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import org.eclipse.jgit.transport.CredentialsProvider
import org.eclipse.jgit.transport.UsernamePasswordCredentialsProvider
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URI
import java.net.URL

object GitConfiguration {
    fun read(context: Context): Map<String, Any?> {
        val values = load(context)
        return mapOf(
            "name" to values.optString("name"),
            "email" to values.optString("email"),
            "defaultBranch" to values.optString("defaultBranch", "main"),
            "httpsCredentials" to values.optJSONArray("httpsCredentials").toPublicCredentials(),
        )
    }

    fun write(context: Context, values: Map<String, Any?>): Map<String, Any?> {
        val name = (values["name"] as String).trim()
        val email = (values["email"] as String).trim()
        val branch = (values["defaultBranch"] as String).trim()
        val credentials = values["httpsCredentials"] as List<*>
        require(branch.matches(Regex("[A-Za-z0-9._/-]+"))) { "默认分支名称无效" }
        require(email.isEmpty() || email.matches(Regex("^[^@\\s]+@[^@\\s]+$"))) { "Git 邮箱格式无效" }
        val previous = load(context)
        val previousCredentials = previous.optJSONArray("httpsCredentials").byHost()
        val savedCredentials = JSONArray()
        credentials.forEach { item ->
            val credential = item as Map<*, *>
            val host = (credential["host"] as String).trim().lowercase()
            val username = (credential["username"] as String).trim()
            val token = credential["token"] as String?
            require(validHost(host)) { "Git 服务域名无效" }
            require(host in AUTOMATIC_USERNAME_HOSTS || username.isNotEmpty()) { "请输入 $host 的 HTTPS 用户名" }
            savedCredentials.put(
                JSONObject()
                    .put("host", host)
                    .put("username", username)
                    .put("token", token?.takeIf { it.isNotEmpty() } ?: previousCredentials[host]?.optString("token").orEmpty()),
            )
        }
        save(
            context,
            JSONObject()
                .put("name", name)
                .put("email", email)
                .put("defaultBranch", branch)
                .put("httpsCredentials", savedCredentials),
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

    fun credentials(context: Context, remoteUrl: String): CredentialsProvider? {
        if (!remoteUrl.startsWith("https://")) return null
        val host = URI(remoteUrl).host.lowercase()
        val credential = load(context).optJSONArray("httpsCredentials").byHost()[host]
            ?: error("请先在 Git 设置中配置 $host 的 HTTPS 凭据")
        val token = credential.optString("token")
        require(token.isNotEmpty()) { "请先配置 $host 的 HTTPS 密码或访问令牌" }
        val username = credential.optString("username").ifEmpty {
            when (host) {
                CODEUP_HOST -> resolveCodeupUsername(context, remoteUrl, token)
                "github.com" -> "git"
                else -> error("请先配置 $host 的 HTTPS 用户名")
            }
        }
        return UsernamePasswordCredentialsProvider(username, token)
    }

    private fun resolveCodeupUsername(context: Context, remoteUrl: String, token: String): String {
        val organizationId = URI(remoteUrl).path.trim('/').substringBefore('/')
        require(organizationId.matches(Regex("[a-fA-F0-9]{24}"))) { "Codeup 仓库地址缺少组织 ID" }
        val userId = getCodeupJson("https://$CODEUP_HOST/oapi/v1/platform/user", token).getString("id")
        val username = getCodeupJson(
            "https://$CODEUP_HOST/oapi/v1/codeup/organizations/$organizationId/users/$userId/httpsCloneUsername",
            token,
        ).getString("httpsCloneUsername")
        val values = load(context)
        val credentials = values.getJSONArray("httpsCredentials")
        for (index in 0 until credentials.length()) {
            val credential = credentials.getJSONObject(index)
            if (credential.getString("host") == CODEUP_HOST) credential.put("username", username)
        }
        save(context, values)
        return username
    }

    private fun getCodeupJson(url: String, token: String): JSONObject {
        val connection = URL(url).openConnection() as HttpURLConnection
        connection.requestMethod = "GET"
        connection.connectTimeout = 15_000
        connection.readTimeout = 15_000
        connection.setRequestProperty("Accept", "application/json")
        connection.setRequestProperty("x-yunxiao-token", token)
        require(connection.responseCode in 200..299) { "Codeup 账号识别失败（HTTP ${connection.responseCode}）" }
        return connection.inputStream.bufferedReader().use { JSONObject(it.readText()) }
    }

    private fun JSONArray?.toPublicCredentials(): List<Map<String, Any?>> =
        if (this == null) emptyList() else (0 until length()).map { index ->
            getJSONObject(index).let { credential ->
                mapOf(
                    "host" to credential.getString("host"),
                    "username" to credential.getString("username"),
                    "tokenConfigured" to credential.optString("token").isNotEmpty(),
                )
            }
        }

    private fun JSONArray?.byHost(): Map<String, JSONObject> =
        if (this == null) emptyMap() else (0 until length())
            .map(::getJSONObject)
            .associateBy { it.getString("host") }

    private fun validHost(host: String): Boolean =
        host.matches(Regex("[A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?")) && host.contains('.')

    private const val CODEUP_HOST = "codeup.aliyun.com"
    private val AUTOMATIC_USERNAME_HOSTS = setOf(CODEUP_HOST, "github.com")

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
