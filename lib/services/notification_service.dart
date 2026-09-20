import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/prayer_schedule.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _permissionGranted = false;

  static const _channelId = 'prayer_times';
  static const _channelName = 'Prayer Times';

  Future<void> init() async {
    if (_initialized) return;

    try {
      log('Initializing notification service...');

      tz.initializeTimeZones();
      await _setLocalTimezone();

      const android = AndroidInitializationSettings(
        '@drawable/ic_notification',
      );
      const ios = DarwinInitializationSettings();
      await _plugin.initialize(
        const InitializationSettings(android: android, iOS: ios),
        onDidReceiveNotificationResponse: (response) {
          log('Notification tapped: ${response.payload}');
        },
      );

      // Request notification permission for Android 13+
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlugin != null) {
        final granted = await androidPlugin.requestNotificationsPermission();
        _permissionGranted = granted ?? false;
        log('Notification permission granted: $_permissionGranted');
      }

      // Create notification channel
      await _createNotificationChannel();

      _initialized = true;
      log('Notification service initialized successfully');
    } catch (e) {
      log('Failed to initialize notification service: $e');
      rethrow;
    }
  }

  Future<void> _createNotificationChannel() async {
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Notifications at each prayer time',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(androidChannel);
      log('Notification channel created: $_channelId');
    }
  }

  Future<void> _setLocalTimezone() async {
    try {
      log('Setting local timezone...');
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      log('Detected timezone: ${tzInfo.identifier}');
      final location = tz.getLocation(tzInfo.identifier);
      tz.setLocalLocation(location);
      log('Timezone set to: ${tz.local}');
    } catch (e) {
      log('Failed to set local timezone: $e');
      // Fall back to UTC
      tz.setLocalLocation(tz.UTC);
      log('Fell back to UTC timezone');
    }
  }

  /// Called every time a new prayer schedule is loaded (i.e. on every location update).
  /// Cancels all existing notifications and schedules fresh ones for today's prayers.
  Future<void> schedulePrayerNotifications(PrayerSchedule schedule) async {
    try {
      // Ensure service is initialized
      if (!_initialized) {
        await init();
      }

      log('Scheduling notifications for ${schedule.date}');

      await cancelAll();

      final now = tz.TZDateTime.now(tz.local);
      log('Current time: $now');

      int scheduledCount = 0;

      for (int i = 0; i < schedule.prayers.length; i++) {
        final prayer = schedule.prayers[i];
        final tzTime = tz.TZDateTime.from(prayer.time, tz.local);

        log('Prayer: ${prayer.name} at $tzTime');

        // Only schedule prayers that haven't passed yet
        if (tzTime.isAfter(now)) {
          try {
            await _plugin.zonedSchedule(
              i,
              'Time for ${prayer.name}',
              'It\'s time for ${prayer.name} prayer.',
              tzTime,
              NotificationDetails(
                android: AndroidNotificationDetails(
                  _channelId,
                  _channelName,
                  channelDescription: 'Notifications at each prayer time',
                  importance: Importance.max,
                  priority: Priority.high,
                  playSound: true,
                  enableVibration: true,
                  icon: '@drawable/ic_notification',
                  color: Colors.blue,
                ),
                iOS: const DarwinNotificationDetails(sound: 'default'),
              ),
              androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
              uiLocalNotificationDateInterpretation:
                  UILocalNotificationDateInterpretation.absoluteTime,
            );
            scheduledCount++;
            log('Scheduled notification for ${prayer.name} at $tzTime');
          } catch (e) {
            log('Failed to schedule notification for ${prayer.name}: $e');
          }
        } else {
          log('Skipped ${prayer.name} - already passed at $tzTime');
        }
      }

      log('Total notifications scheduled: $scheduledCount');

      // If no prayers were scheduled (all passed), schedule tomorrow's Fajr
      if (scheduledCount == 0) {
        await _scheduleTomorrowFajr(schedule);
      }
    } catch (e) {
      log('Error scheduling notifications: $e');
    }
  }

  Future<void> _scheduleTomorrowFajr(PrayerSchedule schedule) async {
    try {
      final tomorrow = schedule.date.add(const Duration(days: 1));
      // Schedule Fajr for tomorrow at the same time as today's Fajr
      final fajrTime = schedule.prayers
          .firstWhere((p) => p.name == 'Fajr')
          .time;
      final tomorrowFajr = DateTime(
        tomorrow.year,
        tomorrow.month,
        tomorrow.day,
        fajrTime.hour,
        fajrTime.minute,
      );

      final tzTime = tz.TZDateTime.from(tomorrowFajr, tz.local);

      await _plugin.zonedSchedule(
        100, // Use a different ID
        'Time for Fajr (Tomorrow)',
        'It\'s time for Fajr prayer tomorrow.',
        tzTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'Notifications at each prayer time',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            icon: '@drawable/ic_notification',
            color: Colors.blue,
          ),
          iOS: const DarwinNotificationDetails(sound: 'default'),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      log('Scheduled tomorrow\'s Fajr at $tzTime');
    } catch (e) {
      log('Failed to schedule tomorrow\'s Fajr: $e');
    }
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
      log('Cancelled all notifications');
    } catch (e) {
      log('Error cancelling notifications: $e');
    }
  }
}
