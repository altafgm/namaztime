package com.salahtime.maniyars

/**
 * Pure sizing math for the resizable home-screen widget.
 *
 * `res/xml/prayer_widget_info.xml` declares the widget as resizable on both
 * axes, so the content has to grow with the box the launcher hands it. Every
 * value here is derived from the widget's current size and from the size of the
 * default 2x1 widget. The file is deliberately free of Android imports so the
 * rules below can be covered by JVM unit tests.
 *
 * Rules that keep the original look intact:
 *  - at (or below) the default footprint the scale is exactly 1.0, which renders
 *    identically to the original fixed sizes (12sp name, 20sp time, 8sp AM/PM,
 *    9sp divider, 2dp side padding);
 *  - scaling only starts once the widget is [RESIZE_THRESHOLD] times larger than
 *    the default in *both* axes — one resize step up on a cell based launcher
 *    grid (e.g. 3x2 cells) — so a default widget is never drawn differently
 *    just because it can now be resized;
 *  - the smaller of the two axis ratios wins, which keeps the font proportions
 *    of a widget that was stretched in only one direction, and a widget that was
 *    shrunk never renders smaller than the default (the ratio is clamped at 1.0).
 */
object WidgetSizing {

    /**
     * Typical footprint of the default 2x1 widget in dp, used when the launcher
     * does not report the sizes the widget can be resized to (API < 31, or
     * launchers that omit `OPTION_APPWIDGET_SIZES`). Real grids land within a
     * few dp of this and [RESIZE_THRESHOLD] absorbs the difference.
     */
    const val DEFAULT_WIDTH_DP = 145f
    const val DEFAULT_HEIGHT_DP = 50f

    /**
     * How much larger than the default footprint the widget has to be before any
     * text is scaled up. The first resize step on a launcher grid is at least
     * 1.5x (3 cells where the default uses 2), so a default widget stays 1:1.
     */
    const val RESIZE_THRESHOLD = 1.4f

    /** Largest factor the content is ever scaled by. */
    const val MAX_SCALE = 2.5f

    /** Sizes declared in `res/layout/prayer_widget_layout.xml`, at scale 1. */
    const val BASE_NAME_SP = 12f
    const val BASE_TIME_SP = 20f
    const val BASE_PERIOD_SP = 8f
    const val BASE_DIVIDER_SP = 9f
    const val BASE_PADDING_DP = 2f

    /** A prayer name is never shrunk below this (legibility floor). */
    const val MIN_NAME_SP = 7f

    /** Average glyph width, in em, for the bold labels / digits / AM-PM text. */
    const val NAME_WIDTH_PER_CHARACTER = 0.65f
    const val DIGIT_WIDTH_PER_CHARACTER = 0.62f
    const val PERIOD_WIDTH_PER_CHARACTER = 0.70f

    /** Horizontal inset taken off each half of the widget for the columns. */
    const val COLUMN_INSET_DP = 8f

    /** A widget size in dp, as reported by `AppWidgetManager`. */
    data class SizeDp(val widthDp: Float, val heightDp: Float)

    /** Everything the provider needs to draw one widget at its current size. */
    data class Metrics(
        val scale: Float,
        val widthDp: Float,
        val nameSp: Float,
        val timeSp: Float,
        val periodSp: Float,
        val dividerSp: Float,
        val minNameSp: Float,
        val horizontalPaddingDp: Float,
    ) {
        /** Width available to one of the two prayer columns. */
        val columnWidthDp: Float get() = (widthDp / 2f) - COLUMN_INSET_DP
    }

    /**
     * Sizes for a widget of [current] size. [defaultFootprint] is the size the
     * launcher reports for the smallest resize step (i.e. the untouched widget);
     * when it is unknown the typical 2x1 footprint is assumed.
     */
    fun metricsFor(current: SizeDp, defaultFootprint: SizeDp? = null): Metrics {
        val baseWidth = defaultFootprint?.widthDp?.takeIf { it > 0f } ?: DEFAULT_WIDTH_DP
        val baseHeight = defaultFootprint?.heightDp?.takeIf { it > 0f } ?: DEFAULT_HEIGHT_DP
        val scale = scaleFor(current.widthDp, current.heightDp, baseWidth, baseHeight)
        return Metrics(
            scale = scale,
            widthDp = current.widthDp,
            nameSp = BASE_NAME_SP * scale,
            timeSp = BASE_TIME_SP * scale,
            periodSp = BASE_PERIOD_SP * scale,
            dividerSp = BASE_DIVIDER_SP * scale,
            minNameSp = MIN_NAME_SP * scale,
            horizontalPaddingDp = BASE_PADDING_DP * scale,
        )
    }

    /**
     * Scale factor for a widget of [widthDp] x [heightDp]. Returns exactly 1.0
     * for anything that is not clearly bigger than the default footprint, so the
     * default rendering is untouched; larger widgets scale with the smaller of
     * the two axes, up to [MAX_SCALE].
     */
    fun scaleFor(widthDp: Float, heightDp: Float, baseWidthDp: Float, baseHeightDp: Float): Float {
        if (widthDp <= 0f || heightDp <= 0f || baseWidthDp <= 0f || baseHeightDp <= 0f) return 1f
        val ratio = minOf(widthDp / baseWidthDp, heightDp / baseHeightDp)
        if (ratio < RESIZE_THRESHOLD) return 1f
        return ratio.coerceAtMost(MAX_SCALE)
    }

    /**
     * Font size (sp) for a prayer name: [requestedSp] when it fits the column,
     * otherwise the size at which it exactly fits, never below [minSp]. This is
     * the original shrink-to-fit formula, so the scale 1 result is unchanged.
     */
    fun fitNameToWidthSp(
        textLength: Int,
        columnWidthDp: Float,
        requestedSp: Float,
        minSp: Float,
        fontScale: Float,
    ): Float {
        if (textLength <= 0) return requestedSp
        val scale = fontScale.coerceAtLeast(0.9f)
        val needed = textLength * NAME_WIDTH_PER_CHARACTER * requestedSp * scale
        return if (needed > columnWidthDp) {
            (columnWidthDp / (textLength * NAME_WIDTH_PER_CHARACTER * scale)).coerceAtLeast(minSp)
        } else {
            requestedSp
        }
    }

    /**
     * Font size (sp) for the big digits so that they plus the AM/PM suffix still
     * fit inside one column. Only used once the widget grew ([Metrics.scale] > 1):
     * at the default size the widget has always drawn the full size time, and
     * that must stay untouched.
     */
    fun fitTimeToWidthSp(
        digitsLength: Int,
        periodLength: Int,
        columnWidthDp: Float,
        requestedSp: Float,
        periodSp: Float,
        fontScale: Float,
    ): Float {
        if (digitsLength <= 0 || requestedSp <= 0f || columnWidthDp <= 0f) return requestedSp
        val scale = fontScale.coerceAtLeast(0.9f)
        val needed = (
            digitsLength * DIGIT_WIDTH_PER_CHARACTER * requestedSp +
                periodLength * PERIOD_WIDTH_PER_CHARACTER * periodSp
            ) * scale
        if (needed <= columnWidthDp) return requestedSp
        return requestedSp * (columnWidthDp / needed)
    }

    /** Size of the AM/PM suffix, kept proportional to the digits it follows. */
    fun periodSpFor(timeSp: Float, requestedTimeSp: Float, requestedPeriodSp: Float): Float {
        if (requestedTimeSp <= 0f) return requestedPeriodSp
        return requestedPeriodSp * (timeSp / requestedTimeSp)
    }
}
