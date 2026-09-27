package com.haiskynology.aurai

import android.content.Context
import android.content.Intent
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.drawable.Icon
import android.os.Build
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class ProjectShortcutAccess(private val context: Context) {
    fun handle(call: MethodCall, result: MethodChannel.Result): Boolean {
        if (call.method != "pinProjectShortcut") return false
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            result.error("shortcut_unsupported", "当前系统不支持添加到主屏幕", null)
            return true
        }
        val manager = context.getSystemService(ShortcutManager::class.java)
        if (!manager.isRequestPinShortcutSupported) {
            result.error("shortcut_unsupported", "当前桌面不支持添加快捷方式", null)
            return true
        }
        val projectId = call.argument<String>("projectId")!!
        val shortcut = ShortcutInfo.Builder(context, "project:" + projectId)
            .setShortLabel(call.argument<String>("name")!!)
            .setIcon(Icon.createWithResource(context, R.mipmap.ic_aurai_brand))
            .setIntent(Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                putExtra("projectId", projectId)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }).build()
        if (manager.pinnedShortcuts.any { it.id == shortcut.id }) {
            manager.updateShortcuts(listOf(shortcut))
            result.success(mapOf("existing" to true))
        } else if (manager.requestPinShortcut(shortcut, null)) {
            result.success(mapOf("existing" to false))
        } else {
            result.error("shortcut_rejected", "桌面未接受添加请求，请检查桌面权限", null)
        }
        return true
    }
}
