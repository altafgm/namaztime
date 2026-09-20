class LocationData {
  final double latitude;
  final double longitude;
  final String city;
  final String country;

  const LocationData({
    required this.latitude,
    required this.longitude,
    required this.city,
    required this.country,
  });

  String get displayName => '$city, $country';

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'city': city,
      'country': country,
    };
  }

  factory LocationData.fromJson(Map<String, dynamic> json) {
    return LocationData(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      city: json['city'] as String,
      country: json['country'] as String,
    );
  }

  @override
  String toString() {
    return 'LocationData(latitude: $latitude, longitude: $longitude, city: $city, country: $country)';
  }
}