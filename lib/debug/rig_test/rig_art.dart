import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'rig_deform.dart';
import 'rig_expression.dart';
import 'rig_manifest.dart';
import 'rig_tuning.dart';

/// A layer as a grid of quads over its crop of the canvas.
///
/// `rest` holds canvas-space positions, `tex` the matching pixel positions in
/// the layer's own image (an ImageShader samples in image pixels), `indices`
/// two triangles per cell. Built once; only the deformed positions change.
class LayerMesh {
  LayerMesh._(this.cols, this.rows, this.rest, this.tex, this.indices);

  /// A grid for a crop at (x, y) of size w x h. [cols] overrides the cell size.
  factory LayerMesh.grid({
    required double x,
    required double y,
    required double w,
    required double h,
    int? cols,
  }) {
    final c = cols ?? math.max(3, (w / RigTuning.meshCellPx).ceil());
    final r = math.max(3, (h / RigTuning.meshCellPx).ceil());
    final count = (c + 1) * (r + 1);
    final rest = Float32List(count * 2);
    final tex = Float32List(count * 2);
    for (var j = 0; j <= r; j++) {
      for (var i = 0; i <= c; i++) {
        final k = (j * (c + 1) + i) * 2;
        final u = w * i / c;
        final v = h * j / r;
        tex[k] = u;
        tex[k + 1] = v;
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
  }) {
    final mesh = LayerMesh.grid(
      x: spec.x,
      y: spec.y,
      w: spec.w,
      h: spec.h,
      // One spring per vertex column: n columns of vertices is n - 1 cells.
      cols: part == RigPart.hairLong ? RigTuning.hairColumns - 1 : null,
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
          lagWeight[v] = math.pow(j / mesh.rows, RigTuning.hairLagCurve).toDouble();
          column[v] = i;
        }
      }
    }
    final shader = ui.ImageShader(
      image,
      ui.TileMode.clamp,
      ui.TileMode.clamp,
      _identity,
      filterQuality: RigTuning.mipmap ? ui.FilterQuality.medium : ui.FilterQuality.low,
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
class RigArtSet {
  RigArtSet._({
    required this.manifest,
    required this.deformer,
    required this.base,
    required this.outfit,
    required this.patches,
    required this.mouths,
    required this.eyesHalf,
    required this.eyesClosed,
    required this.glanceLeft,
    required this.glanceRight,
    required this.hairLong,
    required this.hairFront,
  });

  /// Builds the set from decoded images keyed by file name. Throws a
  /// [FormatException] when rig.json and the images disagree.
  factory RigArtSet.build(RigManifest manifest, Map<String, ui.Image> images) {
    final deformer = RigDeformer(RigGeometry.fromManifest(manifest));
    RigLayerArt art(String name, RigPart part) {
      final spec = manifest.layer(name);
      final image = images[spec.file];
      if (image == null) throw FormatException('missing image ${spec.file}');
      return RigLayerArt.build(spec: spec, part: part, image: image, deformer: deformer);
    }

    final others = RigExpression.values.where((e) => e != RigExpression.neutral);
    return RigArtSet._(
      manifest: manifest,
      deformer: deformer,
      base: art('base', RigPart.base),
      outfit: art('outfit_blazer', RigPart.outfit),
      patches: {for (final e in others) e: art('face_${e.name}', RigPart.patch)},
      mouths: {
        for (final e in RigExpression.values)
          e: art(
            e == RigExpression.neutral ? 'mouth_open' : 'mouth_open_${e.name}',
            RigPart.mouth,
          ),
      },
      eyesHalf: art('eyes_half', RigPart.eyes),
      eyesClosed: art('eyes_closed', RigPart.eyes),
      glanceLeft: art('eyes_glance_left', RigPart.eyes),
      glanceRight: art('eyes_glance_right', RigPart.eyes),
      hairLong: art('hair_long', RigPart.hairLong),
      hairFront: art('hair_front', RigPart.hairFront),
    );
  }

  final RigManifest manifest;
  final RigDeformer deformer;
  final RigLayerArt base;
  final RigLayerArt outfit;
  final Map<RigExpression, RigLayerArt> patches;
  final Map<RigExpression, RigLayerArt> mouths;
  final RigLayerArt eyesHalf;
  final RigLayerArt eyesClosed;
  final RigLayerArt glanceLeft;
  final RigLayerArt glanceRight;
  final RigLayerArt hairLong;
  final RigLayerArt hairFront;

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

/// Reads rig.json and the PNGs from [dir] and decodes each image once.
Future<RigArtSet> loadRigArt(Directory dir) async {
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
      final codec = await ui.instantiateImageCodec(bytes);
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
