import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_device_compass/flutter_device_compass.dart';
import 'package:provider/provider.dart';

import '../providers/prayer_provider.dart';
import '../services/location_service.dart';
import '../utils/qibla_calculator.dart';
import '../widgets/qibla_compass.dart';

/// The Qibla direction tab: shows the bearing to the Kaaba for the current
/// location at the top, and a live compass underneath. When the green Qibla
/// needle aligns with the amber "you are here" marker at the top of the dial,
/// the device is facing the Qibla.
class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key, this.latitude, this.longitude});

  /// Latest known location, so the bearing can be shown before a fresh GPS
  /// fix arrives. Falls back to the persisted provider location when omitted.
  final double? latitude;
  final double? longitude;

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  final LocationService _locationService = LocationService();
  StreamSubscription<CompassEvent>? _subscription;
  double? _heading;
  bool _refreshingLocation = false;

  double? _lat;
  double? _lng;
  String _city = 'Unknown';
  String _country = 'Unknown';
  double _qiblaBearing = 0;

  @override
  void initState() {
    super.initState();
    final providerLocation = context.read<PrayerProvider>().currentLocation;
    _lat = widget.latitude ?? providerLocation?.latitude;
    _lng = widget.longitude ?? providerLocation?.longitude;
    if (_lat != null && _lng != null) {
      _qiblaBearing = QiblaCalculator.bearingToKaaba(_lat!, _lng!);
    }
    // Painting first with any known coordinate, then fetch a fresh GPS fix so
    // the green line tracks where the user actually is right now (e.g. after
    // the emulator's mock location is changed).
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshLocation());
    _initCompass();
  }

  void _initCompass() {
    try {
      _subscription = FlutterCompass.events?.listen((event) {
        final heading = event.heading;
        if (heading == null || !heading.isFinite || !mounted) return;
        setState(() => _heading = heading);
      });
    } catch (_) {
      _subscription = null;
    }
  }

  /// Re-resolves the device location and recomputes the Qibla bearing. Safe to
  /// call repeatedly: on failure it keeps the previous bearing and shows a
  /// message instead of blanking the needle.
  Future<void> _refreshLocation() async {
    setState(() => _refreshingLocation = true);
    final location = await _locationService.getCurrentLocation();
    if (!mounted) return;
    setState(() => _refreshingLocation = false);
    if (location == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not refresh location. Qibla direction unchanged.'),
        ),
      );
      return;
    }
    setState(() {
      _lat = location.latitude;
      _lng = location.longitude;
      _city = location.city;
      _country = location.country;
      _qiblaBearing = QiblaCalculator.bearingToKaaba(_lat!, _lng!);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Qibla Direction'),
        actions: [
          IconButton(
            icon: _refreshingLocation
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
            tooltip: 'Refresh location',
            onPressed: _refreshingLocation ? null : _refreshLocation,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildBearingHeader(context),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Expanded(
                      child: QiblaCompass(
                        heading: _heading ?? double.nan,
                        qiblaBearing: _qiblaBearing,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The green line shows the Qibla direction',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBearingHeader(BuildContext context) {
    final theme = Theme.of(context);
    final hasLocation = _lat != null && _lng != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(
                      Icons.mosque,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Qibla Direction',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasLocation
                              ? 'Towards the Kaaba, Makkah'
                              : 'Location unavailable',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                        Text(
                          hasLocation
                              ? '$_city, $_country'
                              : 'Tap the location icon to resolve GPS',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        hasLocation
                            ? '${_qiblaBearing.toStringAsFixed(1)}°'
                            : '—',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      Text(
                        hasLocation
                            ? QiblaCalculator.directionOfKaaba(_qiblaBearing)
                            : 'bearing',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
              if (hasLocation) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'You: ${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)}',
                      style: theme.textTheme.bodySmall,
                    ),
                    Text(
                      'Kaaba: '
                      '${QiblaCalculator.kaabaLatitude.toStringAsFixed(3)}°, '
                      '${QiblaCalculator.kaabaLongitude.toStringAsFixed(2)}°E',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}