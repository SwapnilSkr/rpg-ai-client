import 'package:everlore/debug/rig_test/rig_deform.dart';
import 'package:everlore/debug/rig_test/rig_tuning.dart';
import 'package:flutter_test/flutter_test.dart';

const _geometry = RigGeometry(neck: Offset(512, 650), waist: Offset(512, 1536));
const _deformer = RigDeformer(_geometry);

Offset _move(Offset p, RigPose pose, {double depth = 1}) =>
    _deformer.deform(p, pose, depth: depth) - p;

void main() {
  test('is the identity when every input is at rest', () {
    final pose = RigPose();
    for (var y = 0.0; y <= 1536; y += 64) {
      for (var x = 0.0; x <= 1024; x += 64) {
        final p = Offset(x, y);
        for (final depth in [0.6, 1.0, 1.25]) {
          final q = _deformer.deform(p, pose, depth: depth);
          expect((q - p).distance, lessThan(1e-9), reason: '$p depth $depth');
        }
      }
    }
  });

  test('eyes and mouth patches move with the face under them', () {
    final pose = RigPose()
      ..headX = 0.12
      ..headY = 0.06
      ..breath = 1;
    // Same depth: the eyes, the face and the mouth slide together.
    final eyes = _move(const Offset(492, 410), pose);
    final face = _move(const Offset(492, 445), pose);
    final mouth = _move(const Offset(513, 537), pose);
    expect((eyes - face).distance, lessThan(1));
    expect((mouth - face).distance, lessThan(1));
  });

  test('a patch one depth step in front stays within a pixel of the face', () {
    final pose = RigPose()..headX = 0.12;
    for (final p in const [Offset(430, 410), Offset(560, 410), Offset(513, 537)]) {
      final patch = _move(p, pose, depth: RigTuning.depthFeatures);
      final base = _move(p, pose, depth: RigTuning.depthFace);
      expect((patch - base).distance, lessThan(1), reason: '$p');
    }
  });

  test('nearer layers slide further in a turn', () {
    final pose = RigPose()..headX = 0.12;
    const p = Offset(512, 300);
    final back = _move(p, pose, depth: RigTuning.depthBackHead).dx;
    final face = _move(p, pose, depth: RigTuning.depthFace).dx;
    final bangs = _move(p, pose, depth: RigTuning.depthHairFront).dx;
    expect(back, lessThan(face));
    expect(face, lessThan(bangs));
    expect(face, closeTo(0.12 * RigTuning.turnPxX, 1));
  });

  test('the base painting is deeper at the face than at the hair outline', () {
    expect(_deformer.baseDepth(const Offset(500, 410)), RigTuning.depthFace);
    expect(_deformer.baseDepth(const Offset(120, 300)), RigTuning.depthBackHead);
    final mid = _deformer.baseDepth(const Offset(740, 410));
    expect(mid, inInclusiveRange(RigTuning.depthBackHead, RigTuning.depthFace));
  });

  test('the head motion fades out through the neck and stops below it', () {
    final pose = RigPose()
      ..headX = 0.12
      ..headTilt = 0.03;
    expect(_move(const Offset(512, 300), pose).distance, greaterThan(10));
    expect(_move(const Offset(512, 1000), pose).distance, lessThan(1e-9));
    // Monotone fade between the two, no seam.
    var last = double.infinity;
    for (var y = 590.0; y <= 710; y += 10) {
      final d = _move(Offset(512, y), pose).distance;
      expect(d, lessThanOrEqualTo(last + 0.5));
      last = d;
    }
  });

  test('the side the head turns toward is squeezed, the other is not', () {
    final pose = RigPose()..headX = 0.12;
    const rightEdge = Offset(660, 400);
    const leftEdge = Offset(380, 400);
    const shift = 0.12 * RigTuning.turnPxX;
    // Right edge is pulled in (moves less than the plain slide); left is free.
    expect(_move(rightEdge, pose).dx, lessThan(shift - 1));
    expect(_move(leftEdge, pose).dx, closeTo(shift, 1));
  });

  test('breath lifts the chest and leaves the waist where it is', () {
    final pose = RigPose()..breath = 1;
    expect(_move(const Offset(512, 850), pose).dy, lessThan(-4));
    expect(_move(const Offset(512, 1536), pose).distance, lessThan(1e-3));
  });

  test('sway moves the neck most and the waist not at all', () {
    final pose = RigPose()..bodyX = 1;
    expect(_move(const Offset(512, 650), pose).dx, closeTo(RigTuning.bodyPx, 0.5));
    expect(_move(const Offset(512, 1536), pose).dx, lessThan(1e-9));
  });

  test('roll turns the head about the neck', () {
    final pose = RigPose()..headTilt = 0.1;
    expect(_move(const Offset(512, 650), pose).distance, lessThan(1e-9));
    // Above the pivot, clockwise roll moves the point to the right.
    expect(_move(const Offset(512, 400), pose).dx, greaterThan(20));
  });

  test('hair lag shifts only the vertex it is applied to', () {
    final pose = RigPose();
    final tip = _deformer.deform(const Offset(300, 900), pose, lagWeight: 1, lagX: 12);
    final root = _deformer.deform(const Offset(300, 900), pose, lagWeight: 0, lagX: 12);
    expect(tip.dx, closeTo(312, 1e-9));
    expect(root.dx, closeTo(300, 1e-9));
  });

  test('the hair drive follows a turn and a sway', () {
    expect(_deformer.hairDrive(RigPose()), 0);
    expect(_deformer.hairDrive(RigPose()..headX = 0.1), greaterThan(5));
    expect(_deformer.hairDrive(RigPose()..bodyX = 0.5), greaterThan(5));
  });
}
