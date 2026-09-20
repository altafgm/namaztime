import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _themeModeKey = 'theme_mode';
  static const _notificationsKey = 'notifications_enabled';

  SharedPreferences? _preferences;

  Future<void> init() async {
    _preferences = await SharedPreferences.getInstance();
  }

  ThemeMode loadThemeMode() {
    final value = _preferences?.getString(_themeModeKey) ?? 'system';
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      _ => 'system',
    };
    await _preferences?.setString(_themeModeKey, value);
  }

  bool loadNotificationsEnabled() {
    return _preferences?.getBool(_notificationsKey) ?? true;
  }

  Future<void> saveNotificationsEnabled(bool enabled) async {
    await _preferences?.setBool(_notificationsKey, enabled);
  }
}