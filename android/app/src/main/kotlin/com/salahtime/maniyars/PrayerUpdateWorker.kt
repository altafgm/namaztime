package com.salahtime.maniyars

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.text.SimpleDateFormat
import java.time.Instant
import java.time.ZoneId
import java.util.Date
import java.util.Locale

class PrayerUpdateWorker(
    private val context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {

    companion object {
        const val WORK_NAME = "prayer_update_worker"
        const val ALARM_ACTION = "com.salahtime.maniyars.PRAYER_UPDATE_ALARM"
        private const val RETRY_DELAY_MS = 60L * 60L * 1000L
        private const val NOTIFICATION_CHANNEL_ID = "prayer_times"
        private const val NOTIFICATION_CHANNEL_NAME = "Prayer Times"
        private const val KEY_LAST_NOTIFIED = "flutter.widget_last_notified_prayer"
        private const val DOUBLE_PREFIX = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBEb3VibGUu"

        private fun notificationIdFor(name: String): Int = when (name) {
            "Fajr" -> 101
            "Dhuhr" -> 102
            "Asr" -> 103
            "Maghrib" -> 104
            "Isha" -> 105
            else -> 106
        }

        private fun readPrefDouble(prefs: android.content.SharedPreferences, key: String): Double? {
            val raw = prefs.getString(key, null) ?: return null
            val value = if (raw.startsWith(DOUBLE_PREFIX)) {
                raw.substring(DOUBLE_PREFIX.length)
            } else {
                raw
            }
            return value.toDoubleOrNull()
        }
    }

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        val prefs = context.getSharedPreferences(
            PrayerWidgetProvider.PREFS_NAME, Context.MODE_PRIVATE
        )
        try {
            createNotificationChannel()

            // Refresh today and tomorrow from the persisted GPS coordinates on
            // every run, so the chain rolls forward indefinitely without the
            // Flutter UI or a network request.
            val latitude = readPrefDouble(prefs, "flutter.bg_lat")
            val longitude = readPrefDouble(prefs, "flutter.bg_lng")
            if (latitude != null && longitude != null) {
                val zone = ZoneId.systemDefault()
                val today = Instant.now().atZone(zone).toLocalDate()
                val tomorrow = today.plusDays(1)
                val todayTimes = NativePrayerEngine.calculate(today, latitude, longitude)
                val tomorrowTimes = NativePrayerEngine.calculate(tomorrow, latitude, longitude)
                PrayerScheduleData.save(
                    prefs,
                    Date.from(today.atStartOfDay(zone).toInstant()),
                    todayTimes,
                    Date.from(tomorrow.atStartOfDay(zone).toInstant()),
                    tomorrowTimes,
                )
            }
            PrayerScheduleData.recomputeFromStoredSchedule(context, prefs)

            val lastName = prefs.getString(
                PrayerWidgetProvider.KEY_LAST_PRAYER_NAME, "—"
            ) ?: "—"
            val lastTime = prefs.getString(
                PrayerWidgetProvider.KEY_LAST_PRAYER_TIME, "--:--"
            ) ?: "--:--"
            val dateKey = SimpleDateFormat("dd-MM-yyyy", Locale.US).format(Date())

            val prayerDueNow = PrayerScheduleData.prayerDueNow(prefs)
            if (prayerDueNow != null) {
                val notificationKey = "$prayerDueNow|$dateKey"
                if (prefs.getString(KEY_LAST_NOTIFIED, null) != notificationKey) {
                    val prayerTime = if (prayerDueNow == lastName) lastTime else ""
                    postPrayerNotification(prayerDueNow, prayerTime)
                    prefs.edit().putString(KEY_LAST_NOTIFIED, notificationKey).apply()
                }
            }

            PrayerWidgetProvider.refreshAll(context)
            val nextRun = PrayerScheduleData.nextPrayerDate(prefs)
                ?: Date(System.currentTimeMillis() + RETRY_DELAY_MS)
            scheduleNextRun(nextRun)
            Result.success()
        } catch (_: Exception) {
            scheduleNextRun(Date(System.currentTimeMillis() + RETRY_DELAY_MS))
            Result.success()
        }
    }

    private fun createNotificationChannel() {
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                NOTIFICATION_CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Notifications at each prayer time"
                enableVibration(true)
            },
        )
    }

    private fun postPrayerNotification(prayerName: String, prayerTime: String) {
        if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) return

        val contentTitle = "Time for $prayerName"
        val contentText = if (prayerTime.isEmpty()) {
            "It's time for the $prayerName prayer."
        } else {
            "It's time for the $prayerName prayer ($prayerTime)."
        }
        val intent = Intent(context, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(context, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(contentTitle)
            .setContentText(contentText)
            .setStyle(NotificationCompat.BigTextStyle().bigText(contentText))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        try {
            NotificationManagerCompat.from(context).notify(
                notificationIdFor(prayerName),
                notification,
            )
        } catch (_: SecurityException) {
            // POST_NOTIFICATIONS is not granted.
        }
    }

    private fun scheduleNextRun(nextRun: Date) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        if (android.os.Build.VERSION.SDK_INT >= 31 && !alarmManager.canScheduleExactAlarms()) {
            alarmManager.setWindow(
                AlarmManager.RTC_WAKEUP,
                nextRun.time,
                60_000L,
                createAlarmPendingIntent(),
            )
            return
        }
        alarmManager.setExactAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            nextRun.time,
            createAlarmPendingIntent(),
        )
    }

    private fun createAlarmPendingIntent(): PendingIntent {
        val intent = Intent(context, PrayerUpdateReceiver::class.java).apply {
            action = ALARM_ACTION
        }
        return PendingIntent.getBroadcast(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
