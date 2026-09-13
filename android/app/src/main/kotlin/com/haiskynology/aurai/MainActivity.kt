package com.haiskynology.aurai

import android.Manifest
import android.content.Intent
import android.os.Bundle
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleNotificationIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleNotificationIntent(intent)
    }

    private fun handleNotificationIntent(intent: Intent) {
        val conversationId = intent.getStringExtra("conversationId") ?: return
        intent.removeExtra("conversationId")
        AuraiApplication.notificationOpened(conversationId)
    }

    override fun provideFlutterEngine(context: Context): FlutterEngine =
        FlutterEngineCache.getInstance().get(AuraiApplication.ENGINE_ID)!!

    override fun shouldDestroyEngineWithHost() = false

    override fun onStart() {
        super.onStart()
        isVisible = true
        AttentionNotifications.visibilityChanged(this)
    }

    override fun onStop() {
        isVisible = false
        AttentionNotifications.visibilityChanged(this)
        super.onStop()
    }

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

    fun requestVpnPermission(intent: Intent) {
        startActivityForResult(intent, 1402)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == PreviewImageAccess.REQUEST) PreviewImageAccess.picker?.selected(if (resultCode == RESULT_OK) data?.data else null)
        if (requestCode == ChatFileAccess.REQUEST) ChatFileAccess.picker?.selected(if (resultCode == RESULT_OK) data else null)
        if (requestCode == DocumentAccess.REQUEST) DocumentAccess.picker?.selected(if (resultCode == RESULT_OK) data else null)
        if (requestCode == 1402) NetworkCaptureAccess.consent(this, resultCode == RESULT_OK)
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
        var isVisible = false
        var isResumed = false
            private set
        private const val NOTIFICATION_PERMISSION_REQUEST = 1108
    }

    private var notificationPermissionReply: ((Boolean) -> Unit)? = null
}
