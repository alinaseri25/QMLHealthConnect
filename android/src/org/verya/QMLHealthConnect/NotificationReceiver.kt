package org.verya.QMLHealthConnect

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class NotificationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when(intent.action) {
        "org.verya.QMLHealthConnect.ACTION_STOP" -> {
            TestBridge.nativeOnNotificationAction("stop")
        }
        "org.verya.QMLHealthConnect.ACTION_START" -> {
            TestBridge.nativeOnNotificationAction("start")
        }
    }
    }
}
