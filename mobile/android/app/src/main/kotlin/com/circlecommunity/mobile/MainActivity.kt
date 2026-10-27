package com.circlecommunity.mobile

import android.app.Activity
import android.content.ActivityNotFoundException
import android.net.Uri
import android.provider.ContactsContract
import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

class MainActivity : FlutterActivity() {
    private var contactResult: MethodChannel.Result? = null
    private val contactRequest = 4107

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != contactRequest) return
        val result = contactResult ?: return
        contactResult = null
        if (resultCode != Activity.RESULT_OK) { result.success(null); return }
        val uri = data?.data
        if (uri == null || uri.scheme != "content") {
            result.error("unavailable", "A phone number could not be selected.", null); return
        }
        try {
            // ACTION_PICK grants access to this selected record only. Never
            // enumerate contacts or retain names, numbers or the URI.
            val number = contentResolver.query(uri,
                arrayOf(ContactsContract.CommonDataKinds.Phone.NUMBER), null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) cursor.getString(0) else null
            }
            if (number.isNullOrBlank()) result.error("unavailable", "No phone number selected.", null)
            else result.success(number)
        } catch (error: Exception) {
            result.error("unavailable", "The selected number could not be read.", null)
        }
    }

    override fun onDestroy() {
        runCatching { contactResult?.success(null) }
        contactResult = null
        super.onDestroy()
    }

    private fun composeInvite(call: io.flutter.plugin.common.MethodCall): Boolean {
        val text = call.argument<String>("text") ?: return false
        if (text.isBlank() || text.length > 2048) return false
        return try {
            when (call.argument<String>("target")) {
                "whatsapp" -> {
                    var opened = false
                    for (targetPackage in listOf("com.whatsapp", "com.whatsapp.w4b")) {
                        try {
                            startActivity(Intent(Intent.ACTION_SEND).setType("text/plain")
                                .putExtra(Intent.EXTRA_TEXT, text).setPackage(targetPackage))
                            opened = true; break
                        } catch (missing: ActivityNotFoundException) { /* Try the next installed variant. */ }
                    }
                    opened
                }
                "sms" -> {
                    val phone = call.argument<String>("phone") ?: ""
                    if (phone.isNotEmpty() && !Regex("^\\+?[0-9]{2,20}$").matches(phone)) return false
                    startActivity(Intent(Intent.ACTION_SENDTO, Uri.fromParts("smsto", phone, null))
                        .putExtra("sms_body", text))
                    true
                }
                "other" -> {
                    val send = Intent(Intent.ACTION_SEND).setType("text/plain")
                        .putExtra(Intent.EXTRA_TEXT, text)
                    startActivity(Intent.createChooser(send, "Share CIRCLE invite"))
                    true
                }
                else -> false
            }
        } catch (error: Exception) { false }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "circle/invite_share")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickPhone" -> {
                        if (contactResult != null) {
                            result.error("busy", "Finish the current contact selection.", null)
                        } else {
                            contactResult = result
                            try {
                                startActivityForResult(Intent(Intent.ACTION_PICK,
                                    ContactsContract.CommonDataKinds.Phone.CONTENT_URI), contactRequest)
                            } catch (error: Exception) {
                                contactResult = null
                                result.error("unavailable", "Contact picker unavailable.", null)
                            }
                        }
                    }
                    "compose" -> result.success(composeInvite(call))
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "circle/notification_preferences")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "timezone" -> result.success(TimeZone.getDefault().id)
                    "settings" -> {
                        try {
                            startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName))
                            result.success(null)
                        } catch (error: Exception) {
                            result.error("unavailable", "Notification settings could not open.", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
