package com.haiskynology.aurai

import android.Manifest
import android.app.ActivityOptions
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.os.SystemClock
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.time.Instant

class AndroidAgentBridge(private val context: Context) {
    private val chatFiles = ChatFileAccess(context)
    private val previewImages = PreviewImageAccess(context)
    private val documents = DocumentAccess(context)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val appUidAdapter = AppUidExecutionAdapter(File(context.filesDir, "agent-shell"))
    private val shizuku = ShizukuAccess(context)
    private val adbAdapter = UnavailableExecutionAdapter(
        ExecutionIdentity.ADB,
        "Adapter reserved; no ADB transport is connected",
    )

    fun handle(call: MethodCall, result: MethodChannel.Result): Boolean {
        if (previewImages.handle(call, result)) return true
        if (chatFiles.handle(call, result)) return true
        if (documents.handle(call, result)) return true
        when (call.method) {
            "getCapabilities" -> result.success(capabilities())
            "getDeviceExtensions" -> result.success(mapOf("shizuku" to shizuku.state(), "vpn" to NetworkCaptureAccess.state(context)))
            "requestShizukuAccess" -> shizuku.requestPermission(result)
            "openShizukuManager" -> { shizuku.openManager(); result.success(null) }
            "executeShizuku" -> shizuku.execute(call.argument<String>("command")!!, call.argument<Int>("timeoutSeconds")!!, result)
            "cancelShizuku" -> { shizuku.cancel(); result.success(null) }
            "startNetworkCapture" -> NetworkCaptureAccess.start(context, call.argument<Int>("durationSeconds")!!, result)
            "stopNetworkCapture" -> { NetworkCaptureAccess.stop(context); result.success(NetworkCaptureAccess.state(context)) }
            "cancelNetworkCaptureStart" -> { NetworkCaptureAccess.cancelStart(context); result.success(null) }
            "readNetworkTraffic" -> result.success(NetworkTrafficLog.read(call.argument<Int>("limit")!!, call.argument<Number>("after")!!.toLong()))
            "clearNetworkTraffic" -> { NetworkTrafficLog.clear(); result.success(mapOf("cleared" to true)) }
            "getNotificationAccessState" -> result.success(
                AuraiNotificationListenerService.accessState(context),
            )
            "getNotifications" -> result.success(
                AuraiNotificationListenerService.query(
                    call.argument<Int>("lookbackMinutes")!!,
                    call.argument<Int>("limit")!!,
                    call.argument<String>("appName"),
                ),
            )
            "getBackgroundRunReadiness" -> result.success(backgroundRunReadiness())
            "requestNotificationPermission" -> {
                context.getSharedPreferences("aurai", Context.MODE_PRIVATE)
                    .edit().putBoolean("notification_permission_requested", true).apply()
                val activity = MainActivity.current
                if (activity == null) result.success(false)
                else activity.requestNotificationPermission(result::success)
            }
            "openNotificationSettings" -> {
                startActivity(
                    Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                        .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName),
                )
                result.success(null)
            }
            "observeDevice" -> result.success(observeDevice())
            "captureScreen" -> captureScreen(result)
            "preflightTapScreen" -> result.success(preflightTapScreen(call))
            "tapScreen" -> tapScreen(call, result)
            "act" -> result.success(act(call))
            "findApps" -> result.success(findApps(call.argument<String>("query")!!))
            "launchApp" -> result.success(launchApp(call.argument<String>("packageName")!!))
            "startIntent" -> result.success(startIntent(call))
            "openSourceFile" -> SourceFileOpener.open(context, call.argument<String>("uri")!!, result)
            "openSettings" -> result.success(openSettings(call.argument<String>("screen")!!))
            "openBatterySettings" -> {
                startActivity(
                    Intent(
                        Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        Uri.parse("package:${context.packageName}"),
                    ),
                )
                result.success(null)
            }
            "openAccessibilitySettings" -> {
                startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                result.success(null)
            }
            "startAgentSession" -> {
                sessionActive = true
                AuraiAccessibilityService.instance?.startSession()
                AgentSessionService.start(context, call.argument<String>("step")!!)
                result.success(null)
            }
            "updateAttentionNotification" -> {
                AttentionNotifications.update(
                    context,
                    call.argument<String>("conversationId")!!,
                    call.argument<String>("kind")!!,
                    call.argument<String>("title"),
                    call.argument<String>("body"),
                    call.argument<Int>("timeoutSeconds"),
                )
                result.success(null)
            }
            "updateAgentSessionStep" -> {
                AgentSessionService.updateStep(context, call.argument<String>("step")!!)
                result.success(null)
            }
            "endAgentSession" -> {
                sessionActive = false
                AuraiAccessibilityService.instance?.endSession()
                AgentSessionService.finish(
                    context, call.argument<String>("outcome")!!,
                    call.argument<String>("conversationId")!!,
                    call.argument<String>("title")!!,
                    call.argument<String>("reply")!!,
                )
                result.success(null)
            }
            "getScreenAccess" -> result.success(
                context.getSharedPreferences("screen_access", Context.MODE_PRIVATE).getBoolean("allowed", false),
            )
            "setScreenAccess" -> {
                context.getSharedPreferences("screen_access", Context.MODE_PRIVATE)
                    .edit().putBoolean("allowed", call.argument<Boolean>("allowed")!!).apply()
                result.success(null)
            }
            "requestConfirmation" -> requestConfirmation(call, result)
            "cancelPendingInteraction" -> {
                documents.cancelTasks()
                appUidAdapter.cancel()
                AuraiAccessibilityService.instance?.cancelInteraction()
                result.success(null)
            }
            else -> return false
        }
        return true
    }

    fun shell(command: String): Map<String, Any?> {
        return appUidAdapter.execute(command)
    }

    private fun backgroundRunReadiness() = mapOf(
        "notificationGranted" to notificationGranted(),
        "notificationRequestedBefore" to context.getSharedPreferences("aurai", Context.MODE_PRIVATE)
            .getBoolean("notification_permission_requested", false),
        "accessibilityAvailable" to (AuraiAccessibilityService.instance != null),
    )

    private fun notificationGranted() = Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
        context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

    private fun accessibilityEnabled(): Boolean {
        val target = ComponentName(context, AuraiAccessibilityService::class.java)
        val enabled = Settings.Secure.getString(
            context.contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        ).orEmpty()
        return enabled.split(':').any { ComponentName.unflattenFromString(it) == target }
    }

    private fun accessibilityMissing(): Map<String, Any?> = if (accessibilityEnabled()) {
        mapOf("reason" to "service_disconnected", "next" to
            "Accessibility is already enabled. Do not request permission again. Wait briefly and observeDevice again; if still disconnected, report the connection issue.")
    } else {
        mapOf("reason" to "permission_required", "next" to "requestAccessibilityAccess")
    }

    private fun capabilities(): List<Map<String, Any?>> {
        val accessibility = AuraiAccessibilityService.instance != null
        val accessAvailability = when {
            accessibility -> "available"
            accessibilityEnabled() -> "unavailable"
            else -> "permissionRequired"
        }
        val accessReason = when (accessAvailability) {
            "available" -> "可按观察结果点击、输入、滚动和导航"
            "unavailable" -> "无障碍已开启，但服务暂未连接"
            else -> "需要你在系统设置中手动开启 Aurai 无障碍服务"
        }
        val notificationAccess = AuraiNotificationListenerService.accessState(context)
        val screenshotAvailability = when {
            Build.VERSION.SDK_INT < Build.VERSION_CODES.R -> "unsupported"
            accessibility -> "available"
            else -> accessAvailability
        }
        return listOf(
            capability("android.documents", "文件与文档", "available", "访问你授权的文件夹，读取文档并保存文件"),
            capability("android.network", "网络状态与连接诊断", "available", "可读取网络状态并执行 DNS 与 TLS 探测"),
            capability("android.observe", "设备与界面观察", "available", if (accessibility) "可观察前台 App 和无障碍界面树" else "可观察基础设备状态；界面树需要无障碍权限"),
            capability(
                "android.notifications.observe",
                "通知观察",
                notificationAccess["availability"] as String,
                notificationAccess["reason"] as String,
            ),
            capability("android.accessibility", "跨 App 界面操作", accessAvailability, accessReason),
            capability(
                "android.vision",
                "屏幕视觉",
                screenshotAvailability,
                when (screenshotAvailability) {
                    "available" -> "可在用户确认后读取当前屏幕，并对最新截图执行一次性坐标点击"
                    "permissionRequired" -> "需要先开启 Aurai 无障碍服务"
                    "unavailable" -> accessReason
                    else -> "需要 Android 11 或更高版本"
                },
            ),
            capability("android.runtime", "原生代码执行", "available", "可查询 Android API 并在独立进程中以 Aurai 权限执行代码"),
            capability("android.notifications.send", "发送通知", "available", "可发送通知，是否展示由系统通知设置控制"),
            capability("android.permissions", "任务内权限引导", "available", "需要额外权限时会说明原因并等待你授权"),
            capability("android.apps", "可见 App 查找与启动", "available", "受 Android App 可见性规则限制，只能发现系统允许 Aurai 查询的应用"),
            capability("android.intents", "Android 操作", "available", "可在确认后启动通用 Intent"),
            capability("android.settings", "系统设置", "available", "可打开稳定的 Android 设置页面"),
            capability("android.shell.app_uid", "本机命令（仅限 Aurai 权限）", "available", "不是 ADB 或 root，无法读取其他 App 私有数据或修改受保护设置"),
            capability("android.execution.shizuku", "Shizuku", shizuku.state()["availability"] as String, shizuku.state()["reason"] as String),
            capability("android.network.capture", "本地 VPN", "available", NetworkCaptureAccess.state(context)["reason"] as String),
            capability("android.execution.adb", "ADB 执行", "unavailable", adbAdapter.reason),
        )
    }

    private fun observeDevice(): Map<String, Any?> {
        val service = AuraiAccessibilityService.instance
        return mapOf(
            "platform" to "android",
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
            "sdk" to Build.VERSION.SDK_INT,
            "capturedAt" to Instant.now().toString(),
            "timeZone" to java.util.TimeZone.getDefault().id,
            "automaticTime" to (Settings.Global.getInt(context.contentResolver, Settings.Global.AUTO_TIME, 0) == 1),
            "automaticTimeZone" to (Settings.Global.getInt(context.contentResolver, Settings.Global.AUTO_TIME_ZONE, 0) == 1),
            "uptimeMs" to SystemClock.elapsedRealtime(),
            "ui" to (service?.observe() ?: mapOf(
                "accessibilityAvailable" to false,
            ) + accessibilityMissing()),
        )
    }

    private fun act(call: MethodCall): Map<String, Any?> {
        val service = AuraiAccessibilityService.instance
            ?: return (mapOf("performed" to false) + accessibilityMissing())
        @Suppress("UNCHECKED_CAST")
        val args = call.arguments as Map<String, Any?>
        return service.perform(args["callId"] as String, args - "callId")
    }

    private fun findApps(query: String): Map<String, Any?> {
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val apps = context.packageManager.queryIntentActivities(intent, 0)
            .map { info -> mapOf("name" to info.loadLabel(context.packageManager).toString(), "packageName" to info.activityInfo.packageName) }
            .filter { (it["name"] as String).contains(query, true) || (it["packageName"] as String).contains(query, true) }
            .distinctBy { it["packageName"] }
            .sortedBy { it["name"] as String }
            .take(20)
        return mapOf("apps" to apps, "visibility" to "partial_by_android_policy")
    }

    private fun launchApp(packageName: String): Map<String, Any?> {
        val intent = context.packageManager.getLaunchIntentForPackage(packageName)
            ?: return mapOf("launched" to false, "reason" to "not_visible_or_not_launchable")
        startActivity(intent)
        val appName = context.packageManager.getApplicationLabel(
            context.packageManager.getApplicationInfo(packageName, 0),
        ).toString()
        return mapOf("launched" to true, "packageName" to packageName, "appName" to appName, "next" to "observeDevice")
    }

    private fun startIntent(call: MethodCall): Map<String, Any?> {
        val action = call.argument<String>("action")!!
        val intent = Intent(action)
        call.argument<String>("data")?.let { intent.data = Uri.parse(it) }
        call.argument<String>("mimeType")?.let { intent.type = it }
        call.argument<String>("packageName")?.let { intent.setPackage(it) }
        call.argument<List<Map<String, String>>>("extras")?.forEach { extra ->
            intent.putExtra(extra["key"]!!, extra["value"]!!)
        }
        startActivity(intent)
        return mapOf("started" to true, "action" to action, "next" to "observeDevice")
    }

    private fun openSettings(screen: String): Map<String, Any?> {
        val intent = when (screen) {
            "wifi" -> Intent(Settings.ACTION_WIFI_SETTINGS)
            "network" -> Intent(Settings.ACTION_WIRELESS_SETTINGS)
            "vpn" -> Intent(Settings.ACTION_VPN_SETTINGS)
            "accessibility" -> Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
            "notificationAccess" -> notificationAccessSettingsIntent()
            "appDetails" -> Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${context.packageName}"))
            else -> Intent(Settings.ACTION_SETTINGS)
        }
        startActivity(intent)
        return mapOf("opened" to true, "screen" to screen, "next" to "observeDevice")
    }

    private fun notificationAccessSettingsIntent(): Intent {
        val component = ComponentName(context, AuraiNotificationListenerService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val detail = Intent(Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS)
                .putExtra(
                    Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME,
                    component.flattenToString(),
                )
            if (detail.resolveActivity(context.packageManager) != null) return detail
        }
        return Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
    }

    private fun requestConfirmation(call: MethodCall, result: MethodChannel.Result) {
        val service = AuraiAccessibilityService.instance
        if (service == null) {
            result.success("deny")
            return
        }
        @Suppress("UNCHECKED_CAST")
        val args = call.argument<Map<String, Any?>>("arguments")!!
        service.requestConfirmation(
            call.argument<String>("callId")!!,
            call.argument<String>("toolName")!!,
            args,
            call.argument<String>("description"),
            call.argument<Boolean>("taskScoped")!!,
            call.argument<Number>("confirmationTimeoutSeconds")?.toLong()?.times(1000),
            call.argument<Boolean>("autoApproved")!!,
        ) { approved -> mainHandler.post { result.success(if (approved) service.confirmationScope else "deny") } }
    }

    private fun captureScreen(result: MethodChannel.Result) {
        val service = AuraiAccessibilityService.instance
        if (service == null) {
            result.success(
                mapOf(
                    "captured" to false,
                ) + accessibilityMissing(),
            )
            return
        }
        service.captureScreen { value -> mainHandler.post { result.success(value) } }
    }

    private fun preflightTapScreen(call: MethodCall): Map<String, Any?> {
        val service = AuraiAccessibilityService.instance
            ?: return mapOf(
                "valid" to false,
            ) + accessibilityMissing()
        @Suppress("UNCHECKED_CAST")
        return service.preflightTapScreen(call.arguments as Map<String, Any?>)
    }

    private fun tapScreen(call: MethodCall, result: MethodChannel.Result) {
        val service = AuraiAccessibilityService.instance
        if (service == null) {
            result.success(
                mapOf(
                    "performed" to false,
                ) + accessibilityMissing(),
            )
            return
        }
        @Suppress("UNCHECKED_CAST")
        val args = call.arguments as Map<String, Any?>
        service.tapScreen(args["callId"] as String, args - "callId") { value ->
            mainHandler.post { result.success(value) }
        }
    }

    private fun startActivity(intent: Intent) {
        val activity = MainActivity.current
        if (activity != null) {
            activity.startActivity(intent)
            return
        }
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        val displayId = AuraiAccessibilityService.instance?.activeDisplayId()
        if (displayId == null) {
            context.startActivity(intent)
        } else {
            context.startActivity(
                intent,
                ActivityOptions.makeBasic().setLaunchDisplayId(displayId).toBundle(),
            )
        }
    }

    private fun capability(id: String, name: String, availability: String, reason: String) =
        mapOf("id" to id, "name" to name, "availability" to availability, "reason" to reason)
    companion object {
        var sessionActive = false
            private set
    }
}
