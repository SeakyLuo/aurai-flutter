package com.haiskynology.aurai

import android.content.Context
import android.location.Address
import android.location.Geocoder
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel
import java.util.Locale
import java.util.concurrent.Executors
import java.util.concurrent.Semaphore

/** Resolves only the supplied photo coordinates; never requests device location. */
object PhotoAddressResolver {
    private val slots = Semaphore(2)
    private val workers = Executors.newFixedThreadPool(2)
    private val main = Handler(Looper.getMainLooper())

    fun resolve(context: Context, latitude: Double, longitude: Double, result: MethodChannel.Result) {
        if (!latitude.isFinite() || !longitude.isFinite() || latitude !in -90.0..90.0 || longitude !in -180.0..180.0) {
            result.error("photo_location_invalid", "照片定位坐标无效", null)
            return
        }
        if (!Geocoder.isPresent()) {
            result.error("geocoder_unavailable", "此设备没有可用的系统地图地址服务，请手动填写地址", null)
            return
        }
        if (!slots.tryAcquire()) {
            result.error("geocoder_busy", "系统地图地址服务仍在处理请求，请手动填写地址或稍后再选照片", null)
            return
        }
        var replied = false
        val timeout = Runnable {
            replied = true
            result.error("geocoder_timeout", "照片地址识别超时，请手动填写地址或重新选择照片", null)
        }
        main.postDelayed(timeout, 15_000)
        fun complete(addresses: List<Address>?, error: String? = null) {
            // A timeout ends the UI wait, but the slot stays held until the system call ends.
            slots.release()
            main.post {
                if (!replied) {
                    replied = true
                    main.removeCallbacks(timeout)
                    if (error != null) result.error("geocoder_failed", "系统地图服务未能识别照片地址，请手动填写或换张照片", error)
                    else result.success(mapOf("address" to addresses?.firstOrNull()?.let(::fields)))
                }
            }
        }
        val geocoder = Geocoder(context.applicationContext, Locale.getDefault())
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                geocoder.getFromLocation(latitude, longitude, 1, object : Geocoder.GeocodeListener {
                    override fun onGeocode(addresses: MutableList<Address>) = complete(addresses)
                    override fun onError(errorMessage: String?) = complete(null, errorMessage ?: "系统地图地址服务识别失败")
                })
            } else {
                workers.execute {
                    try {
                        @Suppress("DEPRECATION")
                        val addresses = geocoder.getFromLocation(latitude, longitude, 1)
                        complete(addresses)
                    } catch (error: Exception) { complete(null, error.toString()) }
                }
            }
        } catch (error: Exception) { complete(null, error.toString()) }
    }

    private fun fields(value: Address): Map<String, String> {
        val parts = listOfNotNull(value.adminArea, value.locality, value.subLocality).filter { it.isNotBlank() }.distinct()
        var detail = value.getAddressLine(0).orEmpty()
        for (prefix in listOfNotNull(value.countryName) + parts) {
            if (detail.startsWith(prefix)) detail = detail.removePrefix(prefix).trimStart(' ', ',')
        }
        return mapOf("district" to parts.joinToString(""), "address" to detail)
    }
}
