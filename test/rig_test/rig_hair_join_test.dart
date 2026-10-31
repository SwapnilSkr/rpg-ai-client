import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:everlore/debug/rig_test/rig_art.dart';
import 'package:everlore/debug/rig_test/rig_deform.dart';
import 'package:everlore/debug/rig_test/rig_manifest.dart';
import 'package:everlore/debug/rig_test/rig_quality.dart';
import 'package:everlore/debug/rig_test/rig_tuning.dart';
import 'package:flutter_test/flutter_test.dart';

// The two hair crops of rig.json (1024 x 1536 canvas). The front's painted
// pixels stop at row 603 and the long layer's start at 604, so the crops abut:
// one painted strand is drawn by hair_front above the row and hair_long below.
const _front = RigLayerSpec(
  name: 'hair_front',
  file: 'hair_front.png',
  group: 'hair',
  x: 288,
  y: 142,
  w: 386,
  h: 466,
);
const _long = RigLayerSpec(
  name: 'hair_long',
  file: 'hair_long.png',
  group: 'hair',
  x: 44,
  y: 600,
  w: 946,
  h: 634,
);

const _deformer = RigDeformer(
  RigGeometry(neck: Offset(512, 650), waist: Offset(512, 1536)),
);

/// The join row: where the front's crop ends and the long crop begins.
double get _joinY => _front.y + _front.h;

/// Where the two paintings meet: the front's last painted row is 603 and the
/// long layer's first is 604, so the seam lies between them.
const _seamY = 603.5;

/// A rest point's cell in a layer's grid, with the weights the GPU uses.
class _Cell {
  _Cell(this.layer, this.i, this.j, this.fu, this.fv);

  final RigLayerArt layer;
  final int i;
  final int j;
  final double fu;
  final double fv;

  int get _head => layer.mesh.cols + 1;

  /// A per-vertex number, interpolated across the cell.
  double attribute(Float32List v) {
    double row(int r) =>
        v[r * _head + i] + (v[r * _head + i + 1] - v[r * _head + i]) * fu;
    return row(j) + (row(j + 1) - row(j)) * fv;
  }

  /// The lag of the two springs either side, interpolated across the row. A
  /// spring belongs to a column, so it has no vertical component.
  double springLag(Float64List lag) {
    final a = lag[layer.column[j * _head + i]];
    final b = lag[layer.column[j * _head + i + 1]];
    return a + (b - a) * fu;
  }

  /// The point the GPU draws for this rest point: the deformed vertices,
  /// interpolated across the cell. Not the same as deforming the interpolated
  /// depth, because a cell's corners pull differently.
  Offset position(RigPose pose, Float64List lag) {
    Offset corner(int r, int c) {
      final k = r * _head + c;
      return _deformer.deform(
        Offset(layer.mesh.rest[k * 2], layer.mesh.rest[k * 2 + 1]),
        pose,
        depth: layer.depth[k],
        lagWeight: layer.lagWeight[k],
        lagX: lag[layer.column[k]],
      );
    }

    final top = corner(j, i) + (corner(j, i + 1) - corner(j, i)) * fu;
    final bottom =
        corner(j + 1, i) + (corner(j + 1, i + 1) - corner(j + 1, i)) * fu;
    return top + (bottom - top) * fv;
  }
}

/// Locates a rest point in a layer. Rows are not evenly spaced on every layer
/// (the front's are finer near its join), so the cell is found by its edges.
_Cell _locate(RigLayerArt a, double x, double y) {
  final m = a.mesh;
  final head = m.cols + 1;
  final u = ((x - a.spec.x) / a.spec.w * m.cols).clamp(0.0, m.cols - 1e-9);
  final i = u.floor().clamp(0, m.cols - 1);
  var j = 0;
  while (j < m.rows - 1 && y > m.rest[(j + 1) * head * 2 + 1]) {
    j++;
  }
  final y0 = m.rest[j * head * 2 + 1];
  final y1 = m.rest[(j + 1) * head * 2 + 1];
  return _Cell(a, i, j, u - i, ((y - y0) / (y1 - y0)).clamp(0.0, 1.0));
}

/// What a layer does at a rest point: the numbers `deform` is called with.
class _Motion {
  const _Motion(this.depth, this.lagWeight, this.lag);

  final double depth;
  final double lagWeight;
  final double lag;

  Offset at(RigPose pose, Offset p) =>
      _deformer.deform(p, pose, depth: depth, lagWeight: lagWeight, lagX: lag);
}

_Motion _motionAt(RigLayerArt a, Offset p, Float64List lag) {
  final c = _locate(a, p.dx, p.dy);
  return _Motion(
    c.attribute(a.depth),
    c.attribute(a.lagWeight),
    c.springLag(lag),
  );
}

Future<ui.Image> _solid(int w, int h) {
  final rec = ui.PictureRecorder();
  ui.Canvas(rec).drawRect(
    ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    ui.Paint()..color = const ui.Color(0xFFAA8866),
  );
  return rec.endRecording().toImage(w, h);
}

Future<RigLayerArt> _layer(
  RigLayerSpec spec,
  RigPart part,
  RigQuality quality,
) async => RigLayerArt.build(
  spec: spec,
  part: part,
  image: await _solid(2, 2),
  deformer: _deformer,
  quality: quality,
);

/// Every pose the sim can reach, at and past each limit in the brief.
List<(RigPose, double)> _poses() => [
  for (final headX in const [-0.15, -0.12, 0.0, 0.12, 0.15])
    for (final headY in const [-0.05, 0.0, 0.06, 0.12])
      for (final tilt in const [-0.03, 0.0, 0.03])
        for (final bodyX in const [-0.3, 0.0, 0.3])
          for (final breath in const [0.0, 0.5, 1.0])
            for (final lag in const [-12.0, 0.0, 12.0])
              (
                RigPose()
                  ..headX = headX
                  ..headY = headY
                  ..headTilt = tilt
                  ..bodyX = bodyX
                  ..breath = breath,
                lag,
              ),
];

/// The sim's per-column lags for a pose: a ramp, so neighbouring springs
/// differ and the interpolation across hair_long's columns is exercised.
Float64List _longLags(int columns, double lag) {
  final out = Float64List(columns);
  for (var c = 0; c < columns; c++) {
    out[c] = lag * (0.5 + 0.5 * c / (columns - 1));
  }
  return out;
}

Float64List _frontLag(int columns, double lag) =>
    Float64List(columns)..fillRange(0, columns, lag);

String _poseText(RigPose pose, double lag) =>
    'headX ${pose.headX} headY ${pose.headY} tilt ${pose.headTilt} '
    'bodyX ${pose.bodyX} breath ${pose.breath} lag $lag';

void main() {
  testWidgets('the join row moves exactly as the long hair does', (
    tester,
  ) async {
    await tester.runAsync(() async {
      for (final quality in RigQuality.values) {
        final front = await _layer(_front, RigPart.hairFront, quality);
        final long = await _layer(_long, RigPart.hairLong, quality);
        final head = front.mesh.cols + 1;
        for (var i = 0; i <= front.mesh.cols; i++) {
          final v = front.mesh.rows * head + i;
          expect(
            front.mesh.rest[v * 2 + 1],
            closeTo(_joinY, 1e-3),
            reason: '${quality.name}: the bottom row is the join',
          );
          expect(
            front.depth[v],
            closeTo(RigTuning.depthHairLong, 1e-6),
            reason: '${quality.name}: the join row is as deep as hair_long',
          );
          expect(
            front.lagWeight[v],
            0,
            reason: '${quality.name}: the join row has no lag, like the root',
          );
        }
        // hair_long's top row is the other side of the same join.
        for (var i = 0; i <= long.mesh.cols; i++) {
          expect(long.mesh.rest[i * 2 + 1], closeTo(_long.y, 1e-3));
          expect(long.depth[i], closeTo(RigTuning.depthHairLong, 1e-6));
          expect(long.lagWeight[i], 0);
        }
        front.dispose();
        long.dispose();
      }
      // The neck band must not have moved: both rows sit fully inside the head.
      expect(_deformer.headWeight(_long.y), 1);
      expect(_deformer.headWeight(_joinY), 1);
    });
  });

  testWidgets('hair_front and hair_long agree at the join point', (
    tester,
  ) async {
    await tester.runAsync(() async {
      for (final quality in RigQuality.values) {
        final front = await _layer(_front, RigPart.hairFront, quality);
        final long = await _layer(_long, RigPart.hairLong, quality);
        final head = front.mesh.cols + 1;

        for (final (pose, lag) in _poses()) {
          final longLag = _longLags(quality.hairColumns, lag);
          for (var i = 0; i <= front.mesh.cols; i++) {
            final v = front.mesh.rows * head + i;
            final p = Offset(front.mesh.rest[v * 2], _joinY);
            // The same rest point on the long layer, as the GPU blends it.
            final theirs = _motionAt(long, p, longLag);
            final mine = _Motion(front.depth[v], front.lagWeight[v], lag);
            expect(
              (mine.at(pose, p) - theirs.at(pose, p)).distance,
              lessThan(0.25),
              reason: '${quality.name} x ${p.dx} ${_poseText(pose, lag)}',
            );
          }
        }
        front.dispose();
        long.dispose();
      }
    });
  });

  testWidgets('the painted seam does not tear', (tester) async {
    await tester.runAsync(() async {
      for (final quality in RigQuality.values) {
        final front = await _layer(_front, RigPart.hairFront, quality);
        final long = await _layer(_long, RigPart.hairLong, quality);
        final head = front.mesh.cols + 1;
        // Sample on both meshes' columns: the worst point of a cell is between
        // the two layers' columns, not on them.
        final xs = <double>{
          for (var i = 0; i <= front.mesh.cols; i++)
            front.mesh.rest[(front.mesh.rows * head + i) * 2],
          for (var i = 0; i <= long.mesh.cols; i++)
            long.mesh.rest[(long.mesh.rows * (long.mesh.cols + 1) + i) * 2],
        }.where((x) => x >= _front.x && x <= _front.x + _front.w);

        for (final (pose, lag) in _poses()) {
          final longLag = _longLags(quality.hairColumns, lag);
          final frontLag = _frontLag(front.mesh.cols + 1, lag);
          for (final x in xs) {
            final mine = _locate(front, x, _seamY).position(pose, frontLag);
            final theirs = _locate(long, x, _seamY).position(pose, longLag);
            // Not 0: hair_long's columns are far apart, so each layer chords
            // the compression curve differently, which costs up to ~2 px at the
            // far strand. A tear is 9 px of shear and a 5 px gap.
            expect(
              (mine - theirs).distance,
              lessThan(3),
              reason: '${quality.name} x $x ${_poseText(pose, lag)}',
            );
          }
        }
        front.dispose();
        long.dispose();
      }
    });
  });

  testWidgets('the band is cut by at least three vertex rows', (tester) async {
    await tester.runAsync(() async {
      expect(RigTuning.hairJoinBandPx, greaterThan(0));
      for (final quality in RigQuality.values) {
        final front = await _layer(_front, RigPart.hairFront, quality);
        final bandTop = _joinY - RigTuning.hairJoinBandPx;
        var inside = 0;
        for (var j = 0; j <= front.mesh.rows; j++) {
          final y = front.mesh.rest[j * (front.mesh.cols + 1) * 2 + 1];
          if (y > bandTop && y < _joinY) inside++;
        }
        expect(
          inside,
          greaterThanOrEqualTo(3),
          reason: '${quality.name}: the fade is sampled, not stretched',
        );
        front.dispose();
      }
    });
  });

  testWidgets('the bangs keep the depth and lag weight they always had', (
    tester,
  ) async {
    await tester.runAsync(() async {
      for (final quality in RigQuality.values) {
        final front = await _layer(_front, RigPart.hairFront, quality);
        final bandTop = _joinY - RigTuning.hairJoinBandPx;
        final head = front.mesh.cols + 1;
        var above = 0;
        for (var j = 0; j <= front.mesh.rows; j++) {
          for (var i = 0; i <= front.mesh.cols; i++) {
            final v = j * head + i;
            final y = front.mesh.rest[v * 2 + 1];
            if (y >= bandTop) continue;
            above++;
            expect(front.depth[v], RigTuning.depthHairFront);
            final f = (y - _front.y) / _front.h;
            expect(
              front.lagWeight[v],
              closeTo(math.pow(f, RigTuning.hairLagCurve).toDouble(), 1e-6),
            );
          }
        }
        // The band is a small part of the layer, so most of it is untouched.
        expect(above, greaterThanOrEqualTo(front.mesh.cols + 1));
        front.dispose();
      }
    });
  });
}
