import 'package:everlore/debug/rig_test/rig_expression.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('settles on the new expression in about 200 ms', () {
    final b = ExpressionBlend()..set(RigExpression.happy);
    expect(b.patchAlpha(RigExpression.happy), 0);
    b.update(0.1);
    final mid = b.patchAlpha(RigExpression.happy);
    expect(mid, inExclusiveRange(0.2, 0.8));
    b.update(0.11);
    expect(b.settled, isTrue);
    expect(b.patchAlpha(RigExpression.happy), 1);
    expect(b.patchAlpha(RigExpression.shy), 0);
  });

  test('the outgoing patch stays opaque under the incoming one', () {
    final b = ExpressionBlend()..set(RigExpression.shy);
    b.update(1);
    b.set(RigExpression.surprised);
    b.update(0.1);
    expect(b.patchAlpha(RigExpression.shy), 1);
    expect(b.patchAlpha(RigExpression.surprised), inExclusiveRange(0, 1));
  });

  test('fading to neutral fades the old patch out', () {
    final b = ExpressionBlend()..set(RigExpression.happy);
    b.update(1);
    b.set(RigExpression.neutral);
    b.update(0.1);
    expect(b.patchAlpha(RigExpression.happy), inExclusiveRange(0.2, 0.8));
    b.update(0.2);
    expect(b.patchAlpha(RigExpression.happy), 0);
    expect(b.patchAlpha(RigExpression.neutral), 0, reason: 'no neutral patch');
  });

  test('every alpha stays within 0..1 through any change', () {
    final b = ExpressionBlend();
    for (final e in [
      ...RigExpression.values,
      RigExpression.happy,
      RigExpression.neutral,
    ]) {
      b.set(e);
      for (var i = 0; i < 20; i++) {
        b.update(0.012);
        for (final x in RigExpression.values) {
          expect(b.patchAlpha(x), inInclusiveRange(0, 1));
          expect(b.mouthWeight(x), inInclusiveRange(0, 1));
        }
      }
    }
  });

  test('the mouth follows the expression, neutral included', () {
    final b = ExpressionBlend();
    expect(b.mouthWeight(RigExpression.neutral), 1);
    b.set(RigExpression.happy);
    b.update(1);
    expect(b.mouthWeight(RigExpression.happy), 1);
    expect(b.mouthWeight(RigExpression.neutral), 0);
  });
}
