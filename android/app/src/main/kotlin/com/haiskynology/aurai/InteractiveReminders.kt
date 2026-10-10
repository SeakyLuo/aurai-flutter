package com.haiskynology.aurai

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

/** User-triggered local reminders. No model invocation or view lifetime dependency. */
object InteractiveReminders {
    private const val CHANNEL = "interactive_reminders"
    private const val ACTION = "aurai.INTERACTIVE_REMINDER"
    private lateinit var context: Context
    private lateinit var items: JSONObject
    private lateinit var channel: MethodChannel
    private fun alarms() = context.getSystemService(AlarmManager::class.java)
    private fun notifications() = context.getSystemService(NotificationManager::class.java)
    private fun allowed() = Build.VERSION.SDK_INT < 31 || alarms().canScheduleExactAlarms()

    fun initialize(app: Context, messenger: BinaryMessenger) {
        context = app
        items = JSONObject(app.getSharedPreferences(CHANNEL, 0).getString("items", "{}")!!)
        notifications().createNotificationChannel(NotificationChannel(CHANNEL, "互动消息提醒", NotificationManager.IMPORTANCE_HIGH).apply {
            description = "由你启用的闹钟和倒计时提醒"
            setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM), AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM).setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build())
            enableVibration(true)
        })
        channel = MethodChannel(messenger, "com.haiskynology.aurai/interactive_reminders")
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "read" -> result.success(read(call.argument<String>("messageId")!!, call.argument<String>("actorId")!!))
                    "apply" -> {
                        @Suppress("UNCHECKED_CAST")
                        apply(call.arguments as Map<String, Any?>)
                        result.success(null)
                    }
                    "permissions" -> permissions(result)
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error(error.javaClass.simpleName, error.toString(), null)
            }
        }
    }

    private fun read(messageId: String, actorId: String): Map<String, Any?> {
        val result = linkedMapOf<String, Any?>()
        for (id in items.keys()) {
            val identity = JSONArray(id)
            if (identity.getString(0) != messageId || identity.getString(1) != actorId) continue
            val item = items.getJSONObject(id)
            result[identity.getString(2)] = mapOf("at" to item.getLong("at"), "enabled" to (item.getLong("at") > 0),
                "title" to item.getString("title"), "ringUntil" to item.getLong("ringUntil"))
        }
        return result
    }

    private fun permissions(result: MethodChannel.Result) {
        val activity = checkNotNull(MainActivity.current) { "请在应用前台设置提醒权限" }
        activity.requestNotificationPermission { granted ->
            if (!granted) {
                result.error("notification_permission", "通知权限未开启，无法设置响铃提醒", null)
            } else {
                try {
                    when {
                        !notifications().areNotificationsEnabled() -> activity.startActivity(
                            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName))
                        !allowed() -> activity.startActivity(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                            Uri.parse("package:${context.packageName}")))
                        notifications().getNotificationChannel(CHANNEL).importance == NotificationManager.IMPORTANCE_NONE ->
                            activity.startActivity(Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
                                .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                                .putExtra(Settings.EXTRA_CHANNEL_ID, CHANNEL))
                    }
                    result.success(null)
                } catch (error: Exception) {
                    result.error(error.javaClass.simpleName, error.toString(), null)
                }
            }
        }
    }

    private fun open(id: String): PendingIntent = PendingIntent.getActivity(context, 0,
        Intent(context, MainActivity::class.java).setAction(Intent.ACTION_MAIN)
            .setData(Uri.Builder().scheme("aurai").authority("reminder").appendPath(id).build())
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

    private fun pending(id: String, command: String = "due"): PendingIntent = PendingIntent.getBroadcast(
        context, 0, Intent(context, InteractiveReminderReceiver::class.java)
            .setAction(ACTION).setData(Uri.Builder().scheme("aurai").authority("reminder").appendPath(id).appendPath(command).build()),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    private fun save() {
        check(context.getSharedPreferences(CHANNEL, 0).edit().putString("items", items.toString()).commit()) { "保存提醒失败" }
    }

    private fun schedule(id: String, item: JSONObject) {
        alarms().setAlarmClock(AlarmManager.AlarmClockInfo(item.getLong("at"), open(id)), pending(id))
    }

    private fun apply(args: Map<String, Any?>) {
        val id = args["id"] as String
        if (args["cancel"] == true) {
            alarms().cancel(pending(id))
            notifications().cancel(id, 0)
            items.remove(id)
            save()
            channel.invokeMethod("changed", id)
            return
        }
        check(allowed()) { "请先通过提醒权限入口开启精确闹钟权限" }
        check(notifications().areNotificationsEnabled() && notifications().getNotificationChannel(CHANNEL).importance != NotificationManager.IMPORTANCE_NONE) {
            "请先通过提醒权限入口开启通知权限"
        }
        val suppliedAt = (args["at"] as Number).toDouble()
        require(suppliedAt.isFinite() && suppliedAt == suppliedAt.toLong().toDouble()) { "提醒时间需要整数毫秒时间戳" }
        val at = suppliedAt.toLong()
        require(at > System.currentTimeMillis()) { "提醒时间必须晚于当前时间" }
        val title = args["title"] as String
        val body = args["body"] as String? ?: "时间到了"
        require(title.isNotBlank() && title.length <= 100 && body.length <= 1000) { "提醒标题需要 1–100 字，正文最多 1000 字" }
        val weekdays = (args["weekdays"] as List<*>).map { (it as Number).toInt() }
        require(weekdays.size <= 7 && weekdays.distinct().size == weekdays.size && weekdays.all { it in 1..7 }) { "重复星期无效" }
        require(items.has(id) || items.length() < 64) { "同时启用的提醒最多 64 个，请先关闭不再使用的提醒" }
        val calendar = Calendar.getInstance().apply { timeInMillis = at }
        val item = JSONObject().put("at", at).put("ringUntil", 0L).put("title", title).put("body", body).put("weekdays", JSONArray(weekdays))
            .put("hour", calendar.get(Calendar.HOUR_OF_DAY)).put("minute", calendar.get(Calendar.MINUTE))
        if (weekdays.isNotEmpty()) {
            val weekday = (calendar.get(Calendar.DAY_OF_WEEK) + 5) % 7 + 1
            require(weekday in weekdays) { "首次提醒时间必须符合重复星期" }
        }
        // Register before changing saved UI state; a permission failure never looks armed.
        schedule(id, item)
        items.put(id, item)
        save()
        notifications().cancel(id, 0)
        channel.invokeMethod("changed", id)
    }

    private fun next(item: JSONObject, after: Long): Long {
        val weekdays = item.getJSONArray("weekdays")
        val selected = (0 until weekdays.length()).map { weekdays.getInt(it) }
        val date = Calendar.getInstance().apply {
            timeInMillis = after
            set(Calendar.HOUR_OF_DAY, item.getInt("hour")); set(Calendar.MINUTE, item.getInt("minute"))
            set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        }
        repeat(8) {
            val weekday = (date.get(Calendar.DAY_OF_WEEK) + 5) % 7 + 1
            if (date.timeInMillis > after && weekday in selected) return date.timeInMillis
            date.add(Calendar.DAY_OF_MONTH, 1)
        }
        error("无法计算下一次提醒")
    }

    fun receive(intent: Intent) {
        if (intent.action != ACTION) {
            restore(intent.action == Intent.ACTION_TIMEZONE_CHANGED || intent.action == Intent.ACTION_TIME_CHANGED)
            return
        }
        val segments = intent.data!!.pathSegments
        val id = segments[0]
        when (segments[1]) {
            "open" -> context.startActivity(Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            "stop" -> {
                notifications().cancel(id, 0)
                if (items.has(id)) {
                    val item = items.getJSONObject(id)
                    if (item.getJSONArray("weekdays").length() == 0) items.remove(id)
                    else item.put("ringUntil", 0L)
                    save()
                }
            }
            "snooze" -> {
                val item = items.getJSONObject(id)
                check(allowed()) { "精确闹钟权限已关闭" }
                item.put("at", System.currentTimeMillis() + 300_000).put("ringUntil", 0L)
                schedule(id, item); save(); notifications().cancel(id, 0)
            }
            "due" -> {
                if (!items.has(id)) return // A cancelled alarm may already be queued by Android.
                val item = items.getJSONObject(id)
                if (item.getLong("at") > System.currentTimeMillis() + 1000) return
                val notification = NotificationBranding(context.resources).applyTo(Notification.Builder(context, CHANNEL))
                    .setContentTitle(item.getString("title")).setContentText(item.getString("body"))
                    .setCategory(Notification.CATEGORY_ALARM).setAutoCancel(false)
                    .setContentIntent(open(id)).setDeleteIntent(pending(id, "stop"))
                    .addAction(Notification.Action.Builder(null, "停止", pending(id, "stop")).build())
                    .addAction(Notification.Action.Builder(null, "稍后 5 分钟", pending(id, "snooze")).build())
                    .setTimeoutAfter(600_000).build().apply { flags = flags or Notification.FLAG_INSISTENT }
                notifications().notify(id, 0, notification)
                item.put("ringUntil", System.currentTimeMillis() + 600_000)
                if (item.getJSONArray("weekdays").length() != 0) {
                    item.put("at", next(item, System.currentTimeMillis())); schedule(id, item)
                } else item.put("at", 0)
                save()
            }
        }
        channel.invokeMethod("changed", id)
    }

    private fun restore(timeChanged: Boolean) {
        if (!allowed()) return // Permission is surfaced when the user next enables a reminder.
        for (id in items.keys().asSequence().toList()) {
            val item = items.getJSONObject(id)
            if (item.getLong("at") == 0L) continue
            if (timeChanged && item.getJSONArray("weekdays").length() != 0) item.put("at", next(item, System.currentTimeMillis()))
            schedule(id, item)
        }
        save()
    }
}

class InteractiveReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        try {
            InteractiveReminders.receive(intent)
        } catch (error: Exception) {
            android.util.Log.e("InteractiveReminder", "Reminder delivery failed", error)
            android.widget.Toast.makeText(context, error.toString(), android.widget.Toast.LENGTH_LONG).show()
        }
    }
}
