import 'dart:convert';
import 'package:everlore/core/guide/guide_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:everlore/app/theme/nexus_theme.dart';
import 'package:everlore/features/group_chat/models/group_chat_models.dart';
import 'package:everlore/features/group_chat/presentation/screens/direct_thread_screen.dart';
import 'package:everlore/features/group_chat/presentation/screens/group_room_screen.dart';
import 'package:everlore/features/group_chat/presentation/widgets/group_chat_backdrop.dart';
import 'package:everlore/features/group_chat/state/chats_cubit.dart';
import 'package:everlore/features/group_chat/state/group_chat_cubit.dart';
import 'package:everlore/shared/widgets/everlore_network_image.dart';

import '../fakes.dart';

Widget _host(Widget child) => BlocProvider<ChatsCubit>(
  create: (_) => ChatsCubit(
    repository: FakeChatsRepository(),
    loadTemplates: () async => const [],
  ),
  child: MaterialApp(
    theme: ThemeData(splashFactory: InkRipple.splashFactory),
    home: child,
  ),
);

void main() {
  // The guide's first-visit arcs are not what these tests are about.
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await guide.onSignedOut();
    await guide.setOptOut(true);
  });
  tearDown(() async {
    await guide.setOptOut(false);
    await guide.onSignedOut();
  });
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (ByteData? message) async {
          if (message == null) return null;
          final key = utf8.decode(
            message.buffer.asUint8List(
              message.offsetInBytes,
              message.lengthInBytes,
            ),
          );
          if (key == 'AssetManifest.bin') {
            return const StandardMessageCodec().encodeMessage(
              <String, Object?>{},
            );
          }
          if (key == 'AssetManifest.json') {
            return ByteData.view(Uint8List.fromList(utf8.encode('{}')).buffer);
          }
          return null;
        });
  });

  group('GroupChatBackdrop', () {
    testWidgets('an empty URL draws no network image; a set URL draws one', (
      tester,
    ) async {
      // 1. null URL: draws no network image, shows plain void1
      await tester.pumpWidget(_host(const GroupChatBackdrop(imageUrl: null)));
      await tester.pump();
      expect(find.byType(EverloreNetworkImage), findsNothing);
      final nullColoredBoxFinder = find.descendant(
        of: find.byType(GroupChatBackdrop),
        matching: find.byType(ColoredBox),
      );
      expect(nullColoredBoxFinder, findsOneWidget);
      final coloredBoxNull = tester.widget<ColoredBox>(nullColoredBoxFinder);
      expect(coloredBoxNull.color, EverloreTheme.void1);

      // 2. empty string URL: draws no network image
      await tester.pumpWidget(_host(const GroupChatBackdrop(imageUrl: '')));
      await tester.pump();
      expect(find.byType(EverloreNetworkImage), findsNothing);
      final emptyColoredBoxFinder = find.descendant(
        of: find.byType(GroupChatBackdrop),
        matching: find.byType(ColoredBox),
      );
      expect(emptyColoredBoxFinder, findsOneWidget);
      final coloredBoxEmpty = tester.widget<ColoredBox>(emptyColoredBoxFinder);
      expect(coloredBoxEmpty.color, EverloreTheme.void1);

      // 3. whitespace-only URL: draws no network image
      await tester.pumpWidget(_host(const GroupChatBackdrop(imageUrl: '   ')));
      await tester.pump();
      expect(find.byType(EverloreNetworkImage), findsNothing);

      // 4. set URL: draws exactly one network image with BoxFit.cover and memCacheWidth 1440
      await tester.pumpWidget(
        _host(
          const GroupChatBackdrop(
            imageUrl: 'https://example.com/art/group-cover.png',
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(EverloreNetworkImage), findsOneWidget);

      final imageWidget = tester.widget<EverloreNetworkImage>(
        find.byType(EverloreNetworkImage),
      );
      expect(imageWidget.imageUrl, 'https://example.com/art/group-cover.png');
      expect(imageWidget.fit, BoxFit.cover);
      expect(imageWidget.memCacheWidth, 1440);
      expect(imageWidget.alignment, Alignment.center);
      expect(imageWidget.placeholder, isA<ColoredBox>());
      expect(
        (imageWidget.placeholder as ColoredBox).color,
        EverloreTheme.void1,
      );
      expect(imageWidget.errorWidget, isA<ColoredBox>());
      expect(
        (imageWidget.errorWidget as ColoredBox).color,
        EverloreTheme.void1,
      );

      // Gradient scrim is positioned above the image
      final decoratedBoxes = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .toList();
      final scrimBox = decoratedBoxes.firstWhere(
        (box) =>
            box.decoration is BoxDecoration &&
            (box.decoration as BoxDecoration).gradient is LinearGradient,
      );
      final gradient =
          (scrimBox.decoration as BoxDecoration).gradient as LinearGradient;
      expect(gradient.begin, Alignment.topCenter);
      expect(gradient.end, Alignment.bottomCenter);
      expect(gradient.colors, [
        EverloreTheme.void0.withValues(alpha: kGroupBackdropScrimTopAlpha),
        EverloreTheme.void0.withValues(alpha: kGroupBackdropScrimMidAlpha),
        EverloreTheme.void0.withValues(alpha: kGroupBackdropScrimBottomAlpha),
      ]);
    });

    testWidgets('custom alignment is applied to the network image', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const GroupChatBackdrop(
            imageUrl: 'https://example.com/portrait.png',
            alignment: Alignment(0, -0.6),
          ),
        ),
      );
      await tester.pump();

      final imageWidget = tester.widget<EverloreNetworkImage>(
        find.byType(EverloreNetworkImage),
      );
      expect(imageWidget.alignment, const Alignment(0, -0.6));
    });
  });

  group('GroupRoomScreen backdrop wiring', () {
    testWidgets(
      'loaded room renders GroupChatBackdrop with group cover and transparent scaffold',
      (tester) async {
        final gateway = FakeGateway();
        final cubit = GroupChatCubit(
          instanceId: instanceId,
          gateway: gateway,
          repository: FakeRepository(),
          clock: FakeClock(),
        );
        await cubit.start();

        final frame = loadedFrame();
        final data = frame['data'] as Map<String, dynamic>;
        data['template'] = <String, dynamic>{
          'is_nsfw_capable': false,
          'image_url': 'https://example.com/guild-cover.jpg',
        };
        gateway.pushLoaded(frame);

        await tester.pumpWidget(
          _host(GroupRoomScreen(instanceId: instanceId, cubit: cubit)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final backdropFinder = find.byType(GroupChatBackdrop);
        expect(backdropFinder, findsOneWidget);
        final backdrop = tester.widget<GroupChatBackdrop>(backdropFinder);
        expect(backdrop.imageUrl, 'https://example.com/guild-cover.jpg');

        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        expect(scaffold.backgroundColor, Colors.transparent);

        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(
          appBar.backgroundColor,
          EverloreTheme.void0.withValues(alpha: 0.72),
        );

        cubit.close();
      },
    );
  });

  group('DirectThreadScreen backdrop wiring', () {
    testWidgets('portrait URL is used with Alignment(0, -0.6)', (tester) async {
      final gateway = FakeGateway();
      final cubit = GroupChatCubit(
        instanceId: instanceId,
        gateway: gateway,
        repository: FakeRepository(),
        clock: FakeClock(),
      );
      await cubit.start();
      gateway.pushLoaded(loadedFrame());

      const memberWithPortrait = GroupMember(
        id: jess,
        name: 'Jess',
        portraitUrl: 'https://example.com/jess-portrait.jpg',
      );

      await tester.pumpWidget(
        _host(DirectThreadScreen(cubit: cubit, member: memberWithPortrait)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final backdropFinder = find.byType(GroupChatBackdrop);
      expect(backdropFinder, findsOneWidget);
      final backdrop = tester.widget<GroupChatBackdrop>(backdropFinder);
      expect(backdrop.imageUrl, 'https://example.com/jess-portrait.jpg');
      expect(backdrop.alignment, const Alignment(0, -0.6));

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, Colors.transparent);

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(
        appBar.backgroundColor,
        EverloreTheme.void0.withValues(alpha: 0.72),
      );

      cubit.close();
    });

    testWidgets('member without portrait falls back to group cover', (
      tester,
    ) async {
      final gateway = FakeGateway();
      final cubit = GroupChatCubit(
        instanceId: instanceId,
        gateway: gateway,
        repository: FakeRepository(),
        clock: FakeClock(),
      );
      await cubit.start();

      final frame = loadedFrame();
      final data = frame['data'] as Map<String, dynamic>;
      data['template'] = <String, dynamic>{
        'is_nsfw_capable': false,
        'image_url': 'https://example.com/fallback-cover.jpg',
      };
      gateway.pushLoaded(frame);

      const memberNoPortrait = GroupMember(
        id: jess,
        name: 'Jess',
        portraitUrl: null,
      );

      await tester.pumpWidget(
        _host(DirectThreadScreen(cubit: cubit, member: memberNoPortrait)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final backdropFinder = find.byType(GroupChatBackdrop);
      expect(backdropFinder, findsOneWidget);
      final backdrop = tester.widget<GroupChatBackdrop>(backdropFinder);
      expect(backdrop.imageUrl, 'https://example.com/fallback-cover.jpg');
      expect(backdrop.alignment, Alignment.center);

      cubit.close();
    });

    testWidgets(
      'member without portrait and group without cover falls back to void1',
      (tester) async {
        final gateway = FakeGateway();
        final cubit = GroupChatCubit(
          instanceId: instanceId,
          gateway: gateway,
          repository: FakeRepository(),
          clock: FakeClock(),
        );
        await cubit.start();
        gateway.pushLoaded(loadedFrame());

        const memberNoPortrait = GroupMember(
          id: jess,
          name: 'Jess',
          portraitUrl: '',
        );

        await tester.pumpWidget(
          _host(DirectThreadScreen(cubit: cubit, member: memberNoPortrait)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final backdropFinder = find.byType(GroupChatBackdrop);
        expect(backdropFinder, findsOneWidget);
        final backdrop = tester.widget<GroupChatBackdrop>(backdropFinder);
        expect(backdrop.imageUrl, '');

        // Draws no network image and displays void1
        expect(find.byType(EverloreNetworkImage), findsNothing);

        cubit.close();
      },
    );
  });
}
