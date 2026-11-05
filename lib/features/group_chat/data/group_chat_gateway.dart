import 'dart:async';

import '../../../core/network/ws_manager.dart';
import '../../../core/storage/secure_storage.dart';

/// The socket as the group chat sees it: frames in, two requests out. The
/// cubit holds no socket knowledge beyond this.
abstract class GroupChatGateway {
  bool get isConnected;
  Stream<bool> get connectionState;
  Stream<Map<String, dynamic>> get instanceLoaded;
  Stream<Map<String, dynamic>> get groupLines;
  Stream<Map<String, dynamic>> get ack;
  Stream<Map<String, dynamic>> get generationComplete;

  /// Every frame about a picture a character sent of themselves, each with a
  /// `type`: `selfie_started`, `media_ready`, `media_unseen` or `media_failed`.
  /// The media frames also carry other kinds of picture; the cubit keeps the
  /// ones that name a line.
  Stream<Map<String, dynamic>> get selfieFrames;

  /// Failure frames: a rejected send and a turn that could not be written.
  Stream<Map<String, dynamic>> get errors;

  Future<void> connect();

  /// Asks for the history of the group thread, or of one direct thread.
  void loadInstance(String instanceId, {String? directWith});

  void sendChat(
    String instanceId,
    String text, {
    String? directWith,
    bool action = false,
  });
}

/// Backed by the shared [WsManager].
class WsGroupChatGateway implements GroupChatGateway {
  final WsManager _ws;

  WsGroupChatGateway(this._ws);

  late final Stream<Map<String, dynamic>> _selfieFrames = _mergeSelfie();

  Stream<Map<String, dynamic>> _mergeSelfie() {
    final subs = <StreamSubscription<Map<String, dynamic>>>[];
    late final StreamController<Map<String, dynamic>> out;
    void tag(Stream<Map<String, dynamic>> from, String type) {
      // The manager passes frames as received, which already name their type;
      // naming it again keeps the cubit independent of that.
      subs.add(from.listen((m) => out.add({...m, 'type': type})));
    }

    out = StreamController<Map<String, dynamic>>.broadcast(
      onListen: () {
        tag(_ws.onSelfieStarted, 'selfie_started');
        tag(_ws.onMediaReady, 'media_ready');
        tag(_ws.onMediaUnseen, 'media_unseen');
        tag(_ws.onMediaFailed, 'media_failed');
      },
      onCancel: () {
        for (final s in subs) {
          s.cancel();
        }
        subs.clear();
      },
    );
    return out.stream;
  }

  @override
  Stream<Map<String, dynamic>> get selfieFrames => _selfieFrames;

  @override
  Stream<Map<String, dynamic>> get groupLines => _ws.onGroupLines;

  @override
  bool get isConnected => _ws.isConnected;
  @override
  Stream<bool> get connectionState => _ws.onConnectionState;
  @override
  Stream<Map<String, dynamic>> get instanceLoaded => _ws.onInstanceLoaded;
  @override
  Stream<Map<String, dynamic>> get ack => _ws.onAck;
  @override
  Stream<Map<String, dynamic>> get generationComplete =>
      _ws.onGenerationComplete;

  /// `generation_failed` and `error` arrive on the same stream.
  @override
  Stream<Map<String, dynamic>> get errors => _ws.onError;

  @override
  Future<void> connect() async {
    final token = await SecureStore.getToken();
    if (token == null || token.isEmpty) return;
    // Not forced: the manager is shared and may already be connected.
    await _ws.connect(token);
  }

  @override
  void loadInstance(String instanceId, {String? directWith}) {
    _ws.send({
      'action': 'load_instance',
      'instance_id': instanceId,
      if (directWith != null) 'direct_with': directWith,
    });
  }

  @override
  void sendChat(
    String instanceId,
    String text, {
    String? directWith,
    bool action = false,
  }) {
    _ws.send({
      'action': 'chat',
      'instance_id': instanceId,
      if (directWith != null) 'direct_with': directWith,
      if (action) 'kind': 'action',
      'payload': {'message': text},
    });
  }
}
