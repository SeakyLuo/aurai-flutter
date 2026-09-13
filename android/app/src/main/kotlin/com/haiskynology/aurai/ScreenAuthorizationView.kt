package com.haiskynology.aurai

import android.content.Context
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.SystemClock
import android.view.View
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
    private val surfaceColorValue = if (dark) Color.argb(245, 32, 32, 35) else Color.argb(245, 255, 255, 255)
    private val textColorValue = if (dark) Color.rgb(238, 238, 242) else Color.rgb(23, 23, 23)
    private val secondaryColorValue = if (dark) Color.rgb(170, 168, 179) else Color.rgb(115, 117, 128)
    private val outlineColorValue = if (dark) Color.rgb(57, 56, 63) else Color.rgb(233, 233, 240)
    private val countdown: TextView
    private val ticker = object : Runnable {
        override fun run() {
            val seconds = ceil((deadline - SystemClock.elapsedRealtime()) / 1000.0).toInt().coerceAtLeast(0)
            countdown.text = "$seconds 秒后自动拒绝"
            if (seconds > 0) postDelayed(this, 1000)
        }
    }

    init {
        orientation = VERTICAL
        setPadding(dp(20), dp(12), dp(20), dp(20))
        background = GradientDrawable().apply {
            setColor(surfaceColorValue)
            cornerRadius = dp(28).toFloat()
            setStroke(dp(1), outlineColorValue)
        }
        val header = LinearLayout(context).apply {
            orientation = HORIZONTAL
            gravity = android.view.Gravity.CENTER_VERTICAL
            addView(TextView(context).apply {
                text = if (allowLabel == "始终允许") "允许读取和操作屏幕" else "操作确认"
                textSize = 17f
                setTypeface(typeface, Typeface.BOLD)
                setTextColor(textColorValue)
            }, LayoutParams(0, LayoutParams.WRAP_CONTENT, 1f))
            addView(object : View(context) {
                private val pen = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = secondaryColorValue
                    strokeWidth = resources.displayMetrics.density * 1.65f
                    strokeCap = Paint.Cap.ROUND
                }
                override fun onDraw(canvas: Canvas) {
                    val inset = dp(17).toFloat()
                    canvas.drawLine(inset, inset, width - inset, height - inset, pen)
                    canvas.drawLine(width - inset, inset, inset, height - inset, pen)
                }
            }.apply {
                contentDescription = "拒绝并关闭"
                setOnClickListener { onDeny() }
            }, LayoutParams(dp(48), dp(48)))
        }
        addView(header, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT))
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
            bottomMargin = dp(20)
        })
        addView(actionOption(allowLabel) { answer(onAllow) }, buttonLayout())
        if (onAllowPage != null) {
            addView(actionOption("允许此页面导航") { answer(onAllowPage) }, buttonLayout(10))
        }
        countdown = TextView(context).apply {
            text = "${ceil((deadline - SystemClock.elapsedRealtime()) / 1000.0).toInt().coerceAtLeast(0)} 秒后自动拒绝"
            textSize = 13f
            setTextColor(secondaryColorValue)
            setPadding(0, dp(4), 0, 0)
        }
        addView(actionOption("拒绝", countdown, onDeny), buttonLayout(8))
    }

    private fun answer(action: () -> Unit) {
        if (SystemClock.elapsedRealtime() >= deadline) onDeny() else action()
    }

    private fun actionOption(label: String, detail: TextView? = null, action: () -> Unit) = LinearLayout(context).apply {
        orientation = VERTICAL
        minimumHeight = dp(48)
        setPadding(dp(16), dp(14), dp(16), dp(14))
        background = GradientDrawable().apply {
            setColor(if (dark) Color.rgb(45, 45, 48) else Color.rgb(243, 243, 243))
            cornerRadius = dp(20).toFloat()
        }
        addView(TextView(context).apply {
            text = label
            textSize = 15f
            setTextColor(textColorValue)
        })
        if (detail != null) addView(detail)
        isFocusable = true
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
