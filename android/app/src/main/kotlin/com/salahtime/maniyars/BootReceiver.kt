package com.salahtime.maniyars

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return

        // Refresh the widget immediately from the stored schedule (offline, no
        // network needed) so it shows the correct last/next prayer right after
        // the device comes back up, even before WorkManager runs the worker.
        PrayerWidgetProvider.refreshAll(context)

        when (action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED -> enqueueBackgroundUpdate(context)

            // WorkManager's database isn't available until the user unlocks the
            // device, so only refresh the widget for now — ACTION_BOOT_COMPLETED
            // is delivered after unlock and enqueues the real update.
            Intent.ACTION_LOCKED_BOOT_COMPLETED -> Unit
        }
    }

    private fun enqueueBackgroundUpdate(context: Context) {
        try {
            val request = OneTimeWorkRequestBuilder<PrayerUpdateWorker>()
                .build()

            WorkManager.getInstance(context).enqueueUniqueWork(
                PrayerUpdateWorker.WORK_NAME,
                ExistingWorkPolicy.REPLACE,
                request
            )
        } catch (_: Exception) {
            // WorkManager can be unavailable on certain direct-boot paths; the
            // widget was already refreshed and the alarm chain resumes the job.
        }
    }
}