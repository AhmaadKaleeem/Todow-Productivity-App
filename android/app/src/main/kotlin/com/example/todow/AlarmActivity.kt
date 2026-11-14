package com.example.todow

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.content.res.Configuration
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class AlarmActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Wake screen and turn on over lock screen
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            keyguardManager.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }

        window.statusBarColor = Color.parseColor("#F5F1EA")
        window.navigationBarColor = Color.parseColor("#F5F1EA")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR
        }

        val taskId = intent.getStringExtra(AlarmRingingService.EXTRA_TASK_ID) ?: ""
        val taskTitle = intent.getStringExtra(AlarmRingingService.EXTRA_TASK_TITLE) ?: "Task Reminder"

        fun dp(value: Float): Int = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value,
            resources.displayMetrics
        ).toInt()

        val cream = Color.parseColor("#F5F1EA")
        val ink = Color.parseColor("#1A1D24")
        val muted = Color.parseColor("#78716C")
        val azure = Color.parseColor("#0EA5E9")
        val amber = Color.parseColor("#F59E0B")
        val red = Color.parseColor("#EF4444")
        val divider = Color.parseColor("#E8E3DA")
        val isWide = resources.configuration.screenWidthDp >= 600 ||
            resources.configuration.orientation == Configuration.ORIENTATION_LANDSCAPE
        val contentWidth = minOf(dp(560f), resources.displayMetrics.widthPixels - dp(32f))

        fun textView(
            value: String,
            size: Float,
            color: Int,
            weight: Int = Typeface.NORMAL,
        ) = TextView(this).apply {
            text = value
            textSize = size
            setTextColor(color)
            typeface = Typeface.create(Typeface.DEFAULT, weight)
        }

        fun background(color: Int, radius: Float, stroke: Int? = null) =
            GradientDrawable().apply {
                setColor(color)
                cornerRadius = dp(radius).toFloat()
                if (stroke != null) setStroke(dp(1f), stroke)
            }

        val scrollView = ScrollView(this).apply {
            isFillViewport = true
            setBackgroundColor(cream)
        }
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setBackgroundColor(cream)
            setPadding(dp(16f), dp(if (isWide) 20f else 16f), dp(16f), dp(24f))
            layoutParams = ScrollView.LayoutParams(contentWidth, ViewGroup.LayoutParams.MATCH_PARENT)
        }

        val header = LinearLayout(this).apply {
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply { bottomMargin = dp(18f) }
        }
        val badge = textView("TODOW ALARM", 11f, azure, Typeface.BOLD).apply {
            letterSpacing = 0.08f
            setPadding(dp(11f), dp(7f), dp(11f), dp(7f))
            background = background(0x1A0EA5E9, 12f)
        }
        header.addView(badge)
        header.addView(View(this), LinearLayout.LayoutParams(0, 1, 1f))
        val now = textView(
            SimpleDateFormat("h:mm a", Locale.getDefault()).format(Date()),
            15f,
            muted,
            Typeface.BOLD,
        )
        header.addView(now)
        root.addView(header)

        val heading = textView("It’s time for\nyour next step.", if (isWide) 36f else 32f, ink, Typeface.BOLD).apply {
            gravity = Gravity.CENTER
            letterSpacing = -0.03f
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply { bottomMargin = dp(8f) }
        }
        root.addView(heading)
        val date = textView(
            SimpleDateFormat("EEEE, MMMM d", Locale.getDefault()).format(Date()),
            14f,
            muted,
            Typeface.BOLD,
        ).apply {
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply { bottomMargin = dp(20f) }
        }
        root.addView(date)

        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(if (isWide) 28f else 20f), dp(if (isWide) 28f else 22f), dp(if (isWide) 28f else 20f), dp(if (isWide) 28f else 22f))
            background = background(Color.WHITE, 24f, divider)
            elevation = dp(3f).toFloat()
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply { bottomMargin = dp(20f) }
        }
        val alarmLabel = textView("TASK ALARM", 11f, red, Typeface.BOLD).apply {
            letterSpacing = 0.10f
            setPadding(dp(9f), dp(5f), dp(9f), dp(5f))
            background = background(0x14EF4444, 8f)
        }
        card.addView(alarmLabel, LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        val title = textView(taskTitle, if (isWide) 28f else 24f, ink, Typeface.BOLD).apply {
            gravity = Gravity.CENTER
            maxLines = 4
            setPadding(0, dp(16f), 0, dp(8f))
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            )
        }
        card.addView(title)
        val message = textView("Ringing until you stop it or take a short break.", 14f, muted).apply {
            gravity = Gravity.CENTER
            setLineSpacing(0f, 1.2f)
        }
        card.addView(message)
        root.addView(card)

        val actions = LinearLayout(this).apply {
            orientation = if (isWide) LinearLayout.HORIZONTAL else LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            )
        }
        val snoozeButton = Button(this).apply {
            text = "Snooze 10 min"
            textSize = 15f
            setTextColor(ink)
            typeface = Typeface.DEFAULT_BOLD
            isAllCaps = false
            minHeight = dp(54f)
            background = background(0xFFFFF3D0, 16f, amber)
            setOnClickListener {
                sendBroadcast(Intent(this@AlarmActivity, AlarmReceiver::class.java).apply {
                    action = AlarmReceiver.ACTION_SNOOZE
                    putExtra(AlarmReceiver.EXTRA_TASK_ID, taskId)
                    putExtra(AlarmReceiver.EXTRA_TASK_TITLE, taskTitle)
                    putExtra(AlarmReceiver.EXTRA_SOUND_NAME, intent.getStringExtra(AlarmRingingService.EXTRA_SOUND_NAME) ?: "alarm_sound")
                })
                finish()
            }
        }
        val stopButton = Button(this).apply {
            text = "Stop alarm"
            textSize = 16f
            setTextColor(Color.WHITE)
            typeface = Typeface.DEFAULT_BOLD
            isAllCaps = false
            minHeight = dp(56f)
            background = background(azure, 16f)
            elevation = dp(2f).toFloat()
            setOnClickListener {
                AlarmRingingService.stopAlarm(this@AlarmActivity)
                finish()
            }
        }
        val actionWidth = if (isWide) 0 else ViewGroup.LayoutParams.MATCH_PARENT
        actions.addView(snoozeButton, LinearLayout.LayoutParams(actionWidth, dp(56f), if (isWide) 1f else 0f).apply {
            if (isWide) rightMargin = dp(8f) else bottomMargin = dp(10f)
        })
        actions.addView(stopButton, LinearLayout.LayoutParams(actionWidth, dp(56f), if (isWide) 1f else 0f))
        root.addView(actions)

        val openAppButton = Button(this).apply {
            text = "Open Todow"
            textSize = 14f
            setTextColor(ink)
            typeface = Typeface.DEFAULT_BOLD
            isAllCaps = false
            minHeight = dp(48f)
            background = background(Color.WHITE, 14f, divider)
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(50f),
            ).apply { topMargin = dp(12f) }
            setOnClickListener {
                AlarmRingingService.stopAlarm(this@AlarmActivity)
                packageManager.getLaunchIntentForPackage(packageName)?.let { startActivity(it) }
                finish()
            }
        }
        root.addView(openAppButton)

        val helper = textView("Your alarm will stay active until you choose an action.", 12f, muted).apply {
            gravity = Gravity.CENTER
            setPadding(0, dp(14f), 0, 0)
        }
        root.addView(helper)
        scrollView.addView(root)
        setContentView(scrollView)
    }

    override fun onBackPressed() {
        AlarmRingingService.stopAlarm(this)
        super.onBackPressed()
    }
}
