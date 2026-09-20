import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/prayer_schedule.dart';

class LocalStorageService {
  static const _schedulePrefix = 'schedule-';
  SharedPreferences? _preferences;

  Future<void> init() async {
    _preferences = await SharedPreferences.getInstance();
  }

  Future<void> savePrayerSchedule(PrayerSchedule schedule) async {
    final key = _getKey(schedule.date, schedule.latitude, schedule.longitude);
    final jsonValue = jsonEncode(schedule.toJson());
    await _preferences?.setString(key, jsonValue);
  }

  Future<PrayerSchedule?> getPrayerSchedule(DateTime date, double latitude, double longitude) async {
    final key = _getKey(date, latitude, longitude);
    final jsonString = _preferences?.getString(key);
    if (jsonString == null) return null;
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      if (!data.containsKey('latitude') || !data.containsKey('longitude')) {
        await _preferences?.remove(key);
        return null;
      }
      return PrayerSchedule.fromJson(data).withCurrentPrayer(DateTime.now());
    } catch (_) {
      await _preferences?.remove(key);
      return null;
    }
  }

  Future<void> clearAllSchedules() async {
    final keys = _preferences?.getKeys() ?? <String>{};
    for (final key in keys) {
      if (key.startsWith(_schedulePrefix)) {
        await _preferences?.remove(key);
      }
    }
  }

  Future<void> clearOldSchedules({int retentionDays = 7}) async {
    final now = DateTime.now();
    final keys = _preferences?.getKeys() ?? <String>{};
    for (final key in keys) {
      if (!key.startsWith(_schedulePrefix)) continue;
      final date = _parseKey(key);
      if (date.isBefore(now.subtract(Duration(days: retentionDays)))) {
        await _preferences?.remove(key);
      }
    }
  }

  // Round to 2 decimal places (~1km precision) to avoid cache misses from minor GPS drift
  String _getKey(DateTime date, double lat, double lng) {
    final latR = lat.toStringAsFixed(2);
    final lngR = lng.toStringAsFixed(2);
    return '$_schedulePrefix${date.year}-${date.month}-${date.day}-$latR-$lngR';
  }

  DateTime _parseKey(String key) {
    final parts = key.replaceFirst(_schedulePrefix, '').split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }
}