package com.example.pre_thesis_app

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.provider.Telephony
import android.telephony.SubscriptionManager
import android.telephony.TelephonyManager
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val SMS_CHANNEL = "com.nodity/sms"
    private val SMS_RECEIVED_CHANNEL = "com.nodity/sms_received"
    private val PHONE_CHANNEL = "com.nodity/phone"
    private val SMS_PERMISSION_REQUEST_CODE = 1001
    private val PHONE_PERMISSION_REQUEST_CODE = 1002

    private var smsEventSink: EventChannel.EventSink? = null
    private var pendingPhoneResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Method Channel for Phone operations (get phone number from SIM)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PHONE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasPhonePermission" -> {
                    result.success(hasPhonePermission())
                }
                "requestPhonePermission" -> {
                    pendingPhoneResult = result
                    requestPhonePermission()
                }
                "getPhoneNumber" -> {
                    if (hasPhonePermission()) {
                        result.success(getPhoneNumberFromSim())
                    } else {
                        result.error("PERMISSION_DENIED", "Phone permission not granted", null)
                    }
                }
                "getSimInfo" -> {
                    if (hasPhonePermission()) {
                        result.success(getSimInfo())
                    } else {
                        result.error("PERMISSION_DENIED", "Phone permission not granted", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Method Channel for SMS operations
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasPermissions" -> {
                    result.success(hasSmsPermissions())
                }
                "requestPermissions" -> {
                    requestSmsPermissions()
                    result.success(true)
                }
                "getInboxMessages" -> {
                    val limit = call.argument<Int>("limit") ?: 50
                    if (hasSmsPermissions()) {
                        result.success(getMessages(Telephony.Sms.Inbox.CONTENT_URI, limit))
                    } else {
                        result.error("PERMISSION_DENIED", "SMS read permission not granted", null)
                    }
                }
                "getSentMessages" -> {
                    val limit = call.argument<Int>("limit") ?: 50
                    if (hasSmsPermissions()) {
                        result.success(getMessages(Telephony.Sms.Sent.CONTENT_URI, limit))
                    } else {
                        result.error("PERMISSION_DENIED", "SMS read permission not granted", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Event Channel for receiving SMS in real-time
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_RECEIVED_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    smsEventSink = events
                    SmsBroadcastReceiver.setEventSink(events)
                }

                override fun onCancel(arguments: Any?) {
                    smsEventSink = null
                    SmsBroadcastReceiver.setEventSink(null)
                }
            }
        )
    }

    private fun hasSmsPermissions(): Boolean {
        val readSms = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS)
        val receiveSms = ContextCompat.checkSelfPermission(this, Manifest.permission.RECEIVE_SMS)
        return readSms == PackageManager.PERMISSION_GRANTED && 
               receiveSms == PackageManager.PERMISSION_GRANTED
    }

    private fun requestSmsPermissions() {
        val permissions = arrayOf(
            Manifest.permission.READ_SMS,
            Manifest.permission.RECEIVE_SMS,
            Manifest.permission.READ_PHONE_STATE
        )
        ActivityCompat.requestPermissions(this, permissions, SMS_PERMISSION_REQUEST_CODE)
    }

    private fun getMessages(uri: Uri, limit: Int): List<Map<String, Any?>> {
        val messages = mutableListOf<Map<String, Any?>>()
        
        val projection = arrayOf(
            Telephony.Sms._ID,
            Telephony.Sms.ADDRESS,
            Telephony.Sms.BODY,
            Telephony.Sms.DATE,
            Telephony.Sms.TYPE,
            Telephony.Sms.THREAD_ID,
            Telephony.Sms.READ
        )

        val cursor: Cursor? = contentResolver.query(
            uri,
            projection,
            null,
            null,
            "${Telephony.Sms.DATE} DESC"
        )

        cursor?.use {
            var count = 0
            while (it.moveToNext() && count < limit) {
                val message = mapOf(
                    "id" to it.getLong(it.getColumnIndexOrThrow(Telephony.Sms._ID)),
                    "address" to it.getString(it.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)),
                    "body" to it.getString(it.getColumnIndexOrThrow(Telephony.Sms.BODY)),
                    "date" to it.getLong(it.getColumnIndexOrThrow(Telephony.Sms.DATE)),
                    "type" to it.getInt(it.getColumnIndexOrThrow(Telephony.Sms.TYPE)),
                    "thread_id" to it.getLong(it.getColumnIndexOrThrow(Telephony.Sms.THREAD_ID)),
                    "read" to (it.getInt(it.getColumnIndexOrThrow(Telephony.Sms.READ)) == 1)
                )
                messages.add(message)
                count++
            }
        }

        return messages
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        
        when (requestCode) {
            SMS_PERMISSION_REQUEST_CODE -> {
                val allGranted = grantResults.all { it == PackageManager.PERMISSION_GRANTED }
                // You can send this result back to Flutter if needed
            }
            PHONE_PERMISSION_REQUEST_CODE -> {
                val allGranted = grantResults.all { it == PackageManager.PERMISSION_GRANTED }
                pendingPhoneResult?.success(allGranted)
                pendingPhoneResult = null
            }
        }
    }

    // ========== Phone Number Methods ==========

    private fun hasPhonePermission(): Boolean {
        val readPhoneState = ContextCompat.checkSelfPermission(
            this, Manifest.permission.READ_PHONE_STATE
        )
        
        // For Android 10+, also need READ_PHONE_NUMBERS
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val readPhoneNumbers = ContextCompat.checkSelfPermission(
                this, Manifest.permission.READ_PHONE_NUMBERS
            )
            readPhoneState == PackageManager.PERMISSION_GRANTED &&
            readPhoneNumbers == PackageManager.PERMISSION_GRANTED
        } else {
            readPhoneState == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun requestPhonePermission() {
        val permissions = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            arrayOf(
                Manifest.permission.READ_PHONE_STATE,
                Manifest.permission.READ_PHONE_NUMBERS
            )
        } else {
            arrayOf(Manifest.permission.READ_PHONE_STATE)
        }
        ActivityCompat.requestPermissions(this, permissions, PHONE_PERMISSION_REQUEST_CODE)
    }

    @Suppress("DEPRECATION")
    private fun getPhoneNumberFromSim(): Map<String, Any?> {
        val result = mutableMapOf<String, Any?>(
            "phoneNumber" to null,
            "error" to null,
            "source" to null
        )

        try {
            if (!hasPhonePermission()) {
                result["error"] = "Permission not granted"
                return result
            }

            // Method 1: Try TelephonyManager (works on most devices)
            val telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
            var phoneNumber: String? = null

            try {
                phoneNumber = telephonyManager.line1Number
                if (!phoneNumber.isNullOrBlank()) {
                    result["phoneNumber"] = normalizePhoneNumber(phoneNumber)
                    result["source"] = "TelephonyManager"
                    return result
                }
            } catch (e: SecurityException) {
                // Permission might be denied at runtime
            }

            // Method 2: Try SubscriptionManager (Android 5.1+)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
                try {
                    val subscriptionManager = getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as SubscriptionManager
                    val subscriptionInfoList = subscriptionManager.activeSubscriptionInfoList
                    
                    if (subscriptionInfoList != null && subscriptionInfoList.isNotEmpty()) {
                        for (subscriptionInfo in subscriptionInfoList) {
                            val number = subscriptionInfo.number
                            if (!number.isNullOrBlank()) {
                                result["phoneNumber"] = normalizePhoneNumber(number)
                                result["source"] = "SubscriptionManager"
                                return result
                            }
                        }
                    }
                } catch (e: SecurityException) {
                    // Permission denied
                }
            }

            // No phone number found
            result["error"] = "Phone number not available from SIM. Please enter manually."
            
        } catch (e: Exception) {
            result["error"] = "Error reading phone number: ${e.message}"
        }

        return result
    }

    @Suppress("DEPRECATION")
    private fun getSimInfo(): Map<String, Any?> {
        val result = mutableMapOf<String, Any?>(
            "hasSimCard" to false,
            "simState" to "unknown",
            "carrierName" to null,
            "countryCode" to null,
            "phoneNumbers" to listOf<String>()
        )

        try {
            val telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
            
            result["simState"] = when (telephonyManager.simState) {
                TelephonyManager.SIM_STATE_READY -> "ready"
                TelephonyManager.SIM_STATE_ABSENT -> "absent"
                TelephonyManager.SIM_STATE_PIN_REQUIRED -> "pin_required"
                TelephonyManager.SIM_STATE_PUK_REQUIRED -> "puk_required"
                TelephonyManager.SIM_STATE_NETWORK_LOCKED -> "network_locked"
                else -> "unknown"
            }
            
            result["hasSimCard"] = telephonyManager.simState == TelephonyManager.SIM_STATE_READY
            result["carrierName"] = telephonyManager.simOperatorName
            result["countryCode"] = telephonyManager.simCountryIso?.uppercase()

            // Try to get all phone numbers from subscriptions
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1 && hasPhonePermission()) {
                try {
                    val subscriptionManager = getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as SubscriptionManager
                    val subscriptionInfoList = subscriptionManager.activeSubscriptionInfoList
                    
                    val phoneNumbers = mutableListOf<String>()
                    subscriptionInfoList?.forEach { info ->
                        info.number?.let { number ->
                            if (number.isNotBlank()) {
                                phoneNumbers.add(normalizePhoneNumber(number))
                            }
                        }
                    }
                    result["phoneNumbers"] = phoneNumbers
                } catch (e: SecurityException) {
                    // Permission denied
                }
            }
            
        } catch (e: Exception) {
            result["error"] = e.message
        }

        return result
    }

    private fun normalizePhoneNumber(phone: String): String {
        // Remove spaces, dashes, parentheses
        var normalized = phone.replace(Regex("[\\s\\-()]+"), "")
        
        // Ensure it starts with + for international format, or keep local format
        if (!normalized.startsWith("+") && normalized.length >= 10) {
            // Could add country code detection here if needed
        }
        
        return normalized
    }
}

