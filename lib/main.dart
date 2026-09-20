import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'services/aladhan_api_service.dart';
import 'services/local_storage_service.dart';
import 'services/settings_service.dart';
import 'services/notification_service.dart';
import 'repositories/prayer_repository.dart';
import 'providers/prayer_provider.dart';
import 'providers/settings_provider.dart';
import 'services/background_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settingsService = SettingsService();
  await settingsService.init();
  final settingsProvider = SettingsProvider(settingsService);
  await settingsProvider.initialize();

  final localStorage = LocalStorageService();
  await localStorage.init();
  final apiService = AladhanApiService();
  final repository = PrayerRepository(apiService, localStorage);

  // Notification permission is requested async in PrayerProvider, and the
  // native worker owns scheduling. Nothing here needs to block first frame.
  final notificationService = NotificationService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => settingsProvider),
        ChangeNotifierProvider(
          create: (_) => PrayerProvider(repository, notificationService),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // On Android the native PrayerUpdateWorker already owns widget updates
      // and notifications, so the legacy 7-day foreground refresh is redundant
      // duplicate network work. Keep it only for non-Android platforms.
      if (!Platform.isAndroid) {
        await BackgroundService.refreshIfStale();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!Platform.isAndroid) {
        unawaited(BackgroundService.refreshIfStale());
      }
    }
  }

  // Use platform system fonts — no bundling needed
  static String get _fontFamily {
    if (kIsWeb) return 'Roboto';
    if (Platform.isIOS || Platform.isMacOS) return '.SF Pro Text';
    return 'Roboto';
  }

  static TextTheme _textTheme(ColorScheme colorScheme) {
    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: _fontFamily,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      displayMedium: TextStyle(
        fontFamily: _fontFamily,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.25,
      ),
      titleLarge: TextStyle(
        fontFamily: _fontFamily,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      titleMedium: TextStyle(
        fontFamily: _fontFamily,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
      bodyLarge: TextStyle(
        fontFamily: _fontFamily,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.15,
      ),
      bodyMedium: TextStyle(
        fontFamily: _fontFamily,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
      ),
      labelLarge: TextStyle(
        fontFamily: _fontFamily,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<SettingsProvider>().themeMode;

    return MaterialApp(
      title: 'Salah Time',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        fontFamily: _fontFamily,
        textTheme: _textTheme(
          ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: _fontFamily,
        textTheme: _textTheme(
          ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.dark,
          ),
        ),
      ),
      themeMode: themeMode,
      home: const HomeScreen(),
    );
  }
}
