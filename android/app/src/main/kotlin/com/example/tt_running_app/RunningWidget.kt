package com.example.tt_running_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetProvider

// home_widget 패키지가 저장하는 SharedPreferences 이름
const val PREFS_NAME = "HomeWidgetPreferences"

// 백그라운드 갱신 주기: 15분
private const val REFRESH_INTERVAL_MS = 15 * 60 * 1000L

// 소형 위젯
class SmallRunningWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (widgetId in appWidgetIds) {
            updateSmallWidget(context, appWidgetManager, widgetId, widgetData)
        }
        triggerBackgroundRefreshIfStale(context, widgetData)
    }
}

// 대형 위젯
class LargeRunningWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (widgetId in appWidgetIds) {
            updateLargeWidget(context, appWidgetManager, widgetId, widgetData)
        }
        triggerBackgroundRefreshIfStale(context, widgetData)
    }
}

// ── 위젯별 설정 읽기 ─────────────────────────────────────────────────────────

private data class WidgetConfig(
    val filterMode:   String,  // "all" | "good_only"
    val darkMode:     Boolean,
    val alphaPercent: Int      // 0~100
)

private fun loadConfig(data: SharedPreferences, widgetId: Int) = WidgetConfig(
    filterMode   = data.getString("filter_mode_$widgetId", "all") ?: "all",
    darkMode     = data.getBoolean("dark_mode_$widgetId", true),
    alphaPercent = data.getInt("alpha_$widgetId", 90)
)

private fun bgColor(config: WidgetConfig): Int {
    val alpha = (config.alphaPercent * 255 / 100)
    return if (config.darkMode) Color.argb(alpha, 26, 26, 46)
    else                         Color.argb(alpha, 230, 232, 255)
}

private fun textColors(config: WidgetConfig): Triple<Int, Int, Int> {
    // (slots/main, location/dim, updatedAt/muted)
    return if (config.darkMode) Triple(
        Color.parseColor("#CCFFFFFF"),
        Color.parseColor("#99FFFFFF"),
        Color.parseColor("#55FFFFFF")
    ) else Triple(
        Color.parseColor("#CC000000"),
        Color.parseColor("#99000000"),
        Color.parseColor("#55000000")
    )
}

// ── 앱 실행 PendingIntent ────────────────────────────────────────────────────

private fun launchAppIntent(context: Context): PendingIntent {
    val intent = context.packageManager
        .getLaunchIntentForPackage(context.packageName)
        ?.apply { flags = Intent.FLAG_ACTIVITY_NEW_TASK }
        ?: Intent()
    return PendingIntent.getActivity(
        context,
        9000,
        intent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )
}

// ── 소형 위젯 ────────────────────────────────────────────────────────────────

fun updateSmallWidget(
    context: Context,
    appWidgetManager: AppWidgetManager,
    widgetId: Int,
    data: SharedPreferences
) {
    val config    = loadConfig(data, widgetId)
    val location  = data.getString("location",  "앱을 실행해주세요") ?: "앱을 실행해주세요"
    val updatedAt = data.getString("updated_at", "") ?: ""

    val (_, dimColor, mutedColor) = textColors(config)

    val serviceIntent = Intent(context, WidgetListService::class.java).apply {
        putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
        putExtra("is_small", true)
        this.data = Uri.parse("widget://small/$widgetId")
    }

    val views = RemoteViews(context.packageName, R.layout.small_widget).apply {
        setInt(R.id.widget_root, "setBackgroundColor", bgColor(config))
        setTextViewText(R.id.tv_location,   location)
        setTextViewText(R.id.tv_updated_at, updatedAt)
        setTextColor(R.id.tv_location,   dimColor)
        setTextColor(R.id.tv_updated_at, mutedColor)
        setRemoteAdapter(R.id.lv_slots, serviceIntent)
        setOnClickPendingIntent(R.id.widget_root, launchAppIntent(context))
    }

    appWidgetManager.updateAppWidget(widgetId, views)
    appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.lv_slots)
}

// ── 대형 위젯 ────────────────────────────────────────────────────────────────

fun updateLargeWidget(
    context: Context,
    appWidgetManager: AppWidgetManager,
    widgetId: Int,
    data: SharedPreferences
) {
    val config    = loadConfig(data, widgetId)
    val location  = data.getString("location",  "앱을 실행해주세요") ?: "앱을 실행해주세요"
    val updatedAt = data.getString("updated_at", "") ?: ""

    val (_, dimColor, mutedColor) = textColors(config)

    // widgetId를 포함한 고유 URI로 서비스 인텐트 구분
    val serviceIntent = Intent(context, WidgetListService::class.java).apply {
        putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
        this.data = Uri.parse("widget://large/$widgetId")
    }

    val views = RemoteViews(context.packageName, R.layout.large_widget).apply {
        setInt(R.id.widget_root, "setBackgroundColor", bgColor(config))
        setTextViewText(R.id.tv_location,   location)
        setTextViewText(R.id.tv_updated_at, updatedAt)
        setTextColor(R.id.tv_location,   dimColor)
        setTextColor(R.id.tv_updated_at, mutedColor)
        setRemoteAdapter(R.id.lv_slots, serviceIntent)
        setOnClickPendingIntent(R.id.widget_root, launchAppIntent(context))
    }

    appWidgetManager.updateAppWidget(widgetId, views)
    appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.lv_slots)
}

// ── 백그라운드 갱신 ──────────────────────────────────────────────────────────

fun triggerBackgroundRefreshIfStale(context: Context, data: SharedPreferences) {
    val lastRefresh = data.getLong("widget_refreshed_at", 0L)
    if (System.currentTimeMillis() - lastRefresh > REFRESH_INTERVAL_MS) {
        try {
            HomeWidgetBackgroundIntent
                .getBroadcast(context, Uri.parse("runningwidget://refresh"))
                .send()
        } catch (_: Exception) {}
    }
}
