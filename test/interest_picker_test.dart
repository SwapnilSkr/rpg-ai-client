import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:everlore/shared/widgets/interest_picker.dart';
import 'package:everlore/shared/narrative_styles.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final w in ['Regular', 'Medium', 'Semibold']) {
      final f = File('assets/fonts/GeneralSans-$w.ttf');
      if (!f.existsSync()) continue;
      final loader = FontLoader('GeneralSans')
        ..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
      await loader.load();
    }
  });

  for (final width in [320.0, 360.0, 393.0, 412.0]) {
  testWidgets('no interest label is clipped at ${width}dp', (t) async {
    t.view.physicalSize = Size(width * 2, 1600);
    t.view.devicePixelRatio = 2.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: InterestPickerGrid(selected: const {}, onToggle: (_) {}),
        ),
      ),
    ));

    for (final style in kInterestStyles) {
      final finder = find.text(style.label);
      expect(finder, findsOneWidget, reason: style.key);
      final rp = t.renderObject<RenderParagraph>(finder);
      expect(rp.didExceedMaxLines, isFalse,
          reason: '"${style.label}" is being truncated');
    }
  });
  }
}
