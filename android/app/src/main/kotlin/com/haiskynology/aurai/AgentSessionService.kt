package com.haiskynology.aurai

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper

class AgentSessionService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private val coverLogo by lazy { BitmapFactory.decodeResource(resources, R.mipmap.ic_launcher) }

    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action ?: ACTION_START) {
            ACTION_START -> {
                running = true
                startForeground(NOTIFICATION_ID, runningNotification("正在准备"))
            }
            ACTION_STEP -> notificationManager().notify(
                NOTIFICATION_ID,
                runningNotification(intent!!.getStringExtra(EXTRA_STEP)!!),
            )
            ACTION_STOP -> {
                notificationManager().notify(NOTIFICATION_ID, runningNotification("正在停止"))
                AuraiApplication.requestAgentStop()
                handler.postDelayed({ finish("failed") }, STOP_TIMEOUT_MS)
            }
            ACTION_FINISH -> finish(
                intent!!.getStringExtra(EXTRA_OUTCOME)!!,
                intent.getStringExtra("conversationId"),
                intent.getStringExtra("title"),
                intent.getStringExtra("reply"),
            )
        }
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun finish(outcome: String, conversationId: String? = null, title: String? = null, reply: String? = null) {
        handler.removeCallbacksAndMessages(null)
        running = false
        stopForeground(STOP_FOREGROUND_REMOVE)
        if (outcome != "cancelled" && !MainActivity.isResumed) {
            notificationManager().notify(
                conversationId, FINISHED_NOTIFICATION_ID,
                finishedNotification(outcome == "completed", conversationId, title, reply),
            )
        }
        stopSelf()
    }

    private fun runningNotification(step: String): Notification =
        Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_aurai)
            .setLargeIcon(coverLogo)
            .setContentTitle("Aurai 正在执行任务")
            .setContentText(step)
            .setContentIntent(openAppIntent())
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .addAction(
                Notification.Action.Builder(
                    null,
                    "停止",
                    PendingIntent.getService(
                        this,
                        2,
                        Intent(this, AgentSessionService::class.java).setAction(ACTION_STOP),
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                    ),
                ).build(),
            )
            .build()

    private fun finishedNotification(completed: Boolean, conversationId: String?, title: String?, reply: String?): Notification =
        Notification.Builder(this, RESULT_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_aurai)
            .setLargeIcon(coverLogo)
            .setContentTitle(if (completed) "${title!!} · 已完成回复" else "任务未完成")
            .setContentText(if (completed) reply!!.take(240) else "点按返回 Aurai 处理")
            .setStyle(Notification.BigTextStyle().bigText(if (completed) reply!!.take(4000) else "点按返回 Aurai 处理"))
            .setContentIntent(openAppIntent(conversationId))
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .setAutoCancel(true)
            .build()

    private fun openAppIntent(conversationId: String? = null) = PendingIntent.getActivity(
        this,
        1,
        Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            if (conversationId != null) {
                data = Uri.parse("aurai://conversation/${Uri.encode(conversationId)}")
                putExtra("conversationId", conversationId)
            }
        },
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    private fun createChannel() {
        notificationManager().createNotificationChannel(
            NotificationChannel(RESULT_CHANNEL_ID, "回复完成", NotificationManager.IMPORTANCE_DEFAULT).apply {
                description = "会话在后台完成后的回复通知"
            },
        )
        notificationManager().createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                "Agent 任务",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "显示 Aurai 正在执行的任务状态"
                setSound(null, null)
                enableVibration(false)
            },
        )
    }

    private fun notificationManager() = getSystemService(NotificationManager::class.java)

    companion object {
        private const val RESULT_CHANNEL_ID = "aurai_reply_complete"
        private const val FINISHED_NOTIFICATION_ID = 1109
        private const val CHANNEL_ID = "aurai_agent_session"
        private const val NOTIFICATION_ID = 1107
        private const val ACTION_START = "com.haiskynology.aurai.agent.START"
        private const val ACTION_STEP = "com.haiskynology.aurai.agent.STEP"
        private const val ACTION_STOP = "com.haiskynology.aurai.agent.STOP"
        private const val ACTION_FINISH = "com.haiskynology.aurai.agent.FINISH"
        private const val EXTRA_STEP = "step"
        private const val EXTRA_OUTCOME = "outcome"
        private const val STOP_TIMEOUT_MS = 10_000L
        @Volatile private var running = false

        fun start(context: Context) {
            val intent = Intent(context, AgentSessionService::class.java).setAction(ACTION_START)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun updateStep(context: Context, step: String) {
            context.startService(
                Intent(context, AgentSessionService::class.java)
                    .setAction(ACTION_STEP)
                    .putExtra(EXTRA_STEP, step),
            )
        }

        fun finish(context: Context, outcome: String, conversationId: String, title: String, reply: String) {
            context.startService(
                Intent(context, AgentSessionService::class.java)
                    .setAction(ACTION_FINISH)
                    .putExtra(EXTRA_OUTCOME, outcome)
                    .putExtra("conversationId", conversationId)
                    .putExtra("title", title)
                    .putExtra("reply", reply.take(4000)),
            )
        }

        fun clearFinishedNotification(context: Context) {
            if (!running) {
                context.getSystemService(NotificationManager::class.java).cancel(NOTIFICATION_ID)
            }
        }
    }
}
