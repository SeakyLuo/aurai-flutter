package com.haiskynology.aurai

import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.VpnService
import android.os.SystemClock
import android.os.Build
import io.flutter.plugin.common.MethodChannel

object NetworkCaptureAccess {
    @Volatile var status = "stopped"
        private set
    @Volatile var deadline = 0L
        private set
    private var pending: MethodChannel.Result? = null
    private var duration = 300

    fun state(context: Context): Map<String, Any?> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return mapOf(
            "status" to "unsupported", "remainingSeconds" to 0,
            "otherVpnActive" to false, "reason" to "本地 VPN 需要 Android 8.0 或更高版本",
        )
        val manager = context.getSystemService(ConnectivityManager::class.java)
        val otherVpn = manager.allNetworks.any {
            manager.getNetworkCapabilities(it)?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true
        } && status != "running"
        return mapOf(
            "status" to status,
            "remainingSeconds" to ((deadline - SystemClock.elapsedRealtime()) / 1000).coerceAtLeast(0),
            "otherVpnActive" to otherVpn,
            "reason" to if (status == "running") "正在记录连接元数据，不读取 HTTPS 内容"
                else "按需记录其他应用的网络连接，开启会替换当前 VPN",
        )
    }

    fun start(context: Context, seconds: Int, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            result.error("unsupported", "本地 VPN 需要 Android 8.0 或更高版本", null)
            return
        }
        require(seconds in 30..1800) { "记录时长应为 30 秒至 30 分钟" }
        if (status != "stopped") { result.error("busy", "本地 VPN 已开启或正在启动", null); return }
        val activity = MainActivity.current
        if (activity == null || !MainActivity.isResumed) {
            result.error("foreground_required", "请回到 Aurai 后开启本地 VPN", null)
            return
        }
        pending = result
        duration = seconds
        status = "consent"
        try {
            val intent = VpnService.prepare(context)
            if (intent == null) consent(context, true)
            else activity.requestVpnPermission(intent)
        } catch (error: Exception) { failed(error.toString()) }
    }

    fun consent(context: Context, granted: Boolean) {
        if (status != "consent") return
        if (!granted) { failed("未允许 VPN 连接"); return }
        status = "starting"
        try {
            context.startForegroundService(Intent(context, AuraiVpnService::class.java).putExtra("seconds", duration))
        } catch (error: Exception) { failed(error.toString()) }
    }

    fun started(context: Context, seconds: Int) {
        status = "running"
        deadline = SystemClock.elapsedRealtime() + seconds * 1000L
        pending?.success(state(context))
        pending = null
    }

    fun failed(message: String) {
        status = "stopped"
        deadline = 0
        pending?.error("vpn_failed", message, null)
        pending = null
    }

    fun stopping() { status = "stopping" }
    fun stopped() {
        pending?.error("cancelled", "网络记录已停止", null)
        pending = null
        status = "stopped"
        deadline = 0
    }

    fun stop(context: Context) {
        if (status == "consent") { stopped(); return }
        AuraiVpnService.instance?.finishCapture()
        if (status == "starting" && AuraiVpnService.instance == null) {
            context.stopService(Intent(context, AuraiVpnService::class.java))
            stopped()
        }
    }

    fun cancelStart(context: Context) {
        if (pending != null) stop(context)
    }
}
