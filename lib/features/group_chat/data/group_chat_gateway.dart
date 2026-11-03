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
