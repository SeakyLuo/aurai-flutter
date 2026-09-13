package com.haiskynology.aurai

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract as Docs
import org.json.JSONArray
import org.json.JSONObject

class DocumentFolders(private val context: Context) {
    private val preferences = context.getSharedPreferences("document_folders", Context.MODE_PRIVATE)
    private fun stored(): List<JSONObject> {
        val array = JSONArray(preferences.getString("folders", "[]"))
        return (0 until array.length()).map { array.getJSONObject(it) }
    }
    private fun save(items: List<JSONObject>) {
        preferences.edit().putString("folders", JSONArray(items).toString()).apply()
    }

    fun list(): List<Map<String, Any?>> {
        val grants = context.contentResolver.persistedUriPermissions.associateBy { it.uri.toString() }
        return stored().map { folder ->
            val grant = grants[folder.getString("uri")]
            mapOf("uri" to folder.getString("uri"), "name" to folder.getString("name"),
                "source" to folder.getString("source"), "path" to folder.getString("path"),
                "readable" to (grant?.isReadPermission == true && !folder.optBoolean("invalid")),
                "writable" to (grant?.isWritePermission == true && !folder.optBoolean("invalid")))
        }
    }

    fun remember(uri: Uri, title: String) {
        val provider = context.packageManager.resolveContentProvider(uri.authority!!, 0)!!
        val source = provider.loadLabel(context.packageManager).toString()
        val path = if (uri.authority == "com.android.externalstorage.documents")
            Docs.getTreeDocumentId(uri).substringAfter(':', "") else ""
        val folders = stored().toMutableList()
        val existing = folders.indexOfFirst { it.getString("uri") == uri.toString() }
        val name = if (existing >= 0) folders[existing].getString("name") else {
            var candidate = title
            var suffix = 2
            while (folders.any { it.getString("name") == candidate }) candidate = "$title (${suffix++})"
            candidate
        }
        val item = JSONObject().put("uri", uri.toString()).put("name", name)
            .put("source", source).put("path", path)
        if (existing >= 0) folders[existing] = item else folders.add(item)
        save(folders)
    }

    fun rename(uri: String, name: String) {
        require(name.isNotBlank() && name.length <= 80) { "名称需要为 1–80 个字" }
        val folders = stored()
        require(folders.none { it.getString("uri") != uri && it.getString("name") == name }) { "已有同名文件夹，请换一个名称" }
        folders.single { it.getString("uri") == uri }.put("name", name)
        save(folders)
    }

    fun remove(uri: String) {
        context.contentResolver.persistedUriPermissions.singleOrNull { it.uri.toString() == uri }?.let {
            var flags = 0
            if (it.isReadPermission) flags = flags or Intent.FLAG_GRANT_READ_URI_PERMISSION
            if (it.isWritePermission) flags = flags or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            context.contentResolver.releasePersistableUriPermission(it.uri, flags)
        }
        save(stored().filterNot { it.getString("uri") == uri })
    }

    fun invalidate(uri: String) {
        val tree = DocumentUris.tree(Uri.parse(uri)).toString()
        val folders = stored()
        folders.firstOrNull { it.getString("uri") == tree }?.put("invalid", true)
        save(folders)
    }
}

object DocumentUris {
    fun tree(uri: Uri): Uri {
        require(uri.scheme == "content" && Docs.isTreeUri(uri)) { "请使用授权文件夹工具返回的文件链接" }
        return Docs.buildTreeDocumentUri(uri.authority, Docs.getTreeDocumentId(uri))
    }
    fun document(uri: Uri): Uri = if (uri.pathSegments.contains("document")) uri
        else Docs.buildDocumentUriUsingTree(uri, Docs.getTreeDocumentId(uri))

    fun authorized(context: Context, value: String, write: Boolean = false): Uri {
        val uri = Uri.parse(value)
        val tree = tree(uri)
        val grant = context.contentResolver.persistedUriPermissions.singleOrNull { it.uri == tree }
        if (grant?.isReadPermission != true || write && !grant.isWritePermission)
            throw SecurityException("文件夹未授权或授权已失效，请在设备能力中重新选择文件夹")
        return document(uri)
    }
}
