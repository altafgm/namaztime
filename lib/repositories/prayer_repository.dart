import '../models/prayer_schedule.dart';
import '../models/location_data.dart';
import '../services/aladhan_api_service.dart';
import '../services/local_storage_service.dart';

class PrayerRepository {
  final AladhanApiService _apiService;
  final LocalStorageService _localStorage;

  static const int cacheRetentionDays = 7;

  PrayerRepository(this._apiService, this._localStorage);

  Future<PrayerSchedule> getPrayerSchedule({
    required LocationData location,
    required DateTime date,
  }) async {
    final cached = await _localStorage.getPrayerSchedule(
      date,
      location.latitude,
      location.longitude,
    );
    if (cached != null) return cached;

    try {
      final schedule = await _apiService.getPrayerTimes(
        location: location,
        date: date,
      );
      await _localStorage.savePrayerSchedule(schedule);
      return schedule;
    } catch (error) {
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }

  Future<List<PrayerSchedule>> getPrayerSchedules({
    required LocationData location,
    required List<DateTime> dates,
  }) async {
    // Check cache for each date
    final cachedSchedules = <PrayerSchedule>[];
    final datesToFetch = <DateTime>[];
    
    for (final date in dates) {
      final cached = await _localStorage.getPrayerSchedule(
        date,
        location.latitude,
        location.longitude,
      );
      if (cached != null) {
        cachedSchedules.add(cached);
      } else {
        datesToFetch.add(date);
      }
    }
    
    // If all dates are cached, return them
    if (datesToFetch.isEmpty) {
      return cachedSchedules;
    }
    
    try {
      // Fetch missing dates in parallel
      final fetchedSchedules = await _apiService.getPrayerTimesForDates(
        location: location,
        dates: datesToFetch,
      );
      
      // Save fetched schedules to cache
      for (final schedule in fetchedSchedules) {
        await _localStorage.savePrayerSchedule(schedule);
      }
      
      // Combine cached and fetched schedules
      final allSchedules = [...cachedSchedules, ...fetchedSchedules];
      
      // Sort by date to maintain order
      allSchedules.sort((a, b) => a.date.compareTo(b.date));
      
      return allSchedules;
    } catch (error) {
      // If we have any cached schedules, return them
      if (cachedSchedules.isNotEmpty) {
        return cachedSchedules;
      }
      rethrow;
    }
  }

  Future<void> clearAllCache() async {
    await _localStorage.clearAllSchedules();
  }

  Future<void> clearOldCache() async {
    await _localStorage.clearOldSchedules();
  }
}