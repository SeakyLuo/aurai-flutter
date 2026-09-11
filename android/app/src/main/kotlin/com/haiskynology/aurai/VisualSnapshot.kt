package com.haiskynology.aurai

import android.accessibilityservice.AccessibilityService
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import android.os.SystemClock
import android.view.accessibility.AccessibilityNodeInfo
import android.view.accessibility.AccessibilityWindowInfo
import java.util.UUID
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

data class CaptureTarget(
    val packageName: String,
    val windowId: Int,
    val displayId: Int,
    val rotation: Int,
    val windowBounds: Rect,
    val pageFingerprint: String,
)

class ScreenshotFailure(
    val reason: String,
    val errorCode: Int? = null,
) : Exception(reason)

data class Approval(
    val callId: String,
    val fingerprint: String,
    val nodeRef: String?,
    val argumentHash: String,
    val approvedAtElapsedMs: Long,
) {
    fun isExpired(ttlMs: Long) =
        SystemClock.elapsedRealtime() - approvedAtElapsedMs > ttlMs
}

fun screenshotFailureReason(errorCode: Int) = when (errorCode) {
    AccessibilityService.ERROR_TAKE_SCREENSHOT_INTERVAL_TIME_SHORT -> "rate_limited"
    AccessibilityService.ERROR_TAKE_SCREENSHOT_NO_ACCESSIBILITY_ACCESS -> "permission_required"
    AccessibilityService.ERROR_TAKE_SCREENSHOT_INVALID_DISPLAY -> "invalid_display"
    AccessibilityService.ERROR_TAKE_SCREENSHOT_INVALID_WINDOW -> "window_changed"
    AccessibilityService.ERROR_TAKE_SCREENSHOT_SECURE_WINDOW -> "protected_content"
    else -> "system_error"
}

fun labelNear(root: AccessibilityNodeInfo?, x: Int, y: Int): String? {
    var label: String? = null
    var smallestArea = Long.MAX_VALUE
    fun visit(node: AccessibilityNodeInfo) {
        val bounds = Rect().also(node::getBoundsInScreen)
        val candidate = (node.text?.toString() ?: node.contentDescription?.toString() ?: "").trim()
        if (bounds.contains(x, y) && candidate.isNotEmpty()) {
            val area = bounds.width().toLong() * bounds.height()
            if (area < smallestArea) {
                label = candidate
                smallestArea = area
            }
        }
        for (index in 0 until node.childCount) node.getChild(index)?.let(::visit)
    }
    root?.let(::visit)
    return label
}

fun isBlockedVisualPoint(
    windows: List<AccessibilityWindowInfo>,
    targetWindowId: Int,
    x: Int,
    y: Int,
): Boolean = windows.any { window ->
    if (window.id == targetWindowId ||
        (window.type != AccessibilityWindowInfo.TYPE_SYSTEM &&
            window.type != AccessibilityWindowInfo.TYPE_ACCESSIBILITY_OVERLAY)
    ) {
        false
    } else {
        Rect().also(window::getBoundsInScreen).contains(x, y)
    }
}

fun staleVisualResult(
    reason: String,
    staleCount: Int,
    localDifference: Double? = null,
): Map<String, Any?> = mapOf(
    "valid" to false,
    "performed" to false,
    "reason" to reason,
    "localDifference" to localDifference,
    "staleCount" to staleCount,
    "next" to if (staleCount >= 2) {
        "Use accessibility nodes or ask the user to complete this action"
    } else {
        "captureScreen"
    },
)

data class VisualSnapshot(
    val id: String = UUID.randomUUID().toString(),
    val packageName: String,
    val windowId: Int,
    val displayId: Int,
    val rotation: Int,
    val windowBounds: Rect,
    val pageFingerprint: String,
    val image: Bitmap,
    val capturedAtElapsedMs: Long = SystemClock.elapsedRealtime(),
) {
    fun sameGeometry(other: VisualSnapshot): Boolean =
        packageName == other.packageName &&
            windowId == other.windowId &&
            displayId == other.displayId &&
            rotation == other.rotation &&
            windowBounds == other.windowBounds &&
            image.width == other.image.width &&
            image.height == other.image.height

    fun localDifference(other: VisualSnapshot, normalizedX: Double, normalizedY: Double): Double {
        if (!sameGeometry(other)) return 1.0
        val centerX = (normalizedX * (image.width - 1)).toInt()
        val centerY = (normalizedY * (image.height - 1)).toInt()
        val radius = max(12, min(image.width, image.height) / 18)
        var difference = 0L
        var samples = 0
        for (row in 0 until SAMPLE_GRID) {
            for (column in 0 until SAMPLE_GRID) {
                val x = sampleCoordinate(centerX, radius, column, image.width)
                val y = sampleCoordinate(centerY, radius, row, image.height)
                val before = image.getPixel(x, y)
                val after = other.image.getPixel(x, y)
                difference += abs(Color.red(before) - Color.red(after))
                difference += abs(Color.green(before) - Color.green(after))
                difference += abs(Color.blue(before) - Color.blue(after))
                samples += 3
            }
        }
        return difference.toDouble() / (samples * 255)
    }

    fun markedPreview(normalizedX: Double, normalizedY: Double): Bitmap {
        val centerX = (normalizedX * (image.width - 1)).toInt()
        val centerY = (normalizedY * (image.height - 1)).toInt()
        val halfWidth = min(image.width / 2, PREVIEW_SOURCE_WIDTH / 2)
        val halfHeight = min(image.height / 2, PREVIEW_SOURCE_HEIGHT / 2)
        val left = (centerX - halfWidth).coerceIn(0, image.width - halfWidth * 2)
        val top = (centerY - halfHeight).coerceIn(0, image.height - halfHeight * 2)
        val source = Bitmap.createBitmap(image, left, top, halfWidth * 2, halfHeight * 2)
        val preview = Bitmap.createScaledBitmap(source, PREVIEW_WIDTH, PREVIEW_HEIGHT, true)
            .copy(Bitmap.Config.ARGB_8888, true)
        val markerX = (centerX - left).toFloat() / source.width * preview.width
        val markerY = (centerY - top).toFloat() / source.height * preview.height
        Canvas(preview).drawCircle(
            markerX,
            markerY,
            MARKER_RADIUS,
            Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.RED
                style = Paint.Style.STROKE
                strokeWidth = MARKER_STROKE
            },
        )
        return preview
    }

    fun screenX(normalizedX: Double): Float =
        (windowBounds.left + normalizedX * windowBounds.width()).toFloat()

    fun screenY(normalizedY: Double): Float =
        (windowBounds.top + normalizedY * windowBounds.height()).toFloat()

    private fun sampleCoordinate(center: Int, radius: Int, index: Int, limit: Int): Int {
        val offset = -radius + (radius * 2 * index / (SAMPLE_GRID - 1))
        return (center + offset).coerceIn(0, limit - 1)
    }

    companion object {
        private const val SAMPLE_GRID = 9
        private const val PREVIEW_SOURCE_WIDTH = 360
        private const val PREVIEW_SOURCE_HEIGHT = 240
        private const val PREVIEW_WIDTH = 540
        private const val PREVIEW_HEIGHT = 360
        private const val MARKER_RADIUS = 28f
        private const val MARKER_STROKE = 8f
    }
}
