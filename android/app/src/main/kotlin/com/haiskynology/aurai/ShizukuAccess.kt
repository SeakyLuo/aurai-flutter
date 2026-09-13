package com.haiskynology.aurai

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import io.flutter.plugin.common.MethodChannel
import rikka.shizuku.Shizuku
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class ShizukuAccess(private val context: Context) {
    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    @Volatile private var service: IPrivilegedShell? = null
    @Volatile private var cancelled = false
    private val executing = java.util.concurrent.atomic.AtomicBoolean(false)
    private var permissionReply: MethodChannel.Result? = null
    private var connection: ServiceConnection? = null
    private val args = Shizuku.UserServiceArgs(ComponentName(context, PrivilegedShellService::class.java))
        .daemon(false).processNameSuffix("privileged_shell").version(1)

    init {
        Shizuku.addBinderDeadListener {
            service = null
            permissionReply?.error("disconnected", "Shizuku 已停止，请打开 Shizuku 重新启动", null)
            permissionReply = null
        }
        Shizuku.addRequestPermissionResultListener { requestCode, grantResult ->
            if (requestCode == REQUEST) {
                val reply = permissionReply
                permissionReply = null
                if (grantResult == PackageManager.PERMISSION_GRANTED) reply?.success(state())
                else reply?.error("denied", "未授权 Shizuku，可在设备能力中重新授权", null)
            }
        }
    }

    fun state(): Map<String, Any?> {
        val installed = context.packageManager.getLaunchIntentForPackage(MANAGER) != null
        val running = Shizuku.pingBinder()
        val supported = running && !Shizuku.isPreV11()
        val granted = supported && Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED
        return mapOf(
            "installed" to installed, "running" to running, "granted" to granted,
            "availability" to if (granted) "available" else "permissionRequired",
            "reason" to when {
                granted -> "已授权，可使用 Shizuku 执行设备命令"
                !installed && !running -> "安装并启动 Shizuku 后，可使用更高权限的设备操作"
                !running -> "打开 Shizuku 启动服务，重启手机后可能需要重新启动"
                !supported -> "请更新 Shizuku 后重新授权"
                else -> "Shizuku 已运行，等待你授权 Aurai"
            },
            "uid" to if (granted) Shizuku.getUid() else null,
        )
    }

    fun openManager() {
        val intent = context.packageManager.getLaunchIntentForPackage(MANAGER)
            ?: Intent(Intent.ACTION_VIEW, Uri.parse("https://shizuku.rikka.app/download/"))
        context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }

    fun requestPermission(result: MethodChannel.Result) {
        if (!MainActivity.isResumed) {
            result.error("foreground_required", "请回到 Aurai 后授权 Shizuku", null)
            return
        }
        val state = state()
        if (state["granted"] == true) { result.success(state); return }
        if (!Shizuku.pingBinder() || Shizuku.isPreV11() || Shizuku.shouldShowRequestPermissionRationale()) {
            openManager()
            result.success(state + ("openedSetup" to true))
            return
        }
        if (permissionReply != null) { result.error("busy", "正在等待 Shizuku 授权", null); return }
        permissionReply = result
        Shizuku.requestPermission(REQUEST)
    }

    fun execute(command: String, timeout: Int, result: MethodChannel.Result) {
        if (state()["granted"] != true) {
            result.error("permission_required", "请在设备能力中启动并授权 Shizuku", null)
            return
        }
        if (!executing.compareAndSet(false, true)) {
            result.error("busy", "已有 Shizuku 命令正在执行", null)
            return
        }
        cancelled = false
        val ready = CountDownLatch(if (service != null) 0 else 1)
        if (service == null) {
            connection = object : ServiceConnection {
                override fun onServiceConnected(name: ComponentName, binder: IBinder) {
                    service = IPrivilegedShell.Stub.asInterface(binder)
                    ready.countDown()
                }
                override fun onServiceDisconnected(name: ComponentName) { service = null }
            }
            try { Shizuku.bindUserService(args, connection!!) }
            catch (error: Exception) {
                executing.set(false)
                result.error("shizuku_failed", error.message, null)
                return
            }
        }
        worker.execute {
            try {
                check(ready.await(10, TimeUnit.SECONDS)) { "Shizuku 执行服务连接超时" }
                check(!cancelled) { "操作已取消" }
                val bundle = service!!.execute(command, timeout)
                val output = bundle.keySet().associateWith { bundle.get(it) }
                main.post { result.success(output) }
            } catch (error: Exception) {
                main.post { result.error("shizuku_failed", error.message, null) }
            } finally { executing.set(false) }
        }
    }

    fun cancel() {
        cancelled = true
        val active = service ?: return
        Thread {
            try { active.cancel() } catch (_: android.os.RemoteException) {
                // A stopped Shizuku service has no remaining command to cancel.
            }
        }.start()
    }

    companion object {
        private const val MANAGER = "moe.shizuku.privileged.api"
        private const val REQUEST = 1401
    }
}
