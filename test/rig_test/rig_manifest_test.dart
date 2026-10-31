import 'dart:convert';

import 'package:everlore/debug/rig_test/rig_deform.dart';
import 'package:everlore/debug/rig_test/rig_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

const _json = '''
{"canvas":{"w":1024,"h":1536},
 "anchors":{"neck":[512,650],"waist":[512,1536]},
 "layers":[{"name":"base","file":"base.png","group":"base","x":48,"y":85,"w":938,"h":1451}]}
''';

void main() {
  test('reads canvas, anchors and layers', () {
    final m = RigManifest.fromJson(jsonDecode(_json) as Map<String, dynamic>);
    expect(m.canvasW, 1024);
    expect(m.anchor('neck').dy, 650);
    expect(m.layer('base').w, 938);
    expect(RigGeometry.fromManifest(m).waist.dy, 1536);
  });

  test('says which part is missing instead of failing later', () {
    final m = RigManifest.fromJson(jsonDecode(_json) as Map<String, dynamic>);
    expect(() => m.layer('nope'), throwsFormatException);
    expect(() => m.anchor('nope'), throwsFormatException);
    expect(() => RigManifest.fromJson({'canvas': {}}), throwsFormatException);
  });
}
