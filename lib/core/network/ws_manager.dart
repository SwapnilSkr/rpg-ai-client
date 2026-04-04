import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../config/env.dart';

class WsManager {
  static final WsManager _instance = WsManager._internal();
  factory WsManager() => _instance;
  WsManager._internal();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _socketSub;
  String? _token;
  bool _isConnected = false;
  bool _awaitingHandshake = false;
  bool _userInitiatedDisconnect = false;
  int _reconnectAttempts = 0;
  final int _maxReconnectAttempts = 10;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  /// Bumped when replacing the socket so stale [onDone]/[onError] never reconnect.
  int _connectionEpoch = 0;

  final _generationCompleteController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _memoriesCuratedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _errorController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionStateController = StreamController<bool>.broadcast();
  final _instanceLoadedController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onGenerationComplete =>
      _generationCompleteController.stream;
  Stream<Map<String, dynamic>> get onMemoriesCurated =>
      _memoriesCuratedController.stream;
  Stream<Map<String, dynamic>> get onError => _errorController.stream;
  Stream<bool> get onConnectionState => _connectionStateController.stream;
  Stream<Map<String, dynamic>> get onInstanceLoaded =>
      _instanceLoadedController.stream;

  bool get isConnected => _isConnected;

  final List<Map<String, dynamic>> _offlineQueue = [];

  /// Connect to the play WebSocket.
  ///
  /// [force] — close any existing socket and open a new one (use when entering
  /// play so re-entry is never stuck on a stale half-open channel).
  Future<void> connect(String token, {bool force = false}) async {
    if (token.isEmpty) return;
    if (!force && _token == token && _isConnected && _channel != null) return;

    if (force) _offlineQueue.clear();

    _userInitiatedDisconnect = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    final hadSocket = _channel != null;
    await _closeChannelOnly(notifyDisconnected: hadSocket && _isConnected);

    _token = token;
    _reconnectAttempts = 0;
    await _openChannel();

    _connectivitySub ??=
        Connectivity().onConnectivityChanged.listen((result) {
      if (result.isEmpty || result.first == ConnectivityResult.none) return;
      if (_userInitiatedDisconnect || _token == null) return;
      if (_isConnected && _channel != null) return;
      _reconnectAttempts = 0;
      unawaited(_openChannel());
    });
  }

  Uri _playWsUri(String token) {
    final base = AppConfig.wsBaseUrl.replaceAll(RegExp(r'/$'), '');
    return Uri.parse('$base/ws/play')
        .replace(queryParameters: {'token': token});
  }

  Future<void> _closeChannelOnly({required bool notifyDisconnected}) async {
    _pingTimer?.cancel();
    _pingTimer = null;
    await _socketSub?.cancel();
    _socketSub = null;

    final ch = _channel;
    _channel = null;
    _awaitingHandshake = false;

    final wasConnected = _isConnected;
    _isConnected = false;

    if (notifyDisconnected && wasConnected) {
      _connectionStateController.add(false);
    }

    if (ch != null) {
      try {
        await ch.sink.close();
      } catch (_) {}
    }
  }

  Future<void> _openChannel() async {
    if (_token == null || _userInitiatedDisconnect) return;

    await _closeChannelOnly(notifyDisconnected: false);

    try {
      final uri = _playWsUri(_token!);
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      _awaitingHandshake = true;

      final epoch = ++_connectionEpoch;
      _socketSub = channel.stream.listen(
        _onMessage,
        onDone: () {
          if (epoch != _connectionEpoch) return;
          _onDisconnected();
        },
        onError: (_, __) {
          if (epoch != _connectionEpoch) return;
          _onDisconnected();
        },
        cancelOnError: true,
      );

      // Do not set [_isConnected] / flush queue until server sends [connected].
    } catch (_) {
      _channel = null;
      _awaitingHandshake = false;
      if (!_userInitiatedDisconnect) {
        _connectionStateController.add(false);
        _scheduleReconnect();
      }
    }
  }

  void _onMessage(dynamic data) {
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(data as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    switch (msg['type']) {
      case 'connected':
        if (_awaitingHandshake) {
          _awaitingHandshake = false;
          _isConnected = true;
          _reconnectAttempts = 0;
          _connectionStateController.add(true);
          _pingTimer?.cancel();
          _pingTimer = Timer.periodic(
            const Duration(seconds: 25),
            (_) {
              if (_isConnected) send({'action': 'ping'});
            },
          );
          _flushOfflineQueue();
        }
        break;
      case 'generation_complete':
        _generationCompleteController.add(msg);
        break;
      case 'memories_curated':
        _memoriesCuratedController.add(msg);
        break;
      case 'generation_failed':
      case 'error':
        _errorController.add(msg);
        break;
      case 'instance_loaded':
        _instanceLoadedController.add(msg);
        break;
      case 'pong':
      case 'ack':
        break;
    }
  }

  void _onDisconnected() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _awaitingHandshake = false;
    final was = _isConnected;
    _isConnected = false;
    _channel = null;
    unawaited(_socketSub?.cancel());
    _socketSub = null;

    if (was) {
      _connectionStateController.add(false);
    }

    if (!_userInitiatedDisconnect && _token != null) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_userInitiatedDisconnect || _token == null) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) return;
    _reconnectTimer?.cancel();
    final delay = Duration(
      seconds: (2 * (_reconnectAttempts + 1)).clamp(2, 30),
    );
    _reconnectTimer = Timer(delay, () {
      _reconnectAttempts++;
      unawaited(_openChannel());
    });
  }

  void send(Map<String, dynamic> message) {
    if (_isConnected && _channel != null) {
      try {
        _channel!.sink.add(jsonEncode(message));
      } catch (_) {
        _onDisconnected();
      }
    } else {
      _offlineQueue.add(message);
    }
  }

  void _flushOfflineQueue() {
    while (_offlineQueue.isNotEmpty && _isConnected && _channel != null) {
      try {
        _channel!.sink.add(jsonEncode(_offlineQueue.removeAt(0)));
      } catch (_) {
        _onDisconnected();
        break;
      }
    }
  }

  void sendChatMessage(String instanceId, String message) {
    send({
      'action': 'chat',
      'instance_id': instanceId,
      'payload': {'message': message},
    });
  }

  void loadInstance(String instanceId) {
    send({'action': 'load_instance', 'instance_id': instanceId});
  }

  Future<void> disconnect({bool clearToken = false}) async {
    _userInitiatedDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _offlineQueue.clear();
    final had = _isConnected;
    await _closeChannelOnly(notifyDisconnected: had);
    if (clearToken) _token = null;
  }

  void dispose() {
    _connectivitySub?.cancel();
    _generationCompleteController.close();
    _memoriesCuratedController.close();
    _errorController.close();
    _connectionStateController.close();
    _instanceLoadedController.close();
  }
}
