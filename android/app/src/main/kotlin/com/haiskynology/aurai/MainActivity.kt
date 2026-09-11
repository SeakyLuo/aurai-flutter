package com.haiskynology.aurai

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache

class MainActivity : FlutterActivity() {
    override fun provideFlutterEngine(context: Context): FlutterEngine =
        FlutterEngineCache.getInstance().get(AuraiApplication.ENGINE_ID)!!

    override fun shouldDestroyEngineWithHost() = false

    override fun onResume() {
        super.onResume()
        current = this
        isResumed = true
        AgentSessionService.clearFinishedNotification(this)
    }

    override fun onPause() {
        isResumed = false
        super.onPause()
    }

    override fun onDestroy() {
        if (current === this) current = null
        super.onDestroy()
    }

    fun requestNotificationPermission(reply: (Boolean) -> Unit) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        ) {
            reply(true)
            return
        }
        notificationPermissionReply = reply
        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), NOTIFICATION_PERMISSION_REQUEST)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != NOTIFICATION_PERMISSION_REQUEST) return
        val reply = notificationPermissionReply
        notificationPermissionReply = null
        reply?.invoke(grantResults.single() == PackageManager.PERMISSION_GRANTED)
    }

    companion object {
        var current: MainActivity? = null
            private set
        var isResumed = false
            private set
        private const val NOTIFICATION_PERMISSION_REQUEST = 1108
    }

    private var notificationPermissionReply: ((Boolean) -> Unit)? = null
}
