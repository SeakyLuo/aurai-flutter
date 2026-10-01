package com.haiskynology.aurai

import org.json.JSONObject
import org.mozilla.javascript.Context
import org.mozilla.javascript.ContextFactory

/** A pure event reducer. IM effects are validated and committed by the host. */
object MiniappProgram {
    fun run(script: String, input: String): String {
        val deadline = System.nanoTime() + 100_000_000L
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
            val source = "JSON.stringify((function(ctx){\n" + script +
                "\n})(JSON.parse(" + JSONObject.quote(input) + ")))"
            val output = Context.toString(cx.evaluateString(scope, source, "miniapp-program", 1, null))
            require(output != "undefined" && output.length <= 262144) { "小程序必须返回不超过 256 KB 的 JSON" }
            output
        }
    }
}
