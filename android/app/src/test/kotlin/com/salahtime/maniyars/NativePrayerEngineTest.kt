package com.salahtime.maniyars

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.time.LocalTime

class NativePrayerEngineTest {
    @Test
    fun `calculates ordered prayers for future dates`() {
        val schedule = NativePrayerEngine.calculate(
            LocalDate.of(2040, 1, 1),
            20.5937,
            78.9629,
        )
        val times = schedule.values.map { LocalTime.parse(it) }

        assertEquals(5, schedule.size)
        assertTrue(times.zipWithNext().all { (first, second) -> second.isAfter(first) })
    }
}
