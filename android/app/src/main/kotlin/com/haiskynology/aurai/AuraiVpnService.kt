package com.haiskynology.aurai

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkRequest
import android.net.NetworkCapabilities
import android.net.VpnService
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.os.PowerManager
import android.os.SystemClock
import android.widget.Toast
import java.util.concurrent.Executors

class AuraiVpnService : VpnService() {
    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private var tun: ParcelFileDescriptor? = null
    private var relay: LocalSocksRelay? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    private var closing = false
    private var wakeLock: PowerManager.WakeLock? = null
    private val monitor = object : Runnable {
        override fun run() {
            if (closing) return
            if (!TunnelEngine.isRunning()) {
                finishCapture("网络转发已停止")
            } else if (SystemClock.elapsedRealtime() >= NetworkCaptureAccess.deadline) {
                finishCapture()
            } else main.postDelayed(this, 1000)
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == STOP) { finishCapture(); return START_NOT_STICKY }
        if (closing || NetworkCaptureAccess.status != "starting") {
            stopSelf()
            return START_NOT_STICKY
        }
        val seconds = intent!!.getIntExtra("seconds", 300)
        try {
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(NotificationChannel(CHANNEL, "网络记录", NotificationManager.IMPORTANCE_LOW))
            val stop = PendingIntent.getService(this, 0, Intent(this, AuraiVpnService::class.java).setAction(STOP), PendingIntent.FLAG_IMMUTABLE)
            val open = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE)
            startForeground(NOTIFICATION, NotificationBranding(resources).applyTo(Notification.Builder(this, CHANNEL))
                .setContentTitle("Aurai 正在记录网络连接")
                .setContentText("仅记录连接元数据，${seconds / 60} 分钟内自动停止")
                .setContentIntent(open).setOngoing(true)
                .addAction(Notification.Action.Builder(null, "停止", stop).build()).build())
        } catch (error: Exception) {
            finishCapture("无法显示网络记录通知：${error.message}")
            return START_NOT_STICKY
        }
        wakeLock = getSystemService(PowerManager::class.java)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "Aurai:networkCapture")
            .apply { acquire((seconds + 15) * 1000L) }
        worker.execute {
            try {
                val manager = getSystemService(ConnectivityManager::class.java)
                val networks = listOfNotNull(manager.activeNetwork) + manager.allNetworks.toList()
                val physical = networks.firstOrNull { network ->
                    val caps = manager.getNetworkCapabilities(network)
                    caps?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) == true &&
                        caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
                } ?: error("请先连接无线网络或移动网络")
                val dns = manager.getLinkProperties(physical)!!.dnsServers
                check(dns.isNotEmpty()) { "当前网络没有可用的 DNS 服务器" }
                val callback = object : ConnectivityManager.NetworkCallback() {
                    override fun onLost(network: Network) {
                        if (network == physical) main.post { finishCapture("网络已断开或切换，本地 VPN 已停止") }
                    }
                }
                manager.registerNetworkCallback(NetworkRequest.Builder()
                    .addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN).build(), callback)
                networkCallback = callback
                val forwarder = LocalSocksRelay(this, physical)
                relay = forwarder
                forwarder.start()
                val builder = Builder().setSession("Aurai 网络记录").setMtu(1500)
                    .addAddress("198.18.0.1", 32).addRoute("0.0.0.0", 0)
                    .addAddress("fd00:6175:7261::1", 128).addRoute("::", 0)
                    .addDisallowedApplication(packageName).setUnderlyingNetworks(arrayOf(physical)).setBlocking(false)
                dns.forEach { builder.addDnsServer(it) }
                NetworkTrafficLog.clear()
                tun = builder.establish() ?: error("VPN 授权已被撤销")
                val config = """
                    tunnel:
                      mtu: 1500
                      ipv4: 198.18.0.1
                      ipv6: 'fd00:6175:7261::1'
                    socks5:
                      address: 127.0.0.1
                      port: ${forwarder.port}
                      username: '${forwarder.username}'
                      password: '${forwarder.password}'
                      udp: 'udp'
                    misc:
                      max-session-count: 64
                      connect-timeout: 10000
                      tcp-read-write-timeout: 60000
                      udp-read-write-timeout: 60000
                      log-level: error
                """.trimIndent()
                check(TunnelEngine.start(config, tun!!.fd)) { "网络转发启动失败" }
                main.post {
                    if (!closing) {
                        NetworkCaptureAccess.started(this, seconds)
                        main.post(monitor)
                    }
                }
            } catch (error: Throwable) {
                main.post { finishCapture(error.message ?: "网络记录启动失败") }
            }
        }
        return START_NOT_STICKY
    }

    fun finishCapture(error: String? = null) {
        if (closing) return
        closing = true
        main.removeCallbacks(monitor)
        NetworkCaptureAccess.stopping()
        worker.execute {
            try {
                // Stop the engine before releasing its borrowed descriptor.
                if (tun != null) TunnelEngine.stop()
            } finally {
                tun?.close(); tun = null
                relay?.close(); relay = null
                networkCallback?.let { getSystemService(ConnectivityManager::class.java).unregisterNetworkCallback(it) }
                networkCallback = null
                main.post {
                    if (error != null) {
                        NetworkCaptureAccess.failed(error)
                        Toast.makeText(this, error, Toast.LENGTH_LONG).show()
                    } else NetworkCaptureAccess.stopped()
                    wakeLock?.let { if (it.isHeld) it.release() }
                    wakeLock = null
                    stopForeground(STOP_FOREGROUND_REMOVE)
                    stopSelf()
                }
            }
        }
    }

    override fun onRevoke() { finishCapture() }
    override fun onDestroy() {
        if (!closing) finishCapture()
        if (instance === this) instance = null
        worker.shutdown()
        super.onDestroy()
    }

    companion object {
        var instance: AuraiVpnService? = null
            private set
        private const val STOP = "com.haiskynology.aurai.STOP_CAPTURE"
        private const val CHANNEL = "aurai_network_capture"
        private const val NOTIFICATION = 1402
    }
}
