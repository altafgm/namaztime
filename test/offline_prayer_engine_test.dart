import 'package:flutter_test/flutter_test.dart';
import 'package:salah_time/models/location_data.dart';
import 'package:salah_time/services/offline_prayer_engine.dart';

void main() {
  const location = LocationData(
    latitude: 20.5937,
    longitude: 78.9629,
    city: 'Nagpur',
    country: 'India',
  );
  const engine = OfflinePrayerEngine();

  test(
    'calculates five ordered prayers from coordinates without a network',
    () {
      final schedule = engine.calculate(
        date: DateTime(2026, 9, 19),
        location: location,
      );

      expect(schedule.prayers.map((prayer) => prayer.name).toList(), [
        'Fajr',
        'Dhuhr',
        'Asr',
        'Maghrib',
        'Isha',
      ]);
      expect(
        schedule.prayers.every((prayer) => prayer.time.year == 2026),
        isTrue,
      );
      for (var i = 1; i < schedule.prayers.length; i++) {
        expect(
          schedule.prayers[i].time.isAfter(schedule.prayers[i - 1].time),
          isTrue,
        );
      }
    },
  );

  test('calculates a double-digit noon time without formatting artifacts', () {
    final schedule = engine.calculate(
      date: DateTime(2026, 9, 19),
      location: location,
    );
    final dhuhr = schedule.prayers.firstWhere(
      (prayer) => prayer.name == 'Dhuhr',
    );

    expect(dhuhr.time.hour, inInclusiveRange(11, 14));
    expect(dhuhr.time.minute, inInclusiveRange(0, 59));
  });

  test('supports Hanafi Asr shadow multiplier', () {
    final standard = const OfflinePrayerEngine(
      asrMultiplier: 1,
    ).calculate(date: DateTime(2026, 9, 19), location: location);
    final hanafi = const OfflinePrayerEngine(
      asrMultiplier: 2,
    ).calculate(date: DateTime(2026, 9, 19), location: location);

    final standardAsr = standard.prayers.firstWhere(
      (prayer) => prayer.name == 'Asr',
    );
    final hanafiAsr = hanafi.prayers.firstWhere(
      (prayer) => prayer.name == 'Asr',
    );
    expect(hanafiAsr.time.isAfter(standardAsr.time), isTrue);
  });

  test('calculates future leap-day schedules from the requested date', () {
    final date = DateTime(2032, 2, 29);
    final schedule = engine.calculate(date: date, location: location);

    expect(schedule.date, date);
    expect(
      schedule.prayers.every(
        (prayer) =>
            prayer.time.year == 2032 &&
            prayer.time.month == 2 &&
            prayer.time.day == 29,
      ),
      isTrue,
    );
    for (var i = 1; i < schedule.prayers.length; i++) {
      expect(
        schedule.prayers[i].time.isAfter(schedule.prayers[i - 1].time),
        isTrue,
      );
    }
  });

  test('calculates a future year boundary independently of today', () {
    final schedule = engine.calculate(
      date: DateTime(2040, 1, 1),
      location: location,
    );

    expect(schedule.date, DateTime(2040, 1, 1));
    expect(
      schedule.prayers.first.time.isBefore(schedule.prayers.last.time),
      isTrue,
    );
    expect(schedule.prayers.first.time.year, 2040);
  });
}
