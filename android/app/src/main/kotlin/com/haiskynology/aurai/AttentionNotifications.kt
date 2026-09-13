package com.haiskynology.aurai

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri

object AttentionNotifications {
    private const val CHANNEL = "aurai_attention"
    private const val ID = 1110

    private data class Pending(val notification: Notification, val deadline: Long?)
    private val pending = mutableMapOf<String, Pending>()

    fun visibilityChanged(context: Context) {
        val manager = context.getSystemService(NotificationManager::class.java)
        val now = android.os.SystemClock.elapsedRealtime()
        val iterator = pending.iterator()
        while (iterator.hasNext()) {
            val (tag, entry) = iterator.next()
            if (entry.deadline != null && entry.deadline <= now) {
                manager.cancel(tag, ID)
                iterator.remove()
            } else if (MainActivity.isVisible) {
                manager.cancel(tag, ID)
            } else {
                val builder = Notification.Builder.recoverBuilder(context, entry.notification)
                if (entry.deadline != null) builder.setTimeoutAfter(entry.deadline - now)
                manager.notify(tag, ID, builder.build())
            }
        }
    }

    fun update(context: Context, conversationId: String, kind: String, title: String?, body: String?, timeoutSeconds: Int?) {
        val manager = context.getSystemService(NotificationManager::class.java)
        val tag = "$conversationId:$kind"
        if (title == null) {
            pending.remove(tag)
            manager.cancel(tag, ID)
            return
        }
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL, "等待回答与授权", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "AI 需要你回答问题或确认授权时提醒"
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
        val builder = NotificationBranding(context.resources)
            .applyTo(Notification.Builder(context, CHANNEL))
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setContentIntent(open)
            .setCategory(Notification.CATEGORY_MESSAGE)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .setAutoCancel(true)
        if (timeoutSeconds != null) builder.setTimeoutAfter(timeoutSeconds * 1000L)
        val notification = builder.build()
        pending[tag] = Pending(notification, timeoutSeconds?.let {
            android.os.SystemClock.elapsedRealtime() + it * 1000L
        })
        if (MainActivity.isVisible) manager.cancel(tag, ID)
        else manager.notify(tag, ID, notification)
    }
}
