import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:salah_time/main.dart';
import 'package:salah_time/services/settings_service.dart';
import 'package:salah_time/services/notification_service.dart';
import 'package:salah_time/services/aladhan_api_service.dart';
import 'package:salah_time/services/local_storage_service.dart';
import 'package:salah_time/repositories/prayer_repository.dart';
import 'package:salah_time/providers/prayer_provider.dart';
import 'package:salah_time/providers/settings_provider.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    // The app reads preferences on startup; provide empty in-memory values.
    SharedPreferences.setMockInitialValues({});

    final settingsService = SettingsService();
    await settingsService.init();
    final settingsProvider = SettingsProvider(settingsService);
    await settingsProvider.initialize();

    final localStorage = LocalStorageService();
    await localStorage.init();
    final repository = PrayerRepository(AladhanApiService(), localStorage);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => settingsProvider),
          ChangeNotifierProvider(
            create: (_) => PrayerProvider(repository, NotificationService()),
          ),
        ],
        child: const MyApp(),
      ),
    );
    // The screen can continue its platform-location refinement in the
    // background; the initial app frame does not need to wait for it.
    await tester.pump(const Duration(seconds: 16));

    // Verify that the app title is displayed
    expect(find.text('Salah Time'), findsOneWidget);
  });
}
