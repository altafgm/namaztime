package com.salahtime.maniyars

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONObject
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Calendar
import java.util.Date

/**
 * Persists the daily prayer schedule (today + tomorrow) into SharedPreferences
 * so the widget can be recomputed offline — without network — at boot, after the
 * app is killed, or on any widget refresh.
 */
object PrayerScheduleData {

    const val KEY_SCHEDULE = "flutter.widget_schedule"

    private val PRAYER_NAMES = listOf("Fajr", "Dhuhr", "Asr", "Maghrib", "Isha")
    private val DATE_FMT = DateTimeFormatter.ofPattern("dd-MM-yyyy")
    private val TIME_FMT = DateTimeFormatter.ofPattern("HH:mm")

    /** Result of computing the widget's last/next prayer purely from a schedule. */
    data class OfflineResult(
        val lastName: String?,
        val lastTime: LocalTime?,
        val nextName: String?,
        val nextTime: LocalTime?
    )

    /**
     * Pure computation of the last/next prayer from a stored schedule and the
     * current wall-clock time. No Android dependencies, so it is unit-testable
     * on the JVM.
     *
     * @param scheduleDate the date the [scheduleTimes] belong to
     * @param scheduleTimes today's prayers ("Fajr", …) as raw "HH:mm" clock times
     * @param tomorrowDate optionally the date of [tomorrowTimes]
     * @param tomorrowTimes optionally the next day's prayers
     * @param nowDate current local date
     * @param nowTime current local time
     */
    fun computeOffline(
        scheduleDate: LocalDate,
        scheduleTimes: Map<String, LocalTime>,
        tomorrowDate: LocalDate?,
        tomorrowTimes: Map<String, LocalTime>?,
        nowDate: LocalDate,
        nowTime: LocalTime
    ): OfflineResult {
        // Use the stored schedule that matches today; if today equals the stored
        // "tomorrow" day (e.g. the device rebooted into a new day before the
        // worker fetched fresh data), fall back to that.
        val times = when (nowDate) {
            scheduleDate -> scheduleTimes
            tomorrowDate -> tomorrowTimes
            else -> return OfflineResult(null, null, null, null)
        } ?: return OfflineResult(null, null, null, null)

        var lastName: String? = null
        var lastTime: LocalTime? = null
        var nextName: String? = null
        var nextTime: LocalTime? = null

        for (name in PRAYER_NAMES) {
            val time = times[name] ?: continue
            if (!time.isAfter(nowTime)) {
                lastName = name
                lastTime = time
            } else {
                nextName = name
                nextTime = time
                break
            }
        }

        // Every prayer of the day has already passed: the next one is tomorrow's
        // Fajr (only valid when we matched this day's own schedule).
        if (nextName == null && nowDate == scheduleDate) {
            val fajr = tomorrowTimes?.get("Fajr")
            if (fajr != null) {
                nextName = "Fajr"
                nextTime = fajr
            }
        }

        return OfflineResult(lastName, lastTime, nextName, nextTime)
    }

    fun save(
        prefs: SharedPreferences,
        todayDate: Date,
        todayTimes: Map<String, String>,
        tomorrowDate: Date?,
        tomorrowTimes: Map<String, String>?
    ) {
        val zone = ZoneId.systemDefault()
        val json = JSONObject()
        json.put("today", DATE_FMT.format(todayDate.toInstant().atZone(zone)))
        json.put("todayTimes", JSONObject(todayTimes))
        if (tomorrowDate != null && tomorrowTimes != null) {
            json.put("tomorrow", DATE_FMT.format(tomorrowDate.toInstant().atZone(zone)))
            json.put("tomorrowTimes", JSONObject(tomorrowTimes))
        }
        prefs.edit().putString(KEY_SCHEDULE, json.toString()).apply()
    }

    /**
     * Recomputes the widget last/next prayer values from the persisted schedule
     * and the device clock. Requires no network, so it stays correct after a
     * reboot even when the API fetch or WorkManager run is delayed/fails.
     */
    /**
     * Parses a prayer-times object stored in the schedule JSON ("HH:mm" values
     * keyed by prayer name like "Fajr") into a LocalTime map. Unknown or
     * malformed entries are skipped, so a partial schedule still works offline.
     */
    private fun timesFromJson(json: JSONObject?): Map<String, LocalTime> {
        if (json == null) return emptyMap()
        val out = mutableMapOf<String, LocalTime>()
        for (name in PRAYER_NAMES) {
            val raw = json.optString(name, "")
            if (raw.isEmpty()) continue
            try {
                out[name] = LocalTime.parse(raw, TIME_FMT)
            } catch (_: Exception) {
                // ignore malformed time
            }
        }
        return out
    }

    /**
     * Recomputes the widget last/next prayer labels from the persisted schedule
     * and the current clock using no network, so the widget survives reboots
     * and delayed/offline API fetches.
     */
    fun recomputeFromStoredSchedule(context: Context, prefs: SharedPreferences) {
        val raw = prefs.getString(KEY_SCHEDULE, null) ?: return
        val json = try {
            JSONObject(raw)
        } catch (_: Exception) {
            return
        }

        val now = Instant.now()
        val zone = ZoneId.systemDefault()
        val nowDate = now.atZone(zone).toLocalDate()
        val nowTime = now.atZone(zone).toLocalTime()

        val todayDate = try {
            LocalDate.parse(json.getString("today"), DATE_FMT)
        } catch (_: Exception) {
            return
        }
        val tomorrowDate = try {
            if (json.isNull("tomorrow")) null
            else LocalDate.parse(json.getString("tomorrow"), DATE_FMT)
        } catch (_: Exception) {
            null
        }
        val todayTimes = timesFromJson(json.optJSONObject("todayTimes"))
        val tomorrowTimes = json.optJSONObject("tomorrowTimes")?.let(::timesFromJson)

        val result = computeOffline(
            todayDate, todayTimes, tomorrowDate, tomorrowTimes, nowDate, nowTime
        )
        if (result.lastName == null && result.nextName == null) return

        val localeTimeFmt = android.text.format.DateFormat.getTimeFormat(context)

        prefs.edit().apply {
            // Store the time exactly as the locale formats it, AM/PM included —
            // the widget renders the AM/PM suffix at a small relative size so
            // the digits stay dramatically larger than before.
            putString(
                PrayerWidgetProvider.KEY_LAST_PRAYER_NAME,
                result.lastName ?: "\u2014"
            )
            putString(
                PrayerWidgetProvider.KEY_LAST_PRAYER_TIME,
                result.lastTime
                    ?.let { localeTimeFmt.format(it.toDateAt(zone)) }
                    ?: "--:--"
            )
            putString(
                PrayerWidgetProvider.KEY_NEXT_PRAYER_NAME,
                result.nextName ?: "\u2014"
            )
            putString(
                PrayerWidgetProvider.KEY_NEXT_PRAYER_TIME,
                result.nextTime
                    ?.let { localeTimeFmt.format(it.toDateAt(zone)) }
                    ?: "--:--"
            )
            apply()
        }
    }

    fun nextPrayerDate(prefs: SharedPreferences): Date? {
        val raw = prefs.getString(KEY_SCHEDULE, null) ?: return null
        val json = try {
            JSONObject(raw)
        } catch (_: Exception) {
            return null
        }
        val zone = ZoneId.systemDefault()
        val now = Instant.now().atZone(zone)
        val todayDate = try {
            LocalDate.parse(json.getString("today"), DATE_FMT)
        } catch (_: Exception) {
            return null
        }
        val tomorrowDate = try {
            if (json.isNull("tomorrow")) null
            else LocalDate.parse(json.getString("tomorrow"), DATE_FMT)
        } catch (_: Exception) {
            null
        }
        val todayTimes = timesFromJson(json.optJSONObject("todayTimes"))
        val tomorrowTimes = json.optJSONObject("tomorrowTimes")?.let(::timesFromJson)
        val result = computeOffline(
            todayDate,
            todayTimes,
            tomorrowDate,
            tomorrowTimes,
            now.toLocalDate(),
            now.toLocalTime(),
        )
        val nextTime = result.nextTime ?: return null
        val nextDate = when {
            now.toLocalDate() == tomorrowDate -> tomorrowDate
            result.nextName == "Fajr" && todayTimes["Fajr"]?.isAfter(now.toLocalTime()) != true -> tomorrowDate
            else -> now.toLocalDate()
        } ?: return null
        return Date.from(nextDate.atTime(nextTime).atZone(zone).toInstant())
    }

    fun prayerDueNow(prefs: SharedPreferences, toleranceSeconds: Long = 300): String? {
        val raw = prefs.getString(KEY_SCHEDULE, null) ?: return null
        val json = try {
            JSONObject(raw)
        } catch (_: Exception) {
            return null
        }
        val zone = ZoneId.systemDefault()
        val now = Instant.now()
        val dates = listOf("today", "tomorrow")
        for (dateKey in dates) {
            val date = try {
                if (json.isNull(dateKey)) continue
                LocalDate.parse(json.getString(dateKey), DATE_FMT)
            } catch (_: Exception) {
                continue
            }
            val times = timesFromJson(json.optJSONObject("${dateKey}Times"))
            for (name in PRAYER_NAMES) {
                val time = times[name] ?: continue
                val prayerInstant = date.atTime(time).atZone(zone).toInstant()
                if (kotlin.math.abs(prayerInstant.epochSecond - now.epochSecond) <= toleranceSeconds) {
                    return name
                }
            }
        }
        return null
    }

    private fun LocalTime.toDateAt(zone: ZoneId): Date {
        return Date.from(
            LocalDate.now(zone).atTime(this).atZone(zone).toInstant()
        )
    }
}