import 'dart:async';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/location_data.dart';
import 'offline_prayer_engine.dart';
import 'widget_service.dart';

class BackgroundService {
  static const _taskName = 'dailyPrayerUpdate';
  static const _lastRefreshKey = 'background_last_refresh_epoch';
  static const _engine = OfflinePrayerEngine();

  static List<DateTime> getNextSevenDayWindow(
    DateTime now, {
    required DateTime maghribTime,
  }) {
    final startDate = now.isBefore(maghribTime)
        ? DateTime(now.year, now.month, now.day)
        : DateTime(now.year, now.month, now.day).add(const Duration(days: 1));

    return List.generate(7, (index) => startDate.add(Duration(days: index)));
  }

  static Future<void> register() async {
    try {
      const channel = MethodChannel('com.salahtime.maniyars/background');
      await channel.invokeMethod('registerTask');
    } catch (_) {
      // Native scheduling is handled by Android when the app starts.
    }
  }

  @pragma('vm:entry-point')
  static Future<bool> executeTask(
    String taskName,
    Map<String, dynamic>? inputData,
  ) async {
    if (taskName != _taskName) return true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final latitude = prefs.getDouble('bg_lat');
      final longitude = prefs.getDouble('bg_lng');
      if (latitude == null || longitude == null) return true;

      final location = LocationData(
        latitude: latitude,
        longitude: longitude,
        city: 'Current location',
        country: '',
      );
      final today = DateTime.now();
      final todaySchedule = _engine.calculate(date: today, location: location);
      final tomorrowSchedule = _engine.calculate(
        date: today.add(const Duration(days: 1)),
        location: location,
      );
      await WidgetService.updateWidget(todaySchedule, tomorrowSchedule);
      await prefs.setInt(
        _lastRefreshKey,
        DateTime.now().millisecondsSinceEpoch,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> refreshIfStale({
    Duration maxAge = const Duration(hours: 1),
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final lastRefreshAt = prefs.getInt(_lastRefreshKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (now - lastRefreshAt < maxAge.inMilliseconds) return true;
    return executeTask(_taskName, null);
  }
}
