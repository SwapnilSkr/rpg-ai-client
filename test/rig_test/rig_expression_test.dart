import 'package:everlore/debug/rig_test/rig_expression.dart';
import 'package:everlore/debug/rig_test/rig_tuning.dart';
import 'package:flutter_test/flutter_test.dart';

const _cover = RigTuning.blinkClosedHoldExpression;

void main() {
  test('a change is a cover blink: the patch swaps at its midpoint', () {
    final b = ExpressionBlend()..set(RigExpression.happy);
    expect(b.covering, isTrue);
    expect(b.patchAlpha(RigExpression.happy), 0);

    b.update(_cover * 0.4);
    expect(b.patchAlpha(RigExpression.happy), 0, reason: 'before the midpoint');

    b.update(_cover * 0.15);
    expect(b.patchAlpha(RigExpression.happy), 1, reason: 'after the midpoint');
    expect(b.patchAlpha(RigExpression.shy), 0);
    expect(b.covering, isTrue, reason: 'the lids are still shut');

    b.update(_cover);
    expect(b.settled, isTrue);
    expect(b.shown, RigExpression.happy);
  });

  test('the patch alphas are only ever 0 or 1, one at most', () {
    final b = ExpressionBlend();
    for (final e in [
      ...RigExpression.values,
      RigExpression.happy,
      RigExpression.shy,
      RigExpression.neutral,
      RigExpression.surprised,
    ]) {
      b.set(e);
      for (var i = 0; i < 20; i++) {
        b.update(1 / 60);
        final lit = RigExpression.values.where((x) => b.patchAlpha(x) > 0);
        expect(lit.length, lessThanOrEqualTo(1), reason: 'two patches');
        for (final x in RigExpression.values) {
          expect(b.patchAlpha(x), anyOf(0.0, 1.0), reason: '${x.name} fading');
        }
        if (b.settled) expect(b.shown, b.target);
      }
    }
  });

  test('a request before the midpoint retargets: one switch, to the latest', () {
    final b = ExpressionBlend()..set(RigExpression.happy);
    b.update(1 / 60);
    b.set(RigExpression.shy);
    expect(b.patchAlpha(RigExpression.happy), 0);

    var switches = 0;
    var last = b.shown;
    while (!b.settled) {
      b.update(1 / 60);
      if (b.shown != last) {
        switches++;
        last = b.shown;
      }
    }
    expect(switches, 1, reason: 'one switch per cover blink');
    expect(b.shown, RigExpression.shy);
    expect(b.patchAlpha(RigExpression.shy), 1);
    expect(b.patchAlpha(RigExpression.happy), 0);
  });

  test('a request after the midpoint gets its own cover blink', () {
    final b = ExpressionBlend()..set(RigExpression.happy);
    for (var i = 0; i < 3; i++) {
      b.update(1 / 60); // 0.05 s: past the midpoint, inside the hold
    }
    expect(b.shown, RigExpression.happy);

    b.set(RigExpression.surprised);
    expect(b.covering, isTrue);
    expect(b.shown, RigExpression.happy, reason: 'the new cover has not swapped');
    expect(b.target, RigExpression.surprised);

    b.update(_cover);
    expect(b.shown, RigExpression.surprised);
    expect(b.patchAlpha(RigExpression.surprised), 1);
  });

  test('neutral has no patch, and coming back to it lights none', () {
    final b = ExpressionBlend()..set(RigExpression.happy);
    b.update(_cover);
    expect(b.patchAlpha(RigExpression.happy), 1);

    b.set(RigExpression.neutral);
    expect(b.covering, isTrue, reason: 'the swap home is covered too');
    b.update(_cover * 0.6);
    expect(b.patchAlpha(RigExpression.happy), 0);
    b.update(_cover);
    expect(b.settled, isTrue);
    expect(b.patchAlpha(RigExpression.neutral), 0, reason: 'no neutral patch');
  });

  test('asking for the expression already on the face does nothing', () {
    final b = ExpressionBlend();
    b.set(RigExpression.neutral);
    expect(b.covering, isFalse);
    b.set(RigExpression.happy);
    b.update(_cover);
    b.set(RigExpression.happy);
    expect(b.covering, isFalse, reason: 'no blink for no change');
    expect(b.patchAlpha(RigExpression.happy), 1);
  });
}
