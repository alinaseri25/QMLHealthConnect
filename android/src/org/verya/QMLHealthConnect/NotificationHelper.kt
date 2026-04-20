package org.verya.QMLHealthConnect

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

class NotificationHelper(private val context: Context) {

    private val channelId = "qt_channel_primary"

    init {
        createNotificationChannel()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Qt JNI Notifications",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications generated from the C++ (Qt) layer via JNI"
            }

            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    /**
     * نمایش اعلان با دکمه‌ی اکشن (کلیک آن به JNI → C++ Callback می‌رود)
     */
    fun show(title: String, message: String,notifyId: Int,alert: Boolean) {
        // Intent و PendingIntent برای action (BroadcastReceiver)
        // STOP button
        val stopIntent = Intent(context, NotificationReceiver::class.java).apply {
            action = "org.verya.QMLHealthConnect.ACTION_STOP"
        }

        val stopPending = PendingIntent.getBroadcast(
            context,
            2,
            stopIntent,
            PendingIntent.FLAG_IMMUTABLE
        )

        // START button
        val startIntent = Intent(context, NotificationReceiver::class.java).apply {
            action = "org.verya.QMLHealthConnect.ACTION_START"
        }

        val startPending = PendingIntent.getBroadcast(
            context,
            3,
            startIntent,
            PendingIntent.FLAG_IMMUTABLE
        )

        // Intent برای باز کردن Activity اصلی Qt (روی نوتیف کلیک معمولی)
        val openIntent = Intent(context, org.qtproject.qt.android.bindings.QtActivity::class.java)
        val openPendingIntent = PendingIntent.getActivity(
            context,
            1,
            openIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val builder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setLargeIcon(BitmapFactory.decodeResource(context.resources, android.R.drawable.ic_dialog_info))
            .setContentTitle(title)
            .setContentText(message)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(openPendingIntent)
            // دکمه اکشن که BroadcastReceiver را فعال می‌کند
            .addAction(android.R.drawable.ic_input_add, "STOP", stopPending)
            .addAction(android.R.drawable.ic_input_add, "START", startPending)
            .setOnlyAlertOnce(!alert)

        // ارسال نوتیفیکیشن
        NotificationManagerCompat.from(context).notify(
            notifyId,
            builder.build()
        )
    }
}

