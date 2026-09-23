import 'package:flutter_test/flutter_test.dart';

import 'package:salah_time/utils/qibla_calculator.dart';

void main() {
  group('QiblaCalculator.bearingToKaaba', () {
    test('Istanbul to the Kaaba is about 152° (well-known reference)', () {
      final bearing = QiblaCalculator.bearingToKaaba(41.0082, 28.9784);
      expect(bearing, closeTo(151.6, 0.5));
    });

    test('New York to the Kaaba is about 58°', () {
      final bearing = QiblaCalculator.bearingToKaaba(40.7128, -74.0060);
      expect(bearing, closeTo(58.5, 0.5));
    });

    test('standing at the Kaaba yields 0°', () {
      final bearing = QiblaCalculator.bearingToKaaba(
        QiblaCalculator.kaabaLatitude,
        QiblaCalculator.kaabaLongitude,
      );
      expect(bearing, 0);
    });

    test('bearing stays within [0, 360)', () {
      for (final lat in [0.0, 10.0, 41.0, -33.9, 90.0]) {
        for (final lng in [0.0, 28.9, 100.0, -74.0, 180.0]) {
          final bearing = QiblaCalculator.bearingToKaaba(lat, lng);
          expect(bearing, greaterThanOrEqualTo(0));
          expect(bearing, lessThan(360));
        }
      }
    });

    test('matches the Aladhan Qibla API for cities around the world', () {
      // Reference values fetched from https://api.aladhan.com/v1/qibla/{}/{},
      // the same service the app uses for prayer times.
      const references = <String, List<double>>{
        // lat, lng, API direction
        'Istanbul': [41.0082, 28.9784, 151.62],
        'London': [51.5074, -0.1278, 118.99],
        'New York': [40.7128, -74.006, 58.48],
        'Los Angeles': [34.0522, -118.2437, 23.86],
        'Moscow': [55.7558, 37.6173, 176.36],
        'Delhi': [28.6139, 77.209, 266.60],
        'Islamabad': [33.6844, 73.0479, 255.91],
        'Dubai': [25.2048, 55.2708, 258.23],
        'Tokyo': [35.6762, 139.6503, 293.00],
        'Jakarta': [-6.2088, 106.8456, 295.15],
        'Sydney': [-33.8688, 151.2093, 277.50],
        'Cape Town': [-33.9249, 18.4241, 23.35],
        'Sao Paulo': [-23.5505, -46.6333, 68.94],
        'Mexico City': [19.4326, -99.1332, 46.60],
        'Anchorage': [61.2181, -149.9003, 350.88],
        'Reykjavik': [64.1466, -21.9426, 106.12],
        'Auckland': [-36.8485, 174.7633, 261.20],
      };
      references.forEach((city, v) {
        final bearing = QiblaCalculator.bearingToKaaba(v[0], v[1]);
        expect(
          bearing,
          closeTo(v[2], 0.1),
          reason: 'Qibla bearing mismatch for $city',
        );
      });
    });
  });

  group('QiblaCalculator.compassPoint', () {
    test('cardinal and intercardinal points', () {
      expect(QiblaCalculator.compassPoint(0), 'N');
      expect(QiblaCalculator.compassPoint(45), 'NE');
      expect(QiblaCalculator.compassPoint(90), 'E');
      expect(QiblaCalculator.compassPoint(180), 'S');
      expect(QiblaCalculator.compassPoint(270), 'W');
      expect(QiblaCalculator.compassPoint(158), 'SSE');
    });

    test('wraps beyond 360', () {
      expect(QiblaCalculator.compassPoint(360), 'N');
      expect(QiblaCalculator.compassPoint(350), 'N');
    });
  });

  group('QiblaCalculator.signedDelta', () {
    test('picks the shortest turn, both directions', () {
      expect(QiblaCalculator.signedDelta(0, 90), 90);
      expect(QiblaCalculator.signedDelta(90, 0), -90);
      expect(QiblaCalculator.signedDelta(355, 10), 15);
      expect(QiblaCalculator.signedDelta(10, 355), -15);
    });
  });
}