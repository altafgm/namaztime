import '../models/location_data.dart';
import '../models/prayer_schedule.dart';
import 'offline_prayer_engine.dart';

/// Compatibility facade for the repository's existing service dependency.
/// Prayer times are calculated locally; no network request is made.
class AladhanApiService {
  const AladhanApiService({this.engine = const OfflinePrayerEngine()});

  final OfflinePrayerEngine engine;

  Future<PrayerSchedule> getPrayerTimes({
    required LocationData location,
    required DateTime date,
  }) async {
    return engine.calculate(date: date, location: location);
  }

  Future<List<PrayerSchedule>> getPrayerTimesForDates({
    required LocationData location,
    required List<DateTime> dates,
  }) async {
    final schedules = [
      for (final date in dates)
        engine.calculate(date: date, location: location),
    ];
    schedules.sort((a, b) => a.date.compareTo(b.date));
    return schedules;
  }
}
