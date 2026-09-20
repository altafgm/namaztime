class PrayerTime {
  final String name;
  final DateTime time;
  final bool isCurrent;
  final bool isNext;

  PrayerTime({
    required this.name,
    required this.time,
    this.isCurrent = false,
    this.isNext = false,
  });

  PrayerTime copyWith({
    String? name,
    DateTime? time,
    bool? isCurrent,
    bool? isNext,
  }) {
    return PrayerTime(
      name: name ?? this.name,
      time: time ?? this.time,
      isCurrent: isCurrent ?? this.isCurrent,
      isNext: isNext ?? this.isNext,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'time': time.toIso8601String(),
      'isCurrent': isCurrent,
      'isNext': isNext,
    };
  }

  factory PrayerTime.fromJson(Map<String, dynamic> json) {
    return PrayerTime(
      name: json['name'] as String,
      time: DateTime.parse(json['time'] as String),
      isCurrent: json['isCurrent'] as bool? ?? false,
      isNext: json['isNext'] as bool? ?? false,
    );
  }

  String get widgetLabel {
    if (isCurrent) return 'Now';
    if (isNext) return 'Next';
    return '';
  }

  @override
  String toString() {
    return 'PrayerTime(name: $name, time: $time, isCurrent: $isCurrent, isNext: $isNext)';
  }
}