import 'dart:ui' as ui;

import 'package:everlore/debug/rig_test/rig_art.dart';
import 'package:everlore/debug/rig_test/rig_manifest.dart';
import 'package:everlore/debug/rig_test/rig_painter.dart';
import 'package:everlore/debug/rig_test/rig_quality.dart';
import 'package:everlore/debug/rig_test/rig_sim.dart';
import 'package:flutter_test/flutter_test.dart';

// A stand-in character: every layer a small solid crop, so the painter's
// whole path (meshes, shaders, alpha filters, both modes) runs without the art.
const _names = {
  'base': (0.0, 0.0, 400.0, 600.0),
  'outfit_blazer': (20.0, 300.0, 300.0, 280.0),
  'face_happy': (120.0, 150.0, 100.0, 50.0),
  'face_shy': (120.0, 150.0, 100.0, 80.0),
  'face_surprised': (120.0, 140.0, 100.0, 90.0),
  'mouth_open': (150.0, 220.0, 40.0, 20.0),
  'mouth_open_happy': (150.0, 220.0, 40.0, 20.0),
  'mouth_open_shy': (150.0, 220.0, 40.0, 20.0),
  'mouth_open_surprised': (150.0, 220.0, 40.0, 20.0),
  'eyes_half': (110.0, 160.0, 100.0, 40.0),
  'eyes_closed': (110.0, 150.0, 100.0, 40.0),
  'eyes_glance_left': (110.0, 160.0, 100.0, 40.0),
  'eyes_glance_right': (110.0, 160.0, 100.0, 40.0),
  'hair_long': (0.0, 100.0, 400.0, 400.0),
  'hair_front': (100.0, 40.0, 150.0, 140.0),
};

Future<ui.Image> _solid(int w, int h) {
  final rec = ui.PictureRecorder();
  ui.Canvas(rec).drawRect(
    ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    ui.Paint()..color = const ui.Color(0xFF88AACC),
  );
  return rec.endRecording().toImage(w, h);
}

void main() {
  testWidgets('paints both modes through a talk and a look away', (tester) async {
    await tester.runAsync(() async {
      final manifest = RigManifest(
        canvasW: 400,
        canvasH: 600,
        anchors: const {
          'neck': ui.Offset(200, 260),
          'waist': ui.Offset(200, 600),
        },
        layers: [
          for (final e in _names.entries)
            RigLayerSpec(
              name: e.key,
              file: '${e.key}.png',
              group: 'x',
              x: e.value.$1,
              y: e.value.$2,
              w: e.value.$3,
              h: e.value.$4,
            ),
        ],
      );
      final images = {
        for (final l in manifest.layers)
          l.file: await _solid(l.w.round(), l.h.round()),
      };
      final art = RigArtSet.build(manifest, images);
      final sim = RigSim(deformer: art.deformer)
        ..setOutfit(true)
        ..talk();
      final painter = RigPainter(art: art, sim: sim);

      for (final mode in RigMode.values) {
        sim.setMode(mode);
        for (var i = 0; i < 90; i++) {
          if (i == 20) sim.lookAway();
          sim.update(1 / 60);
          final rec = ui.PictureRecorder();
          painter.paint(ui.Canvas(rec), const ui.Size(300, 450));
          rec.endRecording().dispose();
        }
      }

      // And the same again after a tier switch, which rebuilds every mesh and
      // every hair spring: a mismatch between the two would throw here.
      art.setQuality(RigQuality.low);
      sim.setQuality(RigQuality.low);
      sim.setMode(RigMode.mesh);
      for (var i = 0; i < 30; i++) {
        sim.update(1 / 60);
        final rec = ui.PictureRecorder();
        painter.paint(ui.Canvas(rec), const ui.Size(300, 450));
        rec.endRecording().dispose();
      }
      art.dispose();
    });
  });

  test('real-sized meshes fit 16-bit indices and the hair grid has one cell fewer than columns', () {
    final mesh = LayerMesh.grid(x: 48, y: 85, w: 938, h: 1451);
    expect(mesh.vertexCount, lessThan(65536), reason: 'fits a Uint16 index');
    expect(mesh.indices.length, mesh.cols * mesh.rows * 6);
    expect(mesh.rest.every((v) => v.isFinite), isTrue);
    final hair = LayerMesh.grid(x: 44, y: 371, w: 946, h: 863, cols: 15);
    expect(hair.cols, 15);
  });
}
