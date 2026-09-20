package com.salahtime.maniyars

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager

class PrayerUpdateReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val request = OneTimeWorkRequestBuilder<PrayerUpdateWorker>()
            .build()

        WorkManager.getInstance(context).enqueueUniqueWork(
            PrayerUpdateWorker.WORK_NAME,
            ExistingWorkPolicy.REPLACE,
            request
        )
    }
}