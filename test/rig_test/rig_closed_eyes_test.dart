import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:everlore/debug/rig_test/rig_art.dart';
import 'package:everlore/debug/rig_test/rig_expression.dart';
import 'package:everlore/debug/rig_test/rig_manifest.dart';
import 'package:everlore/debug/rig_test/rig_painter.dart';
import 'package:everlore/debug/rig_test/rig_sim.dart';
import 'package:flutter_test/flutter_test.dart';

// A stand-in character whose shut-eye drawings are each a flat colour of its
// own, so a painted pixel says exactly which drawing landed on the face. The
// crops are a 400 x 600 canvas, painted at that size, so canvas pixels are
// screen pixels. The hair starts below the eye band and the bangs end above it,
// so nothing drawn after the lids covers the sample point (160, 172).
const _neutralLids = 0xFFE00000;
const _happyLids = 0xFF00C000;
const _shyLids = 0xFF0040E0;
const _surprisedLids = 0xFFE0C000;

const _layers = <String, (double, double, double, double, int)>{
  'base': (0, 0, 400, 600, 0xFF101418),
  'outfit_blazer': (20, 400, 300, 180, 0xFF201810),
  'face_happy': (110, 140, 100, 60, 0xFF2A2020),
  'face_shy': (110, 140, 100, 60, 0xFF2A2020),
  'face_surprised': (110, 140, 100, 60, 0xFF2A2020),
  'mouth_open': (150, 225, 40, 20, 0xFF3A2020),
  'mouth_open_happy': (150, 225, 40, 20, 0xFF3A2020),
  'mouth_open_shy': (150, 225, 40, 20, 0xFF3A2020),
  'mouth_open_surprised': (150, 225, 40, 20, 0xFF3A2020),
  'eyes_half': (110, 150, 100, 55, 0xFF804080),
  'eyes_closed': (110, 145, 100, 55, _neutralLids),
  'eyes_closed_happy': (110, 145, 100, 55, _happyLids),
  'eyes_closed_shy': (110, 145, 100, 55, _shyLids),
  'eyes_closed_surprised': (110, 145, 100, 55, _surprisedLids),
  'eyes_glance_left': (110, 150, 100, 55, 0xFF604060),
  'eyes_glance_right': (110, 150, 100, 55, 0xFF604060),
  'hair_long': (0, 320, 400, 280, 0xFF303030),
  'hair_front': (0, 0, 96, 130, 0xFF303030),
};

const _sampleX = 160;
const _sampleY = 172;
const _size = ui.Size(400, 600);

bool _optional(String name) =>
    name.startsWith('eyes_closed_') && name != 'eyes_closed';

List<RigLayerSpec> _specs({required bool perExpression}) => [
      for (final e in _layers.entries)
        if (perExpression || !_optional(e.key))
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

RigManifest _manifest({required bool perExpression}) => RigManifest(
      canvasW: _size.width,
      canvasH: _size.height,
      anchors: const {
        'neck': ui.Offset(200, 260),
        'waist': ui.Offset(200, 600),
      },
      layers: _specs(perExpression: perExpression),
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
Future<RigArtSet> _fakeArt({bool perExpression = true}) async {
  final manifest = _manifest(perExpression: perExpression);
  final images = {
    for (final l in manifest.layers)
      l.file: await _solid(
        l.w.round(),
        l.h.round(),
        _layers[l.name]!.$5,
      ),
  };
  return RigArtSet.build(manifest, images);
}

/// Writes a pack (rig.json + the PNGs) the way the orchestrator pushes one, so
/// the real loader can be asked about both.
Future<void> _writePack(Directory dir, {required bool perExpression}) async {
  final manifest = _manifest(perExpression: perExpression);
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

/// The tell-tale colour the painter leaves at the sample point this frame.
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

void main() {
  testWidgets('a natural blink on a happy face shuts with that face\'s lids',
      (tester) async {
    await tester.runAsync(() async {
      final art = await _fakeArt();
      addTearDown(art.dispose);
      expect(
        identical(
          art.closedFor(RigExpression.neutral),
          art.closedFor(RigExpression.happy),
        ),
        isFalse,
        reason: 'the fake pack has happy\'s own shut eyes',
      );

      final sim = RigSim(deformer: art.deformer);
      sim.nextExpression(); // happy
      while (sim.expression.covering) {
        sim.update(1 / 60);
      }
      expect(sim.expression.shown, RigExpression.happy);

      // A natural blink comes 2-6 s apart.
      var frames = 0;
      while (sim.eyeState != RigEyeState.closed && frames++ < 60 * 40) {
        sim.update(1 / 60);
      }
      expect(sim.eyeState, RigEyeState.closed, reason: 'it blinked');
      expect(sim.closedAlpha, 1);
      expect(sim.closedExpression, RigExpression.happy,
          reason: 'the lids belong to the face on screen');
      expect(await _painted(RigPainter(art: art, sim: sim)), _happyLids,
          reason: 'the drawn closed layer is happy\'s, not the neutral one');
    });
  });

  testWidgets('a cover swaps the lids at its midpoint, never drawing both',
      (tester) async {
    await tester.runAsync(() async {
      final art = await _fakeArt();
      addTearDown(art.dispose);
      final sim = RigSim(deformer: art.deformer);
      sim.update(1 / 60);
      expect(sim.expression.shown, RigExpression.neutral);

      sim.nextExpression(); // happy; the cover starts
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
          expect(sim.closedExpression, RigExpression.neutral);
          expect(colour, _neutralLids,
              reason: 'frame $i: the old face\'s lids');
          before++;
        } else {
          expect(sim.expression.shown, RigExpression.happy);
          expect(sim.closedExpression, RigExpression.happy);
          expect(colour, _happyLids, reason: 'frame $i: the new face\'s lids');
          after++;
        }
      }
      expect(before, greaterThan(0), reason: 'frames before the midpoint');
      expect(after, greaterThan(0), reason: 'frames after it');
      expect(seen, {_neutralLids, _happyLids},
          reason: 'one drawing a frame: the two never blend');
    });
  });

  testWidgets('a pack without the per-face drawings falls back to neutral lids',
      (tester) async {
    await tester.runAsync(() async {
      final art = await _fakeArt(perExpression: false);
      addTearDown(art.dispose);
      expect(
        identical(
          art.closedFor(RigExpression.neutral),
          art.closedFor(RigExpression.happy),
        ),
        isTrue,
        reason: 'no happy drawing in this pack, so the neutral lids serve',
      );

      final sim = RigSim(deformer: art.deformer)..nextExpression(); // happy
      while (sim.expression.covering) {
        sim.update(1 / 60);
      }
      var frames = 0;
      while (sim.eyeState != RigEyeState.closed && frames++ < 60 * 40) {
        sim.update(1 / 60);
      }
      expect(sim.eyeState, RigEyeState.closed, reason: 'it blinked');
      expect(sim.closedExpression, RigExpression.happy,
          reason: 'the face is happy even though its drawing is not there');
      expect(await _painted(RigPainter(art: art, sim: sim)), _neutralLids,
          reason: 'the only shut eyes this pack has');
    });
  });

  testWidgets('the loader takes a pack with the extra drawings and one without',
      (tester) async {
    await tester.runAsync(() async {
      for (final perExpression in [true, false]) {
        final dir = await Directory.systemTemp.createTemp('rig_pack_');
        addTearDown(() => dir.delete(recursive: true));
        await _writePack(dir, perExpression: perExpression);

        final art = await loadRigArt(dir);
        final neutral = art.closedFor(RigExpression.neutral);
        final happy = art.closedFor(RigExpression.happy);
        expect(neutral.spec.file, 'eyes_closed.png');
        expect(
          happy.spec.file,
          perExpression ? 'eyes_closed_happy.png' : 'eyes_closed.png',
          reason: 'per-face pack: $perExpression',
        );
        expect(identical(happy, neutral), !perExpression,
            reason: 'the fallback is the same drawing, not a copy of it');
        // The faces that never fell back still have their own.
        if (perExpression) {
          expect(art.closedFor(RigExpression.shy).spec.file,
              'eyes_closed_shy.png');
          expect(art.closedFor(RigExpression.surprised).spec.file,
              'eyes_closed_surprised.png');
        }
        // Disposing a fallback set must not dispose the shared drawing twice.
        art.dispose();
      }
    });
  });
}
