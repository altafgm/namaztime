package com.salahtime.maniyars

/**
 * Splits a locale formatted prayer time into the two pieces the widget draws at
 * different sizes: the big digits and the small AM/PM marker.
 *
 * The string the widget renders is written by two different code paths —
 * Flutter's `DateFormat.jm()` and Android's `DateFormat.getTimeFormat()` — and
 * they do not agree on the character that separates the digits from the marker:
 * CLDR/ICU use a narrow no-break space (U+202F) in locales such as `en_US`
 * ("7:22\u202FPM") where other versions emit a plain space. Matching only
 * `" AM"` / `" PM"` therefore left the marker inside the digits view, so the
 * widget drew the AM/PM at the full time size (the "bigger AM/PM" bug after an
 * app triggered refresh).
 *
 * This helper splits on any kind of space and needs no per-locale list of
 * markers, and it is free of Android imports so the rules below are covered by
 * JVM unit tests.
 */
object WidgetTimeText {

    /** Longest marker accepted, e.g. "p.m." or "μ.μ." (4 characters). */
    const val MAX_PERIOD_LENGTH = 5

    /** A formatted time split into the big digits and the small AM/PM marker. */
    data class Parts(val digits: String, val period: String)

    /**
     * Splits [localeTime] ("7:22 PM", "7:22\u202FPM", "19:22", "7:22 下午") into
     * [Parts.digits] and [Parts.period]. Anything that is not a recognisable
     * marker — a 24 hour time, a placeholder such as "--:--", an empty string —
     * is returned untouched in [Parts.digits] with an empty [Parts.period], which
     * is exactly how the whole string was drawn before the marker got its own
     * view.
     */
    fun split(localeTime: String): Parts {
        val raw = localeTime.trim()
        if (raw.isEmpty()) return Parts("", "")

        val separator = raw.indexOfLast { it.isSeparator() }
        // No separator, or one that trails the string: nothing to split off.
        if (separator <= 0 || separator == raw.lastIndex) return Parts(raw, "")

        val digits = raw.substring(0, separator).trimEnd()
        val period = raw.substring(separator + 1)
        if (digits.isEmpty() || period.length > MAX_PERIOD_LENGTH) return Parts(raw, "")

        // A marker never contains a digit, which keeps a 24 hour time or any other
        // single token in the digits view.
        if (period.any { it.isDigit() }) return Parts(raw, "")

        return Parts(digits, period)
    }

    /**
     * True for every character that can separate a time from its marker: plain
     * spaces, the non-breaking spaces CLDR emits (U+00A0, U+2007, U+202F) and any
     * other Unicode space. `Char.isWhitespace` alone is not enough because it
     * deliberately excludes the non-breaking spaces.
     */
    private fun Char.isSeparator(): Boolean =
        isWhitespace() || java.lang.Character.isSpaceChar(this)
}
