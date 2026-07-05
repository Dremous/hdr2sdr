package com.example.hdr2sdr

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class HdrConversionService : Service() {

    companion object {
        const val CHANNEL_ID = "hdr2sdr_conversion"
        const val NOTIFICATION_ID = 1001
        const val ACTION_START = "com.example.hdr2sdr.action.START_CONVERSION"
        const val ACTION_CANCEL = "com.example.hdr2sdr.action.CANCEL_CONVERSION"
        const val EXTRA_FILE_PATH = "filePath"
        const val EXTRA_OUTPUT_PATH = "outputPath"
        const val EXTRA_ENCODER = "encoder"
        const val EXTRA_CRF = "crf"
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    private var encoder: Int = 1
    private var crf: Int = 23

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                val filePath = intent.getStringExtra(EXTRA_FILE_PATH)
                val outputPath = intent.getStringExtra(EXTRA_OUTPUT_PATH)
                encoder = intent.getIntExtra(EXTRA_ENCODER, 1)
                crf = intent.getIntExtra(EXTRA_CRF, 23)
                if (filePath != null && outputPath != null) {
                    startForeground(NOTIFICATION_ID, buildNotification("转换中..."))
                    MainActivity.sendBackgroundEvent(mapOf(
                        "type" to "progress",
                        "progress" to 0.0,
                        "currentFrame" to 0,
                        "totalFrames" to 0
                    ))
                }
            }
            ACTION_CANCEL -> {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "HDR 转换",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "HDR到SDR后台转换通知"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(contentText: String): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("HDR 转换")
            .setContentText(contentText)
            .setSmallIcon(android.R.drawable.ic_menu_rotate)
            .setOngoing(true)
            .build()
    }
}
