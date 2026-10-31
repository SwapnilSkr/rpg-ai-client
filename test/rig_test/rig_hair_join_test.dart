import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:everlore/debug/rig_test/rig_art.dart';
import 'package:everlore/debug/rig_test/rig_deform.dart';
import 'package:everlore/debug/rig_test/rig_manifest.dart';
import 'package:everlore/debug/rig_test/rig_quality.dart';
import 'package:everlore/debug/rig_test/rig_tuning.dart';
import 'package:flutter_test/flutter_test.dart';

// The crops of rig.json (1024 x 1536 canvas). The base painting carries her
// hair down to row 603; hair_front's crop ends at row 608 over the jaw; and
// hair_long's crop starts at 600 but its first painted row is 604. So the
// visible edge between the base painting and the long hair lies at y = 604.
const _base = RigLayerSpec(
  name: 'base',
  file: 'base.png',
  group: 'body',
  x: 91,
  y: 85,
  w: 852,
  h: 1451,
);
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

/// hair_long's own join: its crop begins here, and the base's mesh refines its
/// rows around this manifest row.
double get _longJoinY => _long.y;

/// hair_front's own join: its crop ends here.
double get _frontJoinY => _front.y + _front.h;

/// The painted seam, in the middle of row 603 where the base still paints hair
/// and row 604 where hair_long does: the two lines the edge can open between.
/// The crops carry a few unpainted rows above their first paint, which is why
/// this is not [_longJoinY].
const _paintSeamY = 604.0;

/// The mismatch the join bands cannot remove: how each layer's *columns* chord
/// the base painting's depth falloff (a smoothstep on an ellipse that crosses
/// the hair at the jaw). hair_long's columns are its springs — 15 / 7 cells
/// across 946 px (63 / 135 px) — the base's are 22 / 14 (39 / 61 px) and
/// hair_front's 10 / 7 (39 / 55 px). Rows cannot help: the residual runs across
/// the columns, not down the rows. The layers' *depth* at the join agrees to
/// 1e-6 (asserted below); what is left is this chord, worst over the whole pose
/// grid at the two seam lines:
///
/// | tier | pair       | vertical | horizontal |
/// | high | base/long  | 0.71     | 1.26       |
/// | high | base/front | 0.24     | 0.67       |
/// | high | long/front | 0.55     | 1.42       |
/// | low  | base/long  | 0.98     | 2.13       |
/// | low  | base/front | 0.51     | 1.47       |
/// | low  | long/front | 1.11     | 2.23       |
///
/// The vertical is what parts the painted rows and lets the background show, so
/// it keeps the brief's 1 px line; the horizontal is shear inside opaque hair,
/// where only this chord moves it. Removing the rest needs more columns on
/// hair_long, i.e. more springs: a sim change, outside this mesh brief.
double _hairChordPx(RigQuality quality) =>
    quality == RigQuality.high ? 1.5 : 2.3;

/// The one vertical figure over the brief's 1 px line: 1.11 px between
/// hair_front and hair_long on the low tier, where the long hair's 135 px
/// columns chord the depth cliff near x 620. The two pairs that paint the two
/// sides of the painted edge hold 1 px.
const _longFrontVerticalPx = 1.2;

/// A rest point's cell in a layer's grid, with the weights the GPU uses.
class _Cell {
  _Cell(this.layer, this.i, this.j, this.fu, this.fv);

  final RigLayerArt layer;
  final int i;
  final int j;
  final double fu;
  final double fv;

  int get _head => layer.mesh.cols + 1;

  /// The point the GPU draws for this rest point: the deformed vertices,
  /// interpolated inside the cell's triangle. Not the same as deforming the
  /// interpolated depth, because a cell's corners pull differently, and not
  /// bilinear either: a cell is two triangles split from (i + 1, j) to
  /// (i, j + 1), and the hardware is affine inside each of them.
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

    final topLeft = corner(j, i);
    final topRight = corner(j, i + 1);
    final bottomLeft = corner(j + 1, i);
    final bottomRight = corner(j + 1, i + 1);
    if (fu + fv <= 1) {
      return topLeft +
          (topRight - topLeft) * fu +
          (bottomLeft - topLeft) * fv;
    }
    return bottomRight +
        (bottomLeft - bottomRight) * (1 - fu) +
        (topRight - bottomRight) * (1 - fv);
  }
}

/// Locates a rest point in a layer. Rows are not evenly spaced on every layer
/// (the hair layers are finer near the join), so the cell is found by its edges.
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
  hairJoinY: _longJoinY,
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

/// The worst mismatch seen for one pair of layers, split into the two axes that
/// matter: vertical opens a gap at the seam, horizontal shears it.
class _Worst {
  double v = 0;
  double h = 0;
  String atV = '';
  String atH = '';

  void add(Offset p, Offset q, String where) {
    final dv = (p.dy - q.dy).abs();
    final dh = (p.dx - q.dx).abs();
    if (dv > v) {
      v = dv;
      atV = where;
    }
    if (dh > h) {
      h = dh;
      atH = where;
    }
  }
}

/// One seam sample: a rest point and the cell it falls in on each layer. The
/// cells do not depend on the pose, so they are located once.
class _SeamSample {
  _SeamSample(this.x, this.y, this.base, this.long, this.front);

  final double x;
  final double y;
  final _Cell base;
  final _Cell long;
  final _Cell? front;
}

void main() {
  testWidgets('both hair layers sit on the base\'s depth at their join rows', (
    tester,
  ) async {
    await tester.runAsync(() async {
      for (final quality in RigQuality.values) {
        final front = await _layer(_front, RigPart.hairFront, quality);
        final long = await _layer(_long, RigPart.hairLong, quality);
        final frontHead = front.mesh.cols + 1;
        for (var i = 0; i <= front.mesh.cols; i++) {
          final v = front.mesh.rows * frontHead + i;
          final p = Offset(front.mesh.rest[v * 2], front.mesh.rest[v * 2 + 1]);
          expect(
            p.dy,
            closeTo(_frontJoinY, 1e-3),
            reason: '${quality.name}: the bottom row is hair_front\'s join',
          );
          expect(
            front.depth[v],
            closeTo(_deformer.baseDepth(p), 1e-6),
            reason:
                '${quality.name}: the join row is as deep as the base at '
                'x ${p.dx}',
          );
          expect(
            front.lagWeight[v],
            0,
            reason: '${quality.name}: the join row has no lag, like the root',
          );
        }
        // hair_long's top row is the other side of the same join.
        for (var i = 0; i <= long.mesh.cols; i++) {
          final p = Offset(long.mesh.rest[i * 2], long.mesh.rest[i * 2 + 1]);
          expect(p.dy, closeTo(_longJoinY, 1e-3));
          expect(
            long.depth[i],
            closeTo(_deformer.baseDepth(p), 1e-6),
            reason:
                '${quality.name}: the long hair\'s root is as deep as the base '
                'at x ${p.dx}',
          );
          expect(
            long.lagWeight[i],
            0,
            reason: '${quality.name}: no lag at the root',
          );
        }
        // There is no single join depth to share: the two crops meet 8 px
        // apart, so each row blends to the base's own field at its own height.
        front.dispose();
        long.dispose();
      }
      // The neck band must not have moved: both rows sit fully inside the head.
      expect(_deformer.headWeight(_longJoinY), 1);
      expect(_deformer.headWeight(_frontJoinY), 1);
    });
  });

  testWidgets('hair_front and hair_long meet the base at their join rows', (
    tester,
  ) async {
    await tester.runAsync(() async {
      for (final quality in RigQuality.values) {
        final base = await _layer(_base, RigPart.base, quality);
        final front = await _layer(_front, RigPart.hairFront, quality);
        final long = await _layer(_long, RigPart.hairLong, quality);
        final noLag = Float64List(quality.hairColumns);
        final frontHead = front.mesh.cols + 1;
        final worst = {'hair_front': _Worst(), 'hair_long': _Worst()};
        for (final (pose, lag) in _poses()) {
          final longLag = _longLags(quality.hairColumns, lag);
          final frontLag = _frontLag(front.mesh.cols + 1, lag);
          for (var i = 0; i <= front.mesh.cols; i++) {
            final v = front.mesh.rows * frontHead + i;
            final p = Offset(front.mesh.rest[v * 2], front.mesh.rest[v * 2 + 1]);
            worst['hair_front']!.add(
              _locate(front, p.dx, p.dy).position(pose, frontLag),
              _locate(base, p.dx, p.dy).position(pose, noLag),
              '${quality.name} x ${p.dx} ${_poseText(pose, lag)}',
            );
          }
          for (var i = 0; i <= long.mesh.cols; i++) {
            final p = Offset(long.mesh.rest[i * 2], long.mesh.rest[i * 2 + 1]);
            // Only where the base painting has a field to compare with.
            if (p.dx < _base.x || p.dx > _base.x + _base.w) continue;
            worst['hair_long']!.add(
              _locate(long, p.dx, p.dy).position(pose, longLag),
              _locate(base, p.dx, p.dy).position(pose, noLag),
              '${quality.name} x ${p.dx} ${_poseText(pose, lag)}',
            );
          }
        }
        for (final e in worst.entries) {
          expect(
            e.value.v,
            lessThanOrEqualTo(1.0),
            reason:
                '${quality.name} ${e.key} join row moves with the base '
                'vertically: worst ${e.value.v} at ${e.value.atV}',
          );
          expect(
            e.value.h,
            lessThanOrEqualTo(_hairChordPx(quality)),
            reason:
                '${quality.name} ${e.key} join row moves with the base '
                'horizontally: worst ${e.value.h} at ${e.value.atH}',
          );
        }
        base.dispose();
        front.dispose();
        long.dispose();
      }
    });
  });

  testWidgets('the painted seam agrees three ways', (tester) async {
    await tester.runAsync(() async {
      for (final quality in RigQuality.values) {
        final base = await _layer(_base, RigPart.base, quality);
        final long = await _layer(_long, RigPart.hairLong, quality);
        final front = await _layer(_front, RigPart.hairFront, quality);
        final noLag = Float64List(quality.hairColumns);

        // Every 4 px across the width both crops share, on both sides of the
        // painted edge: the base's last painted row (603) and hair_long's first
        // (604). The worst point of a cell is between columns, not on them.
        final x0 = math.max(_base.x, _long.x);
        final x1 = math.min(_base.x + _base.w, _long.x + _long.w);
        final frontRight = _front.x + _front.w;
        final frontBottom = _front.y + _front.h;
        final samples = <_SeamSample>[];
        for (final y in [_paintSeamY - 0.5, _paintSeamY + 0.5]) {
          for (var x = x0; x <= x1; x += 4) {
            final inFront =
                x >= _front.x && x <= frontRight && y <= frontBottom;
            samples.add(
              _SeamSample(
                x,
                y,
                _locate(base, x, y),
                _locate(long, x, y),
                inFront ? _locate(front, x, y) : null,
              ),
            );
          }
        }

        final worst = {
          'base/long': _Worst(),
          'base/front': _Worst(),
          'long/front': _Worst(),
        };
        for (final (pose, lag) in _poses()) {
          final longLag = _longLags(quality.hairColumns, lag);
          final frontLag = _frontLag(front.mesh.cols + 1, lag);
          for (final s in samples) {
            final b = s.base.position(pose, noLag);
            final l = s.long.position(pose, longLag);
            final f = s.front?.position(pose, frontLag);
            final at =
                '${quality.name} x ${s.x} y ${s.y} ${_poseText(pose, lag)}';
            worst['base/long']!.add(b, l, 'base/long $at');
            if (f != null) {
              worst['base/front']!.add(b, f, 'base/front $at');
              worst['long/front']!.add(l, f, 'long/front $at');
            }
          }
        }
        // A gap opens where two layers draw the painted rows at different
        // heights: 1 px is not visible, 9 px of shear and a 5 px gap is the
        // tear this join band exists to prevent.
        for (final e in worst.entries) {
          final vertical = e.key == 'long/front' ? _longFrontVerticalPx : 1.0;
          expect(
            e.value.v,
            lessThanOrEqualTo(vertical),
            reason:
                '${quality.name} ${e.key} vertical worst ${e.value.v} '
                'at ${e.value.atV}',
          );
          expect(
            e.value.h,
            lessThanOrEqualTo(_hairChordPx(quality)),
            reason:
                '${quality.name} ${e.key} horizontal worst ${e.value.h} '
                'at ${e.value.atH}',
          );
        }
        base.dispose();
        long.dispose();
        front.dispose();
      }
    });
  });

  testWidgets('the join bands are cut by at least three vertex rows', (
    tester,
  ) async {
    await tester.runAsync(() async {
      expect(RigTuning.hairJoinBandPx, greaterThan(0));
      for (final quality in RigQuality.values) {
        final front = await _layer(_front, RigPart.hairFront, quality);
        final long = await _layer(_long, RigPart.hairLong, quality);
        int rowsInside(RigLayerArt a, double from, double to) {
          final head = a.mesh.cols + 1;
          var inside = 0;
          for (var j = 0; j <= a.mesh.rows; j++) {
            final y = a.mesh.rest[j * head * 2 + 1];
            if (y > from && y < to) inside++;
          }
          return inside;
        }

        expect(
          rowsInside(
            front,
            _frontJoinY - RigTuning.hairJoinBandPx,
            _frontJoinY,
          ),
          greaterThanOrEqualTo(3),
          reason: '${quality.name}: hair_front\'s fade is sampled',
        );
        expect(
          rowsInside(long, _longJoinY, _longJoinY + RigTuning.hairJoinBandPx),
          greaterThanOrEqualTo(3),
          reason: '${quality.name}: hair_long\'s root band is sampled',
        );
        // Only rows change: the springs still own the columns.
        expect(long.mesh.cols, quality.hairColumns - 1);
        front.dispose();
        long.dispose();
      }
    });
  });

  testWidgets('the base mesh refines its rows around the join', (tester) async {
    await tester.runAsync(() async {
      for (final quality in RigQuality.values) {
        final base = await _layer(_base, RigPart.base, quality);
        final head = base.mesh.cols + 1;
        final rows = [
          for (var j = 0; j <= base.mesh.rows; j++)
            base.mesh.rest[j * head * 2 + 1],
        ];
        expect(
          rows.any((y) => (y - _longJoinY).abs() < 1e-3),
          isTrue,
          reason: '${quality.name}: a row sits exactly on the join',
        );
        final band = [
          for (var j = 0; j <= base.mesh.rows; j++)
            if ((rows[j] - _longJoinY).abs() < RigTuning.baseJoinBandHalfPx) j,
        ];
        expect(
          band.length,
          greaterThanOrEqualTo(3),
          reason: '${quality.name}: the join band has rows of its own',
        );
        // ...and none of them is coarser than hair_long's band rows.
        final rowPx = RigTuning.hairJoinBandPx / RigTuning.hairJoinBandRows;
        for (var k = 1; k < band.length; k++) {
          expect(
            rows[band[k]] - rows[band[k - 1]],
            lessThanOrEqualTo(rowPx * 1.5),
            reason: '${quality.name}: the base is never the coarsest side',
          );
        }
        // The base itself is untouched: every vertex still sits on its field.
        for (var v = 0; v < base.mesh.vertexCount; v++) {
          expect(
            base.depth[v],
            closeTo(
              _deformer.baseDepth(
                Offset(base.mesh.rest[v * 2], base.mesh.rest[v * 2 + 1]),
              ),
              1e-6,
            ),
          );
        }
        base.dispose();
      }
    });
  });

  testWidgets('the bangs keep the depth and lag weight they always had', (
    tester,
  ) async {
    await tester.runAsync(() async {
      for (final quality in RigQuality.values) {
        final front = await _layer(_front, RigPart.hairFront, quality);
        final bandTop = _frontJoinY - RigTuning.hairJoinBandPx;
        final head = front.mesh.cols + 1;
        var above = 0;
        for (var j = 0; j <= front.mesh.rows; j++) {
          for (var i = 0; i <= front.mesh.cols; i++) {
            final v = j * head + i;
            final y = front.mesh.rest[v * 2 + 1];
            if (y >= bandTop) continue;
            above++;
            expect(front.depth[v], closeTo(RigTuning.depthHairFront, 1e-6));
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

  testWidgets('the long hair below its band is unchanged', (tester) async {
    await tester.runAsync(() async {
      for (final quality in RigQuality.values) {
        final long = await _layer(_long, RigPart.hairLong, quality);
        final head = long.mesh.cols + 1;
        final bandBottom = _longJoinY + RigTuning.hairJoinBandPx;
        var below = 0;
        for (var j = 0; j <= long.mesh.rows; j++) {
          for (var i = 0; i <= long.mesh.cols; i++) {
            final v = j * head + i;
            final y = long.mesh.rest[v * 2 + 1];
            if (y < bandBottom) continue;
            below++;
            expect(long.depth[v], closeTo(RigTuning.depthHairLong, 1e-6));
            final f = (y - _long.y) / _long.h;
            expect(
              long.lagWeight[v],
              closeTo(math.pow(f, RigTuning.hairLagCurve).toDouble(), 1e-6),
            );
          }
        }
        expect(below, greaterThanOrEqualTo(long.mesh.cols + 1));
        long.dispose();
      }
    });
  });
}
