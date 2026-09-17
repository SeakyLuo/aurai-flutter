package com.haiskynology.aurai

import android.content.ComponentCallbacks2
import android.content.Context
import android.content.res.Configuration

/** Bounded LRU of live pages; evicted pages restore explicitly saved state. */
object HtmlGamePool : ComponentCallbacks2 {
    private val pages = LinkedHashMap<String, HtmlGameRuntime>(4, .75f, true)
    private var registered = false

    fun acquire(context: Context, args: Map<*, *>): HtmlGameRuntime {
        if (!registered) {
            context.applicationContext.registerComponentCallbacks(this)
            registered = true
        }
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
        val iterator = pages.entries.iterator()
        while (pages.size > 3 && iterator.hasNext()) {
            val page = iterator.next().value
            if (page.canEvict) {
                page.destroy()
                iterator.remove()
            }
        }
    }

    private fun releaseIdle() {
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
