import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salah_time/widgets/location_prayer_loading.dart';

Widget _subject(
  LocationPrayerLoadingPhase phase, {
  bool dark = false,
  bool reduceMotion = false,
}) {
  return MaterialApp(
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal)),
    darkTheme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.teal,
        brightness: Brightness.dark,
      ),
    ),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Scaffold(body: LocationPrayerLoading(phase: phase)),
    ),
  );
}

void main() {
  testWidgets('shows a clear label for every loading phase', (tester) async {
    const expectations = {
      LocationPrayerLoadingPhase.locating: 'Finding your location…',
      LocationPrayerLoadingPhase.gps: 'Connecting to GPS satellites…',
      LocationPrayerLoadingPhase.calculating: 'Calculating prayer times…',
      LocationPrayerLoadingPhase.fallback:
          'Preparing prayer times for your saved location…',
    };

    for (final entry in expectations.entries) {
      await tester.pumpWidget(_subject(entry.key));
      expect(find.text(entry.value), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == entry.value,
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('renders in dark theme with reduced motion enabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      _subject(LocationPrayerLoadingPhase.gps, dark: true, reduceMotion: true),
    );

    expect(find.byIcon(Icons.location_on_rounded), findsOneWidget);
    expect(find.text('Connecting to GPS satellites…'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}
