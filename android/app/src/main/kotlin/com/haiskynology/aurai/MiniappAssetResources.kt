package com.haiskynology.aurai

import android.content.res.AssetManager
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import java.io.IOException

/** Miniapps share bundled portraits without copying image bytes into their source. */
object MiniappAssetResources {
    private val portraitPath = Regex("(?:avatars/[a-z0-9_]+|miniapps/icons/animaline-portrait-[a-z0-9_]+)\\.webp")
    fun response(assets: AssetManager, request: WebResourceRequest): WebResourceResponse? {
        val uri = request.url
        if (uri.scheme != "https" || uri.host != "aurai-game.invalid" ||
            !uri.path.orEmpty().startsWith("/bundled/")) return null
        val asset = uri.path!!.removePrefix("/bundled/")
        if (request.method != "GET" || !portraitPath.matches(asset)) {
            return WebResourceResponse("text/plain", "UTF-8", 403, "Forbidden", emptyMap(),
                "Invalid bundled portrait path".byteInputStream())
        }
        return try {
            WebResourceResponse("image/webp", null, 200, "OK",
                mapOf("Cache-Control" to "public, max-age=31536000", "X-Content-Type-Options" to "nosniff"),
                assets.open("flutter_assets/assets/$asset"))
        } catch (error: IOException) {
            WebResourceResponse("text/plain", "UTF-8", 404, "Not Found", emptyMap(),
                error.toString().byteInputStream())
        }
    }
}
