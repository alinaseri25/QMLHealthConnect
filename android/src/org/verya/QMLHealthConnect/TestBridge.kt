package org.verya.QMLHealthConnect

import android.util.Log
import android.content.Context

object TestBridge {
    @JvmStatic
    external fun onMessageFromKotlin(msg: String)

    @JvmStatic
    external fun nativeOnNotificationAction(msg: String)

    @JvmStatic
    external fun nativeOnPermissionResult(msg: String)

    @JvmStatic
    fun notifyCPlusPlus(msg: String) {
        //Log.d("123654", "123654notifyCPlusPlus: $msg")
        onMessageFromKotlin(msg)
    }

    @JvmStatic
    fun postNotification(ctx: Context, title: String, message: String,notifyId: Int,alert: Boolean) {
        val helper = NotificationHelper(ctx)
        helper.show(title, message, notifyId,alert)
    }
}
