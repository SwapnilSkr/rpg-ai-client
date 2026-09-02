import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everlore/app/layout/responsive.dart';
import 'package:everlore/app/theme/nexus_theme.dart';
import 'package:everlore/shared/widgets/everlore_empty_state.dart';
import 'package:everlore/shared/widgets/everlore_nav_bar.dart';
import 'package:everlore/shared/widgets/everlore_notice.dart';
import 'package:everlore/shared/widgets/everlore_sheet.dart';
import 'package:everlore/shared/widgets/interest_picker.dart';
import 'package:everlore/shared/widgets/mature_content_chip.dart';

/// The device envelope the app claims to support. A layout that survives the
/// four corners of this — a 320pt phone at 140% text and a tablet at 100% —
/// survives the range in between.
const _devices = <String, Size>{
  'small phone 320x568': Size(320, 568),
  'phone 360x640': Size(360, 640),
  'tall phone 393x851': Size(393, 851),
  'tablet 800x1280': Size(800, 1280),
};

const _textScales = <double>[1.0, 1.4];

Future<void> _loadFonts() async {
  for (final weight in ['Regular', 'Medium', 'Semibold', 'Bold']) {
    final file = File('assets/fonts/GeneralSans-$weight.ttf');
    if (!file.existsSync()) continue;
    final loader = FontLoader('GeneralSans')
      ..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    await loader.load();
  }
}

/// Pumps [child] at every device/text-scale combination and fails on any
/// layout exception — an overflow is reported through the same channel.
void layoutMatrix(String description, Widget Function() build) {
  for (final entry in _devices.entries) {
    for (final scale in _textScales) {
      testWidgets('$description — ${entry.key} @${scale}x', (tester) async {
        await _loadFonts();
        tester.view.physicalSize = entry.value * 3;
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: entry.value,
              textScaler: TextScaler.linear(scale),
              padding: const EdgeInsets.only(top: 24, bottom: 16),
            ),
            child: MaterialApp(
              theme: EverloreTheme.dark,
              useInheritedMediaQuery: true,
              home: Scaffold(
                backgroundColor: EverloreTheme.void0,
                body: build(),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          tester.takeException(),
          isNull,
          reason: '$description overflowed on ${entry.key} at ${scale}x text',
        );
      });
    }
  }
}

void main() {
  layoutMatrix(
    'interest picker',
    () => SingleChildScrollView(
      child: InterestPickerGrid(selected: const {'noir'}, onToggle: (_) {}),
    ),
  );

  layoutMatrix(
    'sheet frame with a long body and a footer',
    () => SheetFrame(
      footer: const SizedBox(height: 52),
      child: Column(
        children: List.generate(
          14,
          (i) => const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'A line of sheet content that has to wrap on a small screen.',
            ),
          ),
        ),
      ),
    ),
  );

  layoutMatrix(
    'nav bar',
    () => EverloreNavBar(
      currentIndex: 0,
      onSelect: (_) {},
      onCreate: () {},
    ),
  );

  layoutMatrix(
    'mature chip in a tight wrap',
    () => const SizedBox(
      width: 92,
      child: Wrap(children: [MatureContentChip()]),
    ),
  );

  layoutMatrix(
    'empty state',
    () => const EverloreEmptyState(
      icon: Icons.person_add_alt_1_rounded,
      eyebrow: 'PERSONA VAULT',
      title: 'Who will you become?',
      message:
          'Create a reusable identity for your journeys. Your name, voice, '
          'and story begin here.',
      actionLabel: 'Create persona',
      actionIcon: Icons.add_rounded,
      accent: EverloreTheme.gold,
      compact: false,
    ),
  );

  layoutMatrix(
    'centred content that cannot fit',
    () => EvCenteredScroll(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          10,
          (i) => const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text('A tall centred block that must scroll when squeezed.'),
          ),
        ),
      ),
    ),
  );

  group('width classes', () {
    // The Explore masonry picks its column count from this, so a phone that
    // started reporting `expanded` would put three covers on a 360pt screen,
    // and a tablet reporting `regular` is what left two half-screen-wide
    // cards on an 800pt one.
    EvWidthClass classOf(double width) {
      late EvWidthClass seen;
      runApp(
        MediaQuery(
          data: MediaQueryData(size: Size(width, 800)),
          child: Builder(
            builder: (context) {
              seen = EvLayout.of(context).widthClass;
              return const SizedBox();
            },
          ),
        ),
      );
      return seen;
    }

    testWidgets('a narrow phone is compact', (tester) async {
      expect(classOf(320), EvWidthClass.compact);
      expect(classOf(359), EvWidthClass.compact);
    });

    testWidgets('an ordinary phone is regular', (tester) async {
      expect(classOf(360), EvWidthClass.regular);
      expect(classOf(393), EvWidthClass.regular);
      expect(classOf(599), EvWidthClass.regular);
    });

    testWidgets('a tablet is expanded', (tester) async {
      expect(classOf(600), EvWidthClass.expanded);
      expect(classOf(800), EvWidthClass.expanded);
    });
  });

  group('dismissal contracts', () {
    testWidgets('a notice can be tapped away and retires on its own', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: EverloreTheme.dark,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showEverloreNotice(
                    context,
                    'Saved.',
                    tone: NoticeTone.success,
                  ),
                  child: const Text('go'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Saved.'), findsOneWidget);

      // Tapping it dismisses immediately, rather than the player waiting out
      // an overlay that ignored every touch.
      await tester.tap(find.text('Saved.'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Saved.'), findsNothing);

      // And one left alone retires by itself.
      await tester.tap(find.text('go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Saved.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Saved.'), findsNothing);
    });

    testWidgets('only one notice is on screen at a time', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: EverloreTheme.dark,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => showEverloreNotice(context, 'First'),
                      child: const Text('a'),
                    ),
                    TextButton(
                      onPressed: () => showEverloreNotice(context, 'Second'),
                      child: const Text('b'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('a'));
      await tester.pump();
      await tester.tap(find.text('b'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('First'), findsNothing);
      expect(find.text('Second'), findsOneWidget);
    });

    testWidgets('a sheet closes when its grab handle is pulled down', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: EverloreTheme.dark,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showEverloreSheet<void>(
                    context: context,
                    builder: (_) => const SheetFrame(
                      child: SizedBox(height: 300, child: Text('sheet body')),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('sheet body'), findsOneWidget);

      // The pill is the one part of a sheet that is always draggable, even
      // when the body is a scroll view that would otherwise eat the gesture.
      await tester.drag(find.byType(SheetGrabHandle), const Offset(0, 220));
      await tester.pumpAndSettle();
      expect(find.text('sheet body'), findsNothing);
    });
  });
}
