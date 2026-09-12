package com.haiskynology.aurai

import android.app.Notification
import android.content.res.Resources
import android.graphics.BitmapFactory
import android.graphics.drawable.Icon

class NotificationBranding(resources: Resources) {
    private val largeIcon = BitmapFactory.decodeResource(resources, R.mipmap.ic_aurai_brand)
    private val smallIcon = Icon.createWithBitmap(largeIcon)

    fun applyTo(builder: Notification.Builder): Notification.Builder = builder
        .setSmallIcon(smallIcon)
        .setLargeIcon(largeIcon)
}
