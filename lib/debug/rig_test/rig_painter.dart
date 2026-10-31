import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'rig_art.dart';
import 'rig_quality.dart';
import 'rig_sim.dart';
import 'rig_tuning.dart';

/// Draws the character in either mode. One painter, repainted by the sim's
/// notifications: one repaint per frame, no widget rebuilds.
class RigPainter extends CustomPainter {
  RigPainter({required this.art, required this.sim}) : super(repaint: sim);

  final RigArtSet art;
  final RigSim sim;

  // 256 alpha filters made lazily: a `modulate` filter scales the layer's
  // colour and alpha, which is how a layer fades without a saveLayer per layer.
  static final List<ColorFilter?> _alphaFilters = List.filled(256, null);
  final Paint _paint = Paint()..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    final m = art.manifest;
    // Fill the height, centre the width (the canvas is wider than a phone).
    final scale = size.height / m.canvasH;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate((size.width - m.canvasW * scale) / 2, 0);
    canvas.scale(scale);

    final mesh = sim.mode == RigMode.mesh;
    void layer(RigLayerArt a, double alpha, {double nudge = 0}) {
      if (alpha <= 0.004) return;
      mesh ? _drawMesh(canvas, a, alpha, nudge) : _drawFlat(canvas, a);
    }

    layer(art.base, 1);
    if (sim.outfit) layer(art.outfit, 1);

    // One expression drawing at a time: the one on the face, at full opacity.
    // Two patches on screen at once is what read as a doubled, pixelated face,
    // so the switch is a cut under a closed-eyed cover blink, never a fade.
    final shown = sim.expression.shown;
    final patch = art.patches[shown];
    if (patch != null) layer(patch, sim.patchAlpha(shown));
    layer(art.mouths[shown]!, sim.mouthAlpha(shown));

    // Eyes: one drawing at full opacity, chosen by the eye state. OPEN draws
    // nothing — the face under it already carries open eyes — and the glance
    // layers take the little nudge that follows the switch.
    final nudge = sim.pose.eyeX * RigTuning.glanceNudgePx;
    layer(art.glanceLeft, sim.glanceAlpha(right: false), nudge: nudge);
    layer(art.glanceRight, sim.glanceAlpha(right: true), nudge: nudge);
    layer(art.eyesHalf, sim.halfAlpha);
    layer(art.eyesClosed, sim.closedAlpha);

    layer(art.hairLong, 1);
    layer(art.hairFront, 1);
    canvas.restore();
  }

  void _drawFlat(Canvas canvas, RigLayerArt a) {
    _paint
      ..colorFilter = null
      ..filterQuality = art.quality.filterQuality;
    // A rect, not an offset: the texture may have been decoded smaller than
    // its crop of the canvas.
    canvas.drawImageRect(
      a.image,
      Rect.fromLTWH(0, 0, a.image.width.toDouble(), a.image.height.toDouble()),
      Rect.fromLTWH(a.spec.x, a.spec.y, a.spec.w, a.spec.h),
      _paint,
    );
  }

  void _drawMesh(Canvas canvas, RigLayerArt a, double alpha, double nudge) {
    final mesh = a.mesh;
    final pos = a.positions;
    final rest = mesh.rest;
    final pose = sim.pose;
    final deformer = art.deformer;
    final long = a.part == RigPart.hairLong;
    final hair = long || a.part == RigPart.hairFront;
    final lag = sim.longHairLag;
    for (var i = 0; i < mesh.vertexCount; i++) {
      final o = deformer.deform(
        Offset(rest[i * 2], rest[i * 2 + 1]),
        pose,
        depth: a.depth[i],
        lagWeight: a.lagWeight[i],
        lagX: !hair ? 0 : (long ? lag[a.column[i]] : sim.frontHairLag),
        localDx: nudge,
      );
      pos[i * 2] = o.dx;
      pos[i * 2 + 1] = o.dy;
    }
    final vertices = ui.Vertices.raw(
      ui.VertexMode.triangles,
      pos,
      textureCoordinates: mesh.tex,
      indices: mesh.indices,
    );
    _paint
      ..shader = a.shader
      ..colorFilter = _filterFor(alpha);
    canvas.drawVertices(vertices, BlendMode.srcOver, _paint);
    _paint.shader = null;
    vertices.dispose();
  }

  ColorFilter? _filterFor(double alpha) {
    final k = (alpha.clamp(0.0, 1.0) * 255).round();
    if (k >= 255) return null;
    return _alphaFilters[k] ??=
        ColorFilter.mode(Color.fromARGB(k, 255, 255, 255), BlendMode.modulate);
  }

  @override
  bool shouldRepaint(RigPainter old) => old.art != art || old.sim != sim;
}
