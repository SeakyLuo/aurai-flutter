package com.haiskynology.aurai

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri

object GroupMessageNotifications {
    private const val CHANNEL_ID = "aurai_group_messages"

    fun show(context: Context, conversationId: String, title: String, body: String, avatar: ByteArray) {
        if (MainActivity.isResumed) return
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "群消息", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "群成员实际发送的新消息"
            },
        )
        val open = PendingIntent.getActivity(
            context, 0,
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                data = Uri.parse("aurai://conversation/${Uri.encode(conversationId)}")
                putExtra("conversationId", conversationId)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationBranding(context.resources)
            .applyTo(Notification.Builder(context, CHANNEL_ID), avatar = avatar)
            .setContentTitle(title)
            .setContentText(body.take(240))
            .setStyle(Notification.BigTextStyle().bigText(body.take(4000)))
            .setContentIntent(open)
            .setCategory(Notification.CATEGORY_MESSAGE)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .setOnlyAlertOnce(true)
            .setAutoCancel(true)
            .build()
        manager.notify("group:$conversationId", 1110, notification)
    }
}
