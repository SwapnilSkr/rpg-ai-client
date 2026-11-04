import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:everlore/features/group_chat/models/group_chat_models.dart';
import 'package:everlore/features/group_chat/presentation/screens/direct_thread_screen.dart';
import 'package:everlore/features/group_chat/presentation/screens/group_room_screen.dart';
import 'package:everlore/features/group_chat/presentation/widgets/bond_sheet.dart';
import 'package:everlore/features/group_chat/state/chats_cubit.dart';
import 'package:everlore/features/group_chat/state/group_chat_cubit.dart';

import '../fakes.dart';

/// The room, thread and preview sit outside the tab shell and read the chats
/// list from above the Navigator, so the host provides it the same way.
Widget _host(Widget child) => BlocProvider<ChatsCubit>(
  create: (_) => ChatsCubit(
    repository: FakeChatsRepository(),
    loadTemplates: () async => const [],
  ),
  child: MaterialApp(
    theme: ThemeData(
      splashFactory: InkRipple.splashFactory,
    ),
    home: Scaffold(body: child),
  ),
);

Map<String, dynamic> linesFrame(
  List<Map<String, dynamic>> lines, {
  String? directWith,
  String? turnId,
  String? eventId,
  bool partial = false,
}) => {
  'type': 'group_lines',
  'instanceId': instanceId,
  if (directWith != null) 'directWith': directWith,
  if (turnId != null) 'turnId': turnId,
  if (eventId != null) 'eventId': eventId,
  if (partial) 'partial': true,
  'lines': lines,
};

class _TestRig {
  final FakeGateway gateway;
  final FakeRepository repo;
  final FakeClock clock;
  final GroupChatCubit cubit;

  _TestRig({
    required this.gateway,
    required this.repo,
    required this.clock,
    required this.cubit,
  });
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (ByteData? message) async {
      if (message == null) return null;
      final key = utf8.decode(
        message.buffer.asUint8List(message.offsetInBytes, message.lengthInBytes),
      );
      if (key == 'AssetManifest.bin') {
        return const StandardMessageCodec().encodeMessage(<String, Object?>{});
      }
      if (key == 'AssetManifest.json') {
        return ByteData.view(Uint8List.fromList(utf8.encode('{}')).buffer);
      }
      return null;
    });
  });
  late FakeGateway gateway;
  late FakeRepository repo;
  late FakeClock clock;
  late GroupChatCubit cubit;

  _TestRig createRig() {
    final g = FakeGateway();
    final r = FakeRepository();
    final c = FakeClock();
    final cu = GroupChatCubit(
      instanceId: instanceId,
      gateway: g,
      repository: r,
      clock: c,
    );
    gateway = g;
    repo = r;
    clock = c;
    cubit = cu;
    return _TestRig(gateway: g, repo: r, clock: c, cubit: cu);
  }

  tearDown(() {
    cubit.close();
  });

  group('GroupRoomScreen & DirectThreadScreen UI', () {
    testWidgets('lines in both threads render', (tester) async {
      createRig();
      await cubit.start();
      // Load group thread with a character line and player line
      final groupEvent = eventRow(
        id: 'e1',
        sequence: 1,
        playerInput: 'Hello group!',
        lines: [
          storedLine(jess, 'Welcome everyone!', DateTime.utc(2026, 11, 4, 11)),
        ],
      );
      gateway.pushLoaded(loadedFrame(events: [groupEvent]));

      // 1. Group thread rendering
      await tester.pumpWidget(
        _host(GroupRoomScreen(
          instanceId: instanceId,
          title: 'Everlore Guild',
          cubit: cubit,
        )),
      );
      await tester.pumpAndSettle();

      expect(find.text('Everlore Guild'), findsOneWidget);
      expect(find.text('Hello group!'), findsOneWidget);
      expect(find.text('Welcome everyone!'), findsOneWidget);

      // 2. Direct thread rendering
      final directEvent = eventRow(
        id: 'e2',
        sequence: 1,
        lines: [
          storedLine(jess, 'Direct message only for you', DateTime.utc(2026, 11, 4, 11, 5)),
        ],
      );
      gateway.pushLoaded(loadedFrame(
        directWith: jess,
        events: [directEvent],
      ));

      final jessMember = GroupMember(id: jess, name: 'Jess', role: 'friend');
      await tester.pumpWidget(
        _host(DirectThreadScreen(cubit: cubit, member: jessMember)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Direct message only for you'), findsOneWidget);
    });

    testWidgets('typing line renders when member is typing', (tester) async {
      createRig();
      await cubit.start();
      gateway.pushLoaded(loadedFrame());

      await tester.pumpWidget(
        _host(GroupRoomScreen(
          instanceId: instanceId,
          title: 'Everlore Guild',
          cubit: cubit,
        )),
      );
      await tester.pumpAndSettle();

      expect(find.text('Jess is typing…'), findsNothing);

      // Push future-stamped wireLine to show typing
      gateway.pushLines(
        linesFrame([
          wireLine(jess, 'upcoming message', clock.now().add(const Duration(seconds: 5))),
        ]),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Jess is typing…'), findsOneWidget);
    });

    testWidgets('@ suggestions filter and insert member name', (tester) async {
      createRig();
      await cubit.start();
      gateway.pushLoaded(loadedFrame());

      await tester.pumpWidget(
        _host(GroupRoomScreen(
          instanceId: instanceId,
          title: 'Everlore Guild',
          cubit: cubit,
        )),
      );
      await tester.pumpAndSettle();

      // Enter @ in composer
      final textField = find.byType(TextField);
      await tester.enterText(textField, '@J');
      await tester.pump();

      // Suggestions should show 'Jess'
      expect(find.text('Jess'), findsWidgets);

      // Tap on Jess suggestion
      await tester.tap(find.text('Jess').last);
      await tester.pump();

      // Text field should now have '@Jess '
      final tf = tester.widget<TextField>(textField);
      expect(tf.controller?.text, '@Jess ');
    });

    testWidgets('action toggle sends an action', (tester) async {
      createRig();
      await cubit.start();
      gateway.pushLoaded(loadedFrame());

      await tester.pumpWidget(
        _host(GroupRoomScreen(
          instanceId: instanceId,
          title: 'Everlore Guild',
          cubit: cubit,
        )),
      );
      await tester.pumpAndSettle();

      // Toggle action mode
      final actionToggle = find.byIcon(Icons.auto_awesome_outlined);
      expect(actionToggle, findsOneWidget);
      await tester.tap(actionToggle);
      await tester.pump();

      expect(find.text("Say what you do. They'll react."), findsOneWidget);

      // Type action and send
      await tester.enterText(find.byType(TextField), 'I build a camp fire');
      final sendBtn = find.byIcon(Icons.arrow_upward_rounded);
      await tester.tap(sendBtn);
      await tester.pump();

      final chatSends = gateway.chats;
      expect(chatSends.length, 1);
      expect(chatSends.first['text'], 'I build a camp fire');
      expect(chatSends.first['kind'], 'action');
    });

    testWidgets('failed send shows Retry and retrying sends again', (tester) async {
      createRig();
      await cubit.start();
      gateway.pushLoaded(loadedFrame());

      await tester.pumpWidget(
        _host(GroupRoomScreen(
          instanceId: instanceId,
          title: 'Everlore Guild',
          cubit: cubit,
        )),
      );
      await tester.pumpAndSettle();

      // Send a message
      await tester.enterText(find.byType(TextField), 'Failing message');
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pump();

      // Fail the send with an error frame
      gateway.pushError({'type': 'error', 'code': 'INTERNAL'});
      await tester.pump();
      await tester.pump();

      // Failed banner with Retry should appear
      expect(find.text('Failing message'), findsOneWidget);
      final retryBtn = find.text('Retry');
      expect(retryBtn, findsOneWidget);

      final beforeRetries = gateway.chats.length;
      await tester.tap(retryBtn);
      await tester.pump();

      expect(gateway.chats.length, beforeRetries + 1);
    });

    testWidgets('bond sheet shows meters and set it yourself slider', (tester) async {
      createRig();
      repo.bondRows = [
        GroupBond(
          characterId: jess,
          name: 'Jess',
          meters: const BondMeters(trust: 40, affection: 60, fear: 10, rivalry: 20),
          moments: const [
            BondMoment(evidence: 'Shared a secret', deltas: {'trust': 5}),
          ],
        ),
      ];
      repo.setResult = const BondMeters(trust: 75, affection: 60, fear: 10, rivalry: 20);

      await cubit.start();
      gateway.pushLoaded(loadedFrame());

      final jessMember = GroupMember(id: jess, name: 'Jess', role: 'friend');
      await tester.pumpWidget(
        _host(BondSheet(cubit: cubit, member: jessMember)),
      );
      await tester.pumpAndSettle();

      expect(find.text('BOND'), findsOneWidget);
      expect(find.text('40%'), findsOneWidget);
      expect(find.text('60%'), findsOneWidget);
      expect(find.text('Shared a secret'), findsOneWidget);

      // Toggle "Set it yourself" switch
      final sw = find.byType(Switch);
      expect(sw, findsOneWidget);
      await tester.tap(sw);
      await tester.pumpAndSettle();

      expect(find.byType(Slider), findsNWidgets(4));
    });
  });
}
