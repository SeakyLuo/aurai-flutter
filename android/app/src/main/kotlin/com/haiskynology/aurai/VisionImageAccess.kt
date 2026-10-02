package com.haiskynology.aurai

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import androidx.exifinterface.media.ExifInterface
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors
import kotlin.math.max

class VisionImageAccess {
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    fun handle(call: MethodCall, result: MethodChannel.Result): Boolean {
        if (call.method != "readVisionPreview") return false
        val path = call.argument<String>("path")!!
        worker.execute {
            try {
                val preview = read(path)
                main.post { result.success(preview) }
            } catch (error: Exception) {
                main.post { result.error(error.javaClass.name, error.toString(), error.stackTraceToString()) }
            }
        }
        return true
    }

    private fun read(path: String): Map<String, Any> {
        val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, options)
        require(options.outWidth > 0 && options.outHeight > 0) { "Cannot decode image: $path" }
        options.inJustDecodeBounds = false
        options.inSampleSize = 1
        while (max(options.outWidth, options.outHeight) / (options.inSampleSize * 2) >= 2048) {
            options.inSampleSize *= 2
        }
        var bitmap = requireNotNull(BitmapFactory.decodeFile(path, options)) { "Cannot decode image: $path" }
        try {
            val orientation = ExifInterface(path).getAttributeInt(ExifInterface.TAG_ORIENTATION, 1)
            val matrix = Matrix()
            when (orientation) {
                2 -> matrix.setScale(-1f, 1f)
                3 -> matrix.setRotate(180f)
                4 -> matrix.setScale(1f, -1f)
                5 -> { matrix.setRotate(90f); matrix.postScale(-1f, 1f) }
                6 -> matrix.setRotate(90f)
                7 -> { matrix.setRotate(270f); matrix.postScale(-1f, 1f) }
                8 -> matrix.setRotate(270f)
            }
            val scale = (2048f / max(bitmap.width, bitmap.height)).coerceAtMost(1f)
            matrix.postScale(scale, scale)
            val transformed = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
            if (transformed !== bitmap) { bitmap.recycle(); bitmap = transformed }
            val alpha = bitmap.hasAlpha()
            val output = ByteArrayOutputStream()
            check(bitmap.compress(if (alpha) Bitmap.CompressFormat.PNG else Bitmap.CompressFormat.JPEG, 85, output))
            return mapOf("bytes" to output.toByteArray(), "mimeType" to if (alpha) "image/png" else "image/jpeg")
        } finally {
            bitmap.recycle()
        }
    }
}
