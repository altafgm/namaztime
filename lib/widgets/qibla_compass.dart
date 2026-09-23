import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/qibla_calculator.dart';

/// A rotating Qibla compass. The rose (cardinal letters, ticks and the green
/// Qibla needle) rotates with the device heading so the top of the dial always
/// points where the device faces. The fixed amber marker above the rim shows
/// the current direction; when the green Qibla needle slides under it the user
/// is facing the Kaaba.
class QiblaCompass extends StatefulWidget {
  const QiblaCompass({
    super.key,
    required this.heading,
    required this.qiblaBearing,
  });

  /// Current device heading in degrees (0–360, 0 = North). Ignored when
  /// non-finite (sensor data not available yet).
  final double heading;

  /// Bearing to the Kaaba for the current location (0–360).
  final double qiblaBearing;

  @override
  State<QiblaCompass> createState() => _QiblaCompassState();
}

class _QiblaCompassState extends State<QiblaCompass> {
  double _headingTurns = 0;
  double _trackedHeading = 0;

  @override
  void initState() {
    super.initState();
    _trackedHeading = widget.heading.isFinite ? widget.heading : 0;
  }

  @override
  void didUpdateWidget(QiblaCompass oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = widget.heading.isFinite ? widget.heading : _trackedHeading;
    // Accumulate the shortest-turn delta so the rose never spins the long way
    // around (e.g. 359° → 1° rewinds through 360° instead of a full lap).
    _headingTurns +=
        QiblaCalculator.signedDelta(_trackedHeading, target) / 360.0;
    _trackedHeading = target;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;

    final dialColor = isDark ? scheme.surface : Colors.white;
    final ringColor = scheme.onSurface.withValues(alpha: isDark ? 0.9 : 0.5);
    final tickColor = scheme.onSurface.withValues(alpha: isDark ? 0.5 : 0.32);
    final cardinalColor = scheme.onSurface.withValues(alpha: isDark ? 0.75 : 0.6);
    final emphasisColor = scheme.primary;
    final qiblaTint = isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D);
    final markerColor = isDark ? const Color(0xFFF5B83D) : const Color(0xFFB45309);
    final markerStroke = isDark ? Colors.black87 : Colors.white;
    final pivotColor = scheme.onSurface;

    return LayoutBuilder(
      builder: (context, constraints) {
        final edge = math
            .min(constraints.maxWidth, constraints.maxHeight)
            .clamp(240.0, 380.0)
            .toDouble();
        final qiblaRadians = widget.qiblaBearing * math.pi / 180;

        return Center(
          child: SizedBox(
            width: edge,
            height: edge,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // ── rotating rose: ring, ticks, cardinals + Qibla needle ──
                AnimatedRotation(
                  turns: -_headingTurns,
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutCubic,
                  child: SizedBox(
                    width: edge,
                    height: edge,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _CompassRosePainter(
                              dialColor: dialColor,
                              ringColor: ringColor,
                              tickColor: tickColor,
                              cardinalColor: cardinalColor,
                              emphasisColor: emphasisColor,
                            ),
                          ),
                        ),
                        // Needle is drawn in dial-local coordinates pointing
                        // at the Kaaba; the outer AnimatedRotation then keeps it
                        // earth-aligned as the device turns.
                        Positioned.fill(
                          child: Transform.rotate(
                            alignment: Alignment.center,
                            angle: qiblaRadians,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: _QiblaNeedlePainter(
                                      color: qiblaTint,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // ── fixed current-direction marker + pivot (does not rotate) ──
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _FixedMarkerPainter(
                        markerColor: markerColor,
                        markerStroke: markerStroke,
                        pivotColor: pivotColor,
                        dialColor: dialColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CompassRosePainter extends CustomPainter {
  _CompassRosePainter({
    required this.dialColor,
    required this.ringColor,
    required this.tickColor,
    required this.cardinalColor,
    required this.emphasisColor,
  });

  final Color dialColor;
  final Color ringColor;
  final Color tickColor;
  final Color cardinalColor;
  final Color emphasisColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final edge = size.shortestSide;
    final radius = edge / 2;
    final stroke = math.max(edge * 0.012, 1.2);

    // Disc + outer ring background.
    canvas.drawCircle(
      center,
      radius - stroke / 2,
      Paint()
        ..color = dialColor
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center,
      radius - stroke / 2,
      Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    // Soft inner ring separating the ticks from the needle.
    canvas.drawCircle(
      center,
      radius * 0.78,
      Paint()
        ..color = ringColor.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke * 0.55,
    );

    // Degree ticks, major every 30°.
    final tickPaint = Paint()
      ..color = tickColor
      ..strokeWidth = stroke * 0.7
      ..strokeCap = StrokeCap.round;
    final majorPaint = Paint()
      ..color = ringColor.withValues(alpha: 0.9)
      ..strokeWidth = stroke * 1.1
      ..strokeCap = StrokeCap.round;
    for (var deg = 0; deg < 360; deg += 5) {
      final major = deg % 30 == 0;
      final rad = deg * math.pi / 180;
      final dir = Offset(math.sin(rad), -math.cos(rad));
      final outer = radius - (major ? stroke * 3 : stroke * 2);
      final inner = major ? radius * 0.78 : radius * 0.84;
      canvas.drawLine(
        center + dir * inner,
        center + dir * outer,
        major ? majorPaint : tickPaint,
      );
    }

    // Cardinal letters.
    const cardinalAngles = <String, double>{
      'N': 0,
      'E': 90,
      'S': 180,
      'W': 270,
    };
    for (final entry in cardinalAngles.entries) {
      final rad = entry.value * math.pi / 180;
      final pos = center +
          Offset(math.sin(rad), -math.cos(rad)) * (radius * 0.66);
      final isNorth = entry.key == 'N';
      final painter = TextPainter(
        text: TextSpan(
          text: entry.key,
          style: TextStyle(
            color: isNorth ? emphasisColor : cardinalColor,
            fontSize: radius * (isNorth ? 0.26 : 0.22),
            fontWeight: isNorth ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        pos - Offset(painter.width / 2, painter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(_CompassRosePainter oldDelegate) {
    return oldDelegate.dialColor != dialColor ||
        oldDelegate.ringColor != ringColor ||
        oldDelegate.tickColor != tickColor ||
        oldDelegate.cardinalColor != cardinalColor ||
        oldDelegate.emphasisColor != emphasisColor;
  }
}

class _QiblaNeedlePainter extends CustomPainter {
  _QiblaNeedlePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final edge = size.shortestSide;
    final center = size.center(Offset.zero);

    // Shaft from the centre of the dial towards the rim (drawn pointing up;
    // the surrounding Transform.rotate aims it at the Kaaba).
    final shaft = Paint()
      ..color = color
      ..strokeWidth = math.max(edge * 0.016, 2.4)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center,
      Offset(center.dx, edge * 0.185),
      shaft,
    );

    // Arrowhead just clear of the ring.
    final tip = Offset(center.dx, edge * 0.105);
    final head = Path()
      ..moveTo(tip.dx, tip.dy - edge * 0.014)
      ..lineTo(tip.dx - edge * 0.034, tip.dy + edge * 0.05)
      ..lineTo(tip.dx + edge * 0.034, tip.dy + edge * 0.05)
      ..close();
    canvas.drawPath(head, Paint()..color = color);
    canvas.save();
    canvas.clipPath(head);
    canvas.drawCircle(
      tip - Offset(0, edge * 0.02),
      edge * 0.055,
      Paint()..color = color.withValues(alpha: 0.35),
    );
    canvas.restore();

    // Small pivot ring where the needle meets the center.
    canvas.drawCircle(
      center,
      edge * 0.018,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_QiblaNeedlePainter oldDelegate) => oldDelegate.color != color;
}

class _FixedMarkerPainter extends CustomPainter {
  _FixedMarkerPainter({
    required this.markerColor,
    required this.markerStroke,
    required this.pivotColor,
    required this.dialColor,
  });

  final Color markerColor;
  final Color markerStroke;
  final Color pivotColor;
  final Color dialColor;

  @override
  void paint(Canvas canvas, Size size) {
    final edge = size.shortestSide;
    final center = size.center(Offset.zero);

    // Current-direction marker: the fixed triangle over the top of the dial
    // showing which way the device is facing right now. It sits just below
    // the Kaaba badge so the two only meet when facing the Qibla.
    final apex = Offset(center.dx, edge * 0.16);
    final marker = Path()
      ..moveTo(apex.dx, apex.dy)
      ..lineTo(apex.dx - edge * 0.032, edge * 0.12)
      ..lineTo(apex.dx + edge * 0.032, edge * 0.12)
      ..close();
    canvas
      ..drawPath(marker, Paint()..color = markerColor)
      ..drawPath(
        marker,
        Paint()
          ..color = markerStroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(edge * 0.006, 1.2),
      );

    // Center pivot.
    canvas.drawCircle(
      center,
      edge * 0.026,
      Paint()..color = pivotColor,
    );
    canvas.drawCircle(
      center,
      edge * 0.013,
      Paint()..color = dialColor,
    );
  }

  @override
  bool shouldRepaint(_FixedMarkerPainter oldDelegate) {
    return oldDelegate.markerColor != markerColor ||
        oldDelegate.markerStroke != markerStroke ||
        oldDelegate.pivotColor != pivotColor ||
        oldDelegate.dialColor != dialColor;
  }
}

