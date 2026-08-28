import 'dart:async';

import 'package:everlore/core/guide/guide_anchor.dart';
import 'package:everlore/core/guide/guide_beat.dart';
import 'package:everlore/core/guide/guide_controller.dart';
import 'package:everlore/core/guide/widgets/guide_cutout.dart';
import 'package:everlore/core/guide/widgets/guide_host.dart';
import 'package:everlore/core/guide/widgets/guide_speech_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// The host runs a ticker while a beat is anchored and the pulse ring repeats
// forever, so these never quiesce — pump fixed frames rather than settling.

const _flow = GuideFlow(
  id: 'test.flow',
  label: 'Test arc',
  beats: [
    GuideBeat(anchor: 'test.target', title: 'First Beat', body: 'One.'),
    GuideBeat(anchor: 'test.target', title: 'Second Beat', body: 'Two.'),
  ],
);

Widget _app() => MaterialApp(
  home: GuideHost(
    child: Scaffold(
      body: Center(
        child: GuideAnchor(
          id: 'test.target',
          child: const SizedBox(width: 120, height: 40, child: Text('Target')),
        ),
      ),
    ),
  ),
);

const _longBody =
    'The souls present in this scene, and how near they hold you. Open one to '
    'speak with them apart from the story, and whatever passes between you is '
    'remembered exactly as the rest of the world remembers it.';

/// Let an arc finish arriving.
///
/// The overlay fades up over ~0.5s and the opening is allowed to ease for a
/// moment after that, so a single `pump(400ms)` — which is where these tests
/// used to land — now catches the guide mid-animation. A ticker's elapsed time
/// also starts at zero on its *first* frame, so the first pump advances
/// nothing at all; hence the pump before the wait.
Future<void> _depart(WidgetTester tester) async {
  // An arc no longer vanishes between frames: the overlay fades out over
  // ~0.2s and keeps drawing the beat it has left until it has gone. Same
  // first-frame caveat as [_arrive].
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _arrive(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUp(() async {
    await guide.onSignedOut();
    // The quiet gap between arcs is a real-time timer; these tests drive arcs
    // back to back on purpose, so it is off unless a test asks for it.
    GuideController.arcGap = Duration.zero;
  });

  // Cancels the gap timer an arc leaves behind, so it cannot outlive the tree.
  tearDown(() async {
    await guide.onSignedOut();
    GuideController.arcGap = Duration.zero;
  });

  testWidgets('a tab hanging off a sideways strip is scrolled fully in', (
    tester,
  ) async {
    // The Chronicle's tab strip scrolls horizontally, and a tab at the far
    // end can be visible enough to resolve while still running past the
    // bezel. The overflow check only ever looked at top and bottom, so the
    // strip never scrolled and the opening was clipped flat against the edge
    // instead of lighting the whole tab.
    const flow = GuideFlow(
      id: 'test.strip',
      label: 'Strip arc',
      beats: [GuideBeat(anchor: 'tab.last', title: 'Last Tab', body: 'X.')],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GuideHost(
          child: Scaffold(
            body: SizedBox(
              height: 60,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  // Leaves the tab overhanging the 800pt test surface by 10pt
                  // — comfortably past `_minVisible`, so it resolves and the
                  // old code opened on it exactly where it stood.
                  const SizedBox(width: 690),
                  GuideAnchor(
                    id: 'tab.last',
                    child: Container(
                      width: 120,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF333333),
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() => guide.replay(flow));
    await _arrive(tester);
    // The reveal is a 300ms scroll; let it land.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    final hole = _openingOf(tester);
    expect(hole, isNotNull);
    expect(
      hole!.width,
      greaterThanOrEqualTo(120),
      reason: 'the whole tab must be lit, not the sliver of it that fitted',
    );
    expect(hole.right, lessThanOrEqualTo(800));

    guide.skip();
    await _depart(tester);
  });

  testWidgets('a wide row in a vertical list is not treated as overflowing', (
    tester,
  ) async {
    // The other half of the same rule. A card that spans the width of a
    // vertical list overhangs nothing it can be scrolled away from, and
    // answering true here would scroll the page for no reason a reader could
    // see.
    await tester.pumpWidget(
      MaterialApp(
        home: GuideHost(
          child: Scaffold(
            body: ListView(
              children: [
                GuideAnchor(
                  id: 'row.wide',
                  child: Container(height: 80, color: const Color(0xFF333333)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(GuideAnchorRegistry.instance.overflowsViewport('row.wide'), isFalse);
  });

  testWidgets('the lit control answers the first tap, not the second', (
    tester,
  ) async {
    // Lighting a control and then eating the tap it invites is the
    // walkthrough working against itself: the player aims at the thing being
    // explained, the scrim swallows it, and the control only responds once
    // they have worked out that they must tap it again.
    var fired = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: GuideHost(
          child: Scaffold(
            body: Center(
              child: GuideAnchor(
                id: 'test.target',
                child: GestureDetector(
                  onTap: () => fired++,
                  behavior: HitTestBehavior.opaque,
                  child: const SizedBox(
                    width: 160,
                    height: 60,
                    child: Text('Target'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() => guide.replay(_flow));
    await _arrive(tester);
    expect(find.text('FIRST BEAT'), findsOneWidget);

    // Straight at the middle of the opening, with the guide still up.
    await tester.tapAt(tester.getCenter(find.text('Target')));
    await tester.pump();
    expect(fired, 1, reason: 'the control underneath must receive the tap');

    guide.skip();
    await _depart(tester);
  });

  testWidgets('an arc that finds nothing to point at stays owed', (
    tester,
  ) async {
    // The first-run case this exists for: a player opens Realms before they
    // have played anything, so the card the arc is built around does not
    // exist. Recording the arc there spent the one walkthrough that surface
    // ever gets on the day it had nothing to say.
    const flow = GuideFlow(
      id: 'test.empty_surface',
      label: 'Empty surface arc',
      beats: [
        GuideBeat(
          anchor: 'test.absent',
          title: 'Needs A Target',
          body: 'Nothing here yet.',
          requiresAnchor: true,
        ),
      ],
    );

    await tester.pumpWidget(_app());
    await tester.runAsync(() => guide.maybeStart(flow, delay: Duration.zero));
    await _arrive(tester);

    expect(find.text('Needs A Target'), findsNothing);
    expect(
      guide.progress[flow.id],
      isNull,
      reason: 'an arc that showed nothing must leave no record',
    );
    expect(
      guide.canAutoStart(flow),
      isTrue,
      reason: 'and must still be offered the next time the surface has content',
    );
  });

  testWidgets('a beat whose target collapsed to nothing is dropped, not shown', (
    tester,
  ) async {
    // The play screen's bond rail is the case: it renders `SizedBox.shrink()`
    // until the story has actually bonded the player to somebody, so on a
    // fresh playthrough its anchor is *mounted at zero size* rather than
    // absent. `firstMounted` only asked whether the box was laid out, so a
    // collapsed rail read as "present but scrolled past", the beat was shown
    // and handed to the reveal — and `requiresAnchor` was never reached. The
    // player got "Those Who Stand With You" as a card floating over a screen
    // with no rail on it.
    const flow = GuideFlow(
      id: 'test.collapsed',
      label: 'Collapsed arc',
      beats: [
        GuideBeat(
          anchor: 'test.rail',
          title: 'Those Who Stand With You',
          body: 'Nobody yet.',
          requiresAnchor: true,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GuideHost(
          child: Scaffold(
            body: Column(
              children: const [
                GuideAnchor(id: 'test.rail', child: SizedBox.shrink()),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      GuideAnchorRegistry.instance.isMounted('test.rail'),
      isFalse,
      reason: 'a box with no size is collapsed, not merely scrolled away',
    );

    await tester.runAsync(() => guide.maybeStart(flow, delay: Duration.zero));
    await _arrive(tester);

    expect(find.text('THOSE WHO STAND WITH YOU'), findsNothing);
    expect(
      guide.progress[flow.id],
      isNull,
      reason: 'and the arc is still owed for the day the rail has somebody on it',
    );
  });

  testWidgets('spotlights a beat, advances, and ends', (tester) async {
    await tester.pumpWidget(_app());
    await tester.runAsync(() => guide.replay(_flow));
    await _arrive(tester);

    expect(find.text('FIRST BEAT'), findsOneWidget);
    expect(find.text('One.'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await _depart(tester);
    expect(find.text('SECOND BEAT'), findsOneWidget);

    // Last beat closes the arc rather than advancing into nothing.
    await tester.tap(find.text('Done'));
    await _depart(tester);
    expect(find.text('SECOND BEAT'), findsNothing);
    expect(guide.activeFlow, isNull);
  });

  testWidgets('a spotlight beat survives its target scrolling off screen', (
    tester,
  ) async {
    // Regression: the opening is animated with a RectTween, which asserts on a
    // null `end`. Any frame where the anchor resolves to nothing — mid-scroll,
    // mid-route, keyboard opening — used to take the whole app down red.
    final controller = ScrollController();
    await tester.pumpWidget(
      MaterialApp(
        home: GuideHost(
          child: Scaffold(
            body: ListView(
              controller: controller,
              children: [
                GuideAnchor(
                  id: 'test.target',
                  child: const SizedBox(width: 120, height: 40),
                ),
                const SizedBox(height: 4000),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() => guide.replay(_flow));
    await _arrive(tester);
    expect(find.text('FIRST BEAT'), findsOneWidget);

    controller.jumpTo(3000);
    // Two frames: the ticker samples the anchor in the transient phase, before
    // the scroll's new layout, so the first frame after a jump still reads the
    // stale rect and only the next one resolves to nothing.
    await tester.pump(const Duration(milliseconds: 16));
    await _depart(tester);

    expect(tester.takeException(), isNull);
    // The guidance is still delivered; only the opening goes away.
    expect(find.text('FIRST BEAT'), findsOneWidget);
  });

  testWidgets('a beat falls back to its surface when the exact target is gone', (
    tester,
  ) async {
    // The newest passage lives in a lazy list and is not built until the reader
    // reaches it; the column it scrolls in always is. A beat that names both
    // must light the column rather than nothing.
    const flow = GuideFlow(
      id: 'test.fallback',
      label: 'Fallback arc',
      beats: [
        GuideBeat(
          anchor: 'test.missing',
          fallbackAnchor: 'test.area',
          title: 'Narrator',
          body: 'One.',
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: GuideHost(
          child: Scaffold(
            body: GuideAnchor(
              id: 'test.area',
              child: const SizedBox(width: 200, height: 300),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() => guide.replay(flow));
    await _arrive(tester);

    expect(find.text('NARRATOR'), findsOneWidget);
    expect(
      tester.widget<GuideCutout>(find.byType(GuideCutout)).hole,
      isNotNull,
    );
  });

  testWidgets('a spanning beat lights the heading and its control as one', (
    tester,
  ) async {
    const flow = GuideFlow(
      id: 'test.span',
      label: 'Span arc',
      beats: [
        GuideBeat(
          anchor: 'test.label',
          anchorEnd: 'test.control',
          title: 'Mode',
          body: 'One.',
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: GuideHost(
          child: Scaffold(
            body: Column(
              children: [
                GuideAnchor(
                  id: 'test.label',
                  child: const SizedBox(width: 200, height: 20),
                ),
                GuideAnchor(
                  id: 'test.control',
                  child: const SizedBox(width: 200, height: 60),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() => guide.replay(flow));
    await _arrive(tester);

    final hole = tester.widget<GuideCutout>(find.byType(GuideCutout)).hole!;
    // The opening reaches past the 20px heading and over the 60px control.
    expect(hole.height, greaterThan(70));
  });

  testWidgets('the opening takes the target\'s own corners, plus the gap', (
    tester,
  ) async {
    const flow = GuideFlow(
      id: 'test.shape',
      label: 'Shape arc',
      beats: [GuideBeat(anchor: 'test.rounded', title: 'Shape', body: 'One.')],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: GuideHost(
          child: Scaffold(
            body: Center(
              child: GuideAnchor(
                id: 'test.rounded',
                // The anchor wraps padding; the painted box inside it is what
                // the opening must match, not the anchor's own bounds.
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Container(
                    width: 160,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF202020),
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() => guide.replay(flow));
    await _arrive(tester);

    final hole = tester.widget<GuideCutout>(find.byType(GuideCutout)).hole!;
    const gap = 3.0;
    // The painted 160x48 box grown by the gap — not the 184x72 anchor.
    expect(hole.width, closeTo(160 + gap * 2, 0.01));
    expect(hole.height, closeTo(48 + gap * 2, 0.01));
    // Corners grow with the gap so the rim stays parallel to the control.
    expect(hole.tlRadiusX, closeTo(24 + gap, 0.01));
  });

  testWidgets('a lopsided corner radius is carried through, not averaged', (
    tester,
  ) async {
    const flow = GuideFlow(
      id: 'test.lopsided',
      label: 'Lopsided arc',
      beats: [GuideBeat(anchor: 'test.half', title: 'Shape', body: 'One.')],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: GuideHost(
          child: Scaffold(
            body: Center(
              child: GuideAnchor(
                id: 'test.half',
                // The narration marker is rounded down its left side only.
                child: InkWell(
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(18),
                  ),
                  onTap: () {},
                  child: const SizedBox(width: 90, height: 44),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() => guide.replay(flow));
    await _arrive(tester);

    final hole = tester.widget<GuideCutout>(find.byType(GuideCutout)).hole!;
    expect(hole.tlRadiusX, closeTo(18 + 3, 0.01));
    expect(hole.blRadiusX, closeTo(18 + 3, 0.01));
    // The square side stays square apart from the gap itself.
    expect(hole.trRadiusX, closeTo(3, 0.01));
    expect(hole.brRadiusX, closeTo(3, 0.01));
  });

  testWidgets('the opening hugs the ink, not the padding around it', (
    tester,
  ) async {
    const flow = GuideFlow(
      id: 'test.group',
      label: 'Group arc',
      beats: [GuideBeat(anchor: 'test.pair', title: 'Pair', body: 'One.')],
    );
    Widget pill() => Expanded(
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF202020),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: GuideHost(
          child: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: GuideAnchor(
                id: 'test.pair',
                // A toggle: two pills inside generous padding. Neither pill
                // stands for the pair, so the opening has to be their union —
                // cutting the anchor's own box would leave 16pt of dead space
                // down each side and 12pt above.
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [pill(), const SizedBox(width: 8), pill()],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() => guide.replay(flow));
    await _arrive(tester);

    final hole = tester.widget<GuideCutout>(find.byType(GuideCutout)).hole!;
    const gap = 3.0;
    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    // The two pills span the padded width; the anchor is the full width and
    // 56 tall.
    expect(hole.width, closeTo(width - 32 + gap * 2, 0.01));
    expect(hole.height, closeTo(40 + gap * 2, 0.01));
    // And it takes the pills' own corners rather than a guessed default.
    expect(hole.tlRadiusX, closeTo(12 + gap, 0.01));
  });

  testWidgets('a bare glyph in a tap target lights the target, not the glyph', (
    tester,
  ) async {
    const flow = GuideFlow(
      id: 'test.glyph',
      label: 'Glyph arc',
      beats: [GuideBeat(anchor: 'test.icon', title: 'Icon', body: 'One.')],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: GuideHost(
          child: Scaffold(
            body: Center(
              child: GuideAnchor(
                id: 'test.icon',
                // No decoration anywhere: the only ink is the 20pt glyph, and
                // cutting to that would light something smaller than the
                // control the player actually has to press.
                child: GestureDetector(
                  onTap: () {},
                  behavior: HitTestBehavior.opaque,
                  child: const SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(Icons.search, size: 20),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() => guide.replay(flow));
    await _arrive(tester);

    final hole = tester.widget<GuideCutout>(find.byType(GuideCutout)).hole!;
    const gap = 3.0;
    expect(hole.width, closeTo(48 + gap * 2, 0.01));
    expect(hole.height, closeTo(48 + gap * 2, 0.01));

    await tester.tap(find.text('Done'));
    await _depart(tester);
  });

  testWidgets('an arc ends when the surface it points at goes away', (
    tester,
  ) async {
    const flow = GuideFlow(
      id: 'test.vanish',
      label: 'Vanishing arc',
      beats: [
        GuideBeat(anchor: 'test.sheet', title: 'Here', body: 'One.'),
        GuideBeat(anchor: 'test.sheet', title: 'Still here', body: 'Two.'),
      ],
    );
    var showSheet = true;
    late StateSetter setSheet;
    await tester.pumpWidget(
      MaterialApp(
        home: GuideHost(
          child: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                setSheet = setState;
                return showSheet
                    ? const Center(
                        child: GuideAnchor(
                          id: 'test.sheet',
                          child: SizedBox(width: 120, height: 40),
                        ),
                      )
                    : const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() => guide.replay(flow));
    await _arrive(tester);
    expect(find.text('HERE'), findsOneWidget);

    // A dismissed sheet moves no route, so nothing else would ever end this.
    setSheet(() => showSheet = false);
    await tester.pump();
    // The watchdog is a real timer, so it has to be given real time.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 900)),
    );
    await _depart(tester);

    expect(guide.activeFlow, isNull);
    expect(find.text('HERE'), findsNothing);
  });

  testWidgets('a beat that insisted on a target is dropped when it never comes', (
    tester,
  ) async {
    // Seen on the emulator: the bond-rail beat sat on a dimmed screen with
    // nothing lit, forever. Its anchor was mounted — inside a collapsed status
    // panel — so the watchdog read it as "on its way" and never gave up on it,
    // while `ensureVisible` had nothing it could scroll.
    const flow = GuideFlow(
      id: 'test.insists',
      label: 'Insisting arc',
      beats: [
        GuideBeat(
          anchor: 'test.collapsed',
          title: 'Never',
          body: 'Points at nothing.',
          requiresAnchor: true,
        ),
        GuideBeat(anchor: 'test.target', title: 'After', body: 'Two.'),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: GuideHost(
          child: Scaffold(
            body: Column(
              children: [
                // Mounted, laid out, and impossible to see — exactly what a
                // collapsed panel leaves behind.
                const SizedBox(
                  height: 0,
                  child: GuideAnchor(
                    id: 'test.collapsed',
                    child: SizedBox(width: 100),
                  ),
                ),
                GuideAnchor(
                  id: 'test.target',
                  child: const SizedBox(width: 120, height: 40),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() => guide.replay(flow));
    await _arrive(tester);

    // The watchdog is a real timer, so it needs real time.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1100)),
    );
    await _arrive(tester);

    expect(find.text('NEVER'), findsNothing);
    expect(find.text('AFTER'), findsOneWidget);

    guide.skip();
    await _depart(tester);
  });

  testWidgets('an arc never opens over a sheet the player must answer', (
    tester,
  ) async {
    // Seen on the emulator: opening a story for the first time raises the
    // protagonist sheet, and the play arc opened on top of it — its target
    // buried, so it degraded to a floating card, with the scrim over the
    // sheet's own Begin and Skip. The tip had to be dismissed before the
    // question underneath it could be.
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: key,
        home: GuideHost(
          child: Scaffold(
            body: Center(
              child: GuideAnchor(
                id: 'test.target',
                child: const SizedBox(width: 120, height: 40),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    unawaited(
      showModalBottomSheet<void>(
        context: key.currentContext!,
        builder: (_) => const SizedBox(height: 200, child: Text('ANSWER ME')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('ANSWER ME'), findsOneWidget);

    // The real path: an arc coming due on its own, not a forced replay.
    await tester.runAsync(() => guide.maybeStart(_flow, delay: Duration.zero));
    await _arrive(tester);
    expect(
      find.text('FIRST BEAT'),
      findsNothing,
      reason: 'the arc must wait, not talk across the sheet',
    );
    // Held, not spent: nothing was recorded, so it is still owed.
    expect(guide.activeFlow, isNull);

    // Answer the sheet, and the Chronicler arrives on the surface underneath.
    key.currentState!.pop();
    await tester.pump();
    await _arrive(tester);
    expect(find.text('FIRST BEAT'), findsOneWidget);

    guide.skip();
    await _depart(tester);
  });

  testWidgets('an arc ends when a dialog is opened over it', (tester) async {
    const flow = GuideFlow(
      id: 'test.buried',
      label: 'Buried arc',
      beats: [
        GuideBeat(anchor: 'test.under', title: 'Under', body: 'One.'),
        GuideBeat(anchor: 'test.under', title: 'Still under', body: 'Two.'),
      ],
    );
    late BuildContext pageContext;
    await tester.pumpWidget(
      MaterialApp(
        home: GuideHost(
          child: Scaffold(
            body: Builder(
              builder: (context) {
                pageContext = context;
                return const Center(
                  child: GuideAnchor(
                    id: 'test.under',
                    child: SizedBox(width: 120, height: 40),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() => guide.replay(flow));
    await _arrive(tester);
    expect(find.text('UNDER'), findsOneWidget);

    // The anchor is still laid out and perfectly resolvable underneath the
    // dialog. Spotlighting it anyway drops the scrim on top of the dialog and
    // swallows every tap aimed at it.
    unawaited(
      showDialog<void>(
        context: pageContext,
        builder: (_) => const AlertDialog(content: Text('Are you sure?')),
      ),
    );
    // The pulse ring repeats forever, so this never settles — pump fixed
    // frames and give the watchdog real time to notice.
    await tester.pump();
    await _depart(tester);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 900)),
    );
    await _depart(tester);

    expect(guide.activeFlow, isNull);
    expect(find.text('UNDER'), findsNothing);
    expect(find.text('Are you sure?'), findsOneWidget);
  });

  group('the card fits the screen it is on', () {
    // A six-beat arc with the longest body in the app: the worst case the
    // layout actually has to survive.
    const flow = GuideFlow(
      id: 'test.responsive',
      label: 'Responsive arc',
      beats: [
        GuideBeat(anchor: 'test.target', title: 'One', body: _longBody),
        GuideBeat(anchor: 'test.target', title: 'Two', body: _longBody),
        GuideBeat(anchor: 'test.target', title: 'Three', body: _longBody),
        GuideBeat(anchor: 'test.target', title: 'Four', body: _longBody),
        GuideBeat(anchor: 'test.target', title: 'Five', body: _longBody),
        GuideBeat(anchor: 'test.target', title: 'Six', body: _longBody),
      ],
    );

    Future<void> check(
      WidgetTester tester, {
      required Size size,
      double textScale = 1,
      EdgeInsets insets = EdgeInsets.zero,
    }) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              padding: insets,
            ),
            child: child!,
          ),
          home: GuideHost(
            child: Scaffold(
              body: Center(
                child: GuideAnchor(
                  id: 'test.target',
                  child: Container(
                    width: 120,
                    height: 40,
                    color: const Color(0xFF202020),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() => guide.replay(flow));
      await _arrive(tester);

      final view = size / tester.view.devicePixelRatio;

      // Overflow is reported as a thrown exception, so walking the whole arc
      // and finding none is most of the assertion. Advanced through the
      // controller rather than by tapping: on the narrowest screens the card
      // is genuinely taller than its band and scrolls, so its buttons are
      // below the fold — which is the fallback under test, not a failure.
      for (var i = 0; i < flow.beats.length; i++) {
        expect(tester.takeException(), isNull, reason: 'beat $i');
        expect(find.byType(GuideSpeechCard), findsOneWidget, reason: 'beat $i');

        // The card's frame — the band it was given — has to sit inside the
        // usable viewport on every side. The card itself may be taller than
        // its band and scroll inside it; what must never happen is the frame
        // running off an edge, where the actions become unreachable.
        final frame = tester.getRect(find.byType(SingleChildScrollView).first);
        expect(frame.left, greaterThanOrEqualTo(-0.01), reason: 'beat $i');
        expect(
          frame.right,
          lessThanOrEqualTo(view.width + 0.01),
          reason: 'beat $i',
        );
        expect(
          frame.top,
          greaterThanOrEqualTo(insets.top - 0.01),
          reason: 'beat $i',
        );
        expect(
          frame.bottom,
          lessThanOrEqualTo(view.height - insets.bottom + 0.01),
          reason: 'beat $i',
        );

        // And the card is within its frame, capped and centred rather than
        // stretched edge to edge on a wide screen.
        final card = tester.getRect(find.byType(GuideSpeechCard));
        expect(
          card.left,
          greaterThanOrEqualTo(frame.left - 0.01),
          reason: 'beat $i',
        );
        expect(
          card.right,
          lessThanOrEqualTo(frame.right + 0.01),
          reason: 'beat $i',
        );
        expect(card.width, lessThanOrEqualTo(460.01), reason: 'beat $i');

        guide.next();
        await _depart(tester);
      }
      expect(tester.takeException(), isNull);
      // Walked off the end, so nothing is left running behind the test.
      expect(guide.activeFlow, isNull);
    }

    testWidgets('small phone (320x568)', (tester) async {
      await check(tester, size: const Size(320, 568));
    });

    testWidgets('tall phone with a notch (390x844)', (tester) async {
      await check(
        tester,
        size: const Size(390, 844),
        insets: const EdgeInsets.only(top: 47, bottom: 34),
      );
    });

    testWidgets('landscape (844x390)', (tester) async {
      await check(tester, size: const Size(844, 390));
    });

    testWidgets('tablet (834x1112)', (tester) async {
      await check(tester, size: const Size(834, 1112));
    });

    testWidgets('small phone at 200% system text', (tester) async {
      await check(tester, size: const Size(320, 568), textScale: 2);
    });
  });

  testWidgets('system back dismisses the guide instead of navigating', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/first',
      routes: [
        GoRoute(
          path: '/first',
          builder: (context, state) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => context.push('/second'),
                child: const Text('go'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/second',
          builder: (context, state) => const Scaffold(
            body: Center(
              child: GuideAnchor(
                id: 'test.target',
                child: SizedBox(width: 120, height: 40),
              ),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        builder: (context, child) =>
            GuideHost(child: child ?? const SizedBox.shrink()),
      ),
    );
    // Wired the way `main.dart` wires it: a child dispatcher, which the root
    // asks before falling through to the Router's own callback.
    final guideBack = ChildBackButtonDispatcher(router.backButtonDispatcher)
      ..addCallback(guide.handleSystemBack)
      ..takePriority();
    addTearDown(() => guideBack.removeCallback(guide.handleSystemBack));

    await tester.tap(find.text('go'));
    await _depart(tester);
    await tester.runAsync(() => guide.replay(_flow));
    await _arrive(tester);
    expect(find.text('FIRST BEAT'), findsOneWidget);

    // Everything else is behind a scrim, so back is what a player reaches for.
    // Letting it navigate would send them off the surface they were only
    // trying to clear a tip from.
    // Through the back-button dispatcher, which is the path a real system
    // back takes — calling the delegate directly would skip the callback.
    final back = router.backButtonDispatcher;
    final handled = await back.invokeCallback(Future.value(false));
    await _depart(tester);

    expect(handled, isTrue);
    expect(guide.activeFlow, isNull);
    expect(find.text('FIRST BEAT'), findsNothing);
    // Still on the surface it was showing over.
    expect(find.text('go'), findsNothing);

    // And with the guide gone, back navigates again.
    await back.invokeCallback(Future.value(false));
    await _depart(tester);
    expect(find.text('go'), findsOneWidget);
  });

  testWidgets('an arc that has run does not auto-start again', (tester) async {
    await tester.pumpWidget(_app());

    await tester.runAsync(() => guide.maybeStart(_flow, delay: Duration.zero));
    await _depart(tester);
    expect(find.text('FIRST BEAT'), findsOneWidget);

    // Abandoned mid-arc — the record was written when it started, so it is
    // spent whatever happens next.
    await tester.runAsync(() => guide.skip());
    await _depart(tester);
    expect(guide.canAutoStart(_flow), isFalse);

    await tester.runAsync(() => guide.maybeStart(_flow, delay: Duration.zero));
    await _depart(tester);
    expect(find.text('FIRST BEAT'), findsNothing);
  });

  testWidgets('leaving the surface ends the arc without repeating it', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.runAsync(() => guide.maybeStart(_flow, delay: Duration.zero));
    await _depart(tester);
    expect(guide.activeFlow, isNotNull);

    guide.onLocationChanged('/somewhere');
    guide.onLocationChanged('/else');
    await _depart(tester);

    expect(guide.activeFlow, isNull);
    expect(guide.canAutoStart(_flow), isFalse);
  });

  testWidgets('opt-out suppresses auto-start but not an explicit replay', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.runAsync(() => guide.setOptOut(true));

    await tester.runAsync(() => guide.maybeStart(_flow, delay: Duration.zero));
    await _depart(tester);
    expect(find.text('FIRST BEAT'), findsNothing);

    await tester.runAsync(() => guide.replay(_flow));
    await _arrive(tester);
    expect(find.text('FIRST BEAT'), findsOneWidget);
  });

  testWidgets('a beat whose target is absent is dropped, not spotlit', (
    tester,
  ) async {
    const orphan = GuideFlow(
      id: 'test.orphan',
      label: 'Orphan arc',
      beats: [
        GuideBeat(
          anchor: 'test.missing',
          title: 'Gone',
          body: 'Nothing to point at.',
          requiresAnchor: true,
        ),
        GuideBeat(anchor: 'test.target', title: 'Present', body: 'Here.'),
      ],
    );

    await tester.pumpWidget(_app());
    await tester.runAsync(() => guide.replay(orphan));
    await _arrive(tester);

    expect(find.text('GONE'), findsNothing);
    expect(find.text('PRESENT'), findsOneWidget);
  });

  testWidgets('the opening tracks a scrolling target frame for frame', (
    tester,
  ) async {
    // The opening used to ease towards its target over 260ms. That is right
    // when it moves from one control to another and wrong while the control
    // itself is moving: for as long as the player keeps scrolling, the hole
    // trails a quarter-second behind, which reads as an opening stuck to the
    // screen rather than to the card it names.
    final controller = ScrollController();
    await tester.pumpWidget(
      MaterialApp(
        home: GuideHost(
          child: Scaffold(
            body: SingleChildScrollView(
              controller: controller,
              child: Column(
                children: [
                  const SizedBox(height: 200),
                  GuideAnchor(
                    id: 'test.target',
                    child: Container(
                      width: 120,
                      height: 90,
                      color: const Color(0xFF884422),
                    ),
                  ),
                  const SizedBox(height: 2000),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() => guide.replay(_flow));
    await _arrive(tester);
    // Past the short settle the opening is allowed after it lands on a new
    // target; from here on any movement is the target's own.
    await _depart(tester);

    final before = _openingOf(tester)!;
    controller.jumpTo(60);
    // The ticker samples the anchor in the transient phase, before the scroll's
    // new layout, so the rect it reads lands on the frame after.
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));

    final after = _openingOf(tester)!;
    expect(after.top, closeTo(before.top - 60, 0.01));
    expect(after.height, closeTo(before.height, 0.01));

    // Walk the arc off so the beat watchdog is cancelled with the test.
    guide.next();
    guide.next();
    await _depart(tester);
    expect(guide.activeFlow, isNull);
  });

  testWidgets('a target scrolled most of the way out loses its opening', (
    tester,
  ) async {
    // The bug this exists for: a hole hanging off the top of the screen was
    // nudged bodily back inside the bounds, so the spotlight sat pinned under
    // the status bar over whatever content happened to be there — and stayed
    // there while the list moved underneath it.
    final controller = ScrollController();
    await tester.pumpWidget(
      MaterialApp(
        home: GuideHost(
          child: Scaffold(
            body: SingleChildScrollView(
              controller: controller,
              child: Column(
                children: [
                  const SizedBox(height: 200),
                  GuideAnchor(
                    id: 'test.target',
                    child: Container(
                      width: 120,
                      height: 300,
                      color: const Color(0xFF884422),
                    ),
                  ),
                  const SizedBox(height: 2000),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() => guide.replay(_flow));
    await _arrive(tester);
    expect(_openingOf(tester), isNotNull);

    // Enough that only the last stripe of the target is still on screen.
    controller.jumpTo(460);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));

    expect(
      _openingOf(tester),
      isNull,
      reason: 'better no opening than one clamped onto the wrong content',
    );
    // The guidance itself still stands.
    expect(find.text('FIRST BEAT'), findsOneWidget);

    guide.skip();
    await _depart(tester);
    expect(guide.activeFlow, isNull);
  });
  group('the guide arrives and leaves as one object', () {
    // The complaint these exist for: beats cut from one to the next with no
    // transition at all, and the first coachmark of the session slammed onto
    // the screen. Both are invisible to a test that only ever looks at the
    // settled frame, which is why every earlier test pumped straight past them.

    testWidgets('the overlay fades up instead of appearing at full strength', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.runAsync(() => guide.replay(_flow));
      await tester.pump();

      // Part way in: on screen, but not yet arrived.
      await tester.pump(const Duration(milliseconds: 150));
      final entering = _cardOpacity(tester);
      expect(entering, greaterThan(0.0));
      expect(
        entering,
        lessThan(0.99),
        reason: 'the card should still be fading in a sixth of a second later',
      );

      await tester.pump(const Duration(milliseconds: 600));
      expect(_cardOpacity(tester), closeTo(1, 0.001));

      guide.skip();
      await _depart(tester);
    });

    testWidgets('the first opening blooms in place, not in from the corner', (
      tester,
    ) async {
      // `RRect.lerp` from a null begin scales the rect's raw coordinates
      // towards zero, so the very first spotlight of the walkthrough used to
      // fly in diagonally from behind the status bar.
      await tester.pumpWidget(_app());
      await tester.runAsync(() => guide.replay(_flow));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      final early = _openingOf(tester);
      expect(early, isNotNull);
      await _arrive(tester);
      final settled = _openingOf(tester)!;

      expect(
        early!.center.dx,
        closeTo(settled.center.dx, 1),
        reason: 'the opening must grow around its target, not travel to it',
      );
      expect(early.center.dy, closeTo(settled.center.dy, 1));
      // ...and it is genuinely smaller on the way in, rather than simply cut.
      expect(early.width, lessThan(settled.width));

      guide.skip();
      await _depart(tester);
    });

    testWidgets('an arc fades out rather than vanishing between frames', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.runAsync(() => guide.replay(_flow));
      await _arrive(tester);

      guide.skip();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      // The controller has let go, but the player can still see it leaving.
      expect(guide.activeFlow, isNull);
      expect(find.text('FIRST BEAT'), findsOneWidget);
      expect(_cardOpacity(tester), lessThan(1));

      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('FIRST BEAT'), findsNothing);
    });

    testWidgets('a player who asked for no animation gets the end state', (
      tester,
    ) async {
      // Not a faster animation — none. Same rule the gamification flourishes
      // follow (`shared/motion.dart`).
      // Set on the dispatcher rather than in a wrapping `MediaQuery`:
      // `MaterialApp` builds its own from the view, which would discard one
      // installed above it.
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpWidget(_app());
      await tester.runAsync(() => guide.replay(_flow));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      expect(_cardOpacity(tester), closeTo(1, 0.001));
      final opening = _openingOf(tester);
      expect(opening, isNotNull);

      await _arrive(tester);
      expect(_openingOf(tester)!.width, closeTo(opening!.width, 0.01));

      guide.skip();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text('FIRST BEAT'), findsNothing);
    });

    testWidgets(
      'an opening that appears mid-arc grows rather than switching on',
      (tester) async {
        // A card beat followed by a spotlight beat: there is no previous rect
        // for the opening to travel from, so without its own arrival it simply
        // appeared, at full size, between two frames. This is the shape of the
        // arrival arc on Explore — the Chronicler speaks first, then points.
        const flow = GuideFlow(
          id: 'test.mixed',
          label: 'Mixed arc',
          beats: [
            GuideBeat.card(title: 'Spoken', body: 'First, a word.'),
            GuideBeat(
              anchor: 'test.target',
              title: 'Shown',
              body: 'Now, this.',
            ),
          ],
        );
        await tester.pumpWidget(_app());
        await tester.runAsync(() => guide.replay(flow));
        await _arrive(tester);
        expect(_openingOf(tester), isNull);

        guide.next();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        final growing = _openingOf(tester)!;

        await _arrive(tester);
        final settled = _openingOf(tester)!;
        expect(growing.width, lessThan(settled.width));
        expect(growing.center.dx, closeTo(settled.center.dx, 1));
        expect(growing.center.dy, closeTo(settled.center.dy, 1));

        guide.skip();
        await _depart(tester);
      },
    );

    testWidgets('advancing carries the words over instead of cutting', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.runAsync(() => guide.replay(_flow));
      await _arrive(tester);

      guide.next();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      // Mid cross-fade both lines are on screen; the card itself never left.
      expect(find.text('FIRST BEAT'), findsOneWidget);
      expect(find.text('SECOND BEAT'), findsOneWidget);
      expect(find.byType(GuideSpeechCard), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('FIRST BEAT'), findsNothing);
      expect(find.text('SECOND BEAT'), findsOneWidget);

      guide.skip();
      await _depart(tester);
    });
  });

  testWidgets('a circular control is lit as a circle, not boxed in', (
    tester,
  ) async {
    const flow = GuideFlow(
      id: 'test.circle',
      label: 'Circle arc',
      beats: [GuideBeat(anchor: 'test.circle', title: 'Round', body: 'One.')],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: GuideHost(
          child: Scaffold(
            body: Center(
              child: GuideAnchor(
                id: 'test.circle',
                // The world actions button, to the widget. The transparent
                // `Material` is the load-bearing part: with no shape of its
                // own it builds an internal `PhysicalModel` that reports a
                // square-cornered rectangle the exact size of the circle
                // inside it, and that used to win the outline.
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {},
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF202020),
                        border: Border.all(color: const Color(0x66FFD479)),
                      ),
                      child: const Icon(Icons.tune_rounded, size: 19),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() => guide.replay(flow));
    await _arrive(tester);

    final hole = tester.widget<GuideCutout>(find.byType(GuideCutout)).hole!;
    const gap = 3.0;
    expect(hole.width, closeTo(46 + gap * 2, 0.01));
    expect(hole.height, closeTo(46 + gap * 2, 0.01));
    // A circle, not the 12+gap rounded box the group fallback would draw.
    expect(hole.tlRadiusX, closeTo((46 + gap * 2) / 2, 0.01));
    expect(hole.brRadiusY, closeTo((46 + gap * 2) / 2, 0.01));

    guide.skip();
    await _depart(tester);
  });

  testWidgets('a dropped beat leaves no gap in the progress rail', (
    tester,
  ) async {
    const flow = GuideFlow(
      id: 'test.rail',
      label: 'Rail arc',
      beats: [
        GuideBeat(anchor: 'test.target', title: 'One', body: 'A.'),
        GuideBeat(anchor: 'test.target', title: 'Two', body: 'B.'),
        // Nothing on this surface answers to that id, so it is dropped.
        GuideBeat(
          anchor: 'test.absent',
          title: 'Missing',
          body: 'C.',
          requiresAnchor: true,
        ),
        GuideBeat(anchor: 'test.target', title: 'Four', body: 'D.'),
      ],
    );
    await tester.pumpWidget(_app());
    await tester.runAsync(() => guide.replay(flow));
    await _arrive(tester);

    final card = find.byType(GuideSpeechCard);
    int step() => tester.widget<GuideSpeechCard>(card).step;
    int total() => tester.widget<GuideSpeechCard>(card).total;

    expect(step(), 0);
    expect(total(), 4);

    guide.next();
    await _arrive(tester);
    expect(find.text('TWO'), findsOneWidget);
    expect(step(), 1);

    // The third beat is dropped on the way past, so the fourth is delivered
    // as step 3 of 3 rather than jumping the rail to 4 of 4.
    guide.next();
    await _arrive(tester);
    expect(find.text('FOUR'), findsOneWidget);
    expect(total(), 3);
    expect(step(), 2);
    expect(step(), total() - 1, reason: 'the last delivered beat says Done');
    expect(find.text('Done'), findsOneWidget);

    guide.next();
    await _depart(tester);
  });

  testWidgets('an Ink-painted control is measured by its own decoration', (
    tester,
  ) async {
    const flow = GuideFlow(
      id: 'test.ink',
      label: 'Ink arc',
      beats: [GuideBeat(anchor: 'test.ink', title: 'Ink', body: 'One.')],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: GuideHost(
          child: Scaffold(
            body: Center(
              child: GuideAnchor(
                id: 'test.ink',
                // `Ink` paints into the Material's ink layer rather than
                // through a DecoratedBox, so nothing below it reports the box
                // actually on screen. Without it the union stops at the label.
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {},
                    child: Ink(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x22FFD479),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0x66FFD479)),
                      ),
                      child: const Text('Create persona'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() => guide.replay(flow));
    await _arrive(tester);

    final hole = tester.widget<GuideCutout>(find.byType(GuideCutout)).hole!;
    final painted = tester.getRect(find.byType(Ink));
    const gap = 3.0;
    // The padded box, not the label inside it.
    expect(hole.width, closeTo(painted.width + gap * 2, 0.01));
    expect(hole.height, closeTo(painted.height + gap * 2, 0.01));
    expect(hole.tlRadiusX, closeTo(14 + gap, 0.01));

    guide.skip();
    await _depart(tester);
  });

  testWidgets('a second arc waits out the quiet gap instead of piling on', (
    tester,
  ) async {
    const first = GuideFlow(
      id: 'test.gap.first',
      label: 'First arc',
      route: '/',
      beats: [GuideBeat(anchor: 'test.target', title: 'First', body: 'A.')],
    );
    const second = GuideFlow(
      id: 'test.gap.second',
      label: 'Second arc',
      route: '/',
      beats: [GuideBeat(anchor: 'test.target', title: 'Second', body: 'B.')],
    );
    // Comfortably longer than the departure pump, or the gap would expire
    // while the first arc is still fading out.
    GuideController.arcGap = const Duration(seconds: 2);
    addTearDown(() => GuideController.arcGap = Duration.zero);

    await tester.pumpWidget(_app());
    guide.onLocationChanged('/');
    await tester.runAsync(() => guide.replay(first));
    await _arrive(tester);
    expect(find.text('FIRST'), findsOneWidget);

    // Ending the first arc opens the gap.
    guide.next();
    await _depart(tester);

    unawaited(guide.maybeStart(second, delay: Duration.zero));
    await _arrive(tester);
    expect(
      find.text('SECOND'),
      findsNothing,
      reason: 'the second arc must not land on the heels of the first',
    );
    // Held, not spent: nothing was recorded, so it is still owed.
    expect(guide.canAutoStart(second), isTrue);

    // ...and it arrives on its own once the gap expires.
    await tester.pump(const Duration(milliseconds: 2100));
    await _arrive(tester);
    expect(find.text('SECOND'), findsOneWidget);

    // Close the gap first, or ending this arc leaves a live timer behind for
    // the framework to trip over once the tree is torn down.
    GuideController.arcGap = Duration.zero;
    guide.skip();
    await _depart(tester);
  });

  testWidgets('the silence offer puts its actions where every card does', (
    tester,
  ) async {
    // The count is over flows with a skipped record, so waving the same arc
    // off repeatedly is one skip. It takes four *different* arcs.
    GuideFlow other(int n) => GuideFlow(
      id: 'test.flow.$n',
      label: 'Arc $n',
      beats: [GuideBeat(anchor: 'test.target', title: 'Arc $n', body: 'X.')],
    );
    await tester.pumpWidget(_app());
    for (var n = 0; n < 4; n++) {
      await tester.runAsync(() => guide.replay(other(n)));
      await _arrive(tester);
      await tester.runAsync(() => guide.skip());
      await _depart(tester);
    }
    await _arrive(tester);

    expect(find.text('Stay quiet'), findsOneWidget);
    final card = tester.getRect(find.text('SHALL I LEAVE YOU TO IT?'));
    final quiet = tester.getRect(find.text('Stay quiet'));
    final keep = tester.getRect(find.text('Keep them'));
    // Right-aligned: the primary action ends where the prose does, and the
    // other sits to its left rather than both hugging the left edge.
    expect(keep.right, closeTo(card.right, 20));
    expect(quiet.left, greaterThan(card.left));
    // And the primary — the gold pill on the right, where every beat card
    // puts Next and Done, and where a thumb lands without reading — must be
    // the answer that changes nothing. Silencing the guide is irreversible
    // from here (it hides the arcs the player has not met yet) and belongs on
    // the low-emphasis text button.
    expect(
      find.ancestor(
        of: find.text('Stay quiet'),
        matching: find.byType(TextButton),
      ),
      findsOneWidget,
      reason: 'silencing must be the quiet action',
    );
    expect(
      find.ancestor(
        of: find.text('Keep them'),
        matching: find.byType(TextButton),
      ),
      findsNothing,
      reason: 'keeping the guide must be the emphasised action',
    );

    await tester.runAsync(() => guide.resolveSkipAll(silence: false));
    await _depart(tester);
  });
}

/// The opening actually painted this frame, or null when there is none.
Rect? _openingOf(WidgetTester tester) {
  final cutouts = tester.widgetList<GuideCutout>(find.byType(GuideCutout));
  if (cutouts.isEmpty) return null;
  return cutouts.first.hole?.outerRect;
}

/// Opacity the speech card is currently painted at.
double _cardOpacity(WidgetTester tester) {
  final finder = find.ancestor(
    of: find.byType(GuideSpeechCard),
    matching: find.byType(Opacity),
  );
  if (finder.evaluate().isEmpty) return 0;
  return tester.widget<Opacity>(finder.first).opacity;
}
