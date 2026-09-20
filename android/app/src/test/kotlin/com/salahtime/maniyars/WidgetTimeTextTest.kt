package com.salahtime.maniyars

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Unit tests for the locale time split used by the widget (WidgetTimeText).
 *
 * These lock in the fix for the "AM/PM drawn at the full time size" bug: the
 * Flutter writer formats with `DateFormat.jm()`, which separates the marker with
 * a narrow no-break space (U+202F) on current CLDR data, while the native writer
 * uses a plain space. Both must split into digits + marker.
 *
 * Run with:  ./gradlew :app:testDebugUnitTest
 */
class WidgetTimeTextTest {

    private fun digits(raw: String) = WidgetTimeText.split(raw).digits
    private fun period(raw: String) = WidgetTimeText.split(raw).period

    @Test
    fun `plain space separates time and marker`() {
        assertEquals(WidgetTimeText.Parts("7:22", "PM"), WidgetTimeText.split("7:22 PM"))
        assertEquals(WidgetTimeText.Parts("4:49", "AM"), WidgetTimeText.split("4:49 AM"))
    }

    @Test
    fun `narrow no-break space separates time and marker`() {
        // DateFormat.jm() in en_US on current CLDR/ICU data.
        assertEquals(WidgetTimeText.Parts("7:22", "PM"), WidgetTimeText.split("7:22\u202FPM"))
        assertEquals(WidgetTimeText.Parts("12:08", "PM"), WidgetTimeText.split("12:08\u202FPM"))
    }

    @Test
    fun `non-breaking and other unicode spaces separate too`() {
        assertEquals(WidgetTimeText.Parts("7:22", "PM"), WidgetTimeText.split("7:22\u00A0PM"))
        assertEquals(WidgetTimeText.Parts("7:22", "PM"), WidgetTimeText.split("7:22\u2007PM"))
        assertEquals(WidgetTimeText.Parts("7:22", "PM"), WidgetTimeText.split("7:22\tPM"))
    }

    @Test
    fun `lower case and dotted markers keep the text as the locale wrote it`() {
        assertEquals("pm", period("7:22 pm"))
        assertEquals("p.m.", period("7:22 p.m."))
        assertEquals("μ.μ.", period("7:22 μ.μ."))
    }

    @Test
    fun `cjk markers split when they follow the time`() {
        assertEquals(WidgetTimeText.Parts("7:22", "下午"), WidgetTimeText.split("7:22 下午"))
        assertEquals(WidgetTimeText.Parts("7:22", "上午"), WidgetTimeText.split("7:22 上午"))
        // A leading marker cannot be split off: the whole string stays in the
        // digits view, exactly as it was drawn before the marker had its own view.
        assertEquals(WidgetTimeText.Parts("上午7:22", ""), WidgetTimeText.split("上午7:22"))
    }

    @Test
    fun `24 hour times and placeholders have no marker`() {
        assertEquals(WidgetTimeText.Parts("19:22", ""), WidgetTimeText.split("19:22"))
        assertEquals(WidgetTimeText.Parts("--:--", ""), WidgetTimeText.split("--:--"))
        assertEquals(WidgetTimeText.Parts("", ""), WidgetTimeText.split(""))
        assertEquals(WidgetTimeText.Parts("", ""), WidgetTimeText.split("   "))
    }

    @Test
    fun `a trailing separator on its own is not a marker`() {
        assertEquals(WidgetTimeText.Parts("7:22", ""), WidgetTimeText.split("7:22 "))
    }

    @Test
    fun `a second time is not mistaken for a marker`() {
        assertEquals(WidgetTimeText.Parts("7:22 19:22", ""), WidgetTimeText.split("7:22 19:22"))
    }

    @Test
    fun `an over long last word is not mistaken for a marker`() {
        assertEquals(WidgetTimeText.Parts("7:22 Afternoon", ""), WidgetTimeText.split("7:22 Afternoon"))
    }

    @Test
    fun `splitting never loses text`() {
        val samples = listOf(
            "7:22 PM", "7:22\u202FAM", "--:--", "19:22", "7:22 p.m.", "4:49 AM", "上午7:22",
        )
        for (sample in samples) {
            val parts = WidgetTimeText.split(sample)
            val rebuilt = listOf(parts.digits, parts.period).filter { it.isNotEmpty() }.joinToString(" ")
            assertEquals(sample.trim().replace('\u202F', ' '), rebuilt.replace('\u202F', ' '))
        }
    }
}
