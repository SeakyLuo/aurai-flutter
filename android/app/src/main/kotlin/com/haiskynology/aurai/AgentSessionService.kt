package com.haiskynology.aurai

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.PowerManager
import android.os.Looper

class AgentSessionService : Service() {
    private val power by lazy { getSystemService(PowerManager::class.java) }
    private val executionLock by lazy {
        power.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "Aurai:agentExecution").apply {
            setReferenceCounted(false)
        }
    }
    private val renewExecutionLock = object : Runnable {
        override fun run() {
            executionLock.acquire(10 * 60_000L)
            handler.postDelayed(this, 5 * 60_000L)
        }
    }

    private fun keepExecutionAwake() {
        handler.removeCallbacks(renewExecutionLock)
        renewExecutionLock.run()
    }

    private fun releaseExecutionLock() {
        handler.removeCallbacks(renewExecutionLock)
        if (executionLock.isHeld) executionLock.release()
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        releaseExecutionLock()
        running = false
        super.onDestroy()
    }

    private var groupChat = false
    private var avatar: ByteArray? = null
    private val handler = Handler(Looper.getMainLooper())
    private val notificationBranding by lazy { NotificationBranding(resources) }

    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action ?: ACTION_START) {
            ACTION_SCHEDULED -> {
                groupChat = false
                avatar = null
                running = true
                startForeground(NOTIFICATION_ID, runningNotification("正在启动定时任务"))
                keepExecutionAwake()
                ScheduledTasks.dispatch()
                handler.postDelayed({ ScheduledTasks.startupTimedOut() }, 60_000)
            }
            ACTION_START -> {
                groupChat = intent!!.getBooleanExtra("groupChat", false)
                avatar = intent.getByteArrayExtra("avatar")
                running = true
                startForeground(NOTIFICATION_ID, runningNotification(intent!!.getStringExtra(EXTRA_STEP)!!))
                keepExecutionAwake()
            }
            ACTION_STEP -> notificationManager().notify(
                NOTIFICATION_ID,
                runningNotification(intent!!.getStringExtra(EXTRA_STEP)!!),
            )
            ACTION_STOP -> {
                notificationManager().notify(NOTIFICATION_ID, runningNotification("正在停止"))
                val stoppingId = AndroidAgentBridge.activeConversationId
                AuraiApplication.requestAgentStop(stoppingId)
                handler.postDelayed({
                    if (AndroidAgentBridge.activeConversationId == stoppingId && AndroidAgentBridge.sessionCount <= 1) finish("failed")
                }, STOP_TIMEOUT_MS)
            }
            ACTION_FINISH -> finish(
                intent!!.getStringExtra(EXTRA_OUTCOME)!!,
                intent.getStringExtra("conversationId"),
                intent.getStringExtra("title"),
                intent.getStringExtra("reply"),
                intent.getByteArrayExtra("avatar"),
                intent.getBooleanExtra("keepRunning", false),
                intent.getBooleanExtra("completedGroupChat", groupChat),
            )
        }
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun finish(outcome: String, conversationId: String? = null, title: String? = null, reply: String? = null, completedAvatar: ByteArray? = avatar, keepRunning: Boolean = false, completedGroupChat: Boolean = groupChat) {
        val previousAvatar = avatar
        avatar = completedAvatar
        handler.removeCallbacksAndMessages(null)
        if (keepRunning) keepExecutionAwake()
        if (!keepRunning) {
            releaseExecutionLock()
            running = false
            stopForeground(STOP_FOREGROUND_REMOVE)
        }
        if (!completedGroupChat && outcome != "cancelled" && !(MainActivity.isResumed && power.isInteractive) &&
            (outcome != "completed" || reply!!.isNotBlank())) {
            notificationManager().notify(
                conversationId, FINISHED_NOTIFICATION_ID,
                finishedNotification(outcome == "completed", conversationId, title, reply),
            )
        }
        avatar = previousAvatar
        if (!keepRunning) stopSelf()
    }

    private fun runningNotification(step: String): Notification =
        notificationBranding.applyTo(
            Notification.Builder(this, if (groupChat) GROUP_SERVICE_CHANNEL_ID else CHANNEL_ID),
            showLargeIcon = !groupChat,
            avatar = avatar,
        )
            .apply {
                if (groupChat) {
                    setShowWhen(false)
                    setContentTitle(step.substringBefore('\n'))
                    setContentText(step.substringAfter('\n', ""))
                    setStyle(Notification.BigTextStyle().bigText(step.substringAfter('\n', "")))
                } else {
                    setShowWhen(false)
                    setContentTitle("Aurai")
                    setContentText(step)
                    setStyle(Notification.BigTextStyle().bigText(step))
                }
            }
            .setContentIntent(openAppIntent())
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .apply { if (!groupChat) addAction(
                Notification.Action.Builder(
                    null,
                    "停止",
                    PendingIntent.getService(
                        this@AgentSessionService,
                        2,
                        Intent(this@AgentSessionService, AgentSessionService::class.java).setAction(ACTION_STOP),
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                    ),
                ).build(),
            ) }
            .build()

    private fun finishedNotification(completed: Boolean, conversationId: String?, title: String?, reply: String?): Notification =
        notificationBranding.applyTo(Notification.Builder(this, RESULT_CHANNEL_ID), avatar = avatar)
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
            NotificationChannel(GROUP_SERVICE_CHANNEL_ID, "后台连接", NotificationManager.IMPORTANCE_MIN).apply {
                description = "维持后台消息连接，不作为群消息提醒"
                setSound(null, null)
                enableVibration(false)
                setShowBadge(false)
            },
        )
        notificationManager().createNotificationChannel(
            NotificationChannel(RESULT_CHANNEL_ID, "回复完成", NotificationManager.IMPORTANCE_HIGH).apply {
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
        private const val GROUP_SERVICE_CHANNEL_ID = "aurai_group_connection"
        private const val RESULT_CHANNEL_ID = "aurai_reply_complete"
        private const val FINISHED_NOTIFICATION_ID = 1109
        private const val CHANNEL_ID = "aurai_agent_session"
        private const val NOTIFICATION_ID = 1107
        private const val ACTION_SCHEDULED = "com.haiskynology.aurai.agent.SCHEDULED"
        private const val ACTION_START = "com.haiskynology.aurai.agent.START"
        private const val ACTION_STEP = "com.haiskynology.aurai.agent.STEP"
        private const val ACTION_STOP = "com.haiskynology.aurai.agent.STOP"
        private const val ACTION_FINISH = "com.haiskynology.aurai.agent.FINISH"
        private const val EXTRA_STEP = "step"
        private const val EXTRA_OUTCOME = "outcome"
        private const val STOP_TIMEOUT_MS = 10_000L
        @Volatile private var running = false

        val isRunning: Boolean get() = running
        fun startScheduled(context: Context) {
            context.startForegroundService(Intent(context, AgentSessionService::class.java).setAction(ACTION_SCHEDULED))
        }

        fun start(context: Context, step: String, groupChat: Boolean = false, avatar: ByteArray? = null) {
            val intent = Intent(context, AgentSessionService::class.java).setAction(ACTION_START).putExtra(EXTRA_STEP, step).putExtra("groupChat", groupChat).putExtra("avatar", avatar)
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

        fun finish(context: Context, outcome: String, conversationId: String, title: String, reply: String, avatar: ByteArray? = null, keepRunning: Boolean = false, completedGroupChat: Boolean = false) {
            context.startService(
                Intent(context, AgentSessionService::class.java)
                    .setAction(ACTION_FINISH)
                    .putExtra(EXTRA_OUTCOME, outcome)
                    .putExtra("conversationId", conversationId)
                    .putExtra("title", title)
                    .putExtra("reply", reply.take(4000))
                    .putExtra("avatar", avatar)
                    .putExtra("keepRunning", keepRunning)
                    .putExtra("completedGroupChat", completedGroupChat),
            )
        }

        fun clearFinishedNotification(context: Context) {
            if (!running) {
                context.getSystemService(NotificationManager::class.java).cancel(NOTIFICATION_ID)
            }
        }
    }
}
