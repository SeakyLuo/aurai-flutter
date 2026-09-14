package com.haiskynology.aurai

import android.app.Notification
import android.content.res.Resources
import android.graphics.BitmapFactory

class NotificationBranding(resources: Resources) {
    private val largeIcon = BitmapFactory.decodeResource(resources, R.mipmap.ic_aurai_brand)

    fun applyTo(builder: Notification.Builder, showLargeIcon: Boolean = true, avatar: ByteArray? = null): Notification.Builder = builder
        .setSmallIcon(R.drawable.ic_stat_aurai)
        .apply { if (showLargeIcon) setLargeIcon(avatar?.let { BitmapFactory.decodeByteArray(it, 0, it.size) } ?: largeIcon) }
}
