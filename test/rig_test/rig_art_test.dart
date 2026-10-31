import 'package:everlore/debug/rig_test/rig_art.dart';
import 'package:everlore/debug/rig_test/rig_quality.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('textures are decoded at the size they cover on screen', () {
    // A 1080 px tall screen draws the 1536 px canvas at 1080, so a 938 px layer
    // covers 660 px of it.
    expect(
      textureTargetWidth(layerW: 938, canvasH: 1536, displayHeightPx: 1080),
      660,
    );
    // Unanswerable questions decode natively.
    expect(textureTargetWidth(layerW: 938, canvasH: 1536, displayHeightPx: 0), 0);
    expect(textureTargetWidth(layerW: 938, canvasH: 0, displayHeightPx: 1080), 0);
    // Never a zero-width image.
    expect(textureTargetWidth(layerW: 10, canvasH: 1536, displayHeightPx: 1), 1);
  });

  test('a texture decoded smaller than its crop maps the mesh onto it', () {
    final mesh = LayerMesh.grid(x: 10, y: 20, w: 400, h: 300, texScale: 0.5);
    expect(mesh.tex[0], 0);
    expect(mesh.tex[1], 0);
    final last = mesh.vertexCount - 1;
    // The texture ends at the smaller image's size...
    expect(mesh.tex[last * 2], 200);
    expect(mesh.tex[last * 2 + 1], 150);
    // ...while the canvas-space grid still ends at the crop's corner.
    expect(mesh.rest[last * 2], 410);
    expect(mesh.rest[last * 2 + 1], 320);
  });

  test('the low tier builds a cheaper mesh', () {
    final high = LayerMesh.grid(x: 44, y: 371, w: 946, h: 863);
    final low = LayerMesh.grid(
      x: 44,
      y: 371,
      w: 946,
      h: 863,
      cellPx: RigQuality.low.meshCellPx,
    );
    expect(high.cols > low.cols, isTrue);
    expect(low.vertexCount, lessThan(high.vertexCount));
  });
}
