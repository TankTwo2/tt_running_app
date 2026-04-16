package com.example.tt_running_app

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import android.widget.Button
import android.widget.RadioButton
import android.widget.SeekBar
import android.widget.Switch
import android.widget.TextView

class WidgetConfigActivity : Activity() {

    private var widgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 사용자가 뒤로가면 위젯 추가 취소
        setResult(RESULT_CANCELED)

        widgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID

        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        setContentView(R.layout.widget_config)

        val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)

        // 저장된 설정 불러오기
        val filterMode   = prefs.getString("filter_mode_$widgetId", "all") ?: "all"
        val darkMode     = prefs.getBoolean("dark_mode_$widgetId", true)
        val alphaPercent = prefs.getInt("alpha_$widgetId", 90)

        val rbAll     = findViewById<RadioButton>(R.id.rb_filter_all)
        val rbGood    = findViewById<RadioButton>(R.id.rb_filter_good)
        val swDark    = findViewById<Switch>(R.id.sw_dark_mode)
        val seekAlpha = findViewById<SeekBar>(R.id.seek_alpha)
        val tvAlpha   = findViewById<TextView>(R.id.tv_alpha_value)
        val btnSave   = findViewById<Button>(R.id.btn_save)

        rbAll.isChecked      = filterMode == "all"
        rbGood.isChecked     = filterMode == "good_only"
        swDark.isChecked     = darkMode
        seekAlpha.progress   = alphaPercent
        tvAlpha.text         = "$alphaPercent%"

        seekAlpha.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(bar: SeekBar?, progress: Int, fromUser: Boolean) {
                tvAlpha.text = "$progress%"
            }
            override fun onStartTrackingTouch(bar: SeekBar?) {}
            override fun onStopTrackingTouch(bar: SeekBar?) {}
        })

        btnSave.setOnClickListener {
            val newFilter = if (rbGood.isChecked) "good_only" else "all"
            prefs.edit()
                .putString("filter_mode_$widgetId", newFilter)
                .putBoolean("dark_mode_$widgetId", swDark.isChecked)
                .putInt("alpha_$widgetId", seekAlpha.progress)
                .apply()

            // 위젯 즉시 갱신
            val manager = AppWidgetManager.getInstance(this)
            val info    = manager.getAppWidgetInfo(widgetId)
            when (info?.provider?.className) {
                SmallRunningWidget::class.java.name ->
                    updateSmallWidget(this, manager, widgetId, prefs)
                LargeRunningWidget::class.java.name ->
                    updateLargeWidget(this, manager, widgetId, prefs)
            }

            setResult(RESULT_OK, Intent().apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            })
            finish()
        }
    }
}
