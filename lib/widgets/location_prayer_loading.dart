import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The meaningful steps while the app obtains a location and prepares a
/// schedule. Keeping these separate avoids presenting a generic spinner while
/// the app is waiting on a real device operation.
enum LocationPrayerLoadingPhase { locating, gps, calculating, fallback }

class LocationPrayerLoading extends StatefulWidget {
  const LocationPrayerLoading({super.key, required this.phase});

  final LocationPrayerLoadingPhase phase;

  @override
  State<LocationPrayerLoading> createState() => _LocationPrayerLoadingState();
}

class _LocationPrayerLoadingState extends State<LocationPrayerLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _status => switch (widget.phase) {
    LocationPrayerLoadingPhase.locating => 'Finding your location…',
    LocationPrayerLoadingPhase.gps => 'Connecting to GPS satellites…',
    LocationPrayerLoadingPhase.calculating => 'Calculating prayer times…',
    LocationPrayerLoadingPhase.fallback =>
      'Preparing prayer times for your saved location…',
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Center(
      child: Semantics(
        label: _status,
        liveRegion: true,
        child: SizedBox(
          width: 230,
          height: 210,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 126,
                height: 126,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => _LocationVisual(
                    phase: widget.phase,
                    progress: reduceMotion ? 0 : _controller.value,
                    primary: colors.primary,
                    secondary: colors.secondary,
                    surface: colors.surfaceContainerHighest,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                child: Text(
                  _status,
                  key: ValueKey(widget.phase),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationVisual extends StatelessWidget {
  const _LocationVisual({
    required this.phase,
    required this.progress,
    required this.primary,
    required this.secondary,
    required this.surface,
  });

  final LocationPrayerLoadingPhase phase;
  final double progress;
  final Color primary;
  final Color secondary;
  final Color surface;

  bool get _isGps =>
      phase == LocationPrayerLoadingPhase.locating ||
      phase == LocationPrayerLoadingPhase.gps;

  @override
  Widget build(BuildContext context) {
    final pulse = 0.55 + (math.sin(progress * math.pi * 2) + 1) * 0.225;
    return Stack(
      alignment: Alignment.center,
      children: [
        if (_isGps)
          for (final multiplier in [0.58, 0.88])
            Container(
              width: 110 * multiplier * pulse,
              height: 110 * multiplier * pulse,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: primary.withValues(alpha: 0.16),
                  width: 1.5,
                ),
              ),
            ),
        if (_isGps)
          for (var index = 0; index < 3; index++)
            _SatelliteDot(
              angle: (progress * math.pi * 2) + index * (math.pi * 2 / 3),
              color: index == 0 ? secondary : primary,
              opacity:
                  0.45 +
                  ((math.sin(progress * math.pi * 2 + index * 1.9) + 1) / 2) *
                      0.55,
            ),
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(color: surface, shape: BoxShape.circle),
        ),
        Icon(
          _isGps ? Icons.location_on_rounded : Icons.access_time_filled_rounded,
          size: 43,
          color: primary,
        ),
        if (!_isGps)
          Positioned(
            right: 18,
            bottom: 23,
            child: Icon(Icons.auto_awesome_rounded, size: 19, color: secondary),
          ),
      ],
    );
  }
}

class _SatelliteDot extends StatelessWidget {
  const _SatelliteDot({
    required this.angle,
    required this.color,
    required this.opacity,
  });

  final double angle;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    const orbitRadius = 49.0;
    return Transform.translate(
      offset: Offset(
        math.cos(angle) * orbitRadius,
        math.sin(angle) * orbitRadius,
      ),
      child: Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: color.withValues(alpha: opacity),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.22), blurRadius: 8),
          ],
        ),
      ),
    );
  }
}
