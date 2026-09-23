package com.salahtime.maniyars

import java.util.Locale

/**
 * Splits a locale formatted prayer time into the two pieces the widget draws at
 * different sizes: the big digits and the small lower-case AM/PM marker.
 *
 * The string the widget renders is written by two different code paths —
 * Flutter's `DateFormat.jm()` and Android's `DateFormat.getTimeFormat()` — and
 * they do not agree on the character that separates the digits from the marker:
 * CLDR/ICU use a narrow no-break space (U+202F) in locales such as `en_US`
 * ("7:22\u202FPM") where other versions emit a plain space, so a split that only
 * matches `" AM"` / `" PM"` leaves the marker inside the digits view and the
 * widget draws it at the full time size (the "bigger AM/PM" bug after an app
 * triggered refresh). The two paths can likewise disagree about the marker's
 * case, which makes the small "am/pm" flip to a prominent "AM/PM" between
 * refreshes.
 *
 * This helper splits on any kind of space and needs no per-locale list of
 * markers, and it always renders the marker the same way — lower-case
 * ("am", "p.m.") — so the widget's small letters never grow capitals no matter
 * which code path wrote the string. The file is free of Android imports so the
 * rules below are covered by JVM unit tests.
 */
object WidgetTimeText {

    /** Longest marker accepted, e.g. "p.m." or "μ.μ." (4 characters). */
    const val MAX_PERIOD_LENGTH = 5

    /** A formatted time split into the big digits and the small AM/PM marker. */
    data class Parts(val digits: String, val period: String)

    /**
     * Splits [localeTime] ("7:22 PM", "7:22\u202FPM", "19:22", "7:22 下午") into
     * [Parts.digits] and a lower-case [Parts.period]. Anything that is not a
     * recognisable marker — a 24 hour time, a placeholder such as "--:--", an
     * empty string — is returned untouched in [Parts.digits] with an empty
     * [Parts.period], which is exactly how the whole string was drawn before the
     * marker got its own view.
     */
    fun split(localeTime: String): Parts {
        val raw = localeTime.trim()
        if (raw.isEmpty()) return Parts("", "")

        // Collapse every writing-system separator to a plain space so the split
        // below does not care which character the writer chose.
        val normalised = raw.map { if (it.isSeparator()) ' ' else it }.joinToString("")
        val space = normalised.lastIndexOf(' ')
        if (space > 0 && space < normalised.lastIndex) {
            val digits = normalised.substring(0, space).trim()
            val marker = normalised.substring(space + 1).trim()
            if (isMarker(marker)) return Parts(digits, marker.lowercase(Locale.ROOT))
        }

        // No space between digits and marker ("7:22PM"): pull the trailing
        // marker off too, so it can never be drawn at the full time size either.
        val attached = trailingMarker(normalised)
        if (attached != null) {
            val (digits, marker) = attached
            if (digits.isNotEmpty() && isMarker(marker)) {
                return Parts(digits, marker.lowercase(Locale.ROOT))
            }
        }

        return Parts(normalised, "")
    }

    /**
     * True for markers like "PM", "pm", "p.m." or "下午": a short, separated or
     * trailing word that contains a letter and never a digit, which keeps a 24
     * hour time or any other single token in the digits view.
     */
    private fun isMarker(word: String): Boolean =
        word.isNotEmpty() &&
            word.length <= MAX_PERIOD_LENGTH &&
            word.any { it.isLetter() } &&
            word.none { it.isDigit() }

    /**
     * Reads the trailing run of letters (and the dots of a dotted marker such as
     * "p.m.") off the end of [raw], returning it together with the digits before
     * it. Returns null when the string does not end in letters, so 24 hour times
     * and placeholders are left untouched.
     */
    private fun trailingMarker(raw: String): Pair<String, String>? {
        var end = raw.lastIndex
        while (end >= 0 && (raw[end].isLetter() || raw[end] == '.')) end--
        val marker = raw.substring(end + 1)
        if (marker.isEmpty()) return null
        return raw.substring(0, end + 1) to marker
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
