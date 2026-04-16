package com.example.tt_running_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.widget.RemoteViews
import android.widget.RemoteViewsService

class WidgetListService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        WidgetListFactory(applicationContext, intent)
}

class WidgetListFactory(
    private val context: Context,
    private val intent: Intent
) : RemoteViewsService.RemoteViewsFactory {

    private val widgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, -1)
    private val isSmall  = intent.getBooleanExtra("is_small", false)

    private sealed class ListItem {
        data class Header(val day: String) : ListItem()
        data class Slot(val line: String, val gradeEmoji: String) : ListItem()
    }

    private var items: List<ListItem> = emptyList()
    private var darkMode = true

    private val prefs get() = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    override fun onCreate() {}
    override fun onDestroy() {}

    override fun onDataSetChanged() {
        val filterMode = prefs.getString("filter_mode_$widgetId", "all") ?: "all"
        darkMode = prefs.getBoolean("dark_mode_$widgetId", true)

        val result = mutableListOf<ListItem>()

        if (isSmall) {
            // 소형: 오늘만, 헤더 없음
            val key  = if (filterMode == "good_only") "today_slots_good_only_small_text" else "today_slots_small_text"
            result.addAll(parseLines(prefs.getString(key, "") ?: ""))
        } else {
            // 대형: 오늘 + 내일, 섹션 헤더 포함
            val todayKey    = if (filterMode == "good_only") "today_slots_good_only_text"    else "today_slots_text"
            val tomorrowKey = if (filterMode == "good_only") "tomorrow_slots_good_only_text" else "tomorrow_slots_text"
            result.add(ListItem.Header("오늘"))
            result.addAll(parseLines(prefs.getString(todayKey,    "") ?: ""))
            result.add(ListItem.Header("내일"))
            result.addAll(parseLines(prefs.getString(tomorrowKey, "") ?: ""))
        }

        items = result
    }

    private fun parseLines(text: String): List<ListItem.Slot> {
        if (text.isBlank()) return emptyList()
        return text.split("\n").filter { it.isNotBlank() }.map { line ->
            val emoji = when {
                line.startsWith("🟢") -> "🟢"
                line.startsWith("🟡") -> "🟡"
                else                  -> "🔴"
            }
            ListItem.Slot(line, emoji)
        }
    }

    override fun getCount() = items.size
    override fun getViewTypeCount() = 2
    override fun hasStableIds() = true
    override fun getItemId(position: Int) = position.toLong()
    override fun getLoadingView() = null

    override fun getViewAt(position: Int): RemoteViews {
        return when (val item = items.getOrNull(position)) {
            is ListItem.Header -> headerView(item)
            is ListItem.Slot   -> slotView(item)
            null               -> RemoteViews(context.packageName, R.layout.widget_list_item)
        }
    }

    private fun headerView(item: ListItem.Header): RemoteViews {
        val color = if (darkMode) Color.parseColor("#66FFFFFF") else Color.parseColor("#66000000")
        return RemoteViews(context.packageName, R.layout.widget_list_item_header).apply {
            setTextViewText(R.id.tv_header_day, item.day)
            setTextColor(R.id.tv_header_day, color)
        }
    }

    private fun slotView(item: ListItem.Slot): RemoteViews {
        // 형식: "🟢 오전6시  25°C · 강수 10% · PM2.5 8μg"
        // 이중 공백으로 시간 부분과 상세 부분을 구분
        val parts      = item.line.split("  ", limit = 2)
        val timeText   = parts.getOrElse(0) { item.line }
        val detailText = parts.getOrElse(1) { "" }

        val gradeColor = when (item.gradeEmoji) {
            "🟢" -> Color.parseColor("#4CAF50")
            "🟡" -> Color.parseColor("#FFC107")
            else  -> Color.parseColor("#EF5350")
        }
        val detailColor = if (darkMode) Color.parseColor("#BBFFFFFF") else Color.parseColor("#BB000000")

        return RemoteViews(context.packageName, R.layout.widget_list_item).apply {
            setTextViewText(R.id.tv_slot_time,   timeText)
            setTextViewText(R.id.tv_slot_detail, detailText)
            setTextColor(R.id.tv_slot_time,   gradeColor)
            setTextColor(R.id.tv_slot_detail, detailColor)
        }
    }
}
