import 'dart:ui' show Offset;

/// One layer of the character: a crop of the shared canvas, drawn at (x, y).
class RigLayerSpec {
  const RigLayerSpec({
    required this.name,
    required this.file,
    required this.group,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  final String name;
  final String file;
  final String group;
  final double x;
  final double y;
  final double w;
  final double h;

  static RigLayerSpec fromJson(Map<String, dynamic> j) => RigLayerSpec(
        name: _string(j, 'name'),
        file: _string(j, 'file'),
        group: _string(j, 'group'),
        x: _number(j, 'x'),
        y: _number(j, 'y'),
        w: _number(j, 'w'),
        h: _number(j, 'h'),
      );
}

/// `rig.json`: the canvas size, the anchors, and the layers bottom to top.
class RigManifest {
  const RigManifest({
    required this.canvasW,
    required this.canvasH,
    required this.anchors,
    required this.layers,
  });

  final double canvasW;
  final double canvasH;
  final Map<String, Offset> anchors;
  final List<RigLayerSpec> layers;

  static RigManifest fromJson(Map<String, dynamic> json) {
    final canvas = json['canvas'];
    final anchors = json['anchors'];
    final layers = json['layers'];
    if (canvas is! Map<String, dynamic> ||
        anchors is! Map<String, dynamic> ||
        layers is! List) {
      throw const FormatException('rig.json needs canvas, anchors and layers');
    }
    return RigManifest(
      canvasW: _number(canvas, 'w'),
      canvasH: _number(canvas, 'h'),
      anchors: {
        for (final e in anchors.entries)
          e.key: switch (e.value) {
            [final num x, final num y] => Offset(x.toDouble(), y.toDouble()),
            _ => throw FormatException('anchor ${e.key} is not [x, y]'),
          },
      },
      layers: [
        for (final l in layers)
          RigLayerSpec.fromJson(l as Map<String, dynamic>),
      ],
    );
  }

  RigLayerSpec layer(String name) {
    for (final l in layers) {
      if (l.name == name) return l;
    }
    throw FormatException('rig.json has no layer "$name"');
  }

  Offset anchor(String name) {
    final a = anchors[name];
    if (a == null) throw FormatException('rig.json has no anchor "$name"');
    return a;
  }
}

String _string(Map<String, dynamic> j, String key) {
  final v = j[key];
  if (v is! String) throw FormatException('"$key" must be a string');
  return v;
}

double _number(Map<String, dynamic> j, String key) {
  final v = j[key];
  if (v is! num) throw FormatException('"$key" must be a number');
  return v.toDouble();
}
