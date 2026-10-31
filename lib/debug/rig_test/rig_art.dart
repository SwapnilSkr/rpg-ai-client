import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'rig_deform.dart';
import 'rig_expression.dart';
import 'rig_manifest.dart';
import 'rig_quality.dart';
import 'rig_tuning.dart';

/// A layer as a grid of quads over its crop of the canvas.
///
/// `rest` holds canvas-space positions, `tex` the matching pixel positions in
/// the layer's own image (an ImageShader samples in image pixels), `indices`
/// two triangles per cell. Built once per quality tier; only the deformed
/// positions change per frame.
class LayerMesh {
  LayerMesh._(this.cols, this.rows, this.rest, this.tex, this.indices);

  /// A grid for a crop at (x, y) of size w x h. [cols] overrides the cell size.
  ///
  /// [texScale] converts canvas pixels to the decoded image's pixels: the
  /// texture may be smaller than its crop when it was decoded at display size,
  /// and a shader samples its own image.
  ///
  /// [tailPx] splits the bottom of the crop into [tailCells] even rows instead
  /// of covering it with cells of [cellPx]. Only hair_front asks for it: its
  /// motion fades over the last few dozen px before the join with hair_long,
  /// and one 40 px cell across a 60 px band would sample that fade so coarsely
  /// that the seam still showed. Never more than half the crop: the body above
  /// needs cells of its own.
  factory LayerMesh.grid({
    required double x,
    required double y,
    required double w,
    required double h,
    int? cols,
    double cellPx = RigTuning.meshCellPxHigh,
    double texScale = 1,
    double tailPx = 0,
    int tailCells = 0,
  }) {
    final c = cols ?? math.max(3, (w / cellPx).ceil());
    final tailH = tailPx.clamp(0.0, h * 0.5);
    // No tail height means no tail rows: rows of zero height would collapse
    // the grid and the deformations would be read off the wrong cell.
    final tail = tailH > 0 ? tailCells : 0;
    final bodyH = h - tailH;
    final body = tail > 0
        ? math.max(1, (bodyH / cellPx).ceil())
        : math.max(3, (h / cellPx).ceil());
    final r = body + tail;
    // Row j's height above the crop's top: even cells of [cellPx] down to the
    // tail, then the tail's own even rows.
    double rowH(int j) =>
        j <= body ? bodyH * j / body : bodyH + tailH * (j - body) / tail;
    final count = (c + 1) * (r + 1);
    final rest = Float32List(count * 2);
    final tex = Float32List(count * 2);
    for (var j = 0; j <= r; j++) {
      for (var i = 0; i <= c; i++) {
        final k = (j * (c + 1) + i) * 2;
        final u = w * i / c;
        final v = rowH(j);
        tex[k] = u * texScale;
        tex[k + 1] = v * texScale;
        rest[k] = x + u;
        rest[k + 1] = y + v;
      }
    }
    final indices = Uint16List(c * r * 6);
    var n = 0;
    for (var j = 0; j < r; j++) {
      for (var i = 0; i < c; i++) {
        final a = j * (c + 1) + i;
        final b = a + 1;
        final d = a + c + 1;
        final e = d + 1;
        indices[n++] = a;
        indices[n++] = b;
        indices[n++] = d;
        indices[n++] = b;
        indices[n++] = e;
        indices[n++] = d;
      }
    }
    return LayerMesh._(c, r, rest, tex, indices);
  }

  final int cols;
  final int rows;
  final Float32List rest;
  final Float32List tex;
  final Uint16List indices;

  int get vertexCount => (cols + 1) * (rows + 1);
}

final Float64List _identity = Float64List.fromList(
  [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1],
);

enum RigPart { base, outfit, patch, mouth, eyes, hairLong, hairFront }

/// One decoded layer, ready to draw either way: the image for the paper doll,
/// the mesh + shader for the deformed rig. Everything per-vertex that does not
/// change between frames (depth, hair lag weight, hair column) is computed once.
class RigLayerArt {
  RigLayerArt._({
    required this.spec,
    required this.part,
    required this.image,
    required this.mesh,
    required this.shader,
    required this.depth,
    required this.lagWeight,
    required this.column,
  }) : positions = Float32List(mesh.vertexCount * 2);

  factory RigLayerArt.build({
    required RigLayerSpec spec,
    required RigPart part,
    required ui.Image image,
    required RigDeformer deformer,
    RigQuality quality = RigQuality.high,
  }) {
    // The two hair layers are one painted strand cut in two at this row: the
    // front's crop ends and the long crop begins. Everything the join needs is
    // derived from the specs, never from a hand-written pixel number.
    final joinY = spec.y + spec.h;
    final blends = part == RigPart.hairFront;
    final mesh = LayerMesh.grid(
      x: spec.x,
      y: spec.y,
      w: spec.w,
      h: spec.h,
      // One spring per vertex column: n columns of vertices is n - 1 cells.
      cols: part == RigPart.hairLong ? quality.hairColumns - 1 : null,
      cellPx: quality.meshCellPx,
      texScale: image.width / spec.w,
      // Only the front fades, and only over its last hairJoinBandPx, so only it
      // gets the fine rows that sample the fade.
      tailPx: blends ? RigTuning.hairJoinBandPx : 0,
      tailCells: blends ? RigTuning.hairJoinBandRows : 0,
    );
    final n = mesh.vertexCount;
    final depth = Float32List(n);
    final lagWeight = Float32List(n);
    final column = Uint8List(n);
    for (var j = 0; j <= mesh.rows; j++) {
      for (var i = 0; i <= mesh.cols; i++) {
        final v = j * (mesh.cols + 1) + i;
        final rest = ui.Offset(mesh.rest[v * 2], mesh.rest[v * 2 + 1]);
        depth[v] = switch (part) {
          RigPart.base => deformer.baseDepth(rest),
          RigPart.outfit => RigTuning.depthFace,
          RigPart.patch || RigPart.mouth || RigPart.eyes => RigTuning.depthFeatures,
          RigPart.hairLong => RigTuning.depthHairLong,
          RigPart.hairFront => RigTuning.depthHairFront,
        };
        // Roots stay with the head (0), tips trail (1).
        if (part == RigPart.hairLong || part == RigPart.hairFront) {
          // The curve follows the vertex's height in the crop, not its row
          // index: the front's rows are finer near the bottom, and the bangs
          // above the band must keep exactly the weight they always had.
          final f = ((rest.dy - spec.y) / spec.h).clamp(0.0, 1.0);
          lagWeight[v] = math.pow(f, RigTuning.hairLagCurve).toDouble();
          column[v] = i;
          if (blends) {
            // At the join the front must move as the long hair's root row
            // does — depthHairLong and no lag — or the strand tears there.
            // The blend reaches exactly depthHairLong and weight 0 at joinY.
            final s = smoothstep(
              joinY - RigTuning.hairJoinBandPx,
              joinY,
              rest.dy,
            );
            depth[v] += (RigTuning.depthHairLong - RigTuning.depthHairFront) * s;
            lagWeight[v] *= 1 - s;
          }
        }
      }
    }
    final shader = ui.ImageShader(
      image,
      ui.TileMode.clamp,
      ui.TileMode.clamp,
      _identity,
      filterQuality: quality.filterQuality,
    );
    return RigLayerArt._(
      spec: spec,
      part: part,
      image: image,
      mesh: mesh,
      shader: shader,
      depth: depth,
      lagWeight: lagWeight,
      column: column,
    );
  }

  final RigLayerSpec spec;
  final RigPart part;
  final ui.Image image;
  final LayerMesh mesh;
  final ui.ImageShader shader;
  final Float32List depth;
  final Float32List lagWeight;
  final Uint8List column;

  /// Reused every frame; `Vertices.raw` copies it, so one list is enough.
  final Float32List positions;

  void dispose() {
    shader.dispose();
    image.dispose();
  }
}

/// All layers of the character, typed by role.
///
/// The decoded images are shared by every quality tier: switching tier rebuilds
/// the meshes and shaders only, so a mid-session switch costs a vertex buffer
/// per layer and no decode.
class RigArtSet {
  RigArtSet._(this.manifest, this.images, this.deformer, RigQuality quality) {
    _buildLayers(quality);
  }

  /// Builds the set from decoded images keyed by file name. Throws a
  /// [FormatException] when rig.json and the images disagree.
  factory RigArtSet.build(
    RigManifest manifest,
    Map<String, ui.Image> images, {
    RigQuality quality = RigQuality.high,
  }) =>
      RigArtSet._(
        manifest,
        images,
        RigDeformer(RigGeometry.fromManifest(manifest)),
        quality,
      );

  final RigManifest manifest;
  final Map<String, ui.Image> images;
  final RigDeformer deformer;

  late RigLayerArt base;
  late RigLayerArt outfit;
  late Map<RigExpression, RigLayerArt> patches;
  late Map<RigExpression, RigLayerArt> mouths;
  late RigLayerArt eyesHalf;
  late RigLayerArt eyesClosed;
  late RigLayerArt glanceLeft;
  late RigLayerArt glanceRight;
  late RigLayerArt hairLong;
  late RigLayerArt hairFront;

  RigQuality _quality = RigQuality.high;
  RigQuality get quality => _quality;

  void _buildLayers(RigQuality quality) {
    _quality = quality;
    RigLayerArt art(String name, RigPart part) {
      final spec = manifest.layer(name);
      final image = images[spec.file];
      if (image == null) throw FormatException('missing image ${spec.file}');
      return RigLayerArt.build(
        spec: spec,
        part: part,
        image: image,
        deformer: deformer,
        quality: quality,
      );
    }

    final others = RigExpression.values.where((e) => e != RigExpression.neutral);
    base = art('base', RigPart.base);
    outfit = art('outfit_blazer', RigPart.outfit);
    patches = {for (final e in others) e: art('face_${e.name}', RigPart.patch)};
    mouths = {
      for (final e in RigExpression.values)
        e: art(
          e == RigExpression.neutral ? 'mouth_open' : 'mouth_open_${e.name}',
          RigPart.mouth,
        ),
    };
    eyesHalf = art('eyes_half', RigPart.eyes);
    eyesClosed = art('eyes_closed', RigPart.eyes);
    glanceLeft = art('eyes_glance_left', RigPart.eyes);
    glanceRight = art('eyes_glance_right', RigPart.eyes);
    hairLong = art('hair_long', RigPart.hairLong);
    hairFront = art('hair_front', RigPart.hairFront);
  }

  /// Rebuilds the meshes at [quality]. The images are reused and stay owned by
  /// this set, so nothing needs decoding and nothing is disposed here but the
  /// old shaders.
  void setQuality(RigQuality quality) {
    if (quality == _quality) return;
    for (final a in all) {
      a.shader.dispose();
    }
    _buildLayers(quality);
  }

  Iterable<RigLayerArt> get all => [
        base,
        outfit,
        ...patches.values,
        ...mouths.values,
        eyesHalf,
        eyesClosed,
        glanceLeft,
        glanceRight,
        hairLong,
        hairFront,
      ];

  void dispose() {
    for (final a in all) {
      a.dispose();
    }
  }
}

/// The width to decode a layer at: the pixels it will actually cover on screen,
/// i.e. its width times how many physical pixels the canvas height spans.
///
/// Returns 0 for "native size" when the display height is unknown. The codec is
/// asked not to upscale, so a screen bigger than the art caps it at the source
/// width — this only ever saves GPU memory, never spends it.
int textureTargetWidth({
  required double layerW,
  required double canvasH,
  required double displayHeightPx,
}) {
  if (displayHeightPx <= 0 || canvasH <= 0) return 0;
  return math.max(1, (layerW * displayHeightPx / canvasH).round());
}

/// Reads rig.json and the PNGs from [dir] and decodes each image once, at
/// roughly the size it will occupy on a [displayHeightPx]-tall screen.
Future<RigArtSet> loadRigArt(Directory dir, {double displayHeightPx = 0}) async {
  final manifestFile = File('${dir.path}/rig.json');
  if (!await manifestFile.exists()) {
    throw FileSystemException('rig.json not found', manifestFile.path);
  }
  final manifest = RigManifest.fromJson(
    _decodeJson(await manifestFile.readAsString()),
  );
  final images = <String, ui.Image>{};
  try {
    for (final l in manifest.layers) {
      final bytes = await File('${dir.path}/${l.file}').readAsBytes();
      final width = textureTargetWidth(
        layerW: l.w,
        canvasH: manifest.canvasH,
        displayHeightPx: displayHeightPx,
      );
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: width == 0 ? null : width,
        allowUpscaling: false,
      );
      final frame = await codec.getNextFrame();
      codec.dispose();
      images[l.file] = frame.image;
    }
    return RigArtSet.build(manifest, images);
  } catch (_) {
    for (final i in images.values) {
      i.dispose();
    }
    rethrow;
  }
}

Map<String, dynamic> _decodeJson(String text) {
  final v = jsonDecode(text);
  if (v is! Map<String, dynamic>) {
    throw const FormatException('rig.json is not an object');
  }
  return v;
}
