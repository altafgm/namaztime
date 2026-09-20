import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/prayer_provider.dart';
import '../providers/settings_provider.dart';
import '../services/widget_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Appearance',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ThemeMode>(
                decoration: const InputDecoration(
                  labelText: 'Theme',
                  border: OutlineInputBorder(),
                ),
                initialValue: settings.themeMode,
                items: const [
                  DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                  DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                  DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    settings.setThemeMode(value);
                  }
                },
              ),
              const SizedBox(height: 32),
              const Text(
                'Notifications',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SwitchListTile(
                title: const Text('Prayer Notifications'),
                subtitle: const Text('Receive a notification at each prayer time'),
                value: settings.notificationsEnabled,
                onChanged: (value) async {
                  await settings.setNotificationsEnabled(value);
                  if (context.mounted) {
                    await context.read<PrayerProvider>().refreshSchedule(
                          notificationsEnabled: value,
                        );
                  }
                },
              ),
              const SizedBox(height: 32),
              const Text(
                'Widget',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Missed the add-widget prompt? Add the home-screen widget here anytime.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.widgets_outlined),
                title: const Text('Add widget to home screen'),
                subtitle: const Text(
                  'Pin the widget showing current and next prayer times',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final added = await WidgetService.requestAddWidget();
                  if (!added && context.mounted) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Widget pinning is not supported on this device.',
                        ),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 32),
              const Text(
                'Location',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Prayer times will always use the device GPS location. There is no manual location selection in settings.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          );
        },
      ),
    );
  }
}
