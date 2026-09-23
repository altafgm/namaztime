import 'dart:math' as math;

/// Pure math for the Qibla compass: bearing from a given coordinate to the
/// Kaaba in Makkah, plus human readable compass-point names.
class QiblaCalculator {
  static const double kaabaLatitude = 21.4225;
  static const double kaabaLongitude = 39.8262;

  static const List<String> _points16 = [
    'N',
    'NNE',
    'NE',
    'ENE',
    'E',
    'ESE',
    'SE',
    'SSE',
    'S',
    'SSW',
    'SW',
    'WSW',
    'W',
    'WNW',
    'NW',
    'NNW',
  ];

  /// Bearing (0–360°, clockwise from true North) from [latitude]/[longitude]
  /// to the Kaaba, using the great-circle initial course.
  static double bearingToKaaba(double latitude, double longitude) {
    final lat1 = _toRad(latitude);
    final lat2 = _toRad(kaabaLatitude);
    final dLng = _toRad(kaabaLongitude - longitude);

    final x = math.sin(dLng) * math.cos(lat2);
    final y = (math.cos(lat1) * math.sin(lat2)) -
        (math.sin(lat1) * math.cos(lat2) * math.cos(dLng));

    final degrees = math.atan2(x, y) * 180 / math.pi;
    return (degrees + 360) % 360;
  }

  /// Shortest signed turn from [current] to [target] bearings in degrees,
  /// normalized to (-180, 180]. Used to pick the shortest needle animation.
  static double signedDelta(double current, double target) {
    final delta = (target - current + 540) % 360 - 180;
    return delta;
  }

  /// Conventional 16-point name for a bearing, e.g. 158° → 'SSE'.
  static String compassPoint(double bearing) {
    final index = ((bearing % 360) / 22.5).round() % 16;
    return _points16[index];
  }

  /// Position relative to Mecca, e.g. 158° → 'South South East of the Kaaba'.
  static String directionOfKaaba(double bearing) {
    return '${compassPoint(bearing)} of the Kaaba';
  }

  static double _toRad(double degrees) => degrees * math.pi / 180;
}