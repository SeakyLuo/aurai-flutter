package com.haiskynology.aurai

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import org.eclipse.jgit.transport.CredentialsProvider
import org.eclipse.jgit.transport.UsernamePasswordCredentialsProvider
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

object GitConfiguration {
    fun read(context: Context): Map<String, Any?> {
        val preferences = preferences(context)
        return mapOf(
            "name" to preferences.getString(NAME, "")!!,
            "email" to preferences.getString(EMAIL, "")!!,
            "defaultBranch" to preferences.getString(DEFAULT_BRANCH, "main")!!,
            "httpsUsername" to preferences.getString(HTTPS_USERNAME, "")!!,
            "httpsTokenConfigured" to preferences.contains(HTTPS_TOKEN),
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
        val editor = preferences(context).edit()
            .putString(NAME, name)
            .putString(EMAIL, email)
            .putString(DEFAULT_BRANCH, branch)
            .putString(HTTPS_USERNAME, username)
        if (values["clearHttpsToken"] == true) editor.remove(HTTPS_TOKEN)
        else if (!token.isNullOrEmpty()) editor.putString(HTTPS_TOKEN, encrypt(token))
        check(editor.commit()) { "无法保存 Git 设置" }
        return read(context)
    }

    fun identity(context: Context): Pair<String, String> {
        val config = read(context)
        val name = config["name"] as String
        val email = config["email"] as String
        require(name.isNotEmpty() && email.isNotEmpty()) { "请先在设置中配置 Git 用户名和邮箱" }
        return name to email
    }

    fun defaultBranch(context: Context): String =
        read(context)["defaultBranch"] as String

    fun credentials(context: Context): CredentialsProvider? {
        val preferences = preferences(context)
        val payload = preferences.getString(HTTPS_TOKEN, null) ?: return null
        val username = preferences.getString(HTTPS_USERNAME, "")!!.ifEmpty { "oauth2" }
        return UsernamePasswordCredentialsProvider(username, decrypt(payload))
    }

    private fun preferences(context: Context) =
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)

    private fun encrypt(value: String): String {
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, secretKey())
        return Base64.encodeToString(cipher.iv, Base64.NO_WRAP) + "." +
            Base64.encodeToString(cipher.doFinal(value.toByteArray()), Base64.NO_WRAP)
    }

    private fun decrypt(payload: String): String {
        val parts = payload.split('.', limit = 2)
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(
            Cipher.DECRYPT_MODE,
            secretKey(),
            GCMParameterSpec(128, Base64.decode(parts[0], Base64.NO_WRAP)),
        )
        return String(cipher.doFinal(Base64.decode(parts[1], Base64.NO_WRAP)))
    }

    private fun secretKey(): SecretKey {
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val existing = keyStore.getKey(KEY_ALIAS, null)
        if (existing != null) return existing as SecretKey
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
            init(
                KeyGenParameterSpec.Builder(
                    KEY_ALIAS,
                    KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
                )
                    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                    .build(),
            )
        }.generateKey()
    }

    private const val PREFERENCES = "aurai_git"
    private const val NAME = "name"
    private const val EMAIL = "email"
    private const val DEFAULT_BRANCH = "default_branch"
    private const val HTTPS_USERNAME = "https_username"
    private const val HTTPS_TOKEN = "https_token"
    private const val KEY_ALIAS = "aurai_git_credentials_key"
    private const val TRANSFORMATION = "AES/GCM/NoPadding"
}
