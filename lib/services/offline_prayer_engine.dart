import 'dart:math' as math;

import '../models/location_data.dart';
import '../models/prayer_schedule.dart';
import '../models/prayer_time.dart';

class OfflinePrayerEngine {
  const OfflinePrayerEngine({
    this.fajrAngle = 18,
    this.ishaAngle = 17,
    this.asrMultiplier = 1,
  });

  final double fajrAngle;
  final double ishaAngle;
  final int asrMultiplier;

  PrayerSchedule calculate({
    required DateTime date,
    required LocationData location,
  }) {
    final day = DateTime(date.year, date.month, date.day);
    final solar = _solarCoordinates(day);
    final latitude = location.latitude;
    final longitude = location.longitude;
    final timezoneHours = day.timeZoneOffset.inMinutes / 60;

    final solarNoon =
        12 + timezoneHours - longitude / 15 - solar.equationOfTime / 60;
    final sunriseAngle = _hourAngle(latitude, solar.declination, -0.8333);
    final fajrHourAngle = _hourAngle(latitude, solar.declination, -fajrAngle);
    final ishaHourAngle = _hourAngle(latitude, solar.declination, -ishaAngle);
    final asrAltitude = _toDegrees(
      _atan(
        1 /
            (asrMultiplier +
                _tan(_toRadians((latitude - solar.declination).abs()))),
      ),
    );
    final asrHourAngle = _hourAngle(latitude, solar.declination, asrAltitude);

    final sunrise = sunriseAngle == null
        ? _atLocalMinutes(day, solarNoon * 60 - 6 * 60)
        : _atLocalMinutes(day, solarNoon * 60 - sunriseAngle * 4);
    final sunset = sunriseAngle == null
        ? _atLocalMinutes(day, solarNoon * 60 + 6 * 60)
        : _atLocalMinutes(day, solarNoon * 60 + sunriseAngle * 4);

    final fajr = fajrHourAngle == null
        ? _highLatitudeTime(day, sunrise, sunset, beforeSunrise: true)
        : _atLocalMinutes(day, solarNoon * 60 - fajrHourAngle * 4);
    final isha = ishaHourAngle == null
        ? _highLatitudeTime(day, sunrise, sunset, beforeSunrise: false)
        : _atLocalMinutes(day, solarNoon * 60 + ishaHourAngle * 4);
    final asr = asrHourAngle == null
        ? _atLocalMinutes(day, solarNoon * 60 + 4 * 60)
        : _atLocalMinutes(day, solarNoon * 60 + asrHourAngle * 4);

    // Maghrib is sunset plus two minutes. Adding to the full [sunset] instant
    // (rather than resigning its time-of-day to midnight) keeps the correct
    // calendar day when sunset falls after midnight, so the five prayers always
    // stay in canonical order: Fajr, Dhuhr, Asr, Maghrib, Isha.
    final maghrib = sunset.add(const Duration(minutes: 2));

    final prayers = [
      PrayerTime(name: 'Fajr', time: fajr),
      PrayerTime(name: 'Dhuhr', time: _atLocalMinutes(day, solarNoon * 60)),
      PrayerTime(name: 'Asr', time: asr),
      PrayerTime(name: 'Maghrib', time: maghrib),
      PrayerTime(name: 'Isha', time: isha),
    ];

    return PrayerSchedule(
      date: day,
      prayers: prayers,
      location: location.displayName,
      latitude: location.latitude,
      longitude: location.longitude,
    ).withCurrentPrayer(DateTime.now());
  }

  _SolarCoordinates _solarCoordinates(DateTime date) {
    final julianDay = _julianDay(date.year, date.month, date.day);
    final century = (julianDay - 2451545.0) / 36525;
    final l0 = _normalizeDegrees(280.46646 + 36000.76983 * century);
    final meanAnomaly = _normalizeDegrees(357.52911 + 35999.05029 * century);
    final meanAnomalyRadians = _toRadians(meanAnomaly);
    final center =
        (1.914602 - 0.004817 * century) * _sin(meanAnomalyRadians) +
        (0.019993 - 0.000101 * century) * _sin(2 * meanAnomalyRadians) +
        0.000289 * _sin(3 * meanAnomalyRadians);
    final trueLongitude = l0 + center;
    final obliquity = 23.439291 - 0.0130042 * century;
    final declination = _toDegrees(
      _asin(_sin(_toRadians(obliquity)) * _sin(_toRadians(trueLongitude))),
    );
    final eccentricity = 0.016708634 - 0.000042037 * century;
    final y = _tan(_toRadians(obliquity / 2));
    final ySquared = y * y;
    final l0Radians = _toRadians(l0);
    final equationOfTime =
        4 *
        _toDegrees(
          ySquared * _sin(2 * l0Radians) -
              2 * eccentricity * _sin(meanAnomalyRadians) +
              4 *
                  eccentricity *
                  ySquared *
                  _sin(meanAnomalyRadians) *
                  _cos(2 * l0Radians) -
              0.5 * ySquared * ySquared * _sin(4 * l0Radians) -
              1.25 * eccentricity * eccentricity * _sin(2 * meanAnomalyRadians),
        );
    return _SolarCoordinates(declination, equationOfTime);
  }

  double? _hourAngle(double latitude, double declination, double altitude) {
    final denominator =
        _cos(_toRadians(latitude)) * _cos(_toRadians(declination));
    if (denominator.abs() < 1e-10) return null;
    final cosine =
        (_sin(_toRadians(altitude)) -
            _sin(_toRadians(latitude)) * _sin(_toRadians(declination))) /
        denominator;
    if (cosine < -1 || cosine > 1) return null;
    return _toDegrees(_acos(cosine));
  }

  DateTime _highLatitudeTime(
    DateTime date,
    DateTime sunrise,
    DateTime sunset, {
    required bool beforeSunrise,
  }) {
    final nightLength = sunrise.difference(sunset).isNegative
        ? sunrise.add(const Duration(days: 1)).difference(sunset)
        : sunrise.difference(sunset);
    final part = Duration(milliseconds: nightLength.inMilliseconds ~/ 7);
    return beforeSunrise ? sunrise.subtract(part) : sunset.add(part);
  }

  DateTime _atLocalMinutes(DateTime date, double minutes) {
    final wholeMinutes = minutes.round();
    return DateTime(
      date.year,
      date.month,
      date.day,
    ).add(Duration(minutes: wholeMinutes));
  }

  double _julianDay(int year, int month, int day) {
    var adjustedYear = year;
    var adjustedMonth = month;
    if (adjustedMonth <= 2) {
      adjustedYear -= 1;
      adjustedMonth += 12;
    }
    final a = adjustedYear ~/ 100;
    final b = 2 - a + a ~/ 4;
    return (365.25 * (adjustedYear + 4716)).floor() +
        (30.6001 * (adjustedMonth + 1)).floor() +
        day +
        b -
        1524.5;
  }

  double _normalizeDegrees(double value) => (value % 360 + 360) % 360;
  double _toRadians(double value) => value * 3.141592653589793 / 180;
  double _toDegrees(double value) => value * 180 / 3.141592653589793;
  double _sin(double value) => _trig(value, 'sin');
  double _cos(double value) => _trig(value, 'cos');
  double _tan(double value) => _trig(value, 'tan');
  double _asin(double value) => _inverseTrig(value, 'asin');
  double _acos(double value) => _inverseTrig(value, 'acos');
  double _atan(double value) => _inverseTrig(value, 'atan');

  double _trig(double value, String operation) {
    // dart:math is imported lazily through these wrappers to keep the public API small.
    return switch (operation) {
      'sin' => math.sin(value),
      'cos' => math.cos(value),
      _ => math.tan(value),
    };
  }

  double _inverseTrig(double value, String operation) {
    return switch (operation) {
      'asin' => math.asin(value),
      'acos' => math.acos(value),
      _ => math.atan(value),
    };
  }
}

class _SolarCoordinates {
  const _SolarCoordinates(this.declination, this.equationOfTime);
  final double declination;
  final double equationOfTime;
}
