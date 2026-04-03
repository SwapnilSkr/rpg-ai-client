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
  String? _token;
  bool _isConnected = false;
  int _reconnectAttempts = 0;
  final int _maxReconnectAttempts = 10;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

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

  Future<void> connect(String token) async {
    if (_isConnected && _token == token) return;
    _token = token;
    _attemptConnection();

    _connectivitySub ??= Connectivity().onConnectivityChanged.listen((result) {
      if (result.isNotEmpty &&
          result.first != ConnectivityResult.none &&
          !_isConnected) {
        _attemptConnection();
      }
    });
  }

  void _attemptConnection() {
    if (_token == null) return;
    try {
      final uri = Uri.parse('${AppConfig.wsBaseUrl}/ws/play?token=$_token');
      _channel = WebSocketChannel.connect(uri);

      _channel!.stream.listen(
        _onMessage,
        onDone: _onDisconnected,
        onError: (e) => _onDisconnected(),
      );

      _isConnected = true;
      _reconnectAttempts = 0;
      _connectionStateController.add(true);

      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(
        const Duration(seconds: 25),
        (_) => send({'action': 'ping'}),
      );

      _flushOfflineQueue();
    } catch (e) {
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic data) {
    final msg = jsonDecode(data as String) as Map<String, dynamic>;
    switch (msg['type']) {
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
      case 'connected':
        break;
    }
  }

  void _onDisconnected() {
    _isConnected = false;
    _connectionStateController.add(false);
    _pingTimer?.cancel();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) return;
    _reconnectTimer?.cancel();
    final delay = Duration(
      seconds: (2 * (_reconnectAttempts + 1)).clamp(2, 30),
    );
    _reconnectTimer = Timer(delay, () {
      _reconnectAttempts++;
      _attemptConnection();
    });
  }

  void send(Map<String, dynamic> message) {
    if (_isConnected && _channel != null) {
      _channel!.sink.add(jsonEncode(message));
    } else {
      _offlineQueue.add(message);
    }
  }

  void _flushOfflineQueue() {
    while (_offlineQueue.isNotEmpty && _isConnected) {
      send(_offlineQueue.removeAt(0));
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

  Future<void> disconnect() async {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    await _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    _connectionStateController.add(false);
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
