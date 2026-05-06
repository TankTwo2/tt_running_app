package com.example.tt_running_app

import android.content.Context
import android.net.Uri
import androidx.work.Worker
import androidx.work.WorkerParameters
import es.antonborri.home_widget.HomeWidgetBackgroundIntent

class WidgetUpdateWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    override fun doWork(): Result {
        return try {
            HomeWidgetBackgroundIntent
                .getBroadcast(applicationContext, Uri.parse("runningwidget://refresh"))
                .send()
            Result.success()
        } catch (_: Exception) {
            Result.failure()
        }
    }
}
