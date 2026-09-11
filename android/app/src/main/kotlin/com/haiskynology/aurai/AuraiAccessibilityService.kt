package com.haiskynology.aurai

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.accessibilityservice.GestureDescription
import android.content.Context
import android.graphics.Color
import android.graphics.Bitmap
import android.graphics.Path
import android.graphics.Rect
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.hardware.display.DisplayManager
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.Button
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import android.util.Base64
import java.io.ByteArrayOutputStream
import java.security.MessageDigest
import java.time.Instant

class AuraiAccessibilityService : AccessibilityService() {
    private lateinit var windowManager: WindowManager
    private var overlayWindowManager: WindowManager? = null
    private var overlay: View? = null
    private var sessionActive = false
    private var pendingReply: ((Boolean) -> Unit)? = null
    private var approval: Approval? = null
    private var pageGrant: PageGrant? = null
    private var latestVisualSnapshot: VisualSnapshot? = null
    private var visualStaleStreak = 0
    private var confirmationTimeout: Runnable? = null
    private val handler = Handler(Looper.getMainLooper())

    override fun onServiceConnected() {
        instance = this
        windowManager = getSystemService(WindowManager::class.java)
        serviceInfo = serviceInfo.apply {
            flags = flags or AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
        }
        if (AndroidAgentBridge.sessionActive) startSession()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED ||
            event.eventType == AccessibilityEvent.TYPE_WINDOWS_CHANGED
        ) {
            val grant = pageGrant
            if (grant != null && grant.fingerprint != pageFingerprint()) pageGrant = null
        }
    }

    override fun onInterrupt() = cancelPending()

    override fun onDestroy() {
        sessionActive = false
        latestVisualSnapshot?.image?.recycle()
        latestVisualSnapshot = null
        cancelPending()
        instance = null
        super.onDestroy()
    }

    fun observe(): Map<String, Any?> {
        val root = rootInActiveWindow
        val nodes = mutableListOf<Map<String, Any?>>()
        if (root != null) collectNodes(root, "0", nodes)
        return mapOf(
            "accessibilityAvailable" to true,
            "packageName" to root?.packageName?.toString(),
            "windowId" to root?.windowId,
            "observationId" to pageFingerprint(),
            "nodes" to nodes,
            "truncated" to (nodes.size >= MAX_NODES),
        )
    }

    fun captureScreen(reply: (Map<String, Any?>) -> Unit) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            reply(mapOf("captured" to false, "reason" to "unsupported_android_version"))
            return
        }
        latestVisualSnapshot?.image?.recycle()
        latestVisualSnapshot = null
        takeVisualSnapshot(restoreOverlay = true) { outcome ->
            outcome.onSuccess { snapshot ->
                latestVisualSnapshot?.image?.recycle()
                latestVisualSnapshot = snapshot
                val bytes = ByteArrayOutputStream().use { stream ->
                    snapshot.image.compress(Bitmap.CompressFormat.JPEG, SCREENSHOT_QUALITY, stream)
                    stream.toByteArray()
                }
                reply(
                    mapOf(
                        "captured" to true,
                        "capturedAt" to Instant.now().toString(),
                        "screenshotId" to snapshot.id,
                        "observationId" to snapshot.pageFingerprint,
                        "width" to snapshot.image.width,
                        "height" to snapshot.image.height,
                        "mimeType" to "image/jpeg",
                        "imageBase64" to Base64.encodeToString(bytes, Base64.NO_WRAP),
                        "targetPackage" to snapshot.packageName,
                        "windowId" to snapshot.windowId,
                        "windowBounds" to listOf(
                            snapshot.windowBounds.left,
                            snapshot.windowBounds.top,
                            snapshot.windowBounds.right,
                            snapshot.windowBounds.bottom,
                        ),
                        "displayId" to snapshot.displayId,
                        "rotation" to snapshot.rotation,
                    ),
                )
            }.onFailure { error ->
                val failure = error as ScreenshotFailure
                reply(
                    mapOf(
                        "captured" to false,
                        "reason" to failure.reason,
                        "errorCode" to failure.errorCode,
                    ),
                )
            }
        }
    }

    private fun takeVisualSnapshot(
        restoreOverlay: Boolean,
        reply: (Result<VisualSnapshot>) -> Unit,
    ) {
        val root = rootInActiveWindow
        if (root == null) {
            reply(Result.failure(ScreenshotFailure("no_active_window")))
            return
        }
        val displayId = activeDisplayId()
        if (displayId == null) {
            reply(Result.failure(ScreenshotFailure("invalid_display")))
            return
        }
        val display = getSystemService(DisplayManager::class.java).getDisplay(displayId)
        val target = CaptureTarget(
            packageName = root.packageName.toString(),
            windowId = root.windowId,
            displayId = displayId,
            rotation = display.rotation,
            windowBounds = Rect().also(root::getBoundsInScreen),
            pageFingerprint = pageFingerprint(),
        )
        hideOverlay()
        handler.postDelayed(
            { requestScreenshot(target, restoreOverlay, 0, reply) },
            OVERLAY_SETTLE_MS,
        )
    }

    private fun requestScreenshot(
        target: CaptureTarget,
        restoreOverlay: Boolean,
        retryCount: Int,
        reply: (Result<VisualSnapshot>) -> Unit,
    ) {
        val callback = object : TakeScreenshotCallback {
            private fun finish(outcome: Result<VisualSnapshot>) {
                if (restoreOverlay && sessionActive) showSessionPill()
                reply(outcome)
            }

            override fun onSuccess(result: ScreenshotResult) {
                val buffer = result.hardwareBuffer
                val wrapped = Bitmap.wrapHardwareBuffer(buffer, result.colorSpace)
                val software = wrapped?.copy(Bitmap.Config.ARGB_8888, false)
                buffer.close()
                if (software == null) {
                    finish(Result.failure(ScreenshotFailure("image_conversion_failed")))
                    return
                }
                val windowImage = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    software
                } else {
                    val safeBounds = Rect(target.windowBounds).apply {
                        intersect(0, 0, software.width, software.height)
                    }
                    if (safeBounds.isEmpty) {
                        software.recycle()
                        finish(Result.failure(ScreenshotFailure("invalid_window_geometry")))
                        return
                    }
                    Bitmap.createBitmap(
                        software,
                        safeBounds.left,
                        safeBounds.top,
                        safeBounds.width(),
                        safeBounds.height(),
                    )
                }
                val longestEdge = maxOf(windowImage.width, windowImage.height)
                val image = if (longestEdge > MAX_SCREENSHOT_EDGE) {
                    val scale = MAX_SCREENSHOT_EDGE.toFloat() / longestEdge
                    Bitmap.createScaledBitmap(
                        windowImage,
                        (windowImage.width * scale).toInt(),
                        (windowImage.height * scale).toInt(),
                        true,
                    )
                } else {
                    windowImage
                }
                finish(
                    Result.success(
                        VisualSnapshot(
                            packageName = target.packageName,
                            windowId = target.windowId,
                            displayId = target.displayId,
                            rotation = target.rotation,
                            windowBounds = target.windowBounds,
                            pageFingerprint = target.pageFingerprint,
                            image = image,
                        ),
                    ),
                )
            }

            override fun onFailure(errorCode: Int) {
                if (errorCode == ERROR_TAKE_SCREENSHOT_INTERVAL_TIME_SHORT && retryCount == 0) {
                    handler.postDelayed(
                        { requestScreenshot(target, restoreOverlay, 1, reply) },
                        SCREENSHOT_RETRY_DELAY_MS,
                    )
                    return
                }
                finish(
                    Result.failure(
                        ScreenshotFailure(screenshotFailureReason(errorCode), errorCode),
                    ),
                )
            }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            takeScreenshotOfWindow(target.windowId, mainExecutor, callback)
        } else {
            takeScreenshot(target.displayId, mainExecutor, callback)
        }
    }

    fun activeDisplayId(): Int? {
        val activeWindowId = rootInActiveWindow?.windowId ?: return null
        return windows.firstOrNull { it.id == activeWindowId }?.displayId
    }

    fun preflightTapScreen(args: Map<String, Any?>): Map<String, Any?> {
        val snapshot = latestVisualSnapshot
            ?: return staleVisualResult("missing_screenshot", visualStaleStreak)
        if (args["screenshotId"] != snapshot.id ||
            args["observationId"] != snapshot.pageFingerprint
        ) {
            return staleVisualResult("stale_screenshot", visualStaleStreak)
        }
        val normalizedX = (args["x"] as Number).toDouble()
        val normalizedY = (args["y"] as Number).toDouble()
        if (normalizedX < 0.0 || normalizedX >= 1.0 ||
            normalizedY < 0.0 || normalizedY >= 1.0
        ) {
            return mapOf("valid" to false, "reason" to "coordinate_outside_window")
        }
        if (SystemClock.elapsedRealtime() - snapshot.capturedAtElapsedMs > VISUAL_OBSERVATION_TTL_MS) {
            return staleVisualResult("screenshot_expired", visualStaleStreak)
        }
        val root = rootInActiveWindow
            ?: return staleVisualResult("no_active_window", visualStaleStreak)
        val currentBounds = Rect().also(root::getBoundsInScreen)
        val displayId = activeDisplayId()
            ?: return staleVisualResult("invalid_display", visualStaleStreak)
        val rotation = getSystemService(DisplayManager::class.java).getDisplay(displayId).rotation
        if (root.packageName.toString() != snapshot.packageName ||
            root.windowId != snapshot.windowId ||
            displayId != snapshot.displayId ||
            rotation != snapshot.rotation ||
            currentBounds != snapshot.windowBounds ||
            pageFingerprint() != snapshot.pageFingerprint
        ) {
            return staleVisualResult("window_changed", visualStaleStreak)
        }
        val screenX = snapshot.screenX(normalizedX).toInt()
        val screenY = snapshot.screenY(normalizedY).toInt()
        if (isBlockedVisualPoint(windows, snapshot.windowId, screenX, screenY)) {
            return mapOf(
                "valid" to false,
                "performed" to false,
                "reason" to "coordinate_over_system_or_aurai_ui",
                "next" to "captureScreen",
            )
        }
        return mapOf("valid" to true)
    }

    fun tapScreen(
        callId: String,
        args: Map<String, Any?>,
        reply: (Map<String, Any?>) -> Unit,
    ) {
        val token = approval
        approval = null
        val snapshot = latestVisualSnapshot
        if (token == null || snapshot == null || token.callId != callId ||
            token.fingerprint != pageFingerprint() || token.argumentHash != hashArguments(args) ||
            token.isExpired(APPROVAL_TTL_MS) ||
            args["screenshotId"] != snapshot.id
        ) {
            reply(staleVisualResult("approval_stale", visualStaleStreak))
            return
        }
        val preflight = preflightTapScreen(args)
        if (preflight["valid"] != true) {
            reply(preflight)
            return
        }
        val normalizedX = (args["x"] as Number).toDouble()
        val normalizedY = (args["y"] as Number).toDouble()
        takeVisualSnapshot(restoreOverlay = false) { outcome ->
            outcome.onFailure { error ->
                if (sessionActive) showSessionPill()
                val failure = error as ScreenshotFailure
                reply(
                    mapOf(
                        "performed" to false,
                        "reason" to failure.reason,
                        "errorCode" to failure.errorCode,
                        "next" to "observeDevice",
                    ),
                )
            }.onSuccess { current ->
                if (!sessionActive) {
                    current.image.recycle()
                    reply(
                        mapOf(
                            "performed" to false,
                            "reason" to "task_cancelled",
                            "observationInvalidated" to true,
                        ),
                    )
                    return@onSuccess
                }
                val geometryMatches = snapshot.sameGeometry(current)
                val pageMatches = snapshot.pageFingerprint == current.pageFingerprint
                val localDifference = snapshot.localDifference(current, normalizedX, normalizedY)
                current.image.recycle()
                if (!geometryMatches || !pageMatches || localDifference > LOCAL_DIFFERENCE_LIMIT) {
                    visualStaleStreak += 1
                    if (sessionActive) showSessionPill()
                    reply(
                        staleVisualResult(
                            "visual_changed",
                            visualStaleStreak,
                            localDifference,
                        ),
                    )
                    return@onSuccess
                }
                latestVisualSnapshot = null
                snapshot.image.recycle()
                val path = Path().apply {
                    moveTo(snapshot.screenX(normalizedX), snapshot.screenY(normalizedY))
                }
                val gesture = GestureDescription.Builder()
                    .addStroke(GestureDescription.StrokeDescription(path, 0, TAP_DURATION_MS))
                    .build()
                val callback = object : GestureResultCallback() {
                    override fun onCompleted(gestureDescription: GestureDescription) {
                        visualStaleStreak = 0
                        if (sessionActive) showSessionPill()
                        reply(
                            mapOf(
                                "performed" to true,
                                "action" to "tapScreen",
                                "observationInvalidated" to true,
                                "next" to "observeDevice",
                            ),
                        )
                    }

                    override fun onCancelled(gestureDescription: GestureDescription) {
                        if (sessionActive) showSessionPill()
                        reply(
                            mapOf(
                                "performed" to false,
                                "reason" to "gesture_result_uncertain",
                                "observationInvalidated" to true,
                                "next" to "observeDevice",
                            ),
                        )
                    }
                }
                if (!dispatchGesture(gesture, callback, handler)) {
                    if (sessionActive) showSessionPill()
                    reply(
                        mapOf(
                            "performed" to false,
                            "reason" to "gesture_not_dispatched",
                            "observationInvalidated" to true,
                            "next" to "observeDevice",
                        ),
                    )
                }
            }
        }
    }

    fun perform(callId: String, args: Map<String, Any?>): Map<String, Any?> {
        val action = args["action"] as String
        if (args["observationId"] != pageFingerprint()) {
            return mapOf("performed" to false, "reason" to "stale_observation", "next" to "observeDevice")
        }
        if (action == "back") return globalAction(GLOBAL_ACTION_BACK, action)
        if (action == "home") return globalAction(GLOBAL_ACTION_HOME, action)
        val ref = args["nodeRef"] as String
        val node = resolveNode(ref)
            ?: return mapOf("performed" to false, "reason" to "stale_node", "next" to "observeDevice")
        if (action == "click" || action == "inputText") {
            val token = approval
            approval = null
            if (token == null || token.callId != callId || token.fingerprint != pageFingerprint() ||
                token.nodeRef != ref || token.argumentHash != hashArguments(args) ||
                token.isExpired(APPROVAL_TTL_MS)
            ) {
                return mapOf("performed" to false, "reason" to "approval_stale", "next" to "observeDevice")
            }
        }
        val performed = when (action) {
            "click" -> node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            "inputText" -> node.performAction(
                AccessibilityNodeInfo.ACTION_SET_TEXT,
                Bundle().apply { putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, args["text"] as String) },
            )
            "scrollForward" -> node.performAction(AccessibilityNodeInfo.ACTION_SCROLL_FORWARD)
            "scrollBackward" -> node.performAction(AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD)
            else -> false
        }
        return mapOf("performed" to performed, "action" to action, "next" to "observeDevice")
    }

    fun startSession() {
        sessionActive = true
        showSessionPill()
    }

    fun endSession() {
        sessionActive = false
        pageGrant = null
        approval = null
        latestVisualSnapshot?.image?.recycle()
        latestVisualSnapshot = null
        visualStaleStreak = 0
        cancelPending()
        hideOverlay()
    }

    fun requestConfirmation(
        callId: String,
        toolName: String,
        args: Map<String, Any?>,
        description: String?,
        taskScoped: Boolean,
        reply: (Boolean) -> Unit,
    ) {
        val fingerprint = pageFingerprint()
        if (toolName == "act" && args["observationId"] != fingerprint) {
            reply(false)
            return
        }
        if (toolName == "tapScreen" && preflightTapScreen(args)["valid"] != true) {
            reply(false)
            return
        }
        val nodeRef = args["nodeRef"] as String?
        val eligibleForPageGrant = toolName == "act" && args["action"] == "click" &&
            nodeRef != null && isSafeNavigationNode(resolveNode(nodeRef))
        val grant = pageGrant
        if (eligibleForPageGrant && grant != null && grant.fingerprint == fingerprint) {
            approval = Approval(
                callId,
                fingerprint,
                nodeRef,
                hashArguments(args),
                SystemClock.elapsedRealtime(),
            )
            reply(true)
            return
        }
        cancelPending()
        pendingReply = reply
        showConfirmationCard(
            callId,
            toolName,
            args,
            description,
            taskScoped,
            fingerprint,
            nodeRef,
            eligibleForPageGrant,
        )
        confirmationTimeout = Runnable(::denyPending).also {
            handler.postDelayed(it, CONFIRMATION_TIMEOUT_MS)
        }
    }

    fun cancelPending() {
        pendingReply?.invoke(false)
        pendingReply = null
        clearConfirmationTimeout()
        if (sessionActive) showSessionPill() else hideOverlay()
    }

    private fun showSessionPill() {
        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(12), dp(8), dp(8), dp(8))
            setBackgroundColor(Color.rgb(22, 49, 53))
            addView(TextView(context).apply {
                text = "Aurai 运行中"
                setTextColor(Color.WHITE)
                textSize = 14f
            })
            addView(Button(context).apply {
                text = "返回 Aurai"
                setOnClickListener {
                    packageManager.getLaunchIntentForPackage(packageName)?.apply {
                        addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                    }?.let(::startActivity)
                }
            })
            addView(Button(context).apply {
                text = "停止"
                setOnClickListener { AuraiApplication.requestAgentStop(); endSession() }
            })
        }
        replaceOverlay(row, wrapContent = true)
    }

    private fun showConfirmationCard(
        callId: String,
        toolName: String,
        args: Map<String, Any?>,
        description: String?,
        taskScoped: Boolean,
        fingerprint: String,
        nodeRef: String?,
        allowPageGrant: Boolean,
    ) {
        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(18), dp(16), dp(18), dp(14))
            setBackgroundColor(Color.rgb(250, 248, 244))
            addView(TextView(context).apply {
                text = "允许 Aurai 执行？"
                textSize = 19f
                setTextColor(Color.rgb(25, 36, 38))
            })
            addView(TextView(context).apply {
                text = description ?: confirmationText(toolName, args, nodeRef)
                textSize = 15f
                setTextColor(Color.rgb(45, 60, 62))
                setPadding(0, dp(10), 0, dp(6))
            })
            if (toolName == "tapScreen") {
                val snapshot = latestVisualSnapshot!!
                addView(ImageView(context).apply {
                    setImageBitmap(
                        snapshot.markedPreview(
                            (args["x"] as Number).toDouble(),
                            (args["y"] as Number).toDouble(),
                        ),
                    )
                    adjustViewBounds = true
                    contentDescription = "待点击位置预览"
                    setPadding(0, dp(6), 0, dp(6))
                })
            }
            addView(TextView(context).apply {
                text = "30 秒后自动拒绝"
                textSize = 12f
                setTextColor(Color.GRAY)
            })
            addView(LinearLayout(context).apply {
                gravity = Gravity.END
                addView(Button(context).apply { text = "拒绝"; setOnClickListener { denyPending() } })
                if (allowPageGrant) addView(Button(context).apply {
                    text = "允许此页面导航"
                    setOnClickListener {
                        pageGrant = PageGrant(fingerprint)
                        approvePending(callId, fingerprint, nodeRef, args)
                    }
                })
                addView(Button(context).apply {
                    text = if (taskScoped) "本任务允许" else "允许一次"
                    setOnClickListener { approvePending(callId, fingerprint, nodeRef, args) }
                })
            })
        }
        replaceOverlay(card, wrapContent = false)
    }

    private fun approvePending(callId: String, fingerprint: String, nodeRef: String?, args: Map<String, Any?>) {
        approval = Approval(
            callId,
            fingerprint,
            nodeRef,
            hashArguments(args),
            SystemClock.elapsedRealtime(),
        )
        val reply = pendingReply
        pendingReply = null
        clearConfirmationTimeout()
        if (sessionActive) showSessionPill() else hideOverlay()
        reply?.invoke(true)
    }

    private fun denyPending() {
        val reply = pendingReply
        pendingReply = null
        clearConfirmationTimeout()
        if (sessionActive) showSessionPill() else hideOverlay()
        reply?.invoke(false)
    }

    private fun confirmationText(toolName: String, args: Map<String, Any?>, nodeRef: String?): String {
        if (toolName == "shell") return "本机命令（仅限 Aurai 权限）\n${args["command"]}"
        if (toolName == "startIntent") return buildString {
            append("Android 操作：${args["action"]}")
            args["data"]?.let { append("\nData: $it") }
            args["mimeType"]?.let { append("\nType: $it") }
            args["packageName"]?.let { append("\nApp: $it") }
            args["extras"]?.let { append("\nExtras: $it") }
        }
        if (toolName == "tapScreen") {
            val snapshot = latestVisualSnapshot!!
            val normalizedX = (args["x"] as Number).toDouble()
            val normalizedY = (args["y"] as Number).toDouble()
            val label = labelNear(
                rootInActiveWindow,
                snapshot.screenX(normalizedX).toInt(),
                snapshot.screenY(normalizedY).toInt(),
            )
            val app = try {
                packageManager.getApplicationLabel(
                    packageManager.getApplicationInfo(snapshot.packageName, 0),
                )
            } catch (_: Exception) {
                "当前应用"
            }
            return "在 $app 点击标记位置" + if (label == null) "" else "\n附近控件：$label"
        }
        val node = nodeRef?.let(::resolveNode)
        val label = node?.text?.takeIf { it.isNotBlank() } ?: node?.contentDescription ?: nodeRef
        val text = if (node?.isPassword == true) "••••••" else args["text"]
        return "${args["action"]} · ${rootInActiveWindow?.packageName}\n目标：$label" +
            if (text != null) "\n内容：$text" else ""
    }

    private fun isSafeNavigationNode(node: AccessibilityNodeInfo?): Boolean {
        if (node == null || !node.isClickable || node.isPassword || node.isEditable) return false
        val label = (node.text?.toString() ?: node.contentDescription?.toString() ?: "").trim()
        if (label.isEmpty() || hasClickableOverlap(node)) return false
        val className = node.className?.toString() ?: return false
        if (!className.endsWith("TextView") && !className.endsWith("Button")) return false
        return HIGH_IMPACT.none { label.contains(it, ignoreCase = true) }
    }

    private fun hasClickableOverlap(target: AccessibilityNodeInfo): Boolean {
        val targetBounds = Rect().also(target::getBoundsInScreen)
        var overlaps = 0
        fun visit(node: AccessibilityNodeInfo) {
            if (node.isClickable) {
                val bounds = Rect().also(node::getBoundsInScreen)
                if (Rect.intersects(targetBounds, bounds)) overlaps += 1
            }
            if (overlaps > 1) return
            for (index in 0 until node.childCount) node.getChild(index)?.let(::visit)
        }
        rootInActiveWindow?.let(::visit)
        return overlaps > 1
    }

    private fun collectNodes(node: AccessibilityNodeInfo, ref: String, output: MutableList<Map<String, Any?>>) {
        if (output.size >= MAX_NODES) return
        val bounds = Rect().also(node::getBoundsInScreen)
        output += mapOf(
            "ref" to ref,
            "text" to node.text?.toString(),
            "description" to node.contentDescription?.toString(),
            "class" to node.className?.toString(),
            "viewId" to node.viewIdResourceName,
            "bounds" to listOf(bounds.left, bounds.top, bounds.right, bounds.bottom),
            "clickable" to node.isClickable,
            "editable" to node.isEditable,
            "scrollable" to node.isScrollable,
            "password" to node.isPassword,
            "enabled" to node.isEnabled,
            "checked" to node.isChecked,
            "selected" to node.isSelected,
        )
        for (index in 0 until node.childCount) {
            node.getChild(index)?.let { collectNodes(it, "$ref.$index", output) }
            if (output.size >= MAX_NODES) return
        }
    }

    private fun resolveNode(ref: String): AccessibilityNodeInfo? {
        var node = rootInActiveWindow ?: return null
        val parts = ref.split('.')
        if (parts.first() != "0") return null
        for (part in parts.drop(1)) node = node.getChild(part.toInt()) ?: return null
        return node
    }

    private fun pageFingerprint(): String {
        val root = rootInActiveWindow ?: return "no-window"
        val material = StringBuilder("${root.packageName}|${root.windowId}")
        appendFingerprint(root, material, 0)
        return sha256(material.toString())
    }

    private fun appendFingerprint(node: AccessibilityNodeInfo, output: StringBuilder, depth: Int) {
        if (depth > 6 || output.length > 12_000) return
        output.append('|').append(node.className).append(':').append(node.viewIdResourceName)
            .append(':').append(node.text).append(':').append(node.contentDescription)
        for (index in 0 until node.childCount) node.getChild(index)?.let { appendFingerprint(it, output, depth + 1) }
    }

    private fun hashArguments(args: Map<String, Any?>) = sha256(args.toSortedMap().toString())
    private fun sha256(value: String) = MessageDigest.getInstance("SHA-256")
        .digest(value.toByteArray()).joinToString("") { "%02x".format(it) }

    private fun globalAction(id: Int, name: String) =
        mapOf("performed" to performGlobalAction(id), "action" to name, "next" to "observeDevice")

    private fun replaceOverlay(view: View, wrapContent: Boolean) {
        hideOverlay()
        overlay = view
        val manager = activeWindowManager()
        overlayWindowManager = manager
        manager.addView(view, WindowManager.LayoutParams(
            if (wrapContent) WindowManager.LayoutParams.WRAP_CONTENT else dp(360),
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            android.graphics.PixelFormat.TRANSLUCENT,
        ).apply { gravity = Gravity.TOP or Gravity.END; y = dp(42); x = dp(8) })
    }

    private fun hideOverlay() {
        overlay?.let { overlayWindowManager!!.removeView(it) }
        overlay = null
        overlayWindowManager = null
    }

    private fun activeWindowManager(): WindowManager {
        val displayId = activeDisplayId() ?: return windowManager
        val display = getSystemService(DisplayManager::class.java).getDisplay(displayId)
        return createDisplayContext(display).getSystemService(WindowManager::class.java)
    }

    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()

    private fun clearConfirmationTimeout() {
        confirmationTimeout?.let(handler::removeCallbacks)
        confirmationTimeout = null
    }

    private data class PageGrant(val fingerprint: String)

    companion object {
        var instance: AuraiAccessibilityService? = null
            private set
        private const val MAX_NODES = 300
        private const val MAX_SCREENSHOT_EDGE = 1440
        private const val SCREENSHOT_QUALITY = 85
        private const val OVERLAY_SETTLE_MS = 160L
        private const val SCREENSHOT_RETRY_DELAY_MS = 500L
        private const val VISUAL_OBSERVATION_TTL_MS = 30_000L
        private const val APPROVAL_TTL_MS = 30_000L
        private const val TAP_DURATION_MS = 80L
        private const val LOCAL_DIFFERENCE_LIMIT = 0.12
        private const val CONFIRMATION_TIMEOUT_MS = 30_000L
        private val HIGH_IMPACT = listOf(
            "发送", "提交", "授权", "安装", "删除", "购买", "支付", "发布", "拨打", "保存",
            "send", "submit", "allow", "install", "delete", "buy", "pay", "publish", "call", "save",
        )
    }
}
