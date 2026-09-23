import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:salah_time/models/location_data.dart';
import 'package:salah_time/models/prayer_schedule.dart';
import 'package:salah_time/providers/prayer_provider.dart';
import 'package:salah_time/repositories/prayer_repository.dart';
import 'package:salah_time/services/aladhan_api_service.dart';
import 'package:salah_time/services/local_storage_service.dart';
import 'package:salah_time/services/notification_service.dart';
import 'package:salah_time/services/offline_prayer_engine.dart';

/// Returns a schedule for the requested location after a per-city delay, so a
/// test can make an earlier request finish last.
class _DelayedPrayerRepository extends PrayerRepository {
  _DelayedPrayerRepository()
      : super(const AladhanApiService(), LocalStorageService());

  static const _delays = {
    'Slowville': Duration(milliseconds: 50),
    'Fastville': Duration(milliseconds: 1),
  };

  @override
  Future<PrayerSchedule> getPrayerSchedule({
    required LocationData location,
    required DateTime date,
  }) async {
    await Future<void>.delayed(_delays[location.city] ?? Duration.zero);
    return const OfflinePrayerEngine().calculate(date: date, location: location);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a superseded location load cannot overwrite a newer one', () async {
    final provider = PrayerProvider(_DelayedPrayerRepository(), NotificationService());

    // Start the slow (default) load first, then the fast (real) load. Without
    // request ordering the slow one finishes last and replaces the real city.
    final slow = provider.loadPrayerSchedule(
      location: const LocationData(
        latitude: 41.0082,
        longitude: 28.9784,
        city: 'Slowville',
        country: 'Defaultland',
      ),
      date: DateTime(2026, 9, 21),
      notificationsEnabled: false,
    );
    final fast = provider.loadPrayerSchedule(
      location: const LocationData(
        latitude: 12.7361,
        longitude: 75.8146,
        city: 'Fastville',
        country: 'Realplace',
      ),
      date: DateTime(2026, 9, 21),
      notificationsEnabled: false,
    );
    await Future.wait([slow, fast]);

    expect(provider.currentLocation?.city, 'Fastville');
    expect(provider.currentSchedule?.location, 'Fastville, Realplace');
    expect(provider.isLoading, isFalse);
  });
}
