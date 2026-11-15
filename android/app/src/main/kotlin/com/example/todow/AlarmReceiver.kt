package com.example.todow

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.app.AlarmManager
import android.app.PendingIntent
import android.os.Build
import android.util.Log

class AlarmReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_ALARM_TRIGGER = "com.example.todow.ACTION_ALARM_TRIGGER"
        const val ACTION_DISMISS = "com.example.todow.ACTION_DISMISS"
        const val ACTION_SNOOZE = "com.example.todow.ACTION_SNOOZE"

        const val EXTRA_TASK_ID = "EXTRA_TASK_ID"
        const val EXTRA_TASK_TITLE = "EXTRA_TASK_TITLE"
        const val EXTRA_TASK_DESCRIPTION = "EXTRA_TASK_DESCRIPTION"
        const val EXTRA_SOUND_NAME = "EXTRA_SOUND_NAME"
        private const val EXTRA_NOTIFICATION_ID = "EXTRA_NOTIFICATION_ID"
        private const val SNOOZE_MILLIS = 10 * 60 * 1000L

        fun scheduleAlarm(
            context: Context,
            notificationId: Int,
            triggerAt: Long,
            taskId: String,
            taskTitle: String,
            taskDescription: String = "",
            soundName: String,
        ) {
            val triggerIntent = Intent(context, AlarmReceiver::class.java).apply {
                action = ACTION_ALARM_TRIGGER
                putExtra(EXTRA_NOTIFICATION_ID, notificationId)
                putExtra(EXTRA_TASK_ID, taskId)
                putExtra(EXTRA_TASK_TITLE, taskTitle)
                putExtra(EXTRA_TASK_DESCRIPTION, taskDescription)
                putExtra(EXTRA_SOUND_NAME, soundName)
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                notificationId,
                triggerIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or
                    (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0),
            )
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        triggerAt,
                        pendingIntent,
                    )
                } else {
                    @Suppress("DEPRECATION")
                    alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
                }
            } catch (securityException: SecurityException) {
                Log.w("AlarmReceiver", "Exact alarm unavailable; using inexact alarm", securityException)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        triggerAt,
                        pendingIntent,
                    )
                } else {
                    @Suppress("DEPRECATION")
                    alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
                }
            }
        }

        fun cancelAlarm(context: Context, notificationId: Int) {
            val intent = Intent(context, AlarmReceiver::class.java)
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                notificationId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or
                    (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0),
            )
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.cancel(pendingIntent)
            pendingIntent.cancel()
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        Log.d("AlarmReceiver", "Received broadcast: $action")

        when (action) {
            ACTION_ALARM_TRIGGER -> {
                val taskId = intent.getStringExtra(EXTRA_TASK_ID) ?: ""
                val taskTitle = intent.getStringExtra(EXTRA_TASK_TITLE) ?: "Task Reminder"
                val taskDescription = intent.getStringExtra(EXTRA_TASK_DESCRIPTION) ?: ""
                val soundName = intent.getStringExtra(EXTRA_SOUND_NAME) ?: "alarm_sound"

                AlarmRingingService.startAlarm(context, taskId, taskTitle, soundName, taskDescription)
            }
            ACTION_DISMISS -> {
                AlarmRingingService.stopAlarm(context)
            }
            ACTION_SNOOZE -> {
                AlarmRingingService.stopAlarm(context)
                scheduleSnooze(
                    context = context,
                    taskId = intent.getStringExtra(EXTRA_TASK_ID) ?: "",
                    taskTitle = intent.getStringExtra(EXTRA_TASK_TITLE) ?: "Task Reminder",
                    taskDescription = intent.getStringExtra(EXTRA_TASK_DESCRIPTION) ?: "",
                    soundName = intent.getStringExtra(EXTRA_SOUND_NAME) ?: "alarm_sound",
                )
            }
        }
    }

    private fun scheduleSnooze(
        context: Context,
        taskId: String,
        taskTitle: String,
        taskDescription: String,
        soundName: String,
    ) {
        val notificationId = (taskId.hashCode() and 0x7fffffff) xor
            (System.currentTimeMillis() / 60000).toInt()
        scheduleAlarm(
            context = context,
            notificationId = notificationId,
            triggerAt = System.currentTimeMillis() + SNOOZE_MILLIS,
            taskId = taskId,
            taskTitle = taskTitle,
            taskDescription = taskDescription,
            soundName = soundName,
        )
    }
}
