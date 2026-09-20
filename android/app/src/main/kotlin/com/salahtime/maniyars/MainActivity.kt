package com.salahtime.maniyars

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.os.Build
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "com.salahtime.maniyars/widget"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Schedule native background worker
        scheduleBackgroundWork()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "updateWidget" -> {
                        val manager = AppWidgetManager.getInstance(this)
                        val ids = manager.getAppWidgetIds(
                            ComponentName(this, PrayerWidgetProvider::class.java)
                        )
                        for (id in ids) {
                            PrayerWidgetProvider.updateWidget(this, manager, id)
                        }
                        result.success(null)
                    }

                    // Pins the Salah Time widget onto the home screen via the
                    // launcher's pin UI (Android 8.0+). Returns whether the
                    // launcher accepted the request.
                    "requestAddWidget" -> {
                        val manager = AppWidgetManager.getInstance(this)
                        val supported =
                            Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                                manager.isRequestPinAppWidgetSupported()
                        if (supported) {
                            // When the user confirms the pin, refresh the widget
                            // so it renders current/next straight away.
                            val successCallback = PendingIntent.getBroadcast(
                                this, 0,
                                Intent(this, WidgetUpdateReceiver::class.java),
                                PendingIntent.FLAG_UPDATE_CURRENT or
                                    PendingIntent.FLAG_IMMUTABLE
                            )
                            val pinned = manager.requestPinAppWidget(
                                ComponentName(this, PrayerWidgetProvider::class.java),
                                null,
                                successCallback
                            )
                            result.success(pinned)
                        } else {
                            result.success(false)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun scheduleBackgroundWork() {
        // Run immediately once to fetch today's prayers and schedule the chain
        val immediate = OneTimeWorkRequestBuilder<PrayerUpdateWorker>()
            .build()

        WorkManager.getInstance(this).enqueueUniqueWork(
            PrayerUpdateWorker.WORK_NAME,
            ExistingWorkPolicy.KEEP,
            immediate
        )
    }
}
