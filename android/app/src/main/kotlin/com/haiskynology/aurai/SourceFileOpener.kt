package com.haiskynology.aurai

import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileNotFoundException
import java.io.IOException
import java.util.Locale

class SourceFileProvider : FileProvider()

object SourceFileOpener {
    fun open(context: Context, value: String, result: MethodChannel.Result) {
        try {
            val source = Uri.parse(value)
            val uri: Uri
            val mime: String?
            when (source.scheme) {
                "file" -> {
                    val file = File(source.path!!).canonicalFile
                    if (!file.exists()) throw FileNotFoundException()
                    if (!file.isFile) {
                        result.error("not_file", "此来源是文件夹，无法作为文件打开", null)
                        return
                    }
                    if (!file.canRead()) throw SecurityException()
                    uri = FileProvider.getUriForFile(context, "${context.packageName}.source_files", file)
                    val extension = file.extension.lowercase(Locale.ROOT)
                    mime = if (extension in setOf("md", "log", "yaml", "yml")) "text/plain"
                        else MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension)
                }
                "content" -> {
                    context.contentResolver.openFileDescriptor(source, "r").use {
                        if (it == null) throw FileNotFoundException()
                    }
                    uri = source
                    mime = context.contentResolver.getType(source)
                }
                else -> {
                    result.error("invalid_file", "无法识别此文件来源", null)
                    return
                }
            }
            context.startActivity(Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, mime ?: "*/*")
                clipData = ClipData.newRawUri("文件来源", uri)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION)
            })
            result.success(null)
        } catch (_: ActivityNotFoundException) {
            result.error("no_viewer", "手机上没有可以打开此文件的应用", null)
        } catch (_: FileNotFoundException) {
            result.error("file_missing", "文件已移动、删除或无法访问", null)
        } catch (_: SecurityException) {
            result.error("file_access", "没有权限打开此文件", null)
        } catch (_: IllegalArgumentException) {
            result.error("file_location", "此位置的文件暂不支持外部查看", null)
        } catch (_: IOException) {
            result.error("file_io", "无法读取此文件，请稍后再试", null)
        }
    }
}
