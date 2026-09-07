import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/nexus_theme.dart';

/// How long the curtain may stay down for a painting that will not come.
///
/// A single unreachable plate used to keep the gate shut forever. The
/// surfaces already know how to stand on bare ground; past this the player
/// is staring at a sigil for a face that was never going to arrive.
const worldFrameCeiling = Duration(seconds: 8);

/// Holds the curtain until the first frame can actually paint.
///
/// Words arrive before paintings. Showing the room on the words alone
/// leaves the player watching a dark frame fill in, and on a cold opening
/// the map is an empty grid. Only the land in front of them belongs here —
/// waiting on the whole world is a minute of a sigil.
///
/// [cutouts] must be warmed at [cutoutMaxHeight] because that is the
/// decode size the standing figures use. Any other height stocks a shelf
/// the room will not paint from.
Future<void> awaitWorldFrame(
  BuildContext context, {
  Iterable<String?> urls = const [],
  Iterable<String?> cutouts = const [],
  int? cutoutMaxHeight,
}) async {
  if (!context.mounted) return;
  final jobs = <Future<void>>[
    for (final url in _unique(urls)) _warm(context, url),
    for (final url in _unique(cutouts))
      _warm(context, url, maxHeight: cutoutMaxHeight),
  ];
  if (jobs.isEmpty) return;
  try {
    await Future.wait(jobs).timeout(worldFrameCeiling);
  } on TimeoutException {
    // One slow painting used to hold the whole opening. Arriving on a
    // fallback is better than never arriving.
  } catch (_) {
    // A thrown wait must not leave the sigil up after the world has failed.
  }
}

/// The same provider the world's paintings resolve. A different one here
/// would warm a shelf the widgets never read, and the gate would still
/// open onto an empty grid.
Future<void> _warm(
  BuildContext context,
  String url, {
  int? maxWidth,
  int? maxHeight,
}) async {
  if (!context.mounted) return;
  try {
    await precacheImage(
      CachedNetworkImageProvider(
        url,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      ),
      context,
    );
  } catch (_) {
    // The surface already degrades to a dignified absence. Treating a
    // missing painting as a hang is how a vanished file became a locked world.
  }
}

Iterable<String> _unique(Iterable<String?> urls) {
  final seen = <String>{};
  for (final url in urls) {
    if (url != null && url.isNotEmpty) seen.add(url);
  }
  return seen;
}

/// A small, quiet orbit for a wait that is not a whole screen.
///
/// A machine's wheel on the parchment is a crack in the fiction. The
/// same beads as the gate, kept small, are someone thinking.
class WorldStill extends StatefulWidget {
  const WorldStill({
    super.key,
    this.size = 16,
    this.color = EverloreTheme.goldDim,
  });

  final double size;
  final Color color;

  @override
  State<WorldStill> createState() => _WorldStillState();
}

class _WorldStillState extends State<WorldStill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _orbit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  @override
  void dispose() {
    _orbit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _orbit,
        builder: (context, _) => CustomPaint(
          painter: _StillPainter(orbit: _orbit.value, color: widget.color),
        ),
      ),
    );
  }
}

class _StillPainter extends CustomPainter {
  const _StillPainter({required this.orbit, required this.color});

  final double orbit;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide / 2 - 1.2;
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = color.withValues(alpha: 0.28),
    );
    const beads = 2;
    for (var i = 0; i < beads; i++) {
      final angle = orbit * 2 * math.pi + (i / beads) * 2 * math.pi;
      final pos = Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
      canvas.drawCircle(
        pos,
        i.isEven ? 1.8 : 1.3,
        Paint()..color = color.withValues(alpha: i.isEven ? 0.9 : 0.55),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StillPainter old) =>
      old.orbit != orbit || old.color != color;
}
