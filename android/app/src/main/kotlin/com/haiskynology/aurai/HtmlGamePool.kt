package com.haiskynology.aurai

import android.app.ActivityManager
import android.content.ComponentCallbacks2
import android.content.Context
import android.content.res.Configuration

/** Bounded LRU of live pages; evicted pages restore explicitly saved state. */
object HtmlGamePool : ComponentCallbacks2 {
    private val pages = LinkedHashMap<String, HtmlGameRuntime>(4, .75f, true)
    private var registered = false
    private lateinit var memory: ActivityManager
    private var underPressure = false

    // WebView allocations include native/renderer memory. This is a conservative
    // budget estimate, not a measured per-page cost; system pressure takes priority.
    private fun idleBudget(): Int {
        val info = ActivityManager.MemoryInfo()
        memory.getMemoryInfo(info)
        if (underPressure || info.lowMemory) return 0
        val spare = (info.availMem - info.threshold).coerceAtLeast(0)
        val bytes = minOf(memory.memoryClass.toLong() * 1024 * 1024 / 4, spare / 16)
        return (bytes / (32L * 1024 * 1024)).toInt()
    }

    fun acquire(context: Context, args: Map<*, *>): HtmlGameRuntime {
        if (!registered) {
            memory = context.getSystemService(ActivityManager::class.java)
            context.applicationContext.registerComponentCallbacks(this)
            registered = true
        }
        val info = ActivityManager.MemoryInfo()
        memory.getMemoryInfo(info)
        if (!info.lowMemory && info.availMem > info.threshold * 2) underPressure = false
        val id = args["messageId"] as String
        val identity = args["identity"] as String
        val previous = pages[id]
        if (previous != null && previous.alive && previous.identity == identity) return previous
        previous?.destroy()
        val page = HtmlGameRuntime(context, identity, id, args["appId"] as String, args["stateful"] as Boolean)
        pages[id] = page
        return page
    }

    fun trim() {
        val budget = idleBudget()
        var idle = pages.values.count { it.canEvict }
        val iterator = pages.entries.iterator()
        while (idle > budget && iterator.hasNext()) {
            val page = iterator.next().value
            if (page.canEvict) {
                page.destroy()
                iterator.remove()
                idle--
            }
        }
    }

    private fun releaseIdle() {
        underPressure = true
        val iterator = pages.entries.iterator()
        while (iterator.hasNext()) {
            val page = iterator.next().value
            if (page.canEvict) {
                page.destroy()
                iterator.remove()
            }
        }
    }

    override fun onTrimMemory(level: Int) {
        if (level == ComponentCallbacks2.TRIM_MEMORY_RUNNING_LOW ||
            level == ComponentCallbacks2.TRIM_MEMORY_RUNNING_CRITICAL ||
            level >= ComponentCallbacks2.TRIM_MEMORY_BACKGROUND) releaseIdle()
    }
    override fun onLowMemory() = releaseIdle()
    override fun onConfigurationChanged(newConfig: Configuration) {}
}
