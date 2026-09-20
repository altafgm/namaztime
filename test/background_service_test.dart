import 'package:flutter_test/flutter_test.dart';
import 'package:salah_time/services/background_service.dart';

void main() {
  group('BackgroundService date window logic', () {
    test('starts the 7-day window from today before Maghrib is reached', () {
      final base = DateTime(2026, 8, 30, 17, 30);
      final maghrib = DateTime(2026, 8, 30, 19, 15);

      final window = BackgroundService.getNextSevenDayWindow(
        base,
        maghribTime: maghrib,
      );

      expect(window.length, 7);
      expect(window.first, DateTime(2026, 8, 30));
      expect(window.last, DateTime(2026, 9, 5));
    });

    test('starts the 7-day window from tomorrow once Maghrib has started', () {
      final base = DateTime(2026, 8, 30, 19, 30);
      final maghrib = DateTime(2026, 8, 30, 19, 15);

      final window = BackgroundService.getNextSevenDayWindow(
        base,
        maghribTime: maghrib,
      );

      expect(window.length, 7);
      expect(window.first, DateTime(2026, 8, 31));
      expect(window.last, DateTime(2026, 9, 6));
    });
  });
}
