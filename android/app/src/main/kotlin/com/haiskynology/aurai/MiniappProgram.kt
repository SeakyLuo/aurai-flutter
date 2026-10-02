package com.haiskynology.aurai

import org.mozilla.javascript.Context
import org.mozilla.javascript.ContextFactory
import org.mozilla.javascript.Script
import org.mozilla.javascript.ScriptableObject

/** A pure event reducer. IM effects are validated and committed by the host. */
object MiniappProgram {
    private val scripts = object : LinkedHashMap<String, Script>(4, 0.75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, Script>): Boolean = size > 4
    }

    fun run(script: String, input: String): String {
        var deadline = Long.MAX_VALUE
        val factory = object : ContextFactory() {
            override fun makeContext(): Context = super.makeContext().apply {
                optimizationLevel = -1
                languageVersion = Context.VERSION_ES6
                instructionObserverThreshold = 1000
                setClassShutter { false }
            }
            override fun observeInstructionCount(cx: Context, count: Int) {
                check(System.nanoTime() <= deadline) { "小程序事件处理超时" }
            }
        }
        return factory.call<String> { cx ->
            val scope = cx.initSafeStandardObjects()
            val compiled = synchronized(scripts) {
                scripts.getOrPut(script) {
                    cx.compileString("JSON.stringify((function(ctx){\n" + script +
                        "\n})(JSON.parse(__input)))", "miniapp-program", 1, null)
                }
            }
            ScriptableObject.putProperty(scope, "__input", input)
            // The execution limit measures the reducer, not cold engine initialization or parsing.
            deadline = System.nanoTime() + 100_000_000L
            val output = Context.toString(compiled.exec(cx, scope))
            require(output != "undefined" && output.length <= 262144) { "小程序必须返回不超过 256 KB 的 JSON" }
            output
        }
    }
}
