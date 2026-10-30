import 'dart:convert';

import 'package:everlore/core/auth/auth_service.dart';
import 'package:everlore/core/guest/guest_session.dart';
import 'package:everlore/core/guest/sign_in_required.dart';
import 'package:everlore/core/network/api_client.dart';
import 'package:everlore/core/telemetry/reasons.dart';
import 'package:everlore/features/play/state/play_cubit.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../fast_reply_send_test.dart'
    show FakeAudioPlaybackController, FakeMediaRepository, FrameWs, settle;

/// A device and a server, standing in for storage and the network.
class Rig {
  String? token;
  String? userJson;
  final posts = <({String path, Map<String, dynamic>? body})>[];
  final gets = <String>[];
  final waits = <Duration>[];
  var started = 0;
  var discarded = 0;
  var persisted = 0;

  /// Scripted answers, consumed in order; null falls through to [reply].
  final script = <Object>[];
  Object Function(String path, Map<String, dynamic>? body)? reply;

  Map<String, dynamic> guestUser({int turns = 0}) => {
    'id': 'u1',
    'email': '',
    'phone': null,
    'username': 'wanderer',
    'tier': 'free',
    'guest': true,
    'guest_turns': turns,
    'preferences': {'nsfw_enabled': false},
  };

  late final GuestSession session = GuestSession(
    post: (path, {body}) async {
      posts.add((path: path, body: body));
      final next = script.isNotEmpty ? script.removeAt(0) : reply!(path, body);
      if (next is Exception) throw next;
      return next;
    },
    get: (path) async {
      gets.add(path);
      final next = script.removeAt(0);
      if (next is Exception) throw next;
      return next;
    },
    readToken: () async => token,
    readUser: () async => userJson,
    persist: (response) async {
      persisted++;
      token = response['token'] as String;
      userJson = jsonEncode(response['user']);
    },
    saveUser: (user) async => userJson = jsonEncode(user),
    installId: () async => '3f2b8c1e-5a77-4d2e-9d11-0c1b6a7f9e10',
    onStarted: () => started++,
    discard: () async {
      discarded++;
      token = null;
      userJson = null;
    },
    delay: (wait) async => waits.add(wait),
  );
}

class _RecordingWs extends FrameWs {
  int loads = 0;
  @override
  void loadInstance(String instanceId) => loads++;
}

ApiException _api(int status, String code) =>
    ApiException(statusCode: status, message: 'copy for $code', code: code);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('start', () {
    test(
      'creates a guest, saves it through the session path, then resumes it',
      () async {
        final rig = Rig();
        rig.reply = (path, body) => {
          'token': 'guest-jwt',
          'user': rig.guestUser(),
        };

        final first = await rig.session.start();
        expect(first.guest, isTrue);
        expect(rig.posts.single.path, '/auth/guest');
        expect(rig.posts.single.body, {
          'install_id': '3f2b8c1e-5a77-4d2e-9d11-0c1b6a7f9e10',
        });
        expect(rig.token, 'guest-jwt');
        expect(rig.session.isGuest, isTrue);
        expect(rig.session.isGuestListenable.value, isTrue);
        expect(rig.started, 1);

        // Second start: the stored guest is resumed, not announced again.
        final second = await rig.session.start();
        expect(second.guest, isTrue);
        expect(rig.posts, hasLength(2));
        expect(rig.persisted, 2);
        expect(rig.started, 1);
      },
    );

    test('a signed-in session is left alone', () async {
      final rig = Rig()
        ..token = 'real-jwt'
        ..userJson = jsonEncode({
          'id': 'u9',
          'email': 'a@b.c',
          'username': 'x',
          'tier': 'free',
        })
        ..reply = (_, _) => fail('no request expected');
      final user = await rig.session.start();
      expect(user.guest, isFalse);
      expect(rig.posts, isEmpty);
    });

    test('a refused install surfaces so the screen can fall back', () async {
      final rig = Rig()..script.add(_api(409, 'guest_session_required'));
      await expectLater(
        rig.session.start(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            'guest_session_required',
          ),
        ),
      );
      expect(rig.token, isNull);
      expect(rig.started, 0);
    });
  });

  group('resume at launch', () {
    test(
      'a good token resumes through /auth/me without a guest request',
      () async {
        final rig = Rig()
          ..token = 'guest-jwt'
          ..userJson = jsonEncode(Rig().guestUser())
          ..script.add(Rig().guestUser(turns: 2));
        final user = await rig.session.resume();
        expect(user?.guestTurns, 2);
        expect(rig.gets, ['/auth/me']);
        expect(rig.posts, isEmpty);
      },
    );

    test('only a rejected token is answered with POST /auth/guest', () async {
      final rig = Rig()
        ..token = 'old-jwt'
        ..userJson = jsonEncode(Rig().guestUser())
        ..script.addAll([
          _api(401, 'unauthorized'),
          {'token': 'fresh-jwt', 'user': Rig().guestUser()},
        ]);
      final user = await rig.session.resume();
      expect(user?.guest, isTrue);
      expect(rig.posts.single.path, '/auth/guest');
      expect(rig.token, 'fresh-jwt');
    });

    test('a guest that cannot be resumed is dropped locally', () async {
      final rig = Rig()
        ..token = 'old-jwt'
        ..userJson = jsonEncode(Rig().guestUser())
        ..script.addAll([
          _api(401, 'unauthorized'),
          _api(409, 'guest_session_required'),
        ]);
      expect(await rig.session.resume(), isNull);
      expect(rig.discarded, 1);
    });

    test('offline keeps the stored guest', () async {
      final rig = Rig()
        ..token = 'guest-jwt'
        ..userJson = jsonEncode(Rig().guestUser())
        ..script.add(Exception('no route'));
      final user = await rig.session.resume();
      expect(user?.guest, isTrue);
      expect(rig.posts, isEmpty);
      expect(rig.discarded, 0);
    });
  });

  group('refusals raise the sign-in request', () {
    test('a REST 403 sign_in_required raises it and still throws', () {
      final before = SignInRequired.requests.value;
      expect(
        () => ApiClient.parseResponse(
          http.Response.bytes(
            utf8.encode(
              '{"error":"Keep your story — sign in to continue.",'
              '"code":"sign_in_required"}',
            ),
            403,
          ),
        ),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'sign_in_required'),
        ),
      );
      expect(SignInRequired.requests.value, before + 1);
    });

    test('other refusals do not raise it', () {
      final before = SignInRequired.requests.value;
      for (final (status, body) in [
        (403, '{"error":"no","code":"forbidden"}'),
        (400, '{"error":"no","code":"sign_in_required"}'),
        (500, 'oops'),
      ]) {
        expect(
          () => ApiClient.parseResponse(http.Response(body, status)),
          throwsA(isA<ApiException>()),
        );
      }
      expect(SignInRequired.requests.value, before);
    });

    test('SIGN_IN_REQUIRED is not a turn failure', () {
      expect(
        turnFailureReason({'type': 'error', 'code': 'SIGN_IN_REQUIRED'}),
        isNull,
      );
      expect(turnFailureReason({'type': 'error', 'code': 'OTHER'}), 'server');
    });

    test(
      'the socket frame raises it, hands the text back and shows nothing',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel(
                'plugins.it_nomads.com/flutter_secure_storage',
              ),
              (call) async => null,
            );
        final ws = _RecordingWs();
        final cubit = PlayCubit(
          instanceId: 'inst_guest',
          ws: ws,
          mediaRepo: FakeMediaRepository(),
          audio: FakeAudioPlaybackController(),
          onRefreshInk: () async {},
        );
        ws.connectionCtrl.add(true);
        await pumpEventQueue();
        addTearDown(() async {
          await cubit.close();
          ws.dispose();
        });

        final before = GuestSession.instance.signInRequired.value;
        await cubit.sendMessage('I open the door');
        expect(cubit.state.narrativeStreaming, isTrue);
        ws.push('error', {
          'type': 'error',
          'code': 'SIGN_IN_REQUIRED',
          'message': 'Keep your story — sign in to continue.',
        });
        await settle();

        expect(GuestSession.instance.signInRequired.value, before + 1);
        expect(cubit.state.error, isNull);
        expect(cubit.state.canRetry, isFalse);
        expect(cubit.state.restoreComposerText, 'I open the door');
        expect(cubit.state.events.where((e) => e.isOptimistic), isEmpty);
        // Everything the send set is released, so the composer is usable.
        expect(cubit.state.isGenerating, isFalse);
        expect(cubit.state.narrativeStreaming, isFalse);
        expect(cubit.state.composerLocked, isFalse);
        expect(cubit.state.hasQueuedSend, isFalse);

        // Signing in swaps the session: the save is asked for again under it,
        // once, and the restored line sends normally.
        final loads = ws.loads;
        AuthService.sessionEpoch.value++;
        expect(ws.loads, loads + 1);
        AuthService.sessionEpoch.value++;
        expect(ws.loads, loads + 1);
        await cubit.sendMessage('I open the door');
        expect(ws.sends.last, 'chat:I open the door');
        expect(cubit.state.isGenerating, isTrue);
      },
    );
  });

  group('sign-in hand-off', () {
    test('guest_token is sent only while a guest session is pending', () async {
      final rig = Rig()
        ..reply = (_, _) => {
          'token': 'real',
          'user': {'id': 'u1'},
        };

      await rig.session.exchange('/auth/google', {'id_token': 'g'});
      expect(rig.posts.last.body, {'id_token': 'g'});

      rig
        ..token = 'guest-jwt'
        ..userJson = jsonEncode(rig.guestUser());
      expect(await rig.session.pendingGuestToken(), 'guest-jwt');
      await rig.session.exchange('/auth/otp/verify', {
        'phone': '+15555550100',
        'code': '123456',
      });
      expect(rig.posts.last.body, {
        'phone': '+15555550100',
        'code': '123456',
        'guest_token': 'guest-jwt',
      });

      // A signed-in account's token is never offered as a guest.
      rig.userJson = jsonEncode({'id': 'u1', 'username': 'x', 'tier': 'free'});
      expect(await rig.session.pendingGuestToken(), isNull);
    });

    test(
      'a pending transfer retries Google three times, then surfaces',
      () async {
        final rig = Rig()
          ..token = 'guest-jwt'
          ..userJson = jsonEncode(Rig().guestUser())
          ..reply = (_, _) => _api(409, 'guest_transfer_pending');
        await expectLater(
          rig.session.exchange('/auth/google', {
            'id_token': 'g',
          }, retryTransfer: true),
          throwsA(
            isA<ApiException>().having(
              (e) => e.code,
              'code',
              'guest_transfer_pending',
            ),
          ),
        );
        expect(rig.posts, hasLength(4)); // the first try and three retries
        expect(rig.waits, hasLength(3));
        expect(
          rig.posts.every((p) => p.body!['guest_token'] == 'guest-jwt'),
          isTrue,
        );
        // The guest is still there to be retried later.
        expect(await rig.session.pendingGuestToken(), 'guest-jwt');
      },
    );

    test(
      'Google succeeds when the transfer settles during the retries',
      () async {
        final rig = Rig()
          ..token = 'guest-jwt'
          ..userJson = jsonEncode(Rig().guestUser())
          ..script.addAll([
            _api(409, 'guest_transfer_pending'),
            {
              'token': 'real',
              'user': {'id': 'u1'},
              'new_account': true,
            },
          ]);
        final response = await rig.session.exchange('/auth/google', {
          'id_token': 'g',
        }, retryTransfer: true);
        expect(response['token'], 'real');
        expect(rig.posts, hasLength(2));
      },
    );

    test('phone never loops on a pending transfer', () async {
      final rig = Rig()
        ..token = 'guest-jwt'
        ..userJson = jsonEncode(Rig().guestUser())
        ..reply = (_, _) => _api(409, 'guest_transfer_pending');
      await expectLater(
        rig.session.exchange('/auth/otp/verify', {'phone': '+1', 'code': '1'}),
        throwsA(isA<ApiException>()),
      );
      expect(rig.posts, hasLength(1));
      expect(rig.waits, isEmpty);
    });

    test('other errors pass straight through', () async {
      final rig = Rig()..reply = (_, _) => _api(400, 'code_expired');
      await expectLater(
        rig.session.exchange('/auth/google', {
          'id_token': 'g',
        }, retryTransfer: true),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'code_expired'),
        ),
      );
      expect(rig.posts, hasLength(1));
    });
  });

  group('logout', () {
    test('clearing a guest makes no network call', () async {
      final rig = Rig()
        ..token = 'guest-jwt'
        ..userJson = jsonEncode(Rig().guestUser())
        ..reply = (_, _) => fail('no request expected');
      await rig.session.load();
      expect(rig.session.isGuest, isTrue);
      rig.session.clear();
      expect(rig.session.isGuest, isFalse);
      expect(rig.posts, isEmpty);
      expect(rig.gets, isEmpty);
    });
  });
}
