import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/location_data.dart';
import '../services/location_service.dart';

class LocationState extends ChangeNotifier {
  final LocationService _locationService;

  LocationState(this._locationService);

  LocationData? _currentLocation;
  bool _isLoading = false;
  String? _statusMessage;
  bool _permissionDenied = false;

  LocationData? get currentLocation => _currentLocation;
  bool get isLoading => _isLoading;
  String? get statusMessage => _statusMessage;
  bool get permissionDenied => _permissionDenied;

  void setStatus(String? value) {
    _statusMessage = value;
    notifyListeners();
  }

  Future<LocationData> resolveCurrentLocation({
    required LocationData fallback,
  }) async {
    _isLoading = true;
    _permissionDenied = false;
    notifyListeners();

    try {
      final permission = await _locationService.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _permissionDenied = true;
        _statusMessage = 'Location permission denied. Using default location.';
        _currentLocation = fallback;
        _isLoading = false;
        notifyListeners();
        return fallback;
      }

      final location = await _locationService.getCurrentLocation();
      if (location != null) {
        _currentLocation = location;
        _statusMessage = 'Location detected: ${location.displayName}';
        _isLoading = false;
        notifyListeners();
        return location;
      }

      _currentLocation = fallback;
      _statusMessage = 'GPS unavailable. Using default location.';
      _isLoading = false;
      notifyListeners();
      return fallback;
    } catch (_) {
      _currentLocation = fallback;
      _statusMessage = 'GPS unavailable. Using default location.';
      _isLoading = false;
      notifyListeners();
      return fallback;
    }
  }
}
