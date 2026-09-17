package com.haiskynology.aurai

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import org.dmfs.rfc5545.DateTime
import org.dmfs.rfc5545.recur.RecurrenceRule
import java.util.TimeZone
import java.util.UUID

object ScheduledTasks {
    private lateinit var context: Context
    private lateinit var channel: MethodChannel
    private val tasks = linkedMapOf<String, JSONObject>()
    private val activeStates = setOf("starting", "running")
    var pendingId: String? = null
        private set
    private fun alarms() = context.getSystemService(AlarmManager::class.java)
    fun allowed() = Build.VERSION.SDK_INT < 31 || alarms().canScheduleExactAlarms()

    fun initialize(app: Context, messenger: BinaryMessenger) {
        context = app
        val stored = JSONArray(app.getSharedPreferences("scheduled_tasks", 0).getString("tasks", "[]"))
        for (i in 0 until stored.length()) {
            val task = stored.getJSONObject(i)
            when (task.getString("state")) {
                "starting" -> task.put("state", "scheduled")
                "running" -> {
                    task.put("lastOutcome", "interrupted")
                    task.put("state", if (next(task)) "scheduled" else "interrupted")
                }
            }
            tasks[task.getString("id")] = task
        }
        channel = MethodChannel(messenger, "com.haiskynology.aurai/scheduled_tasks")
        channel.setMethodCallHandler { call, result ->
            try {
                @Suppress("UNCHECKED_CAST")
                val args = call.arguments as? Map<String, Any?> ?: emptyMap()
                val output: Any? = when (call.method) {
                    "list" -> mapOf("allowed" to allowed(), "tasks" to tasks.values.map(::map), "timezone" to TimeZone.getDefault().id)
                    "save" -> save(args)
                    "manage" -> manage(args)
                    "permission" -> {
                        if (Build.VERSION.SDK_INT >= 31) context.startActivity(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                            Uri.parse("package:${context.packageName}")).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        null
                    }
                    "take" -> {
                        val task = pendingId?.let(tasks::get)
                        if (task != null && task.getString("state") == "starting") {
                            if (args["busy"] == true) {
                                val deferred = JSONObject(task.toString()).put("state", "scheduled")
                                commitTask(deferred, null)
                                syncAlarm(deferred, System.currentTimeMillis() + 60_000)
                                AgentSessionService.finish(context, "cancelled", "", "", "")
                                null
                            } else {
                                val running = JSONObject(task.toString()).put("state", "running")
                                commitTask(running)
                                map(running)
                            }
                        } else null
                    }
                    "finish" -> { complete(args); null }
                    else -> throw IllegalArgumentException("未知任务操作")
                }
                result.success(output)
            } catch (error: Exception) {
                result.error("schedule_error", error.message, null)
            }
        }
        restore()
    }

    private fun map(task: JSONObject): Map<String, Any?> = task.keys().asSequence().associateWith {
        if (task.isNull(it)) null else task.get(it)
    }
    private fun changed() {
        try { channel.invokeMethod("changed", null) }
        catch (error: Exception) { android.util.Log.w("AuraiSchedule", "Task committed; UI notification failed", error) }
    }

    private fun commitTasks(next: Map<String, JSONObject>, pending: String? = pendingId) {
        check(context.getSharedPreferences("scheduled_tasks", 0).edit()
            .putString("tasks", JSONArray(next.values.toList()).toString()).commit()) { "无法保存任务" }
        tasks.clear()
        tasks.putAll(next)
        pendingId = pending
        changed()
    }

    private fun commitTask(task: JSONObject, pending: String? = pendingId) {
        val next = LinkedHashMap(tasks).apply { put(task.getString("id"), task) }
        commitTasks(next, pending)
    }

    private fun cancelAlarm(id: String) {
        alarmRetries.remove(id)?.let(alarmHandler::removeCallbacks)
        try { alarms().cancel(intent(id)) }
        catch (error: Exception) {
            // A stale broadcast is harmless: due() rechecks the committed state.
            android.util.Log.w("AuraiSchedule", "Task disabled; old alarm could not be cancelled", error)
        }
    }

    private val alarmHandler = android.os.Handler(android.os.Looper.getMainLooper())
    private val alarmRetries = mutableMapOf<String, Runnable>()

    // Persisted scheduled state is the intent. Restart recovery and this retry
    // converge the system alarm without replaying the task that just completed.
    private fun syncAlarm(task: JSONObject, at: Long = task.getLong("runAt")) {
        val id = task.getString("id")
        alarmRetries.remove(id)?.let(alarmHandler::removeCallbacks)
        try { arm(task, at) }
        catch (error: Exception) {
            android.util.Log.w("AuraiSchedule", "Task saved; alarm synchronization will retry", error)
            val retry = Runnable {
                alarmRetries.remove(id)
                if (tasks[id] === task && task.getString("state") == "scheduled") {
                    syncAlarm(task, maxOf(at, System.currentTimeMillis() + 1000))
                }
            }
            alarmRetries[id] = retry
            alarmHandler.postDelayed(retry, 60_000)
        }
    }

    private fun persist() {
        val data = JSONArray(tasks.values.toList()).toString()
        check(context.getSharedPreferences("scheduled_tasks", 0).edit().putString("tasks", data).commit()) { "无法保存任务" }
        changed()
    }
    private fun intent(id: String) = PendingIntent.getBroadcast(context, 0,
        Intent(context, ScheduledTaskReceiver::class.java).setAction("aurai.SCHEDULED_TASK")
            .setData(Uri.parse("aurai://scheduled/$id")), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    private fun arm(task: JSONObject, at: Long = task.getLong("runAt")) {
        check(allowed()) { "请先开启准时执行权限" }
        alarms().setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, intent(task.getString("id")))
        alarmRetries.remove(task.getString("id"))?.let(alarmHandler::removeCallbacks)
    }
    private fun next(task: JSONObject): Boolean {
        val rule = task.getString("rrule")
        if (rule.isEmpty()) return false
        val iterator = RecurrenceRule(rule).iterator(DateTime(TimeZone.getTimeZone(task.getString("timezone")), task.getLong("startAt")))
        iterator.fastForward(System.currentTimeMillis() + 1000)
        if (!iterator.hasNext()) return false
        task.put("runAt", iterator.nextMillis())
        return true
    }
    private fun save(args: Map<String, Any?>): Map<String, Any?> {
        val id = args["id"] as String? ?: UUID.randomUUID().toString()
        val old = tasks[id]
        check(old?.getString("state") !in activeStates) { "请先停止正在执行的任务" }
        val key = args["requestKey"] as String?
        if (key != null) tasks.values.firstOrNull { it.optString("requestKey") == key }?.let { return map(it) }
        require(old != null || tasks.size < 100) { "最多保存100个任务，请删除不再需要的任务" }
        val title = args["title"] as String
        val prompt = args["prompt"] as String
        require(title.isNotBlank() && title.length <= 80) { "任务标题需为1至80字" }
        require(prompt.isNotBlank() && prompt.length <= 4000) { "任务内容需为1至4000字" }
        if (args["scheduleChanged"] == false) {
            check(old != null) { "任务已不存在" }
            val edited = JSONObject(old.toString()).put("title", title).put("prompt", prompt)
            commitTask(edited)
            if (edited.getString("state") == "scheduled") syncAlarm(edited)
            return map(edited)
        }
        check(allowed()) { "请先开启准时执行权限" }
        val rule = args["rrule"] as String
        val timezone = args["timezone"] as String
        require(timezone in TimeZone.getAvailableIDs()) { "无效时区" }
        val at = (args["runAt"] as Number).toLong()
        if (rule.isNotEmpty()) {
            val parsed = RecurrenceRule(rule)
            require(!rule.contains("FREQ=SECONDLY")) { "不支持秒级定时任务" }
            val iterator = parsed.iterator(DateTime(TimeZone.getTimeZone(timezone), at))
            require(iterator.hasNext() && iterator.nextMillis() == at) { "首次执行时间必须符合时间规则" }
        }
        require(at > System.currentTimeMillis()) { "请选择未来的执行时间" }
        val task = if (old == null) JSONObject() else JSONObject(old.toString())
        task.put("id", id).put("title", title).put("prompt", prompt).put("rrule", rule).put("timezone", timezone).put("startAt", at)
            .put("scheduleLabel", args["scheduleLabel"] as String)
            .put("runAt", at).put("state", if (old?.optString("state") == "paused") "paused" else "scheduled")
        if (key != null) task.put("requestKey", key)
        if (args["sourceConversationId"] != null) task.put("sourceConversationId", args["sourceConversationId"])
        if (args["aiSenderId"] != null) task.put("aiSenderId", args["aiSenderId"])
        commitTask(task)
        if (task.getString("state") == "scheduled") syncAlarm(task) else cancelAlarm(id)
        return map(task)
    }
    private fun manage(args: Map<String, Any?>): Any? {
        val id = args["id"] as String
        val current = tasks[id] ?: error("任务已不存在")
        val task = JSONObject(current.toString())
        if (args["action"] == "stop") {
            check(task.getString("state") in activeStates) { "任务当前没有运行" }
            if (task.getString("state") == "starting") {
                commitTask(JSONObject(task.toString()).put("state", "cancelled").put("lastOutcome", "cancelled"), null)
                AgentSessionService.finish(context, "cancelled", "", "", "")
            } else AuraiApplication.requestAgentStop()
            return null
        }
        check(task.getString("state") !in activeStates) { "请先停止正在执行的任务" }
        when (args["action"]) {
            "delete" -> {
                commitTasks(LinkedHashMap(tasks).apply { remove(id) })
                cancelAlarm(id)
            }
            "pause" -> {
                task.put("state", "paused")
                commitTask(task)
                cancelAlarm(id)
            }
            "resume" -> {
                if (task.getLong("runAt") <= System.currentTimeMillis()) {
                    check(next(task)) { "请先修改为未来的执行时间" }
                }
                task.put("state", "scheduled")
                commitTask(task)
                syncAlarm(task)
            }
            else -> error("未知任务操作")
        }
        return null
    }
    fun restore() {
        persist()
        for (task in tasks.values) {
            if (task.getString("state") != "scheduled") continue
            if (allowed()) syncAlarm(task, maxOf(task.getLong("runAt"), System.currentTimeMillis() + 1000))
        }
    }
    fun due(id: String) {
        val task = tasks[id] ?: return
        if (task.getString("state") != "scheduled") return
        if (task.getLong("runAt") > System.currentTimeMillis()) { syncAlarm(task); return }
        if (AgentSessionService.isRunning || pendingId != null) { syncAlarm(task, System.currentTimeMillis() + 60_000); return }
        val starting = JSONObject(task.toString()).put("state", "starting")
        try { commitTask(starting, id) }
        catch (error: Exception) {
            android.util.Log.w("AuraiSchedule", "Task start could not be committed; retrying later", error)
            syncAlarm(task, System.currentTimeMillis() + 60_000)
            return
        }
        try { AgentSessionService.startScheduled(context) }
        catch (error: Exception) {
            commitTask(JSONObject(starting.toString()).put("state", "failed").put("lastOutcome", "failed"), null)
        }
    }
    fun dispatch() { channel.invokeMethod("due", null) }
    fun startupTimedOut() {
        val task = pendingId?.let(tasks::get) ?: return
        if (task.getString("state") == "starting") {
            commitTask(JSONObject(task.toString()).put("state", "failed").put("lastOutcome", "failed"), null)
            AgentSessionService.finish(context, "failed", "", "", "")
        }
    }
    private fun complete(args: Map<String, Any?>) {
        val previous = tasks[args["id"] as String] ?: return
        if (previous.getString("state") !in activeStates) return
        val task = JSONObject(previous.toString())
        val outcome = args["outcome"] as String
        task.put("lastOutcome", outcome).put("lastRunAt", System.currentTimeMillis())
        task.put("conversationId", args["conversationId"])
        task.put("lastError", args["error"])
        if (outcome == "completed" && allowed() && next(task)) {
            task.put("state", "scheduled")
        } else task.put("state", if (task.getString("rrule").isEmpty() || outcome == "completed") outcome else "paused")
        commitTask(task, null)
        if (task.getString("state") == "scheduled") syncAlarm(task)
    }

}

class ScheduledTaskReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == "aurai.SCHEDULED_TASK") ScheduledTasks.due(intent.data!!.lastPathSegment!!)
        else ScheduledTasks.restore()
    }
}
