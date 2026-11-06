package com.haiskynology.aurai

import android.app.ActivityManager
import android.content.Context

/** Keep the system task as the source of truth, including removal from Recents. */
object MiniappTaskHistory {
    private const val PREFERENCES = "miniapp_task_history"
    private const val LAST_TASK = "last_task"

    fun remember(activity: MiniappTaskActivity) {
        activity.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            .edit().putInt(LAST_TASK, activity.taskId).apply()
    }

    fun clear(context: Context) {
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            .edit().remove(LAST_TASK).apply()
    }

    fun closed(activity: MiniappTaskActivity) {
        val preferences = activity.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
        if (preferences.getInt(LAST_TASK, -1) == activity.taskId) clear(activity)
    }

    fun restore(context: Context): Boolean {
        val taskId = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            .getInt(LAST_TASK, -1)
        val task = context.getSystemService(ActivityManager::class.java).appTasks
            .firstOrNull {
                it.taskInfo.taskId == taskId &&
                    it.taskInfo.baseIntent.component?.className == MiniappTaskActivity::class.java.name
            } ?: return false
        task.moveToFront()
        return true
    }
}
