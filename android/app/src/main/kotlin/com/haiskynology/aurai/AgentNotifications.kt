package com.haiskynology.aurai

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import java.util.UUID

class AgentNotifications(private val context: Context) {
    private val notificationBranding by lazy { NotificationBranding(context.resources) }

    fun send(title: String, body: String, conversationId: String): Map<String, Any> {
        if (title.isBlank() || title.length > 120 || body.isBlank() || body.length > 4000) {
            return mapOf("sent" to false, "message" to "通知标题须为 1–120 字，正文须为 1–4000 字")
        }
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "AI 通知", NotificationManager.IMPORTANCE_DEFAULT).apply {
                description = "AI 按任务需要发送的通知"
            },
        )
        if (!manager.areNotificationsEnabled() ||
            manager.getNotificationChannel(CHANNEL_ID).importance == NotificationManager.IMPORTANCE_NONE
        ) {
            return mapOf("sent" to false, "message" to "通知已关闭，请在 Aurai 设置中的通知页面开启 AI 通知")
        }
        val openConversation = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                data = Uri.parse("aurai://conversation/${Uri.encode(conversationId)}")
                putExtra("conversationId", conversationId)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = notificationBranding.applyTo(Notification.Builder(context, CHANNEL_ID))
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setContentIntent(openConversation)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .setAutoCancel(true)
            .build()
        try {
            manager.notify(UUID.randomUUID().toString(), 0, notification)
        } catch (error: SecurityException) {
            return mapOf("sent" to false, "message" to "系统未允许 Aurai 发送通知")
        }
        return mapOf("sent" to true)
    }

    private companion object {
        const val CHANNEL_ID = "aurai_ai_notifications"
    }
}
