package com.haiskynology.aurai

import android.content.Context
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.SystemClock
import android.view.View
import android.widget.Button
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import kotlin.math.ceil

class ScreenAuthorizationView(
    context: Context,
    description: String,
    allowLabel: String,
    private val deadline: Long,
    preview: Bitmap?,
    onAllow: () -> Unit,
    private val onDeny: () -> Unit,
    onAllowPage: (() -> Unit)?,
) : LinearLayout(context) {
    private val dark = resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK == Configuration.UI_MODE_NIGHT_YES
    private val surfaceColorValue = if (dark) Color.rgb(24, 24, 27) else Color.WHITE
    private val textColorValue = if (dark) Color.rgb(238, 238, 242) else Color.rgb(23, 23, 23)
    private val secondaryColorValue = if (dark) Color.rgb(170, 168, 179) else Color.rgb(115, 117, 128)
    private val outlineColorValue = if (dark) Color.rgb(57, 56, 63) else Color.rgb(233, 233, 240)
    private val denyButton: Button
    private val ticker = object : Runnable {
        override fun run() {
            val seconds = ceil((deadline - SystemClock.elapsedRealtime()) / 1000.0).toInt().coerceAtLeast(0)
            denyButton.text = "拒绝 · $seconds 秒后自动拒绝"
            if (seconds > 0) postDelayed(this, 1000)
        }
    }

    init {
        orientation = VERTICAL
        setPadding(dp(24), dp(24), dp(24), dp(24))
        background = GradientDrawable().apply {
            setColor(surfaceColorValue)
            cornerRadii = floatArrayOf(dp(24).toFloat(), dp(24).toFloat(), dp(24).toFloat(), dp(24).toFloat(), 0f, 0f, 0f, 0f)
        }
        addView(TextView(context).apply {
            text = if (allowLabel == "始终允许") "允许读取和操作屏幕" else "操作确认"
            textSize = 20f
            setTypeface(typeface, Typeface.BOLD)
            setTextColor(textColorValue)
        }, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT))
        val content = LinearLayout(context).apply {
            orientation = VERTICAL
            addView(TextView(context).apply {
                text = description
                textSize = 15f
                setTextColor(secondaryColorValue)
                setLineSpacing(dp(4).toFloat(), 1f)
            })
            if (preview != null) addView(ImageView(context).apply {
                setImageBitmap(preview)
                adjustViewBounds = true
                contentDescription = "待点击位置预览"
                setPadding(0, dp(12), 0, 0)
            }, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT))
        }
        addView(ScrollView(context).apply {
            isFillViewport = false
            addView(content)
        }, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT, 1f).apply {
            topMargin = dp(12)
            bottomMargin = dp(24)
        })
        addView(actionButton(allowLabel, true) { answer(onAllow) }, buttonLayout())
        if (onAllowPage != null) {
            addView(actionButton("允许此页面导航", false) { answer(onAllowPage) }, buttonLayout(10))
        }
        denyButton = actionButton("拒绝 · 30 秒后自动拒绝", false, onDeny)
        addView(denyButton, buttonLayout(10))
    }

    private fun answer(action: () -> Unit) {
        if (SystemClock.elapsedRealtime() >= deadline) onDeny() else action()
    }

    private fun actionButton(label: String, primary: Boolean, action: () -> Unit) = Button(context).apply {
        text = label
        textSize = 15f
        isAllCaps = false
        minHeight = dp(52)
        minimumHeight = dp(52)
        setPadding(dp(12), dp(12), dp(12), dp(12))
        setTextColor(if (primary) surfaceColorValue else textColorValue)
        background = GradientDrawable().apply {
            setColor(if (primary) textColorValue else surfaceColorValue)
            cornerRadius = dp(16).toFloat()
            if (!primary) setStroke(dp(1), outlineColorValue)
        }
        setOnClickListener { action() }
    }

    private fun buttonLayout(gap: Int = 0) = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT).apply {
        topMargin = dp(gap)
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val maxHeight = (resources.displayMetrics.heightPixels * 0.8).toInt()
        super.onMeasure(widthMeasureSpec, View.MeasureSpec.makeMeasureSpec(maxHeight, View.MeasureSpec.AT_MOST))
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        ticker.run()
    }

    override fun onDetachedFromWindow() {
        removeCallbacks(ticker)
        super.onDetachedFromWindow()
    }

    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()
}
