import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/prayer_schedule.dart';

class WidgetService {
  static const _channel = MethodChannel('com.salahtime.maniyars/widget');
  static const _widgetPromptKey = 'widget_prompt_shown';

  /// Whether the one-time "add widget to home screen" prompt should be shown.
  /// Returns true only before the user has been asked, i.e. on a fresh install.
  static Future<bool> shouldShowAddWidgetPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_widgetPromptKey) ?? false);
  }

  /// Records that the add-widget prompt was shown (once per install).
  static Future<void> markWidgetPromptShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_widgetPromptKey, true);
  }

  /// Asks the launcher to pin the Salah Time widget (Android 8.0+ only).
  /// Returns true if the launcher accepted the pin request.
  static Future<bool> requestAddWidget() async {
    try {
      final pinned = await _channel.invokeMethod<bool>('requestAddWidget');
      return pinned ?? false;
    } catch (_) {
      // Widget pinning is Android-only; other platforms no-op.
      return false;
    }
  }

  static Future<void> updateWidget(
    PrayerSchedule todaySchedule,
    PrayerSchedule? tomorrowSchedule,
  ) async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();

    String lastName = '';
    String lastTime = '';
    String nextName = '';
    String nextTime = '';

    // Check today's prayers first
    for (final prayer in todaySchedule.prayers) {
      if (prayer.time.isBefore(now)) {
        lastName = prayer.name;
        lastTime = _formatTime(prayer.time);
      } else if (nextName.isEmpty) {
        nextName = prayer.name;
        nextTime = _formatTime(prayer.time);
      }
    }

    // If no next prayer found in today's schedule, check tomorrow's schedule
    if (nextName.isEmpty && tomorrowSchedule != null) {
      // Get the first prayer of tomorrow (Fajr)
      if (tomorrowSchedule.prayers.isNotEmpty) {
        final firstPrayerTomorrow = tomorrowSchedule.prayers.first;
        nextName = firstPrayerTomorrow.name;
        nextTime = _formatTime(firstPrayerTomorrow.time);
      }
    }

    // Flutter shared_preferences adds 'flutter.' prefix automatically
    // So native reads 'flutter.widget_last_prayer_name' etc.
    await prefs.setString(
      'widget_last_prayer_name',
      lastName.isEmpty ? '—' : lastName,
    );
    await prefs.setString(
      'widget_last_prayer_time',
      lastTime.isEmpty ? '--:--' : lastTime,
    );
    await prefs.setString(
      'widget_next_prayer_name',
      nextName.isEmpty ? '—' : nextName,
    );
    await prefs.setString(
      'widget_next_prayer_time',
      nextTime.isEmpty ? '--:--' : nextTime,
    );
    await prefs.setString(
      'widget_schedule',
      jsonEncode({
        'today': _formatDate(todaySchedule.date),
        'todayTimes': _timesFor(todaySchedule),
        if (tomorrowSchedule != null) ...{
          'tomorrow': _formatDate(tomorrowSchedule.date),
          'tomorrowTimes': _timesFor(tomorrowSchedule),
        },
      }),
    );

    try {
      await _channel.invokeMethod('updateWidget');
    } catch (_) {}
  }

  static Map<String, String> _timesFor(PrayerSchedule schedule) {
    return {
      for (final prayer in schedule.prayers)
        prayer.name:
            '${prayer.time.hour.toString().padLeft(2, '0')}:${prayer.time.minute.toString().padLeft(2, '0')}',
    };
  }

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }

  /// Locale time ("7:22 PM") as the widget stores and renders it. Some CLDR
  /// versions separate the AM/PM marker with a narrow no-break space (U+202F) or
  /// a non-breaking space (U+00A0); those are normalised to a plain space so the
  /// value written here matches the one the native code writes and the widget
  /// splits both the same way (see WidgetTimeText on the Android side).
  static String _formatTime(DateTime time) {
    return DateFormat.jm()
        .format(time)
        .replaceAll('\u202F', ' ')
        .replaceAll('\u00A0', ' ');
  }
}
