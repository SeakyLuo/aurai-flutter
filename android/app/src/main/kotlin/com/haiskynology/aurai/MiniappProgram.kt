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
        val factory = object : ContextFactory() {
            override fun makeContext(): Context = super.makeContext().apply {
                optimizationLevel = -1
                languageVersion = Context.VERSION_ES6
                setClassShutter { false }
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
            // Execute the reducer without a wall-clock timeout.
            val output = Context.toString(compiled.exec(cx, scope))
            require(output != "undefined" && output.length <= 262144) { "小程序必须返回不超过 256 KB 的 JSON" }
            output
        }
    }
}
