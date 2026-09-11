package com.haiskynology.aurai

import android.app.Notification
import android.app.NotificationManager
import android.content.ComponentName
import android.content.Context
import android.os.Build
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import java.time.Instant
import java.util.ArrayDeque

class AuraiNotificationListenerService : NotificationListenerService() {
    private data class ObservedNotification(
        val key: String,
        val appName: String,
        val observedAtMs: Long,
        val postedAtMs: Long,
        val category: String,
        val title: String?,
        val content: String,
        val redacted: Boolean,
        val profile: String,
    )

    override fun onListenerConnected() {
        super.onListenerConnected()
        synchronized(lock) {
            instance = this
            listenerEpoch += 1
            coverageStartMs = System.currentTimeMillis()
            dropped = false
            rebindRequested = false
            cache.clear()
            activeNotifications.forEach(::record)
        }
    }

    override fun onListenerDisconnected() {
        synchronized(lock) {
            if (instance === this) instance = null
            rebindRequested = false
        }
        super.onListenerDisconnected()
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        synchronized(lock) { record(sbn) }
    }

    private fun record(sbn: StatusBarNotification) {
        if (sbn.packageName == packageName) return
        val appName = packageManager.getApplicationLabel(
            packageManager.getApplicationInfo(sbn.packageName, 0),
        ).toString()
        val extras = sbn.notification.extras
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim()
        val text = listOfNotNull(
            extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()?.trim(),
            extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()?.trim(),
        ).distinct().joinToString("\n")
        val combined = listOfNotNull(title, text.ifEmpty { null }).joinToString("\n")
        val sensitiveCategory = sensitiveCategory(combined)
        val isSensitive = sensitiveCategory != null
        val item = ObservedNotification(
            key = sbn.key,
            appName = appName,
            observedAtMs = System.currentTimeMillis(),
            postedAtMs = sbn.postTime,
            category = sensitiveCategory ?: notificationCategory(sbn.notification.category),
            title = if (isSensitive) null else title,
            content = if (isSensitive) HIDDEN_CONTENT else text,
            redacted = isSensitive,
            profile = if (sbn.user == android.os.Process.myUserHandle()) "当前用户" else "其他资料",
        )
        cache.removeIf { cached -> cached.key == sbn.key }
        cache.addFirst(item)
        if (cache.size > CACHE_LIMIT) {
            cache.removeLast()
            dropped = true
        }
    }

    private fun sensitiveCategory(text: String): String? = when {
        verificationPattern.containsMatchIn(text) -> "verification"
        accountSecurityPattern.containsMatchIn(text) -> "account_security"
        transferPattern.containsMatchIn(text) -> "transfer"
        paymentPattern.containsMatchIn(text) -> "payment"
        else -> null
    }

    private fun notificationCategory(category: String?): String = when (category) {
        Notification.CATEGORY_MESSAGE -> "message"
        Notification.CATEGORY_CALL -> "call"
        Notification.CATEGORY_EMAIL -> "email"
        Notification.CATEGORY_EVENT -> "event"
        Notification.CATEGORY_TRANSPORT -> "media"
        Notification.CATEGORY_PROGRESS -> "progress"
        Notification.CATEGORY_SERVICE -> "service"
        else -> "other"
    }

    companion object {
        private const val CACHE_LIMIT = 100
        private const val HIDDEN_CONTENT = "[敏感通知内容已隐藏]"
        private val lock = Any()
        private val cache = ArrayDeque<ObservedNotification>()
        private var coverageStartMs = 0L
        private var listenerEpoch = 0L
        private var dropped = false
        private var rebindRequested = false
        var instance: AuraiNotificationListenerService? = null
            private set

        private val verificationPattern = Regex(
            "验证码|校验码|动态码|一次性密码|verification code|security code|\\botp\\b|\\b2fa\\b",
            RegexOption.IGNORE_CASE,
        )
        private val accountSecurityPattern = Regex(
            "密码重置|重置密码|登录验证|异常登录|账户安全|账号安全|password reset|login verification|account security|security alert",
            RegexOption.IGNORE_CASE,
        )
        private val transferPattern = Regex(
            "转账|汇款|收款|到账|transfer|remittance",
            RegexOption.IGNORE_CASE,
        )
        private val paymentPattern = Regex(
            "付款|支付|扣款|银行卡|信用卡|银行|payment|paid|bank|credit card|debit card",
            RegexOption.IGNORE_CASE,
        )

        fun accessState(context: Context): Map<String, Any?> {
            val component = ComponentName(context, AuraiNotificationListenerService::class.java)
            val manager = context.getSystemService(NotificationManager::class.java)
            val granted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                manager.isNotificationListenerAccessGranted(component)
            } else {
                android.provider.Settings.Secure.getString(
                    context.contentResolver,
                    "enabled_notification_listeners",
                )?.split(':')?.map(ComponentName::unflattenFromString)?.contains(component) == true
            }
            synchronized(lock) {
                if (!granted) {
                    return mapOf(
                        "availability" to "permissionRequired",
                        "reason" to "需要在系统设置中允许 Aurai 读取通知",
                    )
                }
                val connected = instance != null
                if (!connected && !rebindRequested) {
                    requestRebind(component)
                    rebindRequested = true
                }
                return if (connected) {
                    mapOf(
                        "availability" to "available",
                        "reason" to "通知监听已连接；内容仅在任务内按范围读取",
                        "listenerEpoch" to listenerEpoch,
                    )
                } else {
                    mapOf(
                        "availability" to "unavailable",
                        "reason" to "系统已授权，但通知监听暂未连接；已请求系统重新连接一次",
                    )
                }
            }
        }

        fun query(
            lookbackMinutes: Int,
            limit: Int,
            appName: String?,
        ): Map<String, Any?> = synchronized(lock) {
            if (instance == null) {
                return@synchronized mapOf(
                    "availability" to "unavailable",
                    "reason" to "通知监听在读取前断开，请稍后重试",
                )
            }
            val requestedStart = System.currentTimeMillis() - lookbackMinutes * 60_000L
            val matches = cache.asSequence()
                .filter { item -> item.observedAtMs >= requestedStart }
                .filter { item -> appName == null || item.appName.contains(appName, ignoreCase = true) }
                .take(limit)
                .map { item ->
                    mapOf(
                        "app" to item.appName,
                        "postedAt" to Instant.ofEpochMilli(item.postedAtMs).toString(),
                        "category" to item.category,
                        "profile" to item.profile,
                        "redacted" to item.redacted,
                        "title" to item.title,
                        "content" to item.content,
                    )
                }
                .toList()
            mapOf(
                "availability" to "available",
                "notifications" to matches,
                "coverageStart" to Instant.ofEpochMilli(coverageStartMs).toString(),
                "partial" to (dropped || requestedStart < coverageStartMs),
                "absenceMeaning" to "仅表示从 coverageStart 起、在当前内存覆盖范围内未观察到匹配通知",
            )
        }
    }
}
