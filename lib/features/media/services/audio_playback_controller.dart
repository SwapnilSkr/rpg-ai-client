import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Manages playback of spoken dialogue lines using just_audio.
///
/// Ensures only one line plays at a time.
class AudioPlaybackController extends ChangeNotifier {
  static final AudioPlaybackController instance = AudioPlaybackController();

  final AudioPlayer? _player;
  StreamSubscription<PlayerState>? _playerSub;

  String? _activeEventId;
  String? _activeLineId;
  bool _isPlaying = false;
  String? _loadingEventId;
  String? _loadingLineId;

  AudioPlaybackController({AudioPlayer? player})
      : _player = player ?? AudioPlayer() {
    _initListener();
  }

  void _initListener() {
    _playerSub = _player?.playerStateStream.listen((state) {
      final playing = state.playing &&
          state.processingState != ProcessingState.completed &&
          state.processingState != ProcessingState.idle;

      if (_isPlaying != playing) {
        _isPlaying = playing;
        if (!_isPlaying && state.processingState == ProcessingState.completed) {
          _activeEventId = null;
          _activeLineId = null;
        }
        notifyListeners();
      }
    });
  }

  String? get activeEventId => _activeEventId;
  String? get activeLineId => _activeLineId;
  bool get isPlaying => _isPlaying;

  String? get loadingEventId => _loadingEventId;
  String? get loadingLineId => _loadingLineId;

  bool isLinePlaying(String eventId, String lineId) =>
      _isPlaying && _activeEventId == eventId && _activeLineId == lineId;

  bool isLineLoading(String eventId, String lineId) =>
      _loadingEventId == eventId && _loadingLineId == lineId;

  void setLoading(String? eventId, String? lineId) {
    _loadingEventId = eventId;
    _loadingLineId = lineId;
    notifyListeners();
  }

  Future<void> play({
    required String eventId,
    required String lineId,
    required String url,
  }) async {
    // If this line is already playing, stop it.
    if (isLinePlaying(eventId, lineId)) {
      await stop();
      return;
    }

    // Stop whatever else might be playing.
    await stop();

    _activeEventId = eventId;
    _activeLineId = lineId;
    _loadingEventId = null;
    _loadingLineId = null;
    _isPlaying = true;
    notifyListeners();

    try {
      if (_player != null) {
        await _player.setUrl(url);
        await _player.play();
      }
    } catch (e) {
      _isPlaying = false;
      _activeEventId = null;
      _activeLineId = null;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    _loadingEventId = null;
    _loadingLineId = null;
    _isPlaying = false;
    _activeEventId = null;
    _activeLineId = null;
    notifyListeners();

    try {
      if (_player != null) {
        await _player.stop();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _playerSub?.cancel();
    _player?.dispose();
    super.dispose();
  }
}
