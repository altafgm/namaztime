import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class SettingsProvider with ChangeNotifier {
  final SettingsService _settingsService;

  ThemeMode _themeMode = ThemeMode.system;
  bool _notificationsEnabled = true;
  bool _isInitialized = false;

  SettingsProvider(this._settingsService);

  ThemeMode get themeMode => _themeMode;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    await _settingsService.init();
    _themeMode = _settingsService.loadThemeMode();
    _notificationsEnabled = _settingsService.loadNotificationsEnabled();
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _settingsService.saveThemeMode(mode);
    notifyListeners();
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    _notificationsEnabled = enabled;
    await _settingsService.saveNotificationsEnabled(enabled);
    notifyListeners();
  }
}