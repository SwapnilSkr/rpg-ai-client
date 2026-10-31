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

/// A stretch of a layer's grid with its own cell count, along one axis
/// (crop-local coordinates).
class _Band {
  const _Band(this.top, this.bottom, this.cells);

  final double top;
  final double bottom;
  final int cells;
}

/// Appends the far edge of each of [cells] even cells from [from] to [to];
/// [from] itself is already an edge.
void _evenCells(List<double> edges, double from, double to, int cells) {
  for (var k = 1; k <= cells; k++) {
    edges.add(from + (to - from) * k / cells);
  }
}

/// Cell edges from 0 to [length]: each of [bands] sampled at its own cell
/// count, the gaps between them even cells of at most [cellPx].
///
/// The first edge is always 0 and the last always [length]. With no bands a
/// layer keeps the even grid it always had, [minCells] even for a crop shorter
/// than one cell.
List<double> _edges(
  double length,
  List<_Band> bands,
  double cellPx, {
  int minCells = 3,
}) {
  final edges = <double>[0];
  if (bands.isEmpty) {
    _evenCells(edges, 0, length, math.max(minCells, (length / cellPx).ceil()));
    return edges;
  }
  var at = 0.0;
  for (final b in bands) {
    // Bands never overlap in practice; a band that starts above the cursor
    // keeps only the part not already covered.
    if (b.bottom <= at) continue;
    final top = math.max(b.top, at);
    if (top > at) {
      _evenCells(edges, at, top, math.max(1, ((top - at) / cellPx).ceil()));
    }
    _evenCells(edges, top, b.bottom, b.cells);
    at = b.bottom;
  }
  if (at < length) {
    _evenCells(edges, at, length, math.max(1, ((length - at) / cellPx).ceil()));
  }
  return edges;
}

/// A band of [width] centred on [centre], clipped to a crop of [length], with
/// [cells] cells across it; null when it is empty or off the crop.
_Band? _band(double centre, double width, double length, int cells) {
  if (!(width > 0) || cells <= 0) return null;
  final mid = centre.clamp(0.0, length);
  final from = math.max(0.0, mid - width * 0.5);
  final to = math.min(length, mid + width * 0.5);
  return to > from ? _Band(from, to, cells) : null;
}

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
  /// The GPU interpolates positions linearly between vertices, so wherever a
  /// chord must stay short — a seam, or a patch that has to keep up with a
  /// coarser layer's curve — the grid gets a fine band. Rows: [headPx] /
  /// [headCells] split the top of the crop (hair_long, whose top row is the
  /// join), [tailPx] / [tailCells] the bottom (hair_front, whose fade runs up to
  /// the join), and [bandPx] / [bandCells] a band of [bandPx] canvas px centred
  /// on canvas row [bandY] (the base painting, which must agree with both at the
  /// join). Columns: [colBandW] canvas px centred on canvas column [colBandX]
  /// with [colCells] cells across it (the base over the face). Every other row
  /// and column covers its stretch with cells of at most [cellPx]. The tail
  /// never takes more than half the crop: the body above needs cells of its own.
  factory LayerMesh.grid({
    required double x,
    required double y,
    required double w,
    required double h,
    int? cols,
    double cellPx = RigTuning.meshCellPxHigh,
    double texScale = 1,
    double headPx = 0,
    int headCells = 0,
    double tailPx = 0,
    int tailCells = 0,
    double bandY = 0,
    double bandPx = 0,
    int bandCells = 0,
    double colBandX = 0,
    double colBandW = 0,
    int colCells = 0,
  }) {
    // Column edges, crop-local x. The hair layers force their cell count (one
    // spring per column); every other layer says how that count is derived.
    final colBand = _band(colBandX - x, colBandW, w, colCells);
    final xs = cols == null
        ? _edges(w, [if (colBand != null) colBand], cellPx)
        : [for (var i = 0; i <= cols; i++) w * i / cols];
    final c = xs.length - 1;
    // The fine bands as crop-local y ranges. A band with no height or no rows is
    // dropped: rows of zero height would collapse the grid and the deformations
    // would be read off the wrong cell.
    final headH = headPx.clamp(0.0, h);
    final tailH = tailPx.clamp(0.0, h * 0.5);
    final bands = <_Band>[
      if (headH > 0 && headCells > 0) _Band(0, headH, headCells),
      if (tailH > 0 && tailCells > 0) _Band(h - tailH, h, tailCells),
      if (_band(bandY - y, bandPx, h, bandCells) case final band?) band,
    ];
    bands.sort((a, b) => a.top.compareTo(b.top));
    final edges = _edges(h, bands, cellPx);
    final r = edges.length - 1;
    final count = (c + 1) * (r + 1);
    final rest = Float32List(count * 2);
    final tex = Float32List(count * 2);
    for (var j = 0; j <= r; j++) {
      for (var i = 0; i <= c; i++) {
        final k = (j * (c + 1) + i) * 2;
        final u = xs[i];
        final v = edges[j];
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

enum RigPart { base, outfit, patch, mouth, eyes, brows, hairLong, hairFront }

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
    required double hairJoinY,
  }) {
    // The hair is one painted strand cut in three at the join: the base
    // painting ends its hair, hair_front's crop ends, and hair_long's crop
    // begins. hair_front's own join is its bottom row and hair_long's is its
    // top row; both are derived from their specs. The base cannot see the other
    // layer's spec, so the set passes hair_long's top row (rig.json).
    final frontJoinY = spec.y + spec.h;
    final longTopY = spec.y;
    final isLong = part == RigPart.hairLong;
    final isFront = part == RigPart.hairFront;
    final isBase = part == RigPart.base;
    // The base's columns are refined over the face. The patches cut from it are
    // drawn by their own, finer meshes, and the GPU interpolates the base's
    // positions linearly between its columns: a base cell as wide as the face's
    // squeeze curve chords it, and a patch vertex then sits up to 1.5 px off the
    // painting under it on the low tier, which is the patch's edge showing.
    final faceBandW =
        2 * RigTuning.baseFaceBandShare * deformer.geometry.headRadii.dx;
    final mesh = LayerMesh.grid(
      x: spec.x,
      y: spec.y,
      w: spec.w,
      h: spec.h,
      // One spring per vertex column: n columns of vertices is n - 1 cells.
      cols: isLong ? quality.hairColumns - 1 : null,
      cellPx: quality.meshCellPx,
      texScale: image.width / spec.w,
      // hair_long's top and hair_front's bottom rows sit on the join. Fine rows
      // there sample the depth fade instead of stretching it across one cell.
      headPx: isLong ? RigTuning.hairJoinBandPx : 0,
      headCells: isLong ? RigTuning.hairJoinBandRows : 0,
      tailPx: isFront ? RigTuning.hairJoinBandPx : 0,
      tailCells: isFront ? RigTuning.hairJoinBandRows : 0,
      // The base is the reference at the join, so its mesh refines rows around
      // hair_long's top: a coarse chord across the seam is what opened the line.
      bandY: isBase ? hairJoinY : 0,
      bandPx: isBase ? 2 * RigTuning.baseJoinBandHalfPx : 0,
      bandCells: isBase ? RigTuning.baseJoinBandCells : 0,
      // ...and it is the reference under the face patches too.
      colBandX: isBase ? deformer.geometry.headCenter.dx : 0,
      colBandW: isBase ? faceBandW : 0,
      colCells: isBase ? (faceBandW / RigTuning.baseFaceCellPx).ceil() : 0,
    );
    final n = mesh.vertexCount;
    final depth = Float32List(n);
    final lagWeight = Float32List(n);
    final column = Uint8List(n);
    for (var j = 0; j <= mesh.rows; j++) {
      for (var i = 0; i <= mesh.cols; i++) {
        final v = j * (mesh.cols + 1) + i;
        final rest = ui.Offset(mesh.rest[v * 2], mesh.rest[v * 2 + 1]);
        // The base painting's own depth field at this vertex. The base uses it
        // everywhere; the patches, mouths and eyes are rectangles cut from edits
        // of that same painting, so they take it too — only then do a patch
        // vertex and the base vertex under it slide identically, and only then
        // are the patch's edges and the base's own irises and brows invisible.
        // The brows are cut from the same painting: they get it for the same
        // reason, and it is what keeps them on the face while the bangs, deeper
        // at 1.08, slide past under them.
        // The two hair layers blend to it at their joins.
        final field = deformer.baseDepth(rest);
        depth[v] = switch (part) {
          RigPart.base ||
          RigPart.patch ||
          RigPart.mouth ||
          RigPart.eyes ||
          RigPart.brows =>
            field,
          RigPart.outfit => RigTuning.depthFace,
          RigPart.hairLong => RigTuning.depthHairLong,
          RigPart.hairFront => RigTuning.depthHairFront,
        };
        if (isLong || isFront) {
          // Roots stay with the head (0), tips trail (1). The curve follows the
          // vertex's height in the crop, not its row index: the rows are finer
          // near a join, and the bangs above the band must keep exactly the
          // weight they always had.
          final f = ((rest.dy - spec.y) / spec.h).clamp(0.0, 1.0);
          lagWeight[v] = math.pow(f, RigTuning.hairLagCurve).toDouble();
          column[v] = i;
          if (isLong) {
            // s = 0 exactly at hair_long's top row, 1 at the far side of the
            // band. The top row must move as the base painting does, or the
            // painted seam opens; below the band the long hair keeps its own
            // depth. Multiplying the lag by s also pins the root row to the
            // head.
            final s = smoothstep(
              longTopY,
              longTopY + RigTuning.hairJoinBandPx,
              rest.dy,
            );
            depth[v] = field + (RigTuning.depthHairLong - field) * s;
            lagWeight[v] *= s;
          } else {
            // The bangs blend from their own depth above the band to the base's
            // depth exactly at their bottom row, so front, long and base all
            // agree where the strand is cut. Lag fades to 0 there as before.
            final s = smoothstep(
              frontJoinY - RigTuning.hairJoinBandPx,
              frontJoinY,
              rest.dy,
            );
            depth[v] = RigTuning.depthHairFront +
                (field - RigTuning.depthHairFront) * s;
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

  /// The shut eyes, one drawing per face.
  ///
  /// `eyes_closed` is a drawing of the neutral face, brows included, so it only
  /// sits honestly on a neutral face. A pack that carries `eyes_closed_<face>`
  /// for an expression gets that face's own shut eyes here; one that does not
  /// falls back to the neutral drawing for every face.
  late Map<RigExpression, RigLayerArt> eyesClosed;
  late RigLayerArt glanceLeft;
  late RigLayerArt glanceRight;

  /// The brow drawing for each face; a face is absent when the pack has no
  /// brows at all.
  ///
  /// The painting draws the brows on top of the bangs (the anime convention),
  /// so `hair_front` carries no brows and they are cut as their own layers. A
  /// face without its own drawing (`brows_<face>`) uses the neutral `brows`;
  /// a pack older than this carries neither and draws none, which leaves the
  /// brows where that pack painted them, in the hair.
  late Map<RigExpression, RigLayerArt> brows;
  late RigLayerArt hairLong;
  late RigLayerArt hairFront;

  RigQuality _quality = RigQuality.high;
  RigQuality get quality => _quality;

  void _buildLayers(RigQuality quality) {
    _quality = quality;
    // The row where the long hair takes over from the base painting, from
    // rig.json: the base mesh refines its rows around it.
    final hairJoinY = manifest.layer('hair_long').y;
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
        hairJoinY: hairJoinY,
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
    // Every blink on a non-neutral face draws this layer. The neutral drawing's
    // patch covers the eyes and the brows' lower edge, so over happy, shy or
    // surprised it left the neutral brow under the expression's own — a doubled
    // or cut brow for the blink's few frames — and on surprised its wide-open
    // upper lash line showed above the neutral lid as a dark smudge. A pack with
    // `eyes_closed_<face>` (that face's eyes, shut, with its own brows) fixes
    // it; without one the neutral drawing is still all there is.
    final closedNeutral = art('eyes_closed', RigPart.eyes);
    RigLayerArt shutEyes(RigExpression e) {
      if (e == RigExpression.neutral) return closedNeutral;
      final own = manifest.layerOrNull('eyes_closed_${e.name}');
      return own == null ? closedNeutral : art(own.name, RigPart.eyes);
    }

    eyesClosed = {for (final e in RigExpression.values) e: shutEyes(e)};
    glanceLeft = art('eyes_glance_left', RigPart.eyes);
    glanceRight = art('eyes_glance_right', RigPart.eyes);
    hairLong = art('hair_long', RigPart.hairLong);
    hairFront = art('hair_front', RigPart.hairFront);

    // Brows, bottom to top after the hair: the painter draws them on top of
    // hair_front. The neutral drawing serves every face that does not carry its
    // own, and is built once so the fallback is the same layer, not a copy of
    // it. A pack with no `brows` at all has no entry for any face.
    final neutralBrows = manifest.layerOrNull('brows') == null
        ? null
        : art('brows', RigPart.brows);
    brows = {};
    for (final e in RigExpression.values) {
      if (e == RigExpression.neutral) {
        if (neutralBrows != null) brows[e] = neutralBrows;
        continue;
      }
      final own = manifest.layerOrNull('brows_${e.name}');
      final layer = own == null ? neutralBrows : art(own.name, RigPart.brows);
      if (layer != null) brows[e] = layer;
    }
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

  /// The shut-eye drawing to draw for [expression].
  ///
  /// The lids belong to the face under them: drawn over another expression the
  /// neutral drawing's brows sit under that expression's own and read as a
  /// doubled brow. This is the one place the choice is made, so the painter and
  /// a test ask the same question.
  RigLayerArt closedFor(RigExpression expression) => eyesClosed[expression]!;

  /// The brow drawing to draw for [expression], or null when the pack has no
  /// brows.
  ///
  /// The brows belong to the face under them and are swapped with its patch,
  /// never blended: the painter asks this one question, so a test asks the same.
  RigLayerArt? browsFor(RigExpression expression) => brows[expression];

  /// A set, not a list: the faces that fall back share the neutral drawing, and
  /// the same layer must not be disposed (or its shader rebuilt) twice.
  Iterable<RigLayerArt> get all => {
        base,
        outfit,
        ...patches.values,
        ...mouths.values,
        eyesHalf,
        ...eyesClosed.values,
        ...brows.values,
        glanceLeft,
        glanceRight,
        hairLong,
        hairFront,
      };

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
