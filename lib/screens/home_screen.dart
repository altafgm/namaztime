import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/location_data.dart';
import '../models/prayer_schedule.dart';
import '../providers/prayer_provider.dart';
import '../providers/settings_provider.dart';
import '../screens/qibla_screen.dart';
import '../screens/settings_screen.dart';
import '../services/location_service.dart';
import '../services/widget_service.dart';
import '../widgets/location_prayer_loading.dart';
import '../widgets/prayer_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final LocationService _locationService = LocationService();
  bool _loading = true;
  LocationPrayerLoadingPhase _loadingPhase =
      LocationPrayerLoadingPhase.locating;
  bool _usingFallbackLocation = false;
  String? _locationStatus;
  DateTime? _lastSyncedAt;
  double? _currentLat;
  double? _currentLng;
  Timer? _timer;

  static const _defaultLocation = LocationData(
    latitude: 41.0082,
    longitude: 28.9784,
    city: 'Istanbul',
    country: 'Turkey',
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startup());
    // Refresh current/next prayer highlight every minute
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        context.read<PrayerProvider>().refreshCurrentPrayer();
      }
    });
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  // ─── startup: permission → location → API ───────────────────────────────

  Future<void> _startup() async {
    // Paint from whatever we already have immediately: the persisted location
    // plus its cached schedule, so the cards show without waiting on GPS. On a
    // first run nothing is persisted yet, so skip straight to the live path
    // rather than painting the hardcoded default as the user's location. The
    // pinned load is awaited so it can never race the live one.
    final pinned = await _storedLocation();
    if (pinned != null) {
      await _startupWithPinnedLocation(pinned);
    }
    await _startupWithLiveLocation();
  }

  /// Fast path — no GPS and no permission prompt. Loads from prefs + cache.
  Future<void> _startupWithPinnedLocation(LocationData pinned) async {
    final settingsProvider = context.read<SettingsProvider>();
    final prayerProvider = context.read<PrayerProvider>();
    if (!mounted) return;
    final notificationsEnabled = settingsProvider.notificationsEnabled;

    try {
      await prayerProvider.loadPrayerSchedule(
        location: pinned,
        date: DateTime.now(),
        notificationsEnabled: notificationsEnabled,
      );
      if (mounted) {
        setState(() {
          _currentLat = pinned.latitude;
          _currentLng = pinned.longitude;
        });
      }
    } catch (_) {
      // Will be retried by the live-location path.
    }
  }

  /// Slow path — GPS fix + geocode. Only runs after the fast path has already
  /// shown today's data, so it never blocks the first frame.
  Future<void> _startupWithLiveLocation() async {
    try {
      if (mounted) {
        setState(() {
          _loadingPhase = LocationPrayerLoadingPhase.locating;
          _usingFallbackLocation = false;
        });
      }
      final location = await _resolveLocation().timeout(
        const Duration(seconds: 15),
        onTimeout: () => _fallbackLocation('Location timed out.'),
      );
      await _loadPrayers(location);
    } catch (_) {
      // last resort — load with the last known (or default) location so the app
      // never stays blank
      try {
        await _loadPrayers(await _fallbackLocation('Location unavailable.'));
      } catch (_) {}
    } finally {
      if (mounted) setState(() => _loading = false);
    }

    await _maybeShowAddWidgetPrompt();
  }

  /// One-time flow on a fresh install: once today's times are loaded, offer to
  /// pin the home-screen widget. Only runs on Android where widgets exist.
  Future<void> _maybeShowAddWidgetPrompt() async {
    if (!mounted || !Platform.isAndroid) return;
    if (context.read<PrayerProvider>().currentSchedule == null) return;
    if (!await WidgetService.shouldShowAddWidgetPrompt()) return;
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Salah Time widget'),
        content: const Text(
          'Add the prayer widget to your home screen to always see the '
          'current and next prayer times at a glance.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add widget'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await WidgetService.requestAddWidget();
    }
    await WidgetService.markWidgetPromptShown();
  }

  // Returns the best available location, never throws.
  Future<LocationData> _resolveLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return await _fallbackLocation('Location permission denied.');
      }

      if (mounted) {
        setState(() => _loadingPhase = LocationPrayerLoadingPhase.gps);
      }
      final location = await _locationService.getCurrentLocation();
      if (location != null) {
        final syncedAt = DateTime.now();
        if (mounted) {
          setState(() {
            _currentLat = location.latitude;
            _currentLng = location.longitude;
            _lastSyncedAt = syncedAt;
            _locationStatus = 'Location detected: ${location.displayName}';
            _usingFallbackLocation = false;
          });
        }
        // Persist location for background task
        await _persistBgLocation(location, syncedAt);
        return location;
      }
    } catch (_) {
      // any unexpected error → fall through to the last known location
    }

    return _fallbackLocation('GPS unavailable.');
  }

  /// The location the last successful fix persisted: the fast startup path, the
  /// Dart background service and the native worker all read these coordinates.
  /// Null before anything has ever been resolved.
  Future<LocationData?> _storedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('bg_lat');
    final lng = prefs.getDouble('bg_lng');
    if (lat == null || lng == null) return null;
    return LocationData(
      latitude: lat,
      longitude: lng,
      city: prefs.getString('bg_city') ?? _defaultLocation.city,
      country: prefs.getString('bg_country') ?? _defaultLocation.country,
    );
  }

  /// Location used when no fix can be obtained. Whatever was resolved before is
  /// kept, because a refresh that cannot get a GPS fix must not silently move the
  /// user — and every prayer time with them — to the default city. On a first
  /// run there is nothing stored; the default is shown only for this session so
  /// the screen is never blank, and it is deliberately *not* persisted, because
  /// doing so would turn the default into a fake "last known location" that every
  /// later launch would trust.
  Future<LocationData> _fallbackLocation(String reason) async {
    final stored = await _storedLocation();
    final location = stored ?? _defaultLocation;
    if (mounted) {
      setState(() {
        _currentLat = location.latitude;
        _currentLng = location.longitude;
        _locationStatus = stored == null
            ? '$reason Using default location.'
            : '$reason Using last known location.';
        _usingFallbackLocation = true;
        _loadingPhase = LocationPrayerLoadingPhase.fallback;
      });
    }
    return location;
  }

  /// Persists the coordinate used by the background workers so it keeps running
  /// even when GPS is unavailable. The city is stored too, so the fast startup
  /// path can label the pinned coordinates correctly.
  Future<void> _persistBgLocation(
    LocationData location, [
    DateTime? syncedAt,
  ]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('bg_lat', location.latitude);
    await prefs.setDouble('bg_lng', location.longitude);
    await prefs.setString('bg_city', location.city);
    await prefs.setString('bg_country', location.country);
    await prefs.setInt(
      'last_synced_at',
      (syncedAt ?? DateTime.now()).millisecondsSinceEpoch,
    );
  }

  String _formatLastSynced(DateTime time) {
    final formatter = DateFormat.yMd().add_jm();
    return formatter.format(time);
  }

  Future<void> _loadPrayers(LocationData location) async {
    if (!mounted) return;
    setState(() {
      _loadingPhase = _usingFallbackLocation
          ? LocationPrayerLoadingPhase.fallback
          : LocationPrayerLoadingPhase.calculating;
    });
    final notificationsEnabled = context
        .read<SettingsProvider>()
        .notificationsEnabled;
    await context.read<PrayerProvider>().loadPrayerSchedule(
      location: location,
      date: DateTime.now(),
      notificationsEnabled: notificationsEnabled,
    );
  }

  // ─── location icon tap ───────────────────────────────────────────────────

  Future<void> _onRefreshTapped() async {
    final permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.deniedForever) {
      await _showDialog(permanentlyDenied: true);
      return;
    }

    if (permission == LocationPermission.denied) {
      await _showDialog(permanentlyDenied: false);
      return;
    }

    await _refreshLocation();
  }

  Future<void> _refreshLocation() async {
    if (!mounted) return;

    // Read provider before async operations
    final provider = context.read<PrayerProvider>();

    setState(() {
      _loading = true;
      _loadingPhase = LocationPrayerLoadingPhase.locating;
      _usingFallbackLocation = false;
    });
    try {
      final location = await _resolveLocation();
      // Only clear cache and re-fetch if location changed
      final current = provider.currentLocation;
      final latChanged =
          current == null ||
          (location.latitude - current.latitude).abs() > 0.01 ||
          (location.longitude - current.longitude).abs() > 0.01;
      if (latChanged) {
        await provider.clearCache();
      }
      await _loadPrayers(location);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showDialog({required bool permanentlyDenied}) async {
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: Text(
          permanentlyDenied
              ? 'Location permission is permanently denied. Please open app settings to allow access.'
              : 'This app needs location permission to show prayer times for your area.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(permanentlyDenied ? 'Open Settings' : 'Allow'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    if (permanentlyDenied) {
      await _locationService.openAppSettings();
      return;
    }

    // Dialog is gone — now show system permission prompt
    final result = await Geolocator.requestPermission();
    if (!mounted) return;

    if (result == LocationPermission.denied ||
        result == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission not granted.')),
      );
      return;
    }

    await _refreshLocation();
  }

  // ─── build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Salah Time'),
        actions: [
          IconButton(
            icon: const Icon(Icons.explore_outlined),
            tooltip: 'Qibla Direction',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => QiblaScreen(
                  latitude: _currentLat,
                  longitude: _currentLng,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _loading ? null : _onRefreshTapped,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: Consumer<PrayerProvider>(
        builder: (context, provider, _) {
          if (provider.currentSchedule == null &&
              (_loading || provider.isLoading)) {
            return LocationPrayerLoading(phase: _loadingPhase);
          }

          if (provider.error != null && provider.currentSchedule == null) {
            return _centeredMessage(
              icon: Icons.error,
              iconColor: Colors.red,
              message: provider.error!,
              buttonLabel: 'Retry',
              onButton: _startup,
            );
          }

          if (provider.currentSchedule == null) {
            return _centeredMessage(
              icon: Icons.calendar_today,
              iconColor: Colors.grey,
              message: 'No prayer data available.',
              buttonLabel: 'Load Prayer Times',
              onButton: _startup,
            );
          }

          final schedule = provider.currentSchedule!;
          return Column(
            children: [
              // Cached prayer times can be shown immediately while a fresh GPS
              // fix is still in progress. Keep that content usable, but make
              // the live-location work visible instead of silently refreshing.
              if (_loading) ...[
                LocationPrayerLoading(phase: _loadingPhase),
              ] else if (provider.isLoading) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                const Text(
                  'Loading tomorrow\'s data...',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
              ],
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _locationCard(schedule),
                    const SizedBox(height: 16),
                    ...schedule.prayers.map((p) => PrayerCard(prayer: p)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _locationCard(PrayerSchedule schedule) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      schedule.location,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (_currentLat != null && _currentLng != null) ...[
              const SizedBox(height: 6),
              Text(
                '${_currentLat!.toStringAsFixed(4)}, ${_currentLng!.toStringAsFixed(4)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
            if (_locationStatus != null) ...[
              const SizedBox(height: 4),
              Text(
                _locationStatus!,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.blue,
                  fontStyle: FontStyle.italic,
                ),
              ),
              if (_lastSyncedAt != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Last synced: ${_formatLastSynced(_lastSyncedAt!)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _centeredMessage({
    required IconData icon,
    required Color iconColor,
    required String message,
    required String buttonLabel,
    required VoidCallback onButton,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: iconColor),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onButton, child: Text(buttonLabel)),
        ],
      ),
    );
  }
}
