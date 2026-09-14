package com.haiskynology.aurai

import android.annotation.SuppressLint
import android.content.Context
import android.content.MutableContextWrapper
import android.view.ViewGroup
import android.widget.FrameLayout
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.view.View
import android.webkit.JavascriptInterface
import android.webkit.PermissionRequest
import android.webkit.RenderProcessGoneDetail
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import org.json.JSONObject
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream

class HtmlGameViewFactory(private val messenger: BinaryMessenger) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val values = args as Map<*, *>
        return HtmlGameView(context, messenger, viewId, values)
    }
}

class HtmlGameView(context: Context, messenger: BinaryMessenger, id: Int, args: Map<*, *>) : PlatformView {
    private val host = FrameLayout(context)
    private val runtime = HtmlGamePool.acquire(context, args)
    private val lease = runtime.attach(context, messenger, id, args["fullscreen"] as Boolean)
    init {
        (runtime.web.parent as? ViewGroup)?.removeView(runtime.web)
        host.addView(runtime.web, FrameLayout.LayoutParams(-1, -1))
        HtmlGamePool.trim()
    }
    override fun getView(): View = host
    override fun dispose() {
        host.removeAllViews()
        runtime.release(lease)
    }
}

@SuppressLint("SetJavaScriptEnabled")
class HtmlGameRuntime(context: Context, val identity: String, private val messageId: String,
                      private val stateful: Boolean, document: String) {
    private val webContext = MutableContextWrapper(context.applicationContext)
    val web = WebView(webContext)
    private var channel: MethodChannel? = null
    private var disposed = false
    private var loaded = false
    private var contentHeight: Double? = null
    private var lease = 0
    var attached = false
        private set
    private var fullscreen = false
    private val preferences = context.applicationContext.getSharedPreferences("html_message_state", Context.MODE_PRIVATE)
    private var inFlight = false

    init {
        // The pool retains paused pages across route and platform-view transitions.
        web.setBackgroundColor(Color.TRANSPARENT)
        web.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = false
            databaseEnabled = false
            allowFileAccess = false
            allowContentAccess = false
            blockNetworkLoads = true
            mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
            javaScriptCanOpenWindowsAutomatically = false
            setSupportMultipleWindows(false)
            setGeolocationEnabled(false)
            mediaPlaybackRequiresUserGesture = true
        }
        web.webChromeClient = object : WebChromeClient() {
            override fun onPermissionRequest(request: PermissionRequest) = request.deny()
        }
        web.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest) = true
            override fun shouldInterceptRequest(view: WebView, request: WebResourceRequest) =
                WebResourceResponse("text/plain", "UTF-8", ByteArrayInputStream(ByteArray(0)))
            override fun onPageFinished(view: WebView, url: String) {
                if (!disposed) { loaded = true; channel?.invokeMethod("ready", null); if (!attached) pause() }
            }
            override fun onRenderProcessGone(view: WebView, detail: RenderProcessGoneDetail): Boolean {
                channel?.invokeMethod("failed", null)
                destroy()
                return true
            }
        }
        web.addJavascriptInterface(object {
            @JavascriptInterface fun loadState(): String =
                if (stateful) preferences.getString(messageId, "null")!! else "null"
            @JavascriptInterface fun saveState(json: String): Boolean {
                if (!stateful || json.toByteArray(Charsets.UTF_8).size > 65536) return false
                return preferences.edit().putString(messageId, json).commit()
            }
            @JavascriptInterface fun reopen() {
                web.post { if (!disposed) channel?.invokeMethod("reopen", null) }
            }
            @JavascriptInterface fun contentHeight(height: Double) {
                if (height.isFinite() && height > 0) web.post {
                    if (!disposed) { contentHeight = height; channel?.invokeMethod("height", height) }
                }
            }
            @JavascriptInterface fun localState(json: String) {
                if (json.length <= 65536) web.post {
                    if (!disposed) channel?.invokeMethod("localState", json)
                }
            }
            @JavascriptInterface fun postMessage(json: String) {
                if (json.length > 100000) return
                web.post {
                    if (disposed || inFlight) return@post
                    inFlight = true
                    channel?.invokeMethod("event", json, object : MethodChannel.Result {
                        override fun success(result: Any?) {
                            inFlight = false
                            if (!disposed) web.evaluateJavascript("window.__auraiGameReply(${result as String})", null)
                        }
                        override fun error(code: String, message: String?, details: Any?) {
                            inFlight = false
                            if (!disposed) web.evaluateJavascript("window.__auraiGameReply({error:${JSONObject.quote("游戏操作未完成，请重试")}})", null)
                        }
                        override fun notImplemented() = error("unavailable", null, null)
                    })
                }
            }
        }, "AuraiGameBridge")
        web.loadDataWithBaseURL("https://aurai-game.invalid/", document, "text/html", "UTF-8", null)
    }


    fun attach(context: Context, messenger: BinaryMessenger, id: Int, fullscreen: Boolean): Int {
        channel?.setMethodCallHandler(null)
        channel = MethodChannel(messenger, "aurai/html_game/$id")
        webContext.baseContext = context
        this.fullscreen = fullscreen
        attached = true
        lease++
        channel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "connect" -> {
                    if (loaded) channel?.invokeMethod("ready", null)
                    contentHeight?.let { channel?.invokeMethod("height", it) }
                    web.onResume()
                    web.evaluateJavascript("window.__auraiLifecycle?.(false); document.documentElement.dataset.auraiDisplay=" + JSONObject.quote(if (fullscreen) "fullscreen" else "inline") + "; document.dispatchEvent(new Event('aurai:displaychange')); window.dispatchEvent(new Event('resize'));", null)
                    result.success(null)
                }
                "state" -> {
                    if (disposed) result.success(null)
                    else web.evaluateJavascript("window.__auraiGameState(${call.arguments as String})") {
                        if (disposed) result.success(null)
                        else web.postVisualStateCallback(0, object : WebView.VisualStateCallback() {
                            override fun onComplete(requestId: Long) = result.success(null)
                        })
                    }
                }
                "snapshot" -> {
                    if (disposed || web.width == 0 || web.height == 0) result.success(null)
                    else {
                        val scale = minOf(1f, 480f / web.width)
                        val bitmap = Bitmap.createBitmap((web.width * scale).toInt(), (web.height * scale).toInt(), Bitmap.Config.ARGB_8888)
                        val canvas = Canvas(bitmap)
                        canvas.scale(scale, scale)
                        web.draw(canvas)
                        val output = ByteArrayOutputStream()
                        bitmap.compress(Bitmap.CompressFormat.WEBP, 65, output)
                        bitmap.recycle()
                        result.success(output.toByteArray())
                    }
                }
                "dispose" -> pause { result.success(null) }
                else -> result.notImplemented()
            }
        }
        return lease
    }

    fun pause(done: () -> Unit = {}) {
        if (disposed) { done(); return }
        val owner = lease
        web.evaluateJavascript("window.__auraiLifecycle?.(true)") {
            if (!disposed && owner == lease) web.onPause()
            done()
        }
    }

    fun release(owner: Int) {
        if (owner != lease) return
        attached = false
        channel?.setMethodCallHandler(null)
        channel = null
        pause()
        webContext.baseContext = webContext.applicationContext
        HtmlGamePool.trim()
    }

    fun destroy() {
        if (disposed) return
        disposed = true
        channel?.setMethodCallHandler(null)
        channel = null
        (web.parent as? ViewGroup)?.removeView(web)
        web.stopLoading()
        web.onPause()
        web.removeJavascriptInterface("AuraiGameBridge")
        web.destroy()
    }
    val alive: Boolean get() = !disposed
}
