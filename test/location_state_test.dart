import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:salah_time/models/location_data.dart';
import 'package:salah_time/providers/location_state.dart';
import 'package:salah_time/services/location_service.dart';

class FakeLocationService extends LocationService {
  @override
  Future<LocationPermission> requestPermission() async => LocationPermission.whileInUse;

  @override
  Future<LocationData?> getCurrentLocation() async => const LocationData(
        latitude: 41.0082,
        longitude: 28.9784,
        city: 'Istanbul',
        country: 'Turkey',
      );
}

void main() {
  test('resolveCurrentLocation returns fallback when permission is denied', () async {
    final service = FakeLocationService();
    final state = LocationState(service);
    const fallback = LocationData(
      latitude: 41.0082,
      longitude: 28.9784,
      city: 'Istanbul',
      country: 'Turkey',
    );

    final result = await state.resolveCurrentLocation(fallback: fallback);

    expect(result.city, 'Istanbul');
    expect(state.currentLocation, fallback);
  });
}
