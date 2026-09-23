package com.salahtime.maniyars

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Unit tests for the locale time split used by the widget (WidgetTimeText).
 *
 * These lock in two fixes:
 *
 * 1. The "AM/PM drawn at the full time size" bug: the Flutter writer formats
 *    with `DateFormat.jm()`, which separates the marker with a narrow no-break
 *    space (U+202F) on current CLDR data, while the native writer uses a plain
 *    space. Both must split into digits + marker, and an attached marker
 *    ("7:22PM") must be split off as well.
 * 2. The marker must always render in small lower-case letters ("pm"), so a
 *    write path that produces capitals cannot flip the widget's "am/pm" into a
 *    prominent "AM/PM" between refreshes.
 *
 * Run with:  ./gradlew :app:testDebugUnitTest
 */
class WidgetTimeTextTest {

    private fun digits(raw: String) = WidgetTimeText.split(raw).digits
    private fun period(raw: String) = WidgetTimeText.split(raw).period

    @Test
    fun `plain space separates time and marker`() {
        assertEquals(WidgetTimeText.Parts("7:22", "pm"), WidgetTimeText.split("7:22 PM"))
        assertEquals(WidgetTimeText.Parts("4:49", "am"), WidgetTimeText.split("4:49 AM"))
    }

    @Test
    fun `narrow no-break space separates time and marker`() {
        // DateFormat.jm() in en_US on current CLDR/ICU data.
        assertEquals(WidgetTimeText.Parts("7:22", "pm"), WidgetTimeText.split("7:22\u202FPM"))
        assertEquals(WidgetTimeText.Parts("12:08", "pm"), WidgetTimeText.split("12:08\u202FPM"))
    }

    @Test
    fun `non-breaking and other unicode spaces separate too`() {
        assertEquals(WidgetTimeText.Parts("7:22", "pm"), WidgetTimeText.split("7:22\u00A0PM"))
        assertEquals(WidgetTimeText.Parts("7:22", "pm"), WidgetTimeText.split("7:22\u2007PM"))
        assertEquals(WidgetTimeText.Parts("7:22", "pm"), WidgetTimeText.split("7:22\tPM"))
    }

    @Test
    fun `the marker is always rendered in small lower-case letters`() {
        // A capital marker written by either code path never reaches the widget.
        assertEquals("pm", period("7:22 PM"))
        assertEquals("am", period("12:00 AM"))
        assertEquals("p.m.", period("7:22 P.M."))
        assertEquals("pm", period("7:22 PM "))
    }

    @Test
    fun `an attached marker is split off so it cannot draw at the full time size`() {
        assertEquals(WidgetTimeText.Parts("7:22", "pm"), WidgetTimeText.split("7:22PM"))
        assertEquals(WidgetTimeText.Parts("7:22", "pm"), WidgetTimeText.split("7:22pm"))
        assertEquals(WidgetTimeText.Parts("7:22", "p.m."), WidgetTimeText.split("7:22p.m."))
        assertEquals(WidgetTimeText.Parts("7:22", "a.m"), WidgetTimeText.split("7:22A.M"))
    }

    @Test
    fun `lower case and dotted markers keep their small letters`() {
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
            "7:22PM", "7:22pm",
        )
        fun compact(s: String) = s.lowercase().filterNot { it.isWhitespace() }
        for (sample in samples) {
            val parts = WidgetTimeText.split(sample)
            val rebuilt = parts.digits + parts.period
            assertEquals(compact(sample), compact(rebuilt))
        }
    }
}
