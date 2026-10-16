import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everlore/core/network/ws_manager.dart';
import 'package:everlore/features/keepsakes/models/keepsake_item.dart';
import 'package:everlore/features/keepsakes/presentation/widgets/keepsake_feed_post.dart';
import 'package:everlore/features/keepsakes/presentation/widgets/keepsakes_viewer_screen.dart';
import 'package:everlore/features/media/data/media_repository.dart';
import 'package:everlore/features/media/models/media_usage.dart';
import 'package:everlore/features/media/models/spoken_line.dart';
import 'package:everlore/features/media/models/turn_media.dart';
import 'package:everlore/features/media/presentation/media_thumbnail.dart';
import 'package:everlore/features/media/presentation/media_viewer_sheet.dart';
import 'package:everlore/features/media/services/audio_playback_controller.dart';
import 'package:everlore/features/play/presentation/widgets/narrative_bubble.dart';
import 'package:everlore/features/play/state/play_cubit.dart';
import 'package:everlore/shared/models/event.dart';

class _TestWsManager extends Fake implements WsManager {
  final _ctrl = StreamController<Map<String, dynamic>>.broadcast();
  final _boolCtrl = StreamController<bool>.broadcast();

  @override
  Stream<Map<String, dynamic>> get onGenerationDelta => _ctrl.stream;
  @override
  Stream<Map<String, dynamic>> get onGenerationStarted => _ctrl.stream;
  @override
  Stream<Map<String, dynamic>> get onGenerationComplete => _ctrl.stream;
  @override
  Stream<Map<String, dynamic>> get onGenerationStreamEnd => _ctrl.stream;
  @override
  Stream<Map<String, dynamic>> get onChoicesReady => _ctrl.stream;
  @override
  Stream<Map<String, dynamic>> get onGenerationRetrying => _ctrl.stream;
  @override
  Stream<Map<String, dynamic>> get onGenerationReset => _ctrl.stream;
  @override
  Stream<Map<String, dynamic>> get onMemoriesCurated => _ctrl.stream;
  @override
  Stream<Map<String, dynamic>> get onError => _ctrl.stream;
  @override
  Stream<bool> get onConnectionState => _boolCtrl.stream;
  @override
  Stream<Map<String, dynamic>> get onInstanceLoaded => _ctrl.stream;
  @override
  Stream<Map<String, dynamic>> get onCharacterCodexUpdated => _ctrl.stream;
  @override
  Stream<Map<String, dynamic>> get onReplayDelta => _ctrl.stream;
  @override
  Stream<Map<String, dynamic>> get onReplayComplete => _ctrl.stream;
  @override
  Stream<Map<String, dynamic>> get onWorldProjectionUpdated => _ctrl.stream;
  @override
  Stream<Map<String, dynamic>> get onMilestoneUnlocked => _ctrl.stream;
  @override
  Stream<Map<String, dynamic>> get onSpokenLines => _ctrl.stream;
  @override
  Stream<Map<String, dynamic>> get onMediaReady => _ctrl.stream;
  @override
  Stream<Map<String, dynamic>> get onMediaUnseen => _ctrl.stream;
  @override
  Stream<Map<String, dynamic>> get onMediaFailed => _ctrl.stream;

  @override
  Future<void> connect(String token, {bool force = false}) async {}
  @override
  Future<void> disconnect({bool clearToken = false}) async {}
  @override
  void loadInstance(String instanceId) {}

  @override
  void dispose() {
    _ctrl.close();
    _boolCtrl.close();
  }
}

class _TestMediaRepo extends Fake implements MediaRepository {
  @override
  Future<MediaUsage?> getUsage() async => null;
}

class _TestAudioPlaybackController extends ChangeNotifier
    implements AudioPlaybackController {
  bool _isPlaying = false;
  String? _activeEventId;
  String? _activeLineId;

  @override
  bool get isPlaying => _isPlaying;

  @override
  String? get activeEventId => _activeEventId;

  @override
  String? get activeLineId => _activeLineId;

  @override
  bool isLinePlaying(String eventId, String lineId) =>
      _isPlaying && _activeEventId == eventId && _activeLineId == lineId;

  @override
  bool isLineLoading(String eventId, String lineId) => false;

  @override
  void setLoading(String? eventId, String? lineId) {}

  @override
  Future<void> play({
    required String eventId,
    required String lineId,
    required String url,
  }) async {
    _activeEventId = eventId;
    _activeLineId = lineId;
    _isPlaying = true;
    notifyListeners();
  }

  @override
  Future<void> stop() async {
    _isPlaying = false;
    _activeEventId = null;
    _activeLineId = null;
    notifyListeners();
  }

  void simulatePlaybackCompleted() {
    _isPlaying = false;
    _activeEventId = null;
    _activeLineId = null;
    notifyListeners();
  }
}

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(width: 400, child: child),
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
  });

  group('Media UI Edge Fixes', () {
    testWidgets('1. Playing line renders a solid underline, dotted when not playing', (
      tester,
    ) async {
      const rawProse = '*He whispered,* "Listen carefully," *before slipping away.*';
      final event = GameEvent(
        id: 'ev_1',
        instanceId: 'inst_1',
        sequence: 1,
        type: 'narration',
        aiResponse: rawProse,
        spokenLines: const [
          SpokenLine(lineId: 'line_1', start: 16, end: 35),
        ],
        createdAt: DateTime.now(),
      );

      // A. Playing line: playingVoiceLineId matches line_1
      await tester.pumpWidget(
        _wrap(
          NarrativeBubble(
            event: event,
            playingVoiceLineId: 'line_1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final playingRichText = tester.widget<RichText>(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('Listen carefully'),
        ),
      );

      TextSpan? playingSpan;
      void findPlayingSpan(InlineSpan span) {
        if (span is TextSpan) {
          if (span.text?.contains('Listen carefully') ?? false) {
            playingSpan = span;
            return;
          }
          span.children?.forEach(findPlayingSpan);
        }
      }

      findPlayingSpan(playingRichText.text);
      expect(playingSpan, isNotNull);
      expect(playingSpan!.style?.decorationStyle, equals(TextDecorationStyle.solid));

      // B. Not playing: playingVoiceLineId is null
      await tester.pumpWidget(
        _wrap(
          NarrativeBubble(
            event: event,
            playingVoiceLineId: null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final idleRichText = tester.widget<RichText>(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('Listen carefully'),
        ),
      );

      TextSpan? idleSpan;
      void findIdleSpan(InlineSpan span) {
        if (span is TextSpan) {
          if (span.text?.contains('Listen carefully') ?? false) {
            idleSpan = span;
            return;
          }
          span.children?.forEach(findIdleSpan);
        }
      }

      findIdleSpan(idleRichText.text);
      expect(idleSpan, isNotNull);
      expect(idleSpan!.style?.decorationStyle, equals(TextDecorationStyle.dotted));
    });

    test('2. The playing line follows the controller and clears when playback ends', () async {
      final ws = _TestWsManager();
      final audio = _TestAudioPlaybackController();
      final cubit = PlayCubit(
        instanceId: 'inst_audio',
        ws: ws,
        mediaRepo: _TestMediaRepo(),
        audio: audio,
        onRefreshInk: () async {},
      );

      // Start playing: the cubit follows the controller on its own.
      await audio.play(
        eventId: 'ev_play_1',
        lineId: 'line_play_1',
        url: 'https://example.com/voice.mp3',
      );

      expect(cubit.state.playingVoiceLineId, 'line_play_1');
      expect(cubit.state.playingVoiceEventId, 'ev_play_1');

      // Audio completes naturally
      audio.simulatePlaybackCompleted();

      // State is immediately cleared
      expect(cubit.state.playingVoiceLineId, isNull);
      expect(cubit.state.playingVoiceEventId, isNull);

      await cubit.close();
      ws.dispose();
    });

    test('3. A temp_* placeholder is stripped before LocalDb and dropped on load', () {
      final eventWithTemp = GameEvent(
        id: 'ev_temp_1',
        instanceId: 'inst_cache',
        sequence: 1,
        type: 'narration',
        createdAt: DateTime.now(),
        media: const [
          TurnMedia(
            mediaId: 'temp_pic_12345',
            kind: MediaKind.picture,
            status: MediaStatus.queued,
          ),
          TurnMedia(
            mediaId: 'pic_real_999',
            kind: MediaKind.picture,
            status: MediaStatus.ready,
            url: 'https://example.com/real.jpg',
          ),
        ],
      );

      final stripped = PlayCubit.stripTempMedia(eventWithTemp);
      expect(stripped.media, hasLength(1));
      expect(stripped.media.first.mediaId, 'pic_real_999');

      // An event without temp media returns unmodified
      final eventWithoutTemp = GameEvent(
        id: 'ev_clean_1',
        instanceId: 'inst_cache',
        sequence: 2,
        type: 'narration',
        createdAt: DateTime.now(),
        media: const [
          TurnMedia(
            mediaId: 'vid_clean_888',
            kind: MediaKind.video,
            status: MediaStatus.ready,
            url: 'https://example.com/clean.mp4',
          ),
        ],
      );
      final cleanStripped = PlayCubit.stripTempMedia(eventWithoutTemp);
      expect(identical(cleanStripped, eventWithoutTemp), isTrue);
    });

    testWidgets('4. "Tap to try again" on film failure retries in place without opening viewer', (
      tester,
    ) async {
      bool viewerOpened = false;

      final testItem = KeepsakeItem(
        mediaId: 'film_fail_1',
        kind: KeepsakeKind.video,
        url: 'https://cdn.everlore.com/video1.mp4',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        _wrap(
          KeepsakeFeedPost(
            item: testItem,
            isAutoplayEnabled: true,
            onRemove: () {},
            onTap: () {
              viewerOpened = true;
            },
          ),
        ),
      );
      // Wait for initialize catchError to run
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // The failure overlay should be visible
      expect(find.text('Tap to try again'), findsOneWidget);

      // Tap "Tap to try again"
      await tester.tap(find.text('Tap to try again'));
      await tester.pump();

      // Ensure widget.onTap was NOT invoked
      expect(viewerOpened, isFalse);
    });

    testWidgets('5. KeepsakesViewerScreen shows "Open their card" only when face has character and instanceId', (
      tester,
    ) async {
      // A. Face without character
      final itemNoChar = KeepsakeItem(
        mediaId: 'face_1',
        kind: KeepsakeKind.portrait,
        url: 'https://cdn.everlore.com/face1.jpg',
        createdAt: DateTime.now(),
        instanceId: 'inst_1',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: KeepsakesViewerScreen(items: [itemNoChar]),
        ),
      );
      await tester.pump();

      expect(find.text('Open their card'), findsNothing);

      // B. Face with character and instanceId
      final itemWithChar = KeepsakeItem(
        mediaId: 'face_2',
        kind: KeepsakeKind.portrait,
        url: 'https://cdn.everlore.com/face2.jpg',
        createdAt: DateTime.now(),
        instanceId: 'inst_1',
        character: const KeepsakeCharacter(id: 'char_1', name: 'Lady Eleanor'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: KeepsakesViewerScreen(items: [itemWithChar]),
        ),
      );
      await tester.pump();

      expect(find.text('Open their card'), findsOneWidget);
    });

    testWidgets('7a. Video failure in thumbnail row shows calm retry overlay', (
      tester,
    ) async {
      final item = const TurnMedia(
        mediaId: 'vid_thumb_1',
        kind: MediaKind.video,
        status: MediaStatus.ready,
        url: 'https://cdn.everlore.com/video.mp4',
      );

      await tester.pumpWidget(_wrap(MediaThumbnailRow(media: [item])));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // The failure overlay should be visible in thumbnail
      expect(find.text('Tap to try again'), findsOneWidget);
    });

    testWidgets('7b. Video failure in viewer sheet shows calm retry overlay', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const MediaViewerSheet(
            media: TurnMedia(
              mediaId: 'vid_viewer_1',
              kind: MediaKind.video,
              status: MediaStatus.ready,
              url: 'https://cdn.everlore.com/video.mp4',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // The failure overlay should be visible in viewer sheet
      expect(find.text('Tap to try again'), findsOneWidget);
    });
  });
}

