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
    private val deadline: Long?,
    preview: Bitmap?,
    onAllow: () -> Unit,
    onAlways: () -> Unit,
    onSession: () -> Unit,
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
            val end = deadline ?: return
            val seconds = ceil((end - SystemClock.elapsedRealtime()) / 1000.0).toInt().coerceAtLeast(0)
            countdown.text = " · $seconds 秒后自动拒绝"
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
        addView(actionOption("允许一次", primary = true) { answer(onAllow) }, buttonLayout())
        addView(actionOption("当前会话允许") { answer(onSession) }, buttonLayout(8))
        addView(actionOption("始终允许") { answer(onAlways) }, buttonLayout(8))
        if (onAllowPage != null) {
            addView(actionOption("允许此页面导航") { answer(onAllowPage) }, buttonLayout(10))
        }
        countdown = TextView(context).apply {
            text = deadline?.let { " · ${ceil((it - SystemClock.elapsedRealtime()) / 1000.0).toInt().coerceAtLeast(0)} 秒后自动拒绝" } ?: ""
            textSize = 15f
            setTextColor(if (dark) Color.rgb(255, 138, 128) else Color.rgb(217, 48, 37))
        }
        addView(actionOption("拒绝", detail = if (deadline == null) null else countdown, reject = true, action = onDeny), buttonLayout(8))
    }

    private fun answer(action: () -> Unit) {
        if (deadline != null && SystemClock.elapsedRealtime() >= deadline) onDeny() else action()
    }

    private fun actionOption(label: String, detail: TextView? = null, primary: Boolean = false, reject: Boolean = false, action: () -> Unit) = LinearLayout(context).apply {
        orientation = HORIZONTAL
        gravity = android.view.Gravity.CENTER
        minimumHeight = dp(48)
        setPadding(dp(16), dp(14), dp(16), dp(14))
        background = GradientDrawable().apply {
            setColor(if (primary) Color.rgb(175, 169, 238) else if (dark) Color.rgb(45, 45, 48) else Color.rgb(243, 243, 243))
            if (primary) {
                colors = intArrayOf(Color.rgb(221, 197, 247), Color.rgb(200, 183, 244), Color.rgb(175, 169, 238))
                orientation = GradientDrawable.Orientation.TL_BR
            }
            cornerRadius = dp(24).toFloat()
        }
        addView(TextView(context).apply {
            text = label
            textSize = 15f
            if (primary) setTypeface(typeface, Typeface.BOLD)
            setTextColor(if (reject) { if (dark) Color.rgb(255, 138, 128) else Color.rgb(217, 48, 37) } else if (primary) Color.rgb(73, 51, 101) else textColorValue)
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
