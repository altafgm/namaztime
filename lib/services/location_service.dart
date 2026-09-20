import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../models/location_data.dart';

class LocationService {
  Future<LocationPermission> requestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission;
  }

  Future<bool> openAppSettings() async {
    return Geolocator.openAppSettings();
  }

  Future<bool> openLocationSettings() async {
    return Geolocator.openLocationSettings();
  }

  Future<LocationData?> getCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    try {
      Position position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 8),
        );
      } catch (_) {
        final last = await Geolocator.getLastKnownPosition();
        if (last == null) return null;
        position = last;
      }

      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        ).timeout(const Duration(seconds: 5));
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          return LocationData(
            latitude: position.latitude,
            longitude: position.longitude,
            city: p.locality ?? 'Unknown',
            country: p.country ?? 'Unknown',
          );
        }
      } catch (_) {
        // Geocoding failed — return raw coords
      }

      return LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        city: 'Unknown',
        country: 'Unknown',
      );
    } catch (_) {
      return null;
    }
  }

  Future<LocationData?> searchLocation(String query) async {
    try {
      final locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final location = locations.first;
        final placemarks = await placemarkFromCoordinates(
          location.latitude,
          location.longitude,
        );

        if (placemarks.isNotEmpty) {
          final placemark = placemarks.first;
          return LocationData(
            latitude: location.latitude,
            longitude: location.longitude,
            city: placemark.locality ?? query,
            country: placemark.country ?? 'Unknown',
          );
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }
}