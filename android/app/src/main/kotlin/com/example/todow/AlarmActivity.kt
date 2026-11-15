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
import android.text.SpannableString
import android.text.Spanned
import android.text.style.ForegroundColorSpan
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
            val timeText = android.text.format.DateFormat
                .getTimeFormat(this@AlarmActivity).format(now)
            clockView?.let { clock ->
                if (clock.text.toString() != timeText) {
                    val styledTime = SpannableString(timeText)
                    val separator = timeText.indexOf(':')
                    if (separator >= 0) {
                        styledTime.setSpan(
                            ForegroundColorSpan(Color.parseColor("#0EA5E9")),
                            separator,
                            separator + 1,
                            Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
                        )
                    }
                    clock.text = styledTime
                    clock.animate().cancel()
                    if (clock.isLaidOut && Settings.Global.getFloat(
                            contentResolver,
                            Settings.Global.ANIMATOR_DURATION_SCALE,
                            1f,
                        ) > 0f
                    ) {
                        clock.alpha = 0.78f
                        clock.animate().alpha(1f).setDuration(180).start()
                    } else {
                        clock.alpha = 1f
                    }
                }
            }
            dateView?.text = android.text.format.DateFormat
                .getLongDateFormat(this@AlarmActivity).format(now)
            clockHandler.postDelayed(this, 1_000)
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
        val isLandscape =
            resources.configuration.orientation == Configuration.ORIENTATION_LANDSCAPE
        val isExpanded = resources.configuration.screenWidthDp >= 600
        val contentWidth = minOf(dp(560f), resources.displayMetrics.widthPixels)

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

        val contentScroll = ScrollView(this).apply {
            isFillViewport = true
            isVerticalScrollBarEnabled = false
            clipToPadding = false
        }
        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, dp(16f))
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
            maxLines = 1
            setHorizontallyScrolling(false)
            includeFontPadding = true
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            )
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                setAutoSizeTextTypeUniformWithConfiguration(
                    if (isLandscape) 28 else 32,
                    if (isLandscape) 48 else if (isExpanded) 80 else 68,
                    1,
                    TypedValue.COMPLEX_UNIT_SP,
                )
            }
        }
        content.addView(clockView)

        dateView = textView("", if (isLandscape) 14f else 16f, muted).apply {
            gravity = Gravity.CENTER
            maxLines = 1
            if (isLandscape) visibility = View.GONE
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply {
                topMargin = dp(6f)
                bottomMargin = dp(if (isLandscape) 12f else 24f)
            }
        }
        content.addView(dateView)

        val titleView = textView(
            taskTitle,
            when {
                isLandscape -> 24f
                isExpanded -> 34f
                else -> 30f
            },
            ink,
            Typeface.BOLD,
        ).apply {
            gravity = Gravity.CENTER
            setLineSpacing(0f, 1.08f)
            includeFontPadding = false
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply { bottomMargin = dp(12f) }
        }
        content.addView(titleView)

        val taskDescription = intent.getStringExtra(AlarmRingingService.EXTRA_TASK_DESCRIPTION)
            ?.trim().orEmpty()
        if (taskDescription.isNotEmpty()) {
            content.addView(textView(taskDescription, 16f, muted).apply {
                gravity = Gravity.CENTER
                setLineSpacing(dp(3f).toFloat(), 1f)
                includeFontPadding = false
                layoutParams = LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                )
            })
        }

        contentScroll.addView(content)
        root.addView(contentScroll, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            0,
            1f,
        ))

        if (Settings.Global.getFloat(
                contentResolver,
                Settings.Global.ANIMATOR_DURATION_SCALE,
                1f,
            ) > 0f
        ) {
            alarmPulse = ObjectAnimator.ofFloat(titleView, View.TRANSLATION_X, 0f, -dp(2f).toFloat(), dp(2f).toFloat(), 0f).apply {
                duration = 1500
                repeatCount = ObjectAnimator.INFINITE
            }
        }

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
                    putExtra(AlarmReceiver.EXTRA_TASK_DESCRIPTION, taskDescription)
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

        setContentView(root)
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
