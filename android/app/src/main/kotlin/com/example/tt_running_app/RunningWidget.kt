package com.example.tt_running_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetProvider

// home_widget 패키지가 저장하는 SharedPreferences 이름
private const val PREFS_NAME = "HomeWidgetPreferences"

// 백그라운드 갱신 주기: 25분 (30분 위젯 주기보다 짧게 설정해 루프 방지)
private const val REFRESH_INTERVAL_MS = 25 * 60 * 1000L

// 소형 위젯 (오늘 추천)
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

// 대형 위젯 (오늘 + 내일 추천)
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

fun updateSmallWidget(
    context: Context,
    appWidgetManager: AppWidgetManager,
    widgetId: Int,
    data: SharedPreferences
) {
    val location  = data.getString("location", "앱을 실행해주세요") ?: "앱을 실행해주세요"
    val bestTime  = data.getString("today_best_time", "데이터 없음") ?: "데이터 없음"
    val summary   = data.getString("today_summary", "") ?: ""
    val updatedAt = data.getString("updated_at", "") ?: ""

    val views = RemoteViews(context.packageName, R.layout.small_widget).apply {
        setTextViewText(R.id.tv_location, location)
        setTextViewText(R.id.tv_best_time, bestTime)
        setTextViewText(R.id.tv_summary, summary)
        setTextViewText(R.id.tv_updated_at, updatedAt)
    }

    appWidgetManager.updateAppWidget(widgetId, views)
}

fun updateLargeWidget(
    context: Context,
    appWidgetManager: AppWidgetManager,
    widgetId: Int,
    data: SharedPreferences
) {
    val location        = data.getString("location", "앱을 실행해주세요") ?: "앱을 실행해주세요"
    val todayBest       = data.getString("today_best_time", "데이터 없음") ?: "데이터 없음"
    val todaySummary    = data.getString("today_summary", "") ?: ""
    val tomorrowBest    = data.getString("tomorrow_best_time", "-") ?: "-"
    val tomorrowSummary = data.getString("tomorrow_summary", "") ?: ""
    val updatedAt       = data.getString("updated_at", "") ?: ""

    val views = RemoteViews(context.packageName, R.layout.large_widget).apply {
        setTextViewText(R.id.tv_location, location)
        setTextViewText(R.id.tv_today_best, todayBest)
        setTextViewText(R.id.tv_today_summary, todaySummary)
        setTextViewText(R.id.tv_tomorrow_best, tomorrowBest)
        setTextViewText(R.id.tv_tomorrow_summary, tomorrowSummary)
        setTextViewText(R.id.tv_updated_at, updatedAt)
    }

    appWidgetManager.updateAppWidget(widgetId, views)
}

// 마지막 갱신 시각이 REFRESH_INTERVAL_MS 이상 지났으면 Dart 백그라운드 콜백 요청
fun triggerBackgroundRefreshIfStale(context: Context, data: SharedPreferences) {
    val lastRefresh = data.getLong("widget_refreshed_at", 0L)
    if (System.currentTimeMillis() - lastRefresh > REFRESH_INTERVAL_MS) {
        try {
            HomeWidgetBackgroundIntent
                .getBroadcast(context, Uri.parse("runningwidget://refresh"))
                .send()
        } catch (_: Exception) {
            // PendingIntent 취소 등 예외 무시
        }
    }
}
