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
import android.animation.ObjectAnimator
import android.provider.Settings
import android.view.animation.AccelerateDecelerateInterpolator
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
            window.decorView.systemUiVisibility =
                View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR or View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR
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
        val muted = Color.parseColor("#625C56")
        val azure = Color.parseColor("#0EA5E9")
        val amber = Color.parseColor("#F59E0B")
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
            layoutParams = ViewGroup.LayoutParams(contentWidth, ViewGroup.LayoutParams.MATCH_PARENT)
        }

        val header = LinearLayout(this).apply {
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply { bottomMargin = dp(30f) }
        }
        val ringStatus = LinearLayout(this).apply {
            gravity = Gravity.CENTER_VERTICAL
            contentDescription = "Alarm is ringing"
        }
        val ringDot = View(this).apply { background = background(amber, 50f) }
        ringStatus.addView(ringDot, LinearLayout.LayoutParams(dp(9f), dp(9f)).apply {
            rightMargin = dp(9f)
        })
        ringStatus.addView(textView("ALARM RINGING", 12f, ink, Typeface.BOLD).apply {
            letterSpacing = 0.06f
        })
        header.addView(ringStatus)
        header.addView(View(this), LinearLayout.LayoutParams(0, 1, 1f))
        val heading = textView(
            SimpleDateFormat("h:mm a", Locale.getDefault()).format(Date()),
            if (isWide) 52f else 46f,
            ink,
            Typeface.BOLD,
        ).apply {
            letterSpacing = -0.04f
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply { bottomMargin = dp(4f) }
        }
        root.addView(header)
        root.addView(heading)

        val date = textView(
            SimpleDateFormat("EEEE, MMMM d", Locale.getDefault()).format(Date()),
            14f,
            muted,
            Typeface.NORMAL,
        ).apply {
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply { bottomMargin = dp(32f) }
        }
        root.addView(date)

        root.addView(textView("YOUR NEXT TASK", 12f, muted, Typeface.BOLD).apply {
            letterSpacing = 0.06f
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply { bottomMargin = dp(8f) }
        })
        root.addView(textView(taskTitle, if (isWide) 30f else 28f, ink, Typeface.BOLD).apply {
            maxLines = 4
            setLineSpacing(0f, 1.08f)
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply { bottomMargin = dp(32f) }
        })

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            Settings.Global.getFloat(contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) > 0f
        ) {
            ObjectAnimator.ofFloat(ringDot, View.ALPHA, 1f, 0.35f).apply {
                duration = 1100
                repeatMode = ObjectAnimator.REVERSE
                repeatCount = ObjectAnimator.INFINITE
                interpolator = AccelerateDecelerateInterpolator()
                start()
            }
        }

        root.addView(View(this), LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            0,
            1f,
        ))

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
            background = background(Color.parseColor("#FFF3D0"), 16f, amber)
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
        actions.addView(stopButton, LinearLayout.LayoutParams(actionWidth, dp(58f), if (isWide) 1f else 0f).apply {
            if (isWide) rightMargin = dp(8f) else bottomMargin = dp(10f)
        })
        actions.addView(snoozeButton, LinearLayout.LayoutParams(actionWidth, dp(56f), if (isWide) 1f else 0f))
        root.addView(actions)

        val openAppButton = Button(this).apply {
            text = "Open Todow · stops alarm"
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

        val helper = textView("Snooze gives you 10 more minutes.", 12f, muted).apply {
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
