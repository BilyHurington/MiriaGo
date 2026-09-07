import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../app_theme.dart';

typedef NavigationHeadingStreamFactory =
    Stream<double?> Function(LatLng position);

Stream<double?> nativeNavigationHeading(LatLng position) {
  if (kIsWeb ||
      (defaultTargetPlatform != TargetPlatform.android &&
          defaultTargetPlatform != TargetPlatform.iOS)) {
    return const Stream.empty();
  }
  return const EventChannel('miriago/map_heading')
      .receiveBroadcastStream({
        'latitude': position.latitude,
        'longitude': position.longitude,
      })
      .map((value) => value is num ? value.toDouble() : null);
}

double? normalizedHeading(double? value) =>
    value == null || !value.isFinite || value < 0 || value >= 360
    ? null
    : value;

double shortestHeadingDelta(double from, double to) =>
    (to - from + 540) % 360 - 180;

class NavigationHeading extends ValueNotifier<double?> {
  NavigationHeading({this.staleAfter = const Duration(seconds: 30)})
    : super(null);
  final Duration staleAfter;
  StreamSubscription<double?>? _subscription;
  Future<void> _cancelled = Future<void>.value();
  Timer? _expiry;
  int _generation = 0;
  bool _disposed = false;

  void start(Stream<double?> Function() source) {
    stop();
    final generation = _generation;
    unawaited(_start(source, generation));
  }

  Future<void> _start(Stream<double?> Function() source, int generation) async {
    await _cancelled;
    if (_disposed || generation != _generation) return;
    try {
      _subscription = source().listen(
        (heading) {
          if (_disposed || generation != _generation) return;
          _expiry?.cancel();
          final normalized = normalizedHeading(heading);
          if (normalized == null) {
            value = null;
            return;
          }
          final previous = value;
          // Unwrapped turns take the short path across north instead of spinning.
          value = previous == null
              ? normalized / 360
              : previous +
                    shortestHeadingDelta(previous * 360, normalized) / 360;
          _expiry = Timer(staleAfter, () {
            if (!_disposed && generation == _generation) value = null;
          });
        },
        onError: (Object _) {
          if (!_disposed && generation == _generation) value = null;
        },
        onDone: () {
          if (!_disposed && generation == _generation) value = null;
        },
      );
    } catch (_) {
      if (!_disposed && generation == _generation) value = null;
    }
  }

  void stop() {
    ++_generation;
    _expiry?.cancel();
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) {
      _cancelled = subscription.cancel().catchError((Object _) {});
    }
    // Lifecycle methods can run during build; let the next frame clear the cue.
    scheduleMicrotask(() {
      if (!_disposed && _subscription == null) value = null;
    });
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    super.dispose();
  }
}

class NavigationLocationPuck extends StatelessWidget {
  const NavigationLocationPuck({
    required this.heading,
    this.stale = false,
    super.key,
  });
  final ValueListenable<double?> heading;
  final bool stale;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double?>(
      valueListenable: heading,
      builder: (context, turns, _) {
        final color = stale ? Colors.grey : AppColors.accent;
        return Semantics(
          label: stale
              ? '上次定位，等待更新'
              : turns == null
              ? '当前位置，朝向不可用'
              : '当前位置，手机朝向',
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (turns != null && !stale)
                AnimatedRotation(
                  key: const ValueKey('navigation-heading-sector'),
                  turns: turns,
                  duration: const Duration(milliseconds: 180),
                  child: CustomPaint(
                    size: const Size(56, 56),
                    painter: _HeadingSector(color),
                  ),
                ),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.18),
                ),
              ),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  border: Border.all(color: Colors.white, width: 3),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeadingSector extends CustomPainter {
  const _HeadingSector(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawArc(
      Offset.zero & size,
      -math.pi * 0.7,
      math.pi * 0.4,
      true,
      Paint()..color = color.withValues(alpha: 0.4),
    );
  }

  @override
  bool shouldRepaint(_HeadingSector oldDelegate) => oldDelegate.color != color;
}
