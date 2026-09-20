package com.salahtime.maniyars

import java.time.LocalDate
import java.time.ZoneId
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import kotlin.math.abs
import kotlin.math.acos
import kotlin.math.asin
import kotlin.math.atan
import kotlin.math.cos
import kotlin.math.floor
import kotlin.math.roundToInt
import kotlin.math.sin
import kotlin.math.tan

object NativePrayerEngine {
    private val timeFormatter = DateTimeFormatter.ofPattern("HH:mm")

    fun calculate(date: LocalDate, latitude: Double, longitude: Double): Map<String, String> {
        val solar = solarCoordinates(date)
        val zone = ZoneId.systemDefault()
        val timezoneHours = date.atStartOfDay(zone).offset.totalSeconds / 3600.0
        val solarNoon = 12 + timezoneHours - longitude / 15 - solar.equationOfTime / 60
        val sunriseAngle = hourAngle(latitude, solar.declination, -0.8333)
        val fajrAngle = hourAngle(latitude, solar.declination, -18.0)
        val ishaAngle = hourAngle(latitude, solar.declination, -17.0)
        val asrAltitude = toDegrees(
            atan(1.0 / (1.0 + tan(toRadians(abs(latitude - solar.declination)))))
        )
        val asrAngle = hourAngle(latitude, solar.declination, asrAltitude)

        val sunrise = sunriseAngle?.let { atMinutes(date, solarNoon * 60 - it * 4) }
            ?: atMinutes(date, solarNoon * 60 - 360)
        val sunset = sunriseAngle?.let { atMinutes(date, solarNoon * 60 + it * 4) }
            ?: atMinutes(date, solarNoon * 60 + 360)
        val fajr = fajrAngle?.let { atMinutes(date, solarNoon * 60 - it * 4) }
            ?: highLatitude(sunrise, sunset, true)
        val isha = ishaAngle?.let { atMinutes(date, solarNoon * 60 + it * 4) }
            ?: highLatitude(sunrise, sunset, false)
        val asr = asrAngle?.let { atMinutes(date, solarNoon * 60 + it * 4) }
            ?: atMinutes(date, solarNoon * 60 + 240)
        val dhuhr = atMinutes(date, solarNoon * 60)
        val maghrib = sunset.plusMinutes(2)

        return linkedMapOf(
            "Fajr" to timeFormatter.format(fajr.localTime),
            "Dhuhr" to timeFormatter.format(dhuhr.localTime),
            "Asr" to timeFormatter.format(asr.localTime),
            "Maghrib" to timeFormatter.format(maghrib.localTime),
            "Isha" to timeFormatter.format(isha.localTime),
        )
    }

    private fun solarCoordinates(date: LocalDate): SolarCoordinates {
        val julianDay = julianDay(date.year, date.monthValue, date.dayOfMonth)
        val century = (julianDay - 2451545.0) / 36525.0
        val l0 = normalize(280.46646 + 36000.76983 * century)
        val anomaly = normalize(357.52911 + 35999.05029 * century)
        val anomalyRadians = toRadians(anomaly)
        val center = (1.914602 - 0.004817 * century) * sin(anomalyRadians) +
            (0.019993 - 0.000101 * century) * sin(2 * anomalyRadians) +
            0.000289 * sin(3 * anomalyRadians)
        val trueLongitude = l0 + center
        val obliquity = 23.439291 - 0.0130042 * century
        val declination = toDegrees(
            asin(sin(toRadians(obliquity)) * sin(toRadians(trueLongitude)))
        )
        val eccentricity = 0.016708634 - 0.000042037 * century
        val y = tan(toRadians(obliquity / 2))
        val ySquared = y * y
        val l0Radians = toRadians(l0)
        val equationOfTime = 4 * toDegrees(
            ySquared * sin(2 * l0Radians) -
                2 * eccentricity * sin(anomalyRadians) +
                4 * eccentricity * ySquared * sin(anomalyRadians) * cos(2 * l0Radians) -
                0.5 * ySquared * ySquared * sin(4 * l0Radians) -
                1.25 * eccentricity * eccentricity * sin(2 * anomalyRadians)
        )
        return SolarCoordinates(declination, equationOfTime)
    }

    private fun hourAngle(latitude: Double, declination: Double, altitude: Double): Double? {
        val denominator = cos(toRadians(latitude)) * cos(toRadians(declination))
        if (abs(denominator) < 1e-10) return null
        val cosine = (sin(toRadians(altitude)) -
            sin(toRadians(latitude)) * sin(toRadians(declination))) / denominator
        if (cosine < -1 || cosine > 1) return null
        return toDegrees(acos(cosine))
    }

    private fun highLatitude(sunrise: DateTimeMinutes, sunset: DateTimeMinutes, beforeSunrise: Boolean): DateTimeMinutes {
        val night = if (sunrise.instant.isBefore(sunset.instant)) {
            sunrise.instant.plusSeconds(24 * 60 * 60).epochSecond - sunset.instant.epochSecond
        } else {
            sunrise.instant.epochSecond - sunset.instant.epochSecond
        } / 60
        val part = night / 7
        return if (beforeSunrise) sunrise.plusMinutes(-part.toInt())
        else sunset.plusMinutes(part.toInt())
    }

    private fun atMinutes(date: LocalDate, minutes: Double): DateTimeMinutes {
        val zone = ZoneId.systemDefault()
        return DateTimeMinutes(date.atStartOfDay(zone).plusMinutes(minutes.roundToInt().toLong()))
    }

    private fun julianDay(year: Int, month: Int, day: Int): Double {
        var y = year
        var m = month
        if (m <= 2) {
            y -= 1
            m += 12
        }
        val a = floor(y / 100.0)
        val b = 2 - a + floor(a / 4.0)
        return floor(365.25 * (y + 4716)) + floor(30.6001 * (m + 1)) + day + b - 1524.5
    }

    private fun normalize(value: Double): Double = (value % 360 + 360) % 360
    private fun toRadians(value: Double): Double = Math.toRadians(value)
    private fun toDegrees(value: Double): Double = Math.toDegrees(value)

    private data class SolarCoordinates(val declination: Double, val equationOfTime: Double)

    private class DateTimeMinutes(private val dateTime: ZonedDateTime) {
        val epochMinutes get() = dateTime.toEpochSecond() / 60
        val instant get() = dateTime.toInstant()
        val localTime get() = dateTime.toLocalTime()
        fun plusMinutes(minutes: Int) = DateTimeMinutes(dateTime.plusMinutes(minutes.toLong()))
    }
}
