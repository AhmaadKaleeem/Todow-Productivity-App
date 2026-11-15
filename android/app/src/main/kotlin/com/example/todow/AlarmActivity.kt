package com.example.todow

import android.animation.ObjectAnimator
import android.app.Activity
import android.content.res.ColorStateList
import android.content.res.Configuration
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import java.util.Date

class AlarmActivity : Activity() {
    private val clockHandler = Handler(Looper.getMainLooper())
    private var clockView: TextView? = null
    private var dateView: TextView? = null
    private var alarmPulse: ObjectAnimator? = null
    private val clockTicker = object : Runnable {
        override fun run() {
            val now = Date()
            clockView?.text = android.text.format.DateFormat
                .getTimeFormat(this@AlarmActivity).format(now)
            dateView?.text = android.text.format.DateFormat
                .getLongDateFormat(this@AlarmActivity).format(now)
            clockHandler.postDelayed(this, 30_000)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }

        window.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS)
        window.statusBarColor = Color.parseColor("#F5F1EA")
        window.navigationBarColor = Color.parseColor("#F5F1EA")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isStatusBarContrastEnforced = false
            window.isNavigationBarContrastEnforced = false
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                window.decorView.systemUiVisibility =
                    View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR or View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR
            } else {
                window.navigationBarColor = Color.parseColor("#1A1D24")
            }
        }

        val taskId = intent.getStringExtra(AlarmRingingService.EXTRA_TASK_ID) ?: ""
        val taskTitle = intent.getStringExtra(AlarmRingingService.EXTRA_TASK_TITLE)
            ?: "Task reminder"
        val soundName = intent.getStringExtra(AlarmRingingService.EXTRA_SOUND_NAME)
            ?: "alarm_sound"

        fun dp(value: Float): Int = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value,
            resources.displayMetrics
        ).toInt()

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

        val cream = Color.parseColor("#F5F1EA")
        val ink = Color.parseColor("#1A1D24")
        val muted = Color.parseColor("#625C56")
        val azure = Color.parseColor("#0EA5E9")
        val amber = Color.parseColor("#B45309")
        val isLandscape =
            resources.configuration.orientation == Configuration.ORIENTATION_LANDSCAPE
        val isExpanded = resources.configuration.screenWidthDp >= 600
        val contentWidth = minOf(dp(560f), resources.displayMetrics.widthPixels)

        val scrollView = ScrollView(this).apply {
            isFillViewport = true
            setBackgroundColor(cream)
            clipToPadding = false
        }
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setBackgroundColor(cream)
            setPadding(
                dp(24f),
                dp(if (isLandscape) 8f else 28f),
                dp(24f),
                dp(if (isLandscape) 8f else 24f),
            )
            layoutParams = FrameLayout.LayoutParams(
                contentWidth,
                ViewGroup.LayoutParams.MATCH_PARENT,
                Gravity.CENTER,
            )
        }

        val statusRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                dp(if (isLandscape) 16f else 24f),
            ).apply { bottomMargin = dp(if (isLandscape) 4f else 12f) }
        }
        val statusMark = View(this).apply { background = background(amber, 50f) }
        statusRow.addView(statusMark, LinearLayout.LayoutParams(dp(6f), dp(6f)).apply {
            rightMargin = dp(8f)
        })
        statusRow.addView(textView("ALARM RINGING", 12f, ink, Typeface.BOLD).apply {
            letterSpacing = 0.1f
        })
        root.addView(statusRow)

        if (Settings.Global.getFloat(
                contentResolver,
                Settings.Global.ANIMATOR_DURATION_SCALE,
                1f,
            ) > 0f
        ) {
            alarmPulse = ObjectAnimator.ofFloat(statusMark, View.ALPHA, 1f, 0.58f).apply {
                duration = 1600
                repeatMode = ObjectAnimator.REVERSE
                repeatCount = ObjectAnimator.INFINITE
            }
        }

        clockView = textView(
            "",
            when {
                isLandscape -> 48f
                isExpanded -> 80f
                else -> 68f
            },
            ink,
            Typeface.BOLD,
        ).apply {
            gravity = Gravity.CENTER
            letterSpacing = -0.04f
            fontFeatureSettings = "tnum"
            includeFontPadding = false
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            )
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                setAutoSizeTextTypeUniformWithConfiguration(
                    if (isLandscape) 42 else 48,
                    if (isLandscape) 48 else if (isExpanded) 80 else 68,
                    1,
                    TypedValue.COMPLEX_UNIT_SP,
                )
            }
        }
        root.addView(clockView)

        dateView = textView("", if (isLandscape) 14f else 16f, muted).apply {
            gravity = Gravity.CENTER
            maxLines = 1
            if (isLandscape) visibility = View.GONE
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply {
                topMargin = dp(6f)
                bottomMargin = dp(if (isLandscape) 8f else 34f)
            }
        }
        root.addView(dateView)

        root.addView(textView("TASK REMINDER", 12f, muted, Typeface.BOLD).apply {
            gravity = Gravity.CENTER
            letterSpacing = 0.12f
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply { bottomMargin = dp(if (isLandscape) 4f else 8f) }
        })
        root.addView(textView(
            taskTitle,
            when {
                isLandscape -> 22f
                isExpanded -> 32f
                else -> 28f
            },
            ink,
            Typeface.BOLD,
        ).apply {
            gravity = Gravity.CENTER
            maxLines = if (isLandscape) 2 else 3
            ellipsize = android.text.TextUtils.TruncateAt.END
            setLineSpacing(0f, 1.08f)
            includeFontPadding = false
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            )
        })
        root.addView(
            View(this).apply { minimumHeight = dp(if (isLandscape) 8f else 32f) },
            LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f),
        )

        val snoozeButton = Button(this).apply {
            text = "Snooze 10 min"
            textSize = 16f
            setTextColor(ink)
            backgroundTintList = null
            typeface = Typeface.DEFAULT_BOLD
            isAllCaps = false
            minHeight = dp(60f)
            background = RippleDrawable(
                ColorStateList.valueOf(Color.parseColor("#33000000")),
                background(azure, 18f),
                null,
            )
            setOnClickListener {
                sendBroadcast(Intent(this@AlarmActivity, AlarmReceiver::class.java).apply {
                    action = AlarmReceiver.ACTION_SNOOZE
                    putExtra(AlarmReceiver.EXTRA_TASK_ID, taskId)
                    putExtra(AlarmReceiver.EXTRA_TASK_TITLE, taskTitle)
                    putExtra(AlarmReceiver.EXTRA_SOUND_NAME, soundName)
                })
                finish()
            }
        }
        root.addView(snoozeButton, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            dp(if (isLandscape) 54f else 60f),
        ))

        val dismissButton = Button(this).apply {
            text = "Dismiss alarm"
            textSize = 16f
            setTextColor(ink)
            backgroundTintList = null
            typeface = Typeface.DEFAULT_BOLD
            isAllCaps = false
            minHeight = dp(52f)
            background = RippleDrawable(
                ColorStateList.valueOf(Color.parseColor("#330EA5E9")),
                null,
                background(Color.WHITE, 16f),
            )
            setOnClickListener {
                AlarmRingingService.stopAlarm(this@AlarmActivity)
                finish()
            }
        }
        root.addView(dismissButton, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            dp(48f),
        ).apply { topMargin = dp(if (isLandscape) 4f else 8f) })

        val openAppButton = Button(this).apply {
            text = "Open Todow"
            textSize = 14f
            setTextColor(muted)
            backgroundTintList = null
            typeface = Typeface.DEFAULT_BOLD
            isAllCaps = false
            minHeight = dp(48f)
            background = RippleDrawable(
                ColorStateList.valueOf(Color.parseColor("#220EA5E9")),
                null,
                background(Color.WHITE, 12f),
            )
            setOnClickListener {
                AlarmRingingService.stopAlarm(this@AlarmActivity)
                packageManager.getLaunchIntentForPackage(packageName)?.let { startActivity(it) }
                finish()
            }
        }
        root.addView(openAppButton, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            dp(48f),
        ).apply { topMargin = dp(if (isLandscape) 0f else 6f) })

        scrollView.addView(root)
        setContentView(scrollView)
    }

    override fun onResume() {
        super.onResume()
        clockHandler.removeCallbacks(clockTicker)
        clockTicker.run()
        alarmPulse?.start()
    }

    override fun onPause() {
        clockHandler.removeCallbacks(clockTicker)
        alarmPulse?.cancel()
        super.onPause()
    }

}
