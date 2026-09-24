package com.haiskynology.aurai

import org.mozilla.javascript.Context
import org.mozilla.javascript.ContextFactory

/** Pure request JSON transforms: no application bridge or Java host objects. */
object ModelRequestTransform {
    fun run(script: String, input: String): String {
        val deadline = System.nanoTime() + 200_000_000L
        val factory = object : ContextFactory() {
            override fun makeContext(): Context = super.makeContext().apply {
                optimizationLevel = -1
                languageVersion = Context.VERSION_ES6
                instructionObserverThreshold = 1000
                setClassShutter { false }
            }
            override fun observeInstructionCount(cx: Context, count: Int) {
                if (System.nanoTime() > deadline) throw IllegalStateException("请求转换执行超时")
            }
        }
        return factory.call<String> { cx ->
            val scope = cx.initSafeStandardObjects()
            val source = "JSON.stringify((function(request){\n" + script +
                "\n})(JSON.parse(" + org.json.JSONObject.quote(input) + ")))"
            val output = Context.toString(cx.evaluateString(scope, source, "request-transform", 1, null))
            require(output != "undefined") { "脚本必须 return {path, body}" }
            output
        }
    }
}
