import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:everlore/debug/rig_test/rig_art.dart';
import 'package:everlore/debug/rig_test/rig_deform.dart';
import 'package:everlore/debug/rig_test/rig_expression.dart';
import 'package:everlore/debug/rig_test/rig_manifest.dart';
import 'package:everlore/debug/rig_test/rig_painter.dart';
import 'package:everlore/debug/rig_test/rig_quality.dart';
import 'package:everlore/debug/rig_test/rig_sim.dart';
import 'package:everlore/debug/rig_test/rig_tuning.dart';
import 'package:flutter_test/flutter_test.dart';

// A stand-in character whose brow drawings are each a flat colour of its own,
// and whose bangs are another flat colour over the brow band. A painted pixel
// then says exactly which layer landed on the face: the brow's colour means the
// brows are drawn above the hair, the hair's means they are not.
//
// The canvas is 400 x 600 and painted at that size, so canvas pixels are screen
// pixels. The bangs cover x 100..320, y 110..180, and the brow crops sit inside
// that band, so the sample point (170, 149) is under the hair until a brow
// layer covers it.
const _baseColour = 0xFF101418;
const _hair = 0xFF303030;
const _neutralBrows = 0xFFE00000;
const _happyBrows = 0xFF00C000;
const _shyBrows = 0xFF0040E0;
const _surprisedBrows = 0xFFE0C000;

const _layers = <String, (double, double, double, double, int)>{
  'base': (0, 0, 400, 600, _baseColour),
  'outfit_blazer': (20, 400, 300, 180, 0xFF201810),
  'face_happy': (110, 140, 100, 60, 0xFF2A2020),
  'face_shy': (110, 140, 100, 60, 0xFF2A2020),
  'face_surprised': (110, 140, 100, 60, 0xFF2A2020),
  'mouth_open': (150, 225, 40, 20, 0xFF3A2020),
  'mouth_open_happy': (150, 225, 40, 20, 0xFF3A2020),
  'mouth_open_shy': (150, 225, 40, 20, 0xFF3A2020),
  'mouth_open_surprised': (150, 225, 40, 20, 0xFF3A2020),
  'eyes_half': (110, 150, 100, 55, 0xFF804080),
  'eyes_closed': (110, 145, 100, 55, 0xFF602060),
  'eyes_closed_happy': (110, 145, 100, 55, 0xFF602060),
  'eyes_closed_shy': (110, 145, 100, 55, 0xFF602060),
  'eyes_closed_surprised': (110, 145, 100, 55, 0xFF602060),
  'eyes_glance_left': (110, 150, 100, 55, 0xFF604060),
  'eyes_glance_right': (110, 150, 100, 55, 0xFF604060),
  'hair_long': (0, 320, 400, 280, _hair),
  // The bangs cover the brow band, the way the real painting does.
  'hair_front': (100, 110, 220, 70, _hair),
  'brows': (130, 138, 80, 22, _neutralBrows),
  'brows_happy': (130, 138, 80, 22, _happyBrows),
  'brows_shy': (130, 138, 80, 22, _shyBrows),
  'brows_surprised': (130, 138, 80, 22, _surprisedBrows),
};

const _sampleX = 170;
const _sampleY = 149;
const _size = ui.Size(400, 600);

bool _included(
  String name, {
  required bool perFaceBrows,
  required bool anyBrows,
}) {
  if (name.startsWith('brows')) {
    if (!anyBrows) return false;
    return name == 'brows' || perFaceBrows;
  }
  return true;
}

List<RigLayerSpec> _specs({
  required bool perFaceBrows,
  required bool anyBrows,
}) =>
    [
      for (final e in _layers.entries)
        if (_included(e.key, perFaceBrows: perFaceBrows, anyBrows: anyBrows))
          RigLayerSpec(
            name: e.key,
            file: '${e.key}.png',
            group: 'x',
            x: e.value.$1,
            y: e.value.$2,
            w: e.value.$3,
            h: e.value.$4,
          ),
    ];

RigManifest _manifest({
  required bool perFaceBrows,
  required bool anyBrows,
}) =>
    RigManifest(
      canvasW: _size.width,
      canvasH: _size.height,
      anchors: const {
        'neck': ui.Offset(200, 260),
        'waist': ui.Offset(200, 600),
      },
      layers: _specs(perFaceBrows: perFaceBrows, anyBrows: anyBrows),
    );

Future<ui.Image> _solid(int w, int h, int argb) {
  final rec = ui.PictureRecorder();
  ui.Canvas(rec).drawRect(
    ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    ui.Paint()..color = ui.Color(argb),
  );
  return rec.endRecording().toImage(w, h);
}

/// A set built in memory, the way a decoded pack would be.
Future<RigArtSet> _fakeArt({
  bool perFaceBrows = true,
  bool anyBrows = true,
}) async {
  final manifest = _manifest(perFaceBrows: perFaceBrows, anyBrows: anyBrows);
  final images = {
    for (final l in manifest.layers)
      l.file: await _solid(l.w.round(), l.h.round(), _layers[l.name]!.$5),
  };
  return RigArtSet.build(manifest, images);
}

/// Writes a pack (rig.json + the PNGs) the way the orchestrator pushes one, so
/// the real loader can be asked about all three brow shapes.
Future<void> _writePack(
  Directory dir, {
  required bool perFaceBrows,
  required bool anyBrows,
}) async {
  final manifest = _manifest(perFaceBrows: perFaceBrows, anyBrows: anyBrows);
  for (final l in manifest.layers) {
    final image = await _solid(l.w.round(), l.h.round(), _layers[l.name]!.$5);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    await File('${dir.path}/${l.file}').writeAsBytes(png!.buffer.asUint8List());
  }
  await File('${dir.path}/rig.json').writeAsString(jsonEncode({
    'canvas': {'w': manifest.canvasW, 'h': manifest.canvasH},
    'anchors': {
      for (final e in manifest.anchors.entries) e.key: [e.value.dx, e.value.dy],
    },
    'layers': [
      for (final l in manifest.layers)
        {
          'name': l.name,
          'file': l.file,
          'group': l.group,
          'x': l.x,
          'y': l.y,
          'w': l.w,
          'h': l.h,
        },
    ],
  }));
}

/// The colour the painter leaves at the brow's centre this frame.
Future<int> _painted(RigPainter painter) async {
  final rec = ui.PictureRecorder();
  painter.paint(ui.Canvas(rec), _size);
  final pic = rec.endRecording();
  final image = await pic.toImage(_size.width.round(), _size.height.round());
  pic.dispose();
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  final b = bytes!;
  final i = (_sampleY * _size.width.round() + _sampleX) * 4;
  return (b.getUint8(i + 3) << 24) |
      (b.getUint8(i) << 16) |
      (b.getUint8(i + 1) << 8) |
      b.getUint8(i + 2);
}

/// Runs the sim until the expression cover blink is over.
void _settle(RigSim sim) {
  while (sim.expression.covering) {
    sim.update(1 / 60);
  }
}

void main() {
  testWidgets('the brows are drawn above the hair', (tester) async {
    await tester.runAsync(() async {
      final art = await _fakeArt();
      addTearDown(art.dispose);
      final sim = RigSim(deformer: art.deformer);
      sim.update(1 / 60);
      expect(sim.expression.shown, RigExpression.neutral);
      expect(art.browsFor(RigExpression.neutral), isNotNull);

      final painted = await _painted(RigPainter(art: art, sim: sim));
      expect(painted, _neutralBrows,
          reason: 'the brow colour is on top; the bangs cover the same point');
      expect(painted, isNot(_hair), reason: 'the brows are not under the hair');
    });
  });

  testWidgets('a cover blink swaps the brows at its midpoint, never both',
      (tester) async {
    await tester.runAsync(() async {
      final art = await _fakeArt();
      addTearDown(art.dispose);
      final sim = RigSim(deformer: art.deformer);
      sim.update(1 / 60);
      expect(sim.expression.shown, RigExpression.neutral);

      sim.expression.set(RigExpression.surprised);
      final painter = RigPainter(art: art, sim: sim);
      var before = 0;
      var after = 0;
      final seen = <int>{};
      // The cover's shut hold is 0.09 s, five frames at 60 fps.
      for (var i = 0; i < 5; i++) {
        sim.update(1 / 60);
        expect(sim.eyeState, RigEyeState.closed, reason: 'frame $i: covered');
        final colour = await _painted(painter);
        seen.add(colour);
        if (sim.expression.shown == RigExpression.neutral) {
          expect(colour, _neutralBrows,
              reason: 'frame $i: the old face\'s brows');
          before++;
        } else {
          expect(sim.expression.shown, RigExpression.surprised);
          expect(colour, _surprisedBrows,
              reason: 'frame $i: the new face\'s brows');
          after++;
        }
      }
      expect(before, greaterThan(0), reason: 'frames before the midpoint');
      expect(after, greaterThan(0), reason: 'frames after it');
      expect(seen, {_neutralBrows, _surprisedBrows},
          reason: 'one drawing a frame: the two never blend');
    });
  });

  testWidgets('a natural blink on surprised keeps that face\'s brows',
      (tester) async {
    await tester.runAsync(() async {
      final art = await _fakeArt();
      addTearDown(art.dispose);
      final sim = RigSim(deformer: art.deformer)..nextExpression();
      // neutral -> happy -> shy -> surprised.
      sim.nextExpression();
      sim.nextExpression();
      _settle(sim);
      expect(sim.expression.shown, RigExpression.surprised);

      // A natural blink comes 2-6 s apart. Brows are above the hair and eyes, so
      // the lids changing never moves or changes them.
      var frames = 0;
      while (sim.eyeState != RigEyeState.closed && frames++ < 60 * 40) {
        sim.update(1 / 60);
      }
      expect(sim.eyeState, RigEyeState.closed, reason: 'it blinked');
      expect(sim.browsAlpha(RigExpression.surprised), 1);
      expect(await _painted(RigPainter(art: art, sim: sim)), _surprisedBrows,
          reason: 'the blink left the brow on the face');
    });
  });

  testWidgets('a pack without per-face brows uses the neutral drawing',
      (tester) async {
    await tester.runAsync(() async {
      final art = await _fakeArt(perFaceBrows: false);
      addTearDown(art.dispose);
      expect(
        identical(
          art.browsFor(RigExpression.neutral),
          art.browsFor(RigExpression.happy),
        ),
        isTrue,
        reason: 'no happy drawing in this pack, so the neutral brows serve',
      );

      final sim = RigSim(deformer: art.deformer)..nextExpression(); // happy
      _settle(sim);
      expect(sim.expression.shown, RigExpression.happy);
      expect(await _painted(RigPainter(art: art, sim: sim)), _neutralBrows,
          reason: 'the only brows this pack has');
    });
  });

  testWidgets('a pack with no brows draws none, and the hair shows through',
      (tester) async {
    await tester.runAsync(() async {
      final art = await _fakeArt(anyBrows: false);
      addTearDown(art.dispose);
      for (final e in RigExpression.values) {
        expect(art.browsFor(e), isNull, reason: '${e.name} has no brows');
      }

      final sim = RigSim(deformer: art.deformer);
      sim.update(1 / 60);
      expect(await _painted(RigPainter(art: art, sim: sim)), _hair,
          reason: 'no brow layer, so the bangs above are what is seen');
    });
  });

  testWidgets('the loader takes a pack with brows, one per face only, and none',
      (tester) async {
    await tester.runAsync(() async {
      final cases = [
        (perFaceBrows: true, anyBrows: true),
        (perFaceBrows: false, anyBrows: true),
        (perFaceBrows: false, anyBrows: false),
      ];
      for (final c in cases) {
        final dir = await Directory.systemTemp.createTemp('rig_brows_');
        addTearDown(() => dir.delete(recursive: true));
        await _writePack(dir,
            perFaceBrows: c.perFaceBrows, anyBrows: c.anyBrows);

        final art = await loadRigArt(dir);
        final neutral = art.browsFor(RigExpression.neutral);
        final happy = art.browsFor(RigExpression.happy);
        final name = 'perFace ${c.perFaceBrows} any ${c.anyBrows}';
        if (!c.anyBrows) {
          expect(neutral, isNull, reason: name);
          expect(happy, isNull, reason: name);
        } else {
          expect(neutral, isNotNull, reason: name);
          expect(happy, isNotNull, reason: name);
          expect(
            happy!.spec.file,
            c.perFaceBrows ? 'brows_happy.png' : 'brows.png',
            reason: name,
          );
          expect(identical(happy, neutral), !c.perFaceBrows,
              reason: '$name: the fallback is the same drawing');
        }
        // Disposing a fallback set must not dispose the shared drawing twice.
        art.dispose();
      }
    });
  });

  testWidgets('a brow vertex stays on the face under a look away and a look down',
      (tester) async {
    await tester.runAsync(() async {
      for (final quality in RigQuality.values) {
        final base = RigLayerArt.build(
          spec: _baseSpec,
          part: RigPart.base,
          image: await _solid(2, 2, _baseColour),
          deformer: _lockDeformer,
          quality: quality,
          hairJoinY: 600,
        );
        final brow = RigLayerArt.build(
          spec: _browSpec,
          part: RigPart.brows,
          image: await _solid(2, 2, _neutralBrows),
          deformer: _lockDeformer,
          quality: quality,
          hairJoinY: 600,
        );

        // The brows take the face's depth, not the bangs' — that is the whole
        // fix: the bangs (1.08) slide a little apart from the face (1.0).
        for (var v = 0; v < brow.mesh.vertexCount; v++) {
          final p = _rest(brow, v);
          expect(brow.depth[v], closeTo(_lockDeformer.baseDepth(p), 1e-6));
          expect(brow.depth[v], closeTo(RigTuning.depthFace, 1e-6),
              reason: '${quality.name}: the brow crop is on the face');
        }

        var worst = 0.0;
        var at = '';
        for (final pose in _poses()) {
          for (var v = 0; v < brow.mesh.vertexCount; v++) {
            final p = _rest(brow, v);
            final own = _lockDeformer.deform(p, pose, depth: brow.depth[v]);
            final under = _drawn(base, pose, p.dx, p.dy);
            final d = (own - under).distance;
            if (d > worst) {
              worst = d;
              at = '${quality.name} at $p ${_pose(pose)}';
            }
          }
        }
        base.dispose();
        brow.dispose();
        expect(worst, lessThanOrEqualTo(0.05),
            reason: 'the brows drift off the face: worst $worst at $at');
      }
    });
  });
}

// ---- The depth lock, built with its own crop and deformer -------------------

const _baseSpec = RigLayerSpec(
  name: 'base',
  file: 'base.png',
  group: 'body',
  x: 0,
  y: 0,
  w: 400,
  h: 600,
);

/// A brow crop inside the face ellipse, around the brow band. It stays within
/// the head's central fifth either side of the face centre, where a turn does
/// not squeeze the face (the squeeze only starts past |u| = 0.2). Inside that
/// band the base painting's mesh interpolates the face's motion exactly, so the
/// comparison is about the brow's depth alone, not the base's cell size.
const _browSpec = RigLayerSpec(
  name: 'brows',
  file: 'brows.png',
  group: 'brows',
  x: 180,
  y: 180,
  w: 40,
  h: 24,
);

/// A head whose face ellipse (centre 200, 220; radii 110, 150) contains the brow
/// crop, so the base painting's depth is flat there and the face moves rigidly.
const _lockDeformer = RigDeformer(
  RigGeometry(
    neck: Offset(200, 380),
    waist: Offset(200, 600),
    headCenter: Offset(200, 220),
    headRadii: Offset(110, 150),
    jawY: 350,
  ),
);

/// The poses the sim can reach around the brow: a look away each way and a look
/// down, with the torso's small share. Breath at rest keeps the face rigid.
List<RigPose> _poses() => [
      for (final headX in const [-0.08, 0.0, 0.08])
        for (final headY in const [0.0, 0.04, 0.12])
          for (final tilt in const [-0.008, 0.0, 0.008])
            RigPose()
              ..headX = headX
              ..headY = headY
              ..headTilt = tilt
              ..bodyX = 0.05,
    ];

Offset _rest(RigLayerArt a, int v) =>
    Offset(a.mesh.rest[v * 2], a.mesh.rest[v * 2 + 1]);

/// The position the GPU draws at canvas point (x, y) of [a]: the deformed
/// corners of the cell it falls in, interpolated inside the triangle the point
/// is in (the hardware is affine inside each of a cell's two triangles).
Offset _drawn(RigLayerArt a, RigPose pose, double x, double y) {
  final m = a.mesh;
  final head = m.cols + 1;
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
    return _lockDeformer.deform(
      Offset(m.rest[k * 2], m.rest[k * 2 + 1]),
      pose,
      depth: a.depth[k],
    );
  }

  final tl = corner(j, i);
  final tr = corner(j, i + 1);
  final bl = corner(j + 1, i);
  final br = corner(j + 1, i + 1);
  if (fu + fv <= 1) {
    return tl + (tr - tl) * fu + (bl - tl) * fv;
  }
  return br + (bl - br) * (1 - fu) + (tr - br) * (1 - fv);
}

String _pose(RigPose p) =>
    'headX ${p.headX} headY ${p.headY} tilt ${p.headTilt} bodyX ${p.bodyX}';
