import 'prayer_time.dart';

class PrayerSchedule {
  final DateTime date;
  final List<PrayerTime> prayers;
  final String location;
  final double latitude;
  final double longitude;

  PrayerSchedule({
    required this.date,
    required this.prayers,
    required this.location,
    required this.latitude,
    required this.longitude,
  });

  PrayerSchedule withCurrentPrayer(DateTime now) {
    // Find current prayer index (time has passed but next hasn't)
    int currentIndex = -1;
    for (int i = 0; i < prayers.length; i++) {
      final next = i < prayers.length - 1 ? prayers[i + 1] : null;
      if (now.isAfter(prayers[i].time) &&
          (next == null || now.isBefore(next.time))) {
        currentIndex = i;
        break;
      }
    }
    // Next prayer is the one after current, or first if none passed yet
    final nextIndex = currentIndex == -1
        ? 0
        : (currentIndex + 1 < prayers.length ? currentIndex + 1 : -1);

    final updatedPrayers = List<PrayerTime>.generate(prayers.length, (i) {
      return prayers[i].copyWith(
        isCurrent: i == currentIndex,
        isNext: i == nextIndex,
      );
    });
    return PrayerSchedule(
      date: date,
      prayers: updatedPrayers,
      location: location,
      latitude: latitude,
      longitude: longitude,
    );
  }

  PrayerTime? get currentPrayer {
    return prayers.firstWhere(
      (prayer) => prayer.isCurrent,
      orElse: () => prayers.first,
    );
  }

  PrayerTime? get nextPrayer {
    final now = DateTime.now();
    return prayers.firstWhere(
      (prayer) => prayer.time.isAfter(now),
      orElse: () => prayers.first,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'prayers': prayers.map((prayer) => prayer.toJson()).toList(),
    };
  }

  factory PrayerSchedule.fromJson(Map<String, dynamic> json) {
    final prayerList = (json['prayers'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(PrayerTime.fromJson)
        .toList();

    return PrayerSchedule(
      date: DateTime.parse(json['date'] as String),
      location: json['location'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      prayers: prayerList,
    );
  }

  @override
  String toString() {
    return 'PrayerSchedule(date: $date, location: $location, lat: $latitude, lng: $longitude)';
  }
}