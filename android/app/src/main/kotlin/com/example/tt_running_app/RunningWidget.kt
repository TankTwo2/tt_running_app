package com.example.tt_running_app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

// 소형 위젯 (오늘 추천)
class SmallRunningWidget : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (widgetId in appWidgetIds) {
            updateSmallWidget(context, appWidgetManager, widgetId)
        }
    }
}

// 대형 위젯 (오늘 + 내일 추천)
class LargeRunningWidget : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (widgetId in appWidgetIds) {
            updateLargeWidget(context, appWidgetManager, widgetId)
        }
    }
}

// home_widget SharedPreferences에서 데이터 읽어 소형 위젯 갱신
fun updateSmallWidget(context: Context, appWidgetManager: AppWidgetManager, widgetId: Int) {
    val data = HomeWidgetPlugin.getData(context)

    val location  = data.getString("location", "위치 없음") ?: "위치 없음"
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

// 대형 위젯 갱신
fun updateLargeWidget(context: Context, appWidgetManager: AppWidgetManager, widgetId: Int) {
    val data = HomeWidgetPlugin.getData(context)

    val location       = data.getString("location", "위치 없음") ?: "위치 없음"
    val todayBest      = data.getString("today_best_time", "데이터 없음") ?: "데이터 없음"
    val todaySummary   = data.getString("today_summary", "") ?: ""
    val tomorrowBest   = data.getString("tomorrow_best_time", "-") ?: "-"
    val tomorrowSummary = data.getString("tomorrow_summary", "") ?: ""
    val updatedAt      = data.getString("updated_at", "") ?: ""

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
