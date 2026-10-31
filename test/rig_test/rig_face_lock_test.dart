import 'dart:ui' as ui;

import 'package:everlore/debug/rig_test/rig_art.dart';
import 'package:everlore/debug/rig_test/rig_deform.dart';
import 'package:everlore/debug/rig_test/rig_manifest.dart';
import 'package:everlore/debug/rig_test/rig_quality.dart';
import 'package:everlore/debug/rig_test/rig_tuning.dart';
import 'package:flutter_test/flutter_test.dart';

// The base painting: the crop rig.json has (the hair join tests use the same
// numbers, and the same anchors: neck 512, 650 and waist 512, 1536).
const _base = RigLayerSpec(
  name: 'base',
  file: 'base.png',
  group: 'body',
  x: 91,
  y: 85,
  w: 852,
  h: 1451,
);

const _deformer = RigDeformer(
  RigGeometry(neck: Offset(512, 650), waist: Offset(512, 1536)),
);

/// One face layer: a crop of a canvas edit, drawn over the base.
class _Face {
  const _Face(this.spec, this.part);

  final RigLayerSpec spec;
  final RigPart part;
}

/// The face layers' crops. rig.json lives in the debug screen's folder on the
/// device, not in this repo, so no test reads it: these are stand-ins at the
/// extent of the real crops — the brow-to-blush band for a patch, the eye band
/// for the eye drawings, the lips' box for a mouth. All of them sit inside the
/// face ellipse (centre 520, 410; radii 170, 215), which is where the base
/// painting's depth is flat; a crop reaching past it would be compared against
/// a depth the base's coarse mesh only chords (see the report).
const _faces = [
  _Face(RigLayerSpec(name: 'face_happy', file: 'face_happy.png', group: 'face',
      x: 388, y: 352, w: 264, h: 128), RigPart.patch),
  _Face(RigLayerSpec(name: 'face_shy', file: 'face_shy.png', group: 'face',
      x: 376, y: 352, w: 288, h: 148), RigPart.patch),
  _Face(RigLayerSpec(name: 'face_surprised', file: 'face_surprised.png',
      group: 'face', x: 380, y: 344, w: 280, h: 152), RigPart.patch),
  _Face(RigLayerSpec(name: 'mouth_open', file: 'mouth_open.png', group: 'mouth',
      x: 455, y: 495, w: 130, h: 80), RigPart.mouth),
  _Face(RigLayerSpec(name: 'mouth_open_happy', file: 'mouth_open_happy.png',
      group: 'mouth', x: 455, y: 495, w: 130, h: 80), RigPart.mouth),
  _Face(RigLayerSpec(name: 'mouth_open_shy', file: 'mouth_open_shy.png',
      group: 'mouth', x: 455, y: 495, w: 130, h: 80), RigPart.mouth),
  _Face(RigLayerSpec(name: 'mouth_open_surprised',
      file: 'mouth_open_surprised.png', group: 'mouth',
      x: 455, y: 495, w: 130, h: 80), RigPart.mouth),
  _Face(RigLayerSpec(name: 'eyes_half', file: 'eyes_half.png', group: 'eyes',
      x: 400, y: 380, w: 240, h: 90), RigPart.eyes),
  _Face(RigLayerSpec(name: 'eyes_closed', file: 'eyes_closed.png',
      group: 'eyes', x: 400, y: 380, w: 240, h: 90), RigPart.eyes),
  _Face(RigLayerSpec(name: 'eyes_glance_left', file: 'eyes_glance_left.png',
      group: 'eyes', x: 390, y: 380, w: 260, h: 90), RigPart.eyes),
  _Face(RigLayerSpec(name: 'eyes_glance_right', file: 'eyes_glance_right.png',
      group: 'eyes', x: 390, y: 380, w: 260, h: 90), RigPart.eyes),
];

Future<ui.Image> _solid(int w, int h) {
  final rec = ui.PictureRecorder();
  ui.Canvas(rec).drawRect(
    ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    ui.Paint()..color = const ui.Color(0xFFAA8866),
  );
  return rec.endRecording().toImage(w, h);
}

Future<RigLayerArt> _build(_Face face, RigQuality quality) async =>
    RigLayerArt.build(
      spec: face.spec,
      part: face.part,
      image: await _solid(2, 2),
      deformer: _deformer,
      quality: quality,
      // Only the base's mesh reads it: the row the long hair takes over (the
      // hair layers themselves derive their joins from their own crops).
      hairJoinY: 600,
    );

/// Every pose the sim can reach, at and past each limit.
List<RigPose> _poses() => [
      for (final headX in const [-0.15, -0.08, 0.0, 0.08, 0.15])
        for (final headY in const [-0.04, 0.0, 0.06, 0.12])
          for (final tilt in const [-0.03, 0.0, 0.03])
            for (final bodyX in const [-0.3, 0.0, 0.3])
              for (final breath in const [0.0, 1.0])
                RigPose()
                  ..headX = headX
                  ..headY = headY
                  ..headTilt = tilt
                  ..bodyX = bodyX
                  ..breath = breath,
    ];

/// The position the GPU draws at canvas point (x, y) of layer [a]: the deformed
/// corners of the cell it falls in, interpolated inside the triangle the point
/// is in. The hardware is affine inside each of a cell's two triangles, not
/// bilinear, and a cell is split from (i + 1, j) to (i, j + 1).
Offset _drawn(RigLayerArt a, RigPose pose, double x, double y) {
  final m = a.mesh;
  final head = m.cols + 1;
  // Neither axis is evenly spaced (the base is finer across the face), so the
  // cell is found by its edges.
  double xAt(int i) => m.rest[i * 2];
  double yAt(int j) => m.rest[j * head * 2 + 1];
  var i = 0;
  while (i < m.cols - 1 && x > xAt(i + 1)) {
    i++;
  }
  var j = 0;
  while (j < m.rows - 1 && y > yAt(j + 1)) {
    j++;
  }
  final fu = ((x - xAt(i)) / (xAt(i + 1) - xAt(i))).clamp(0.0, 1.0);
  final fv = ((y - yAt(j)) / (yAt(j + 1) - yAt(j))).clamp(0.0, 1.0);
  Offset corner(int r, int c) {
    final k = r * head + c;
    return _deformer.deform(
      Offset(m.rest[k * 2], m.rest[k * 2 + 1]),
      pose,
      depth: a.depth[k],
    );
  }

  final tl = corner(j, i);
  final tr = corner(j, i + 1);
  final bl = corner(j + 1, i);
  final br = corner(j + 1, i + 1);
  if (fu + fv <= 1) return tl + (tr - tl) * fu + (bl - tl) * fv;
  return br + (bl - br) * (1 - fu) + (tr - br) * (1 - fv);
}

Offset _rest(RigLayerArt a, int v) =>
    Offset(a.mesh.rest[v * 2], a.mesh.rest[v * 2 + 1]);

String _pose(RigPose p) =>
    'headX ${p.headX} headY ${p.headY} tilt ${p.headTilt} '
    'bodyX ${p.bodyX} breath ${p.breath}';

void main() {
  testWidgets('every face layer has the base painting\'s depth at each vertex', (
    tester,
  ) async {
    await tester.runAsync(() async {
      for (final quality in RigQuality.values) {
        for (final face in _faces) {
          final layer = await _build(face, quality);
          for (var v = 0; v < layer.mesh.vertexCount; v++) {
            final p = _rest(layer, v);
            expect(
              layer.depth[v],
              closeTo(_deformer.baseDepth(p), 1e-6),
              reason: '${quality.name} ${face.spec.name} at $p',
            );
            // The face is where the field is flat, so this also says the whole
            // patch is on skin (a crop that left the face would be a different
            // question: the base's mesh only chords the falloff there).
            expect(
              layer.depth[v],
              RigTuning.depthFace,
              reason: '${quality.name} ${face.spec.name} at $p is on the face',
            );
          }
          layer.dispose();
        }
      }
    });
  });

  testWidgets('a face layer draws where the base painting draws, within 0.25 px', (
    tester,
  ) async {
    await tester.runAsync(() async {
      for (final quality in RigQuality.values) {
        final base = await _build(
          const _Face(_base, RigPart.base),
          quality,
        );
        var worst = 0.0;
        var at = '';
        for (final face in _faces) {
          final layer = await _build(face, quality);
          for (final pose in _poses()) {
            for (var v = 0; v < layer.mesh.vertexCount; v++) {
              final p = _rest(layer, v);
              final own = _deformer.deform(p, pose, depth: layer.depth[v]);
              final under = _drawn(base, pose, p.dx, p.dy);
              final d = (own - under).distance;
              if (d > worst) {
                worst = d;
                at = '${quality.name} ${face.spec.name} at $p ${_pose(pose)}';
              }
            }
          }
          layer.dispose();
        }
        base.dispose();
        expect(
          worst,
          lessThanOrEqualTo(0.25),
          reason: 'the worst face vertex drifts off the base: $at',
        );
      }
    });
  });

  testWidgets('a glance never moves the eye drawing off the face', (
    tester,
  ) async {
    await tester.runAsync(() async {
      // The nudge is the only thing that could move it, and it is off: a patch
      // that slides even a pixel shows its edges against the painting.
      expect(RigTuning.glanceNudgePx, 0);
      for (final quality in RigQuality.values) {
        final base = await _build(const _Face(_base, RigPart.base), quality);
        for (final face in _faces.where(
          (f) => f.spec.name.startsWith('eyes_glance'),
        )) {
          final layer = await _build(face, quality);
          for (final pose in _poses()) {
            // A glance lit as far as it goes: eyeX is the nudge's full value.
            pose.eyeX = 1;
            for (var v = 0; v < layer.mesh.vertexCount; v++) {
              final p = _rest(layer, v);
              final own = _deformer.deform(
                p,
                pose,
                depth: layer.depth[v],
                localDx: pose.eyeX * RigTuning.glanceNudgePx,
              );
              final under = _drawn(base, pose, p.dx, p.dy);
              expect(
                (own - under).distance,
                lessThanOrEqualTo(0.25),
                reason: '${quality.name} ${face.spec.name} at $p ${_pose(pose)}',
              );
            }
          }
          layer.dispose();
        }
        base.dispose();
      }
    });
  });
}
