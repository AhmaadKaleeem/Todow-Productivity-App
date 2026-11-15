package com.example.todow

import android.content.Context
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.todow/alarm_native"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startAlarm" -> {
                    val taskId = call.argument<String>("taskId") ?: ""
                    val taskTitle = call.argument<String>("taskTitle") ?: "Task Reminder"
                    val taskDescription = call.argument<String>("taskDescription") ?: ""
                    val soundName = call.argument<String>("soundName") ?: "alarm_sound"
                    AlarmRingingService.startAlarm(this, taskId, taskTitle, soundName, taskDescription)
                    result.success(true)
                }
                "scheduleAlarm" -> {
                    val notificationId = call.argument<Int>("notificationId")
                        ?: return@setMethodCallHandler result.error(
                            "INVALID_ID",
                            "notificationId is required",
                            null,
                        )
                    val triggerAt = call.argument<Long>("triggerAt")
                        ?: return@setMethodCallHandler result.error(
                            "INVALID_TIME",
                            "triggerAt is required",
                            null,
                        )
                    AlarmReceiver.scheduleAlarm(
                        context = this,
                        notificationId = notificationId,
                        triggerAt = triggerAt,
                        taskId = call.argument<String>("taskId") ?: "",
                        taskTitle = call.argument<String>("taskTitle") ?: "Task Reminder",
                        taskDescription = call.argument<String>("taskDescription") ?: "",
                        soundName = call.argument<String>("soundName") ?: "alarm_sound",
                    )
                    result.success(true)
                }
                "cancelAlarm" -> {
                    val notificationId = call.argument<Int>("notificationId")
                        ?: return@setMethodCallHandler result.error(
                            "INVALID_ID",
                            "notificationId is required",
                            null,
                        )
                    AlarmReceiver.cancelAlarm(this, notificationId)
                    result.success(true)
                }
                "stopAlarm" -> {
                    AlarmRingingService.stopAlarm(this)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
