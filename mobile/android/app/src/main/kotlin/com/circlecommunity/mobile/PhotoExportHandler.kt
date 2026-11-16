package com.circlecommunity.mobile

import android.app.Activity
import android.content.ClipData
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.UUID

/** Explicit user-requested image export. No signed URL or broad storage access. */
class PhotoExportHandler(private val activity: FlutterActivity) {
    private var saveResult: MethodChannel.Result? = null
    private var saveBytes: ByteArray? = null
    private val saveRequest = 4108
    private val maxBytes = 32 * 1024 * 1024

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "export") { result.notImplemented(); return }
        if (saveResult != null) {
            result.error("busy", "Finish the current photo action first.", null); return
        }
        val action = call.argument<String>("action")
        val bytes = call.argument<ByteArray>("bytes")
        val name = call.argument<String>("name") ?: ""
        val mime = call.argument<String>("mime_type") ?: ""
        if ((action != "share" && action != "download") || bytes == null ||
            bytes.isEmpty() || bytes.size > maxBytes || !validNameAndType(name, mime)) {
            result.error("invalid", "The photo could not be exported.", null); return
        }
        if (action == "share") share(bytes, name, mime, result)
        else chooseSaveDestination(bytes, name, mime, result)
    }

    private fun validNameAndType(name: String, mime: String) = when (name) {
        "circle-photo.jpg" -> mime == "image/jpeg"
        "circle-photo.png" -> mime == "image/png"
        "circle-photo.webp" -> mime == "image/webp"
        else -> false
    }

    private fun share(bytes: ByteArray, name: String, mime: String, result: MethodChannel.Result) {
        var file: File? = null
        try {
            val directory = File(activity.cacheDir, "photo_exports")
            if (!directory.exists() && !directory.mkdirs()) throw SecurityException("Cache unavailable")
            // Share targets may continue reading after the sheet closes. Old
            // temporary exports are removed on a later export instead.
            val cutoff = System.currentTimeMillis() - 24 * 60 * 60 * 1000
            directory.listFiles()?.filter { it.lastModified() < cutoff }?.forEach { it.delete() }
            file = File(directory, "${UUID.randomUUID()}-$name")
            FileOutputStream(file).use { it.write(bytes) }
            val uri = FileProvider.getUriForFile(
                activity, "${activity.packageName}.fileprovider", file
            )
            val send = Intent(Intent.ACTION_SEND).setType(mime)
                .putExtra(Intent.EXTRA_STREAM, uri)
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            send.clipData = ClipData.newUri(activity.contentResolver, name, uri)
            activity.startActivity(Intent.createChooser(send, "Share photo")
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION))
            result.success(true)
        } catch (error: Exception) {
            file?.delete()
            result.error("unavailable", "Sharing could not open.", null)
        }
    }

    private fun chooseSaveDestination(
        bytes: ByteArray, name: String, mime: String, result: MethodChannel.Result
    ) {
        saveResult = result
        saveBytes = bytes
        try {
            activity.startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT)
                .addCategory(Intent.CATEGORY_OPENABLE).setType(mime)
                .putExtra(Intent.EXTRA_TITLE, name), saveRequest)
        } catch (error: Exception) {
            saveResult = null
            saveBytes = null
            result.error("unavailable", "No save destination is available.", null)
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != saveRequest) return false
        val result = saveResult ?: return true
        val bytes = saveBytes
        saveResult = null
        saveBytes = null
        if (resultCode != Activity.RESULT_OK) { result.success(false); return true }
        val uri: Uri? = data?.data
        if (uri == null || uri.scheme != "content" || bytes == null) {
            result.error("unavailable", "No save destination was selected.", null); return true
        }
        try {
            val stream = activity.contentResolver.openOutputStream(uri, "w")
                ?: throw SecurityException("Destination unavailable")
            stream.use { it.write(bytes) }
            result.success(true)
        } catch (error: Exception) {
            result.error("unavailable", "The photo could not be saved.", null)
        }
        return true
    }

    fun cancel() {
        runCatching { saveResult?.success(false) }
        saveResult = null
        saveBytes = null
    }
}
