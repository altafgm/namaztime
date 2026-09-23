import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/prayer_schedule.dart';
import '../models/location_data.dart';
import '../repositories/prayer_repository.dart';
import '../services/notification_service.dart';
import '../services/widget_service.dart';

class PrayerProvider with ChangeNotifier {
  final PrayerRepository _repository;
  final NotificationService _notificationService;

  PrayerProvider(this._repository, this._notificationService);

  PrayerSchedule? _currentSchedule;
  PrayerSchedule? _tomorrowSchedule;
  LocationData? _currentLocation;
  bool _isLoading = false;
  String? _error;
  int _loadToken = 0;

  PrayerSchedule? get currentSchedule => _currentSchedule;
  PrayerSchedule? get tomorrowSchedule => _tomorrowSchedule;
  LocationData? get currentLocation => _currentLocation;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadPrayerSchedule({
    required LocationData location,
    required DateTime date,
    bool notificationsEnabled = true,
  }) async {
    // Each call supersedes the previous one. Location loads can overlap (the
    // cached startup load, the live GPS load, a manual refresh), and without
    // this guard a slower earlier request could finish last and replace the UI
    // with stale data — e.g. the hardcoded default city after GPS had already
    // resolved the real location.
    final token = ++_loadToken;
    _isLoading = true;
    _error = null;
    _currentLocation = location;
    notifyListeners();

    try {
      // Load today first so the home screen can paint immediately, then
      // fetch tomorrow's schedule in the background (the widget also uses it).
      final tomorrow = date.add(const Duration(days: 1));

      final today =
          await _repository.getPrayerSchedule(location: location, date: date);
      if (token != _loadToken) return;
      _currentSchedule = today;

      // Paint today's cards right away and refresh the widget; don't wait for
      // tomorrow.
      _isLoading = false;
      notifyListeners();
      if (_currentSchedule != null) {
        await WidgetService.updateWidget(_currentSchedule!, _tomorrowSchedule);
      }
      if (token != _loadToken) return;

      // Fetch tomorrow concurrently in the background. Notifications are owned
      // by the native worker; the plugin init only requests permission and can
      // therefore also be done without blocking the UI.
      if (notificationsEnabled) {
        unawaited(_notificationService.init().catchError((_) {}));
      }
      final tomorrowSchedule = await _repository.getPrayerSchedule(
        location: location,
        date: tomorrow,
      );
      if (token != _loadToken) return;
      _tomorrowSchedule = tomorrowSchedule;
      await WidgetService.updateWidget(_currentSchedule!, _tomorrowSchedule);
    } catch (e) {
      if (token == _loadToken) _error = e.toString();
    } finally {
      if (token == _loadToken) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void refreshCurrentPrayer() {
    if (_currentSchedule == null) return;
    _currentSchedule = _currentSchedule!.withCurrentPrayer(DateTime.now());
    notifyListeners();
  }

  Future<void> clearCache() async {
    await _repository.clearAllCache();
  }

  Future<void> refreshSchedule({bool notificationsEnabled = true}) async {
    if (_currentLocation != null && _currentSchedule != null) {
      await loadPrayerSchedule(
        location: _currentLocation!,
        date: _currentSchedule!.date,
        notificationsEnabled: notificationsEnabled,
      );
    }
  }
}
