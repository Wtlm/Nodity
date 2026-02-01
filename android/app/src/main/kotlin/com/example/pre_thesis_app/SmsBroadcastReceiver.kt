package com.example.pre_thesis_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Telephony
import android.telephony.SmsMessage
import io.flutter.plugin.common.EventChannel

/**
 * BroadcastReceiver for listening to incoming SMS messages.
 * Sends received SMS data to Flutter via EventChannel.
 */
class SmsBroadcastReceiver : BroadcastReceiver() {

    companion object {
        private var eventSink: EventChannel.EventSink? = null

        fun setEventSink(sink: EventChannel.EventSink?) {
            eventSink = sink
        }
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            val messages = extractMessages(intent)
            
            for (message in messages) {
                val smsData = mapOf(
                    "address" to message.displayOriginatingAddress,
                    "body" to message.displayMessageBody,
                    "date" to message.timestampMillis,
                    "type" to 1, // Inbox type
                    "thread_id" to null
                )
                
                // Send to Flutter
                eventSink?.success(smsData)
            }
        }
    }

    private fun extractMessages(intent: Intent): Array<SmsMessage> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            Telephony.Sms.Intents.getMessagesFromIntent(intent)
        } else {
            val pdus = intent.extras?.get("pdus") as? Array<*>
            pdus?.mapNotNull { pdu ->
                @Suppress("DEPRECATION")
                SmsMessage.createFromPdu(pdu as ByteArray)
            }?.toTypedArray() ?: emptyArray()
        }
    }
}

