package com.example.todow

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.IBinder
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log

class AlarmRingingService : Service() {
    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null

    companion object {
        const val CHANNEL_ID = "todow_alarm_ringing_service"
        const val NOTIFICATION_ID = 9999
        const val ACTION_START = "ACTION_START_ALARM"
        const val ACTION_STOP = "ACTION_STOP_ALARM"

        const val EXTRA_TASK_ID = "EXTRA_TASK_ID"
        const val EXTRA_TASK_TITLE = "EXTRA_TASK_TITLE"
        const val EXTRA_SOUND_NAME = "EXTRA_SOUND_NAME"

        fun startAlarm(context: Context, taskId: String, taskTitle: String, soundName: String = "alarm_sound") {
            val intent = Intent(context, AlarmRingingService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_TASK_ID, taskId)
                putExtra(EXTRA_TASK_TITLE, taskTitle)
                putExtra(EXTRA_SOUND_NAME, soundName)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stopAlarm(context: Context) {
            val intent = Intent(context, AlarmRingingService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        if (action == ACTION_STOP) {
            stopRinging()
            stopForeground(true)
            stopSelf()
            return START_NOT_STICKY
        }

        val taskId = intent?.getStringExtra(EXTRA_TASK_ID) ?: ""
        val taskTitle = intent?.getStringExtra(EXTRA_TASK_TITLE) ?: "Task Reminder"
        val soundName = intent?.getStringExtra(EXTRA_SOUND_NAME) ?: "alarm_sound"

        createNotificationChannel()

        // Full Screen Intent to launch the alarm activity over lock screen
        val fullScreenIntent = Intent(this, AlarmActivity::class.java).apply {
            putExtra(EXTRA_TASK_ID, taskId)
            putExtra(EXTRA_TASK_TITLE, taskTitle)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_NO_USER_ACTION)
        }
        val fullScreenPendingIntent = PendingIntent.getActivity(
            this,
            0,
            fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        )

        val dismissIntent = Intent(this, AlarmReceiver::class.java).apply {
            setAction(AlarmReceiver.ACTION_DISMISS)
            putExtra(EXTRA_TASK_ID, taskId)
        }
        val dismissPendingIntent = PendingIntent.getBroadcast(
            this,
            1,
            dismissIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        )

        val notificationBuilder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        val bigTextStyle = Notification.BigTextStyle()
            .setBigContentTitle(taskTitle)
            .bigText("Alarm is ringing continuously.\nTap to stop alarm or view task in Todow.")

        val notification = notificationBuilder
            .setContentTitle(taskTitle)
            .setContentText("Alarm ringing · Ringing continuously")
            .setSmallIcon(R.mipmap.launcher_icon)
            .setColor(android.graphics.Color.parseColor("#0EA5E9"))
            .setCategory(Notification.CATEGORY_ALARM)
            .setPriority(Notification.PRIORITY_MAX)
            .setOngoing(true)
            .setAutoCancel(false)
            .setStyle(bigTextStyle)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .setContentIntent(fullScreenPendingIntent)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Stop Alarm", dismissPendingIntent)
            .addAction(android.R.drawable.ic_menu_info_details, "Open Todow", fullScreenPendingIntent)
            .build()

        startForeground(NOTIFICATION_ID, notification)

        // Launch full-screen alarm overlay activity immediately
        try {
            startActivity(fullScreenIntent)
        } catch (e: Exception) {
            Log.e("AlarmService", "Failed to start full screen activity: ${e.message}")
        }

        playAlarmSoundAndVibration(soundName)

        return START_STICKY
    }

    private fun playAlarmSoundAndVibration(soundName: String) {
        try {
            mediaPlayer?.stop()
            mediaPlayer?.release()

            val resId = resources.getIdentifier(soundName, "raw", packageName)
            val finalResId = if (resId != 0) resId else R.raw.alarm_sound

            mediaPlayer = MediaPlayer().apply {
                val audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .setLegacyStreamType(AudioManager.STREAM_ALARM)
                    .build()
                setAudioAttributes(audioAttributes)
                val afd = resources.openRawResourceFd(finalResId)
                setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                afd.close()
                isLooping = true
                prepare()
                start()
            }
        } catch (e: Exception) {
            Log.e("AlarmService", "Error playing alarm sound: ${e.message}")
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                vibrator = vibratorManager.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }

            val pattern = longArrayOf(0, 800, 400, 800, 400, 1000)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator?.vibrate(VibrationEffect.createWaveform(pattern, 0))
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(pattern, 0)
            }
        } catch (e: Exception) {
            Log.e("AlarmService", "Error starting vibration: ${e.message}")
        }
    }

    private fun stopRinging() {
        try {
            mediaPlayer?.stop()
            mediaPlayer?.release()
            mediaPlayer = null
        } catch (e: Exception) {
            Log.e("AlarmService", "Error stopping player: ${e.message}")
        }

        try {
            vibrator?.cancel()
            vibrator = null
        } catch (e: Exception) {
            Log.e("AlarmService", "Error stopping vibrator: ${e.message}")
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Alarm Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Active ringing task alarm alerts"
                setSound(null, null) // Audio is managed continuously by MediaPlayer on STREAM_ALARM
                enableVibration(false) // Handled by service
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    override fun onDestroy() {
        stopRinging()
        super.onDestroy()
    }
}
