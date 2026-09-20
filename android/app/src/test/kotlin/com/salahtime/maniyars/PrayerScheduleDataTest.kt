package com.salahtime.maniyars

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test
import java.time.LocalDate
import java.time.LocalTime

/**
 * Unit tests for the offline widget recompute logic (PrayerScheduleData).
 *
 * These cover the "widget must update as per the time without network" fix:
 * after a reboot or app kill, the widget reads the persisted schedule and uses
 * the device clock to work out which prayer just passed and which is next.
 *
 * Run with:  ./gradlew :app:testDebugUnitTest
 */
class PrayerScheduleDataTest {

    private val today = LocalDate.of(2026, 9, 8)

    // The five canonical prayer times used in every scenario.
    private val todayTimes = mapOf(
        "Fajr" to LocalTime.of(5, 12),
        "Dhuhr" to LocalTime.of(12, 30),
        "Asr" to LocalTime.of(15, 45),
        "Maghrib" to LocalTime.of(18, 20),
        "Isha" to LocalTime.of(19, 35),
    )

    private val tomorrowTimes = mapOf(
        "Fajr" to LocalTime.of(5, 13),
        "Dhuhr" to LocalTime.of(12, 31),
        "Asr" to LocalTime.of(15, 46),
        "Maghrib" to LocalTime.of(18, 21),
        "Isha" to LocalTime.of(19, 36),
    )

    @Test
    fun `before fajr - only next prayer`() {
        val result = computeAt(LocalTime.of(4, 0))

        assertNull(result.lastName)
        assertNull(result.lastTime)
        assertEquals("Fajr", result.nextName)
        assertEquals(LocalTime.of(5, 12), result.nextTime)
    }

    @Test
    fun `between dhuhr and asr - dhuhr last, asr next`() {
        val result = computeAt(LocalTime.of(15, 0))

        assertEquals("Dhuhr", result.lastName)
        assertEquals(LocalTime.of(12, 30), result.lastTime)
        assertEquals("Asr", result.nextName)
        assertEquals(LocalTime.of(15, 45), result.nextTime)
    }

    @Test
    fun `at exact prayer time - prayer counts as last`() {
        val result = computeAt(LocalTime.of(12, 30))

        assertEquals("Dhuhr", result.lastName)
        assertEquals(LocalTime.of(12, 30), result.lastTime)
        assertEquals("Asr", result.nextName)
    }

    @Test
    fun `after isha - isha last, next is tomorrows fajr`() {
        val result = computeAt(LocalTime.of(22, 0))

        assertEquals("Isha", result.lastName)
        assertEquals(LocalTime.of(19, 35), result.lastTime)
        assertEquals("Fajr", result.nextName)
        assertEquals(LocalTime.of(5, 13), result.nextTime)
    }

    @Test
    fun `reboot into new day - uses stored tomorrow schedule`() {
        // The worker stored "tomorrow" = today's real date, e.g. the device was
        // rebooted at night and the worker has not fetched fresh data yet.
        val result = PrayerScheduleData.computeOffline(
            scheduleDate = today.minusDays(1),
            scheduleTimes = mapOf(
                "Fajr" to LocalTime.of(5, 11),
                "Dhuhr" to LocalTime.of(12, 29),
                "Asr" to LocalTime.of(15, 44),
                "Maghrib" to LocalTime.of(18, 19),
                "Isha" to LocalTime.of(19, 34),
            ),
            tomorrowDate = today,
            tomorrowTimes = tomorrowTimes,
            nowDate = today,
            nowTime = LocalTime.of(9, 0),
        )

        assertEquals("Fajr", result.lastName)
        assertEquals("Dhuhr", result.nextName)
        assertEquals(LocalTime.of(12, 31), result.nextTime)
    }

    @Test
    fun `schedule is stale and does not match - no result`() {
        // Device was off for days: stored schedule matches neither today nor
        // tomorrow, so offline recompute is not possible and the widget keeps
        // its existing values until the worker fetches fresh data.
        val result = PrayerScheduleData.computeOffline(
            scheduleDate = today.minusDays(4),
            scheduleTimes = todayTimes,
            tomorrowDate = today.minusDays(3),
            tomorrowTimes = tomorrowTimes,
            nowDate = today,
            nowTime = LocalTime.of(9, 0),
        )

        assertNull(result.lastName)
        assertNull(result.nextName)
    }

    @Test
    fun `after isha without tomorrow stored - next stays null`() {
        val result = PrayerScheduleData.computeOffline(
            scheduleDate = today,
            scheduleTimes = todayTimes,
            tomorrowDate = null,
            tomorrowTimes = null,
            nowDate = today,
            nowTime = LocalTime.of(23, 0),
        )

        assertEquals("Isha", result.lastName)
        assertNull(result.nextName)
    }

    @Test
    fun `missing one prayer does not break computation`() {
        val partial = todayTimes - "Asr"
        val result = PrayerScheduleData.computeOffline(
            scheduleDate = today,
            scheduleTimes = partial,
            tomorrowDate = today.plusDays(1),
            tomorrowTimes = tomorrowTimes,
            nowDate = today,
            nowTime = LocalTime.of(16, 0),
        )

        assertNotNull(result.lastName)
        assertEquals("Maghrib", result.nextName)
    }

    private fun computeAt(time: LocalTime): PrayerScheduleData.OfflineResult {
        return PrayerScheduleData.computeOffline(
            scheduleDate = today,
            scheduleTimes = todayTimes,
            tomorrowDate = today.plusDays(1),
            tomorrowTimes = tomorrowTimes,
            nowDate = today,
            nowTime = time,
        )
    }
}