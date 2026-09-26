import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/match_event.dart';

/// Halbes Spielfeld aus Angriffssicht: Tor oben, klickbare Wurfzonen.
class HandballCourt extends StatelessWidget {
  const HandballCourt({
    super.key,
    required this.onZoneTap,
    this.selectedZone,
    this.events = const [],
    this.enabled = true,
    this.aspectRatio = 1.45,
  });

  final ValueChanged<CourtZone> onZoneTap;
  final CourtZone? selectedZone;
  final List<MatchEvent> events;
  final bool enabled;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: GestureDetector(
        onTapUp:
            enabled ? (details) => _handleTap(details.localPosition, onZoneTap) : null,
        child: CustomPaint(
          painter: _CourtPainter(selectedZone: selectedZone, events: events),
        ),
      ),
    );
  }

  void _handleTap(Offset local, ValueChanged<CourtZone> tap) {
    final box = context.findRenderObject()! as RenderBox;
    final zone = zoneAt(local, box.size);
    if (zone != null) tap(zone);
  }

  static double _goalCenterY(Size size) => 8.0;

  static double _sixRadius(Size size) => size.height * 0.52;

  static double _nineRadius(Size size) => size.height * 0.95;

  static Offset _sevenPoint(Size size) {
    final r6 = _sixRadius(size);
    final r9 = _nineRadius(size);
    return Offset(size.width / 2, _goalCenterY(size) + r6 + (r9 - r6) * 0.28);
  }

  /// Ermittelt die Zone anhand der Tap-Position.
  static CourtZone? zoneAt(Offset point, Size size) {
    final gc = Offset(size.width / 2, _goalCenterY(size));
    final dx = point.dx - gc.dx;
    final dy = point.dy - gc.dy;
    if (dy < -2) return null;

    final distance = (point - _sevenPoint(size)).distance;
    if (distance < size.width * 0.055) return CourtZone.siebenMeter;

    final radius = math.sqrt(dx * dx + dy * dy);
    if (radius <= _sixRadius(size)) return CourtZone.kreis;

    final angle = math.atan2(dx, math.max(dy, 0.1)) * 180 / math.pi;
    final abs = angle.abs();
    final left = angle < 0;
    if (abs <= 28) return CourtZone.rueckraumMitte;
    if (abs <= 62) {
      return left ? CourtZone.rueckraumLinks : CourtZone.rueckraumRechts;
    }
    return left ? CourtZone.aussenLinks : CourtZone.aussenRechts;
  }
}

class _CourtPainter extends CustomPainter {
  _CourtPainter({this.selectedZone, this.events = const []});

  final CourtZone? selectedZone;
  final List<MatchEvent> events;

  @override
  void paint(Canvas canvas, Size size) {
    final gc = Offset(size.width / 2, HandballCourt._goalCenterY(size));
    final r6 = HandballCourt._sixRadius(size);
    final r9 = HandballCourt._nineRadius(size);

    canvas.drawRect(Offset.zero & size, Paint()..color = ScfColors.courtFill);

    _paintSectors(canvas, size, gc, r6);
    _paintGoalArea(canvas, gc, r6);
    _paintLines(canvas, size, gc, r6, r9);
    _paintSevenMeterPoint(canvas, size);
    _paintShotMarkers(canvas, size, gc, r6);
  }

  double _phi(double thetaDeg) => (90 - thetaDeg) * math.pi / 180.0;

  void _paintSectors(Canvas canvas, Size size, Offset gc, double r6) {
    final sectors = <CourtZone, List<double>>{
      CourtZone.aussenLinks: const [-90.0, -62.0],
      CourtZone.rueckraumLinks: const [-62.0, -28.0],
      CourtZone.rueckraumMitte: const [-28.0, 28.0],
      CourtZone.rueckraumRechts: const [28.0, 62.0],
      CourtZone.aussenRechts: const [62.0, 90.0],
    };

    final rMax = math.sqrt(
      math.pow(size.width / 2 + 6, 2) + math.pow(size.height + 6, 2),
    );

    var index = 0;
    sectors.forEach((zone, range) {
      final isEven = index.isEven;
      index++;
      final isSel = selectedZone == zone;
      final fill = Paint()
        ..color = isSel
            ? ScfColors.accent.withValues(alpha: 0.55)
            : (isEven ? const Color(0xFF242E3B) : ScfColors.courtFill);

      final startPhi = _phi(range[0]);
      final sweep = _phi(range[1]) - startPhi;
      final path = Path()
        ..moveTo(gc.dx, gc.dy)
        ..arcTo(Rect.fromCircle(center: gc, radius: r6), startPhi, sweep, false)
        ..arcTo(
          Rect.fromCircle(center: gc, radius: rMax),
          startPhi + sweep,
          -sweep,
          false,
        )
        ..close();
      canvas.drawPath(path, fill);
    });
  }

  void _paintGoalArea(Canvas canvas, Offset gc, double r6) {
    final areaPath = Path()
      ..moveTo(gc.dx, gc.dy)
      ..arcTo(Rect.fromCircle(center: gc, radius: r6), 0, math.pi, false)
      ..close();

    if (selectedZone == CourtZone.kreis) {
      canvas.drawPath(
        areaPath,
        Paint()..color = ScfColors.accent.withValues(alpha: 0.45),
      );
    }
    canvas.drawPath(areaPath, Paint()..color = ScfColors.courtZoneFill.withValues(alpha: 0.35));
  }

  void _paintLines(Canvas canvas, Size size, Offset gc, double r6, double r9) {
    final line = Paint()
      ..color = ScfColors.courtLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final areaPath = Path()
      ..moveTo(gc.dx, gc.dy)
      ..arcTo(Rect.fromCircle(center: gc, radius: r6), 0, math.pi, false)
      ..close();
    canvas.drawPath(areaPath, line);

    _drawDashedArc(canvas, gc, r9, 0, math.pi, line..strokeWidth = 1.5);

    canvas.drawLine(
        Offset(0, size.height - 1), Offset(size.width, size.height - 1),
        line..strokeWidth = 1);
    canvas.drawLine(Offset(1, 0), Offset(1, size.height), line..strokeWidth = 1);
    canvas.drawLine(Offset(size.width - 1, 0), Offset(size.width - 1, size.height),
        line..strokeWidth = 1);
  }

  void _paintSevenMeterPoint(Canvas canvas, Size size) {
    final seven = HandballCourt._sevenPoint(size);
    final fill = Paint()
      ..color = selectedZone == CourtZone.siebenMeter
          ? ScfColors.accent
          : ScfColors.courtLine;
    canvas.drawCircle(seven, 6, fill);
  }

  void _paintShotMarkers(Canvas canvas, Size size, Offset gc, double r6) {
    final recent =
        events.length > 40 ? events.sublist(events.length - 40) : events;
    for (final event in recent) {
      final zone = event.courtZone;
      if (zone == null || zone == CourtZone.freiwurf) continue;
      final pos = _markerFor(zone, gc, r6, event.id.hashCode);
      final paint = Paint()
        ..color = switch (event.type) {
          MatchEventType.tor => ScfColors.success,
          MatchEventType.fehlwurf => ScfColors.danger,
          _ => ScfColors.textSecondary,
        };
      canvas.drawCircle(pos, 4.5, paint);
    }
  }

  Offset _markerFor(CourtZone zone, Offset gc, double r6, int seed) {
    double theta;
    double radius = r6 * 1.25;
    switch (zone) {
      case CourtZone.aussenLinks:
        theta = -75;
        break;
      case CourtZone.rueckraumLinks:
        theta = -45;
        break;
      case CourtZone.rueckraumMitte:
        theta = 0;
        break;
      case CourtZone.rueckraumRechts:
        theta = 45;
        break;
      case CourtZone.aussenRechts:
        theta = 75;
        break;
      case CourtZone.kreis:
        theta = 18;
        radius = r6 * 0.6;
        break;
      case CourtZone.siebenMeter:
        theta = 0;
        radius = r6 * 1.28;
        break;
      case CourtZone.freiwurf:
        theta = 0;
        radius = r6 * 1.5;
        break;
    }
    final jitterX = (seed % 9) - 4.0;
    final jitterY = ((seed ~/ 9) % 7) - 3.0;
    final rad = _phi(theta);
    return Offset(
      gc.dx + radius * math.sin(rad) + jitterX,
      gc.dy + radius * math.cos(rad) + jitterY,
    );
  }

  void _drawDashedArc(Canvas canvas, Offset center, double radius,
      double startAngle, double sweep, Paint paint) {
    const step = 0.16;
    final rect = Rect.fromCircle(center: center, radius: radius);
    var angle = startAngle;
    while (angle < startAngle + sweep) {
      final end = math.min(angle + step * 0.55, startAngle + sweep);
      canvas.drawArc(rect, angle, end - angle, false, paint);
      angle += step;
    }
  }

  @override
  bool shouldRepaint(covariant _CourtPainter oldDelegate) {
    return oldDelegate.selectedZone != selectedZone ||
        !identical(oldDelegate.events, events);
  }
}
