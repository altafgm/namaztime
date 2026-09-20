package com.salahtime.maniyars

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Unit tests for the resizable widget sizing math (WidgetSizing).
 *
 * These lock in the promise that making the widget resizable does not change how
 * it looks at its default 2x1 size: the scale stays exactly 1.0 there, and the
 * name/time shrink formulas keep producing the original sizes.
 *
 * Run with:  ./gradlew :app:testDebugUnitTest
 */
class WidgetSizingTest {

    private val delta = 0.0001f

    /** The untouched 2x1 widget on a Pixel-like launcher grid. */
    private val defaultWidget = WidgetSizing.SizeDp(
        WidgetSizing.DEFAULT_WIDTH_DP,
        WidgetSizing.DEFAULT_HEIGHT_DP,
    )

    @Test
    fun `default footprint renders exactly like the original fixed layout`() {
        val metrics = WidgetSizing.metricsFor(defaultWidget)

        assertEquals(1f, metrics.scale, delta)
        assertEquals(12f, metrics.nameSp, delta)
        assertEquals(20f, metrics.timeSp, delta)
        assertEquals(8f, metrics.periodSp, delta)
        assertEquals(9f, metrics.dividerSp, delta)
        assertEquals(7f, metrics.minNameSp, delta)
        assertEquals(2f, metrics.horizontalPaddingDp, delta)
    }

    @Test
    fun `column width keeps the original width based formula`() {
        // Originally: columnWidthDp = (minWidth / 2f) - 8f
        assertEquals(52f, WidgetSizing.metricsFor(WidgetSizing.SizeDp(120f, 40f)).columnWidthDp, delta)
        assertEquals(64.5f, WidgetSizing.metricsFor(defaultWidget).columnWidthDp, delta)
    }

    @Test
    fun `missing launcher options keep the default rendering`() {
        assertEquals(1f, WidgetSizing.metricsFor(WidgetSizing.SizeDp(0f, 0f)).scale, delta)
        assertEquals(1f, WidgetSizing.metricsFor(WidgetSizing.SizeDp(120f, 0f)).scale, delta)
    }

    @Test
    fun `growing on only one axis stays at the default size`() {
        // 2x2 cells: no extra width, so the text could not grow inside a column.
        assertEquals(1f, WidgetSizing.metricsFor(WidgetSizing.SizeDp(145f, 100f)).scale, delta)
        // 4x1 cells: only a single row to draw in.
        assertEquals(1f, WidgetSizing.metricsFor(WidgetSizing.SizeDp(290f, 50f)).scale, delta)
    }

    @Test
    fun `a widget resized below the default never renders smaller`() {
        assertEquals(1f, WidgetSizing.metricsFor(WidgetSizing.SizeDp(100f, 38f)).scale, delta)
    }

    @Test
    fun `one resize step up scales every size proportionally`() {
        // 3x2 cells on a Pixel-like grid, ~220dp x 100dp.
        val metrics = WidgetSizing.metricsFor(WidgetSizing.SizeDp(220f, 100f))
        val expectedScale = 220f / WidgetSizing.DEFAULT_WIDTH_DP

        assertEquals(expectedScale, metrics.scale, delta)
        assertEquals(12f * expectedScale, metrics.nameSp, delta)
        assertEquals(20f * expectedScale, metrics.timeSp, delta)
        assertEquals(8f * expectedScale, metrics.periodSp, delta)
        assertEquals(9f * expectedScale, metrics.dividerSp, delta)
        assertEquals(2f * expectedScale, metrics.horizontalPaddingDp, delta)
    }

    @Test
    fun `scale follows the smaller axis and is capped`() {
        // 4x2 cells: both axes doubled.
        assertEquals(2f, WidgetSizing.metricsFor(WidgetSizing.SizeDp(290f, 100f)).scale, delta)
        // Anything much larger stops at the cap.
        assertEquals(
            WidgetSizing.MAX_SCALE,
            WidgetSizing.metricsFor(WidgetSizing.SizeDp(1000f, 1000f)).scale,
            delta,
        )
    }

    @Test
    fun `launcher reported resize sizes are used as the baseline`() {
        val footprint = WidgetSizing.SizeDp(130f, 60f)

        // The widget itself is always 1.0, whatever the launcher's grid is.
        assertEquals(
            1f,
            WidgetSizing.metricsFor(WidgetSizing.SizeDp(130f, 60f), footprint).scale,
            delta,
        )
        // Doubling it in both directions scales by exactly 2.
        assertEquals(
            2f,
            WidgetSizing.metricsFor(WidgetSizing.SizeDp(260f, 120f), footprint).scale,
            delta,
        )
    }

    @Test
    fun `name shrink formula is unchanged at the default size`() {
        // "Maghrib" (7 chars) in a 52dp column at 12sp: 7 * 0.65 * 12 = 54.6dp.
        assertEquals(
            52f / (7f * 0.65f),
            WidgetSizing.fitNameToWidthSp(7, 52f, 12f, 7f, 1f),
            0.001f,
        )
        // A short name keeps its full size.
        assertEquals(12f, WidgetSizing.fitNameToWidthSp(4, 52f, 12f, 7f, 1f), delta)
        // Never below the legibility floor.
        assertEquals(7f, WidgetSizing.fitNameToWidthSp(30, 52f, 12f, 7f, 1f), delta)
        // Empty text is left as requested.
        assertEquals(12f, WidgetSizing.fitNameToWidthSp(0, 52f, 12f, 7f, 1f), delta)
    }

    @Test
    fun `time is only shrunk when it cannot fit a scaled up column`() {
        val needed = 5 * WidgetSizing.DIGIT_WIDTH_PER_CHARACTER * 40f +
            2 * WidgetSizing.PERIOD_WIDTH_PER_CHARACTER * 16f

        assertEquals(
            40f * (64.5f / needed),
            WidgetSizing.fitTimeToWidthSp(5, 2, 64.5f, 40f, 16f, 1f),
            0.001f,
        )
        // A wide column keeps the requested size.
        assertEquals(40f, WidgetSizing.fitTimeToWidthSp(5, 2, 300f, 40f, 16f, 1f), delta)
        // Nothing to measure.
        assertEquals(40f, WidgetSizing.fitTimeToWidthSp(0, 0, 64.5f, 40f, 16f, 1f), delta)
    }

    @Test
    fun `am pm suffix follows the digits when they are shrunk`() {
        assertEquals(8f, WidgetSizing.periodSpFor(20f, 20f, 8f), delta)
        assertEquals(4f, WidgetSizing.periodSpFor(10f, 20f, 8f), delta)
    }
}
