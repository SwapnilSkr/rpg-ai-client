/// The two clocks behind session ids and time-on-screen. Pure: the caller
/// passes the time in, so tests drive them with a fake clock and no timers.
library;

import 'telemetry_vocabulary.dart';

/// A session is one stretch of use. A new id begins on a cold start, or when
/// the app comes back after [rollover] in the background; a quick trip to
/// another app does not split the session.
class SessionClock {
  SessionClock({
    required this.newId,
    this.rollover = const Duration(minutes: 30),
  }) : id = newId();

  final String Function() newId;
  final Duration rollover;
  String id;
  DateTime? _backgroundedAt;

  void paused(DateTime now) => _backgroundedAt = now;

  /// True when this resume began a new session.
  bool resumed(DateTime now) {
    final since = _backgroundedAt;
    _backgroundedAt = null;
    if (since != null && now.difference(since) >= rollover) {
      id = newId();
      return true;
    }
    return false;
  }
}

class ScreenView {
  const ScreenView({
    required this.screen,
    required this.durationMs,
    this.from,
    this.partial = false,
  });

  final String screen;
  final int durationMs;
  final String? from;
  final bool partial;

  Map<String, Object?> toProps() => {
    'screen': screen,
    'duration_ms': durationMs,
    if (partial) 'partial': true,
    if (from != null) 'from': from,
  };
}

/// Foreground-only time on the current screen.
///
/// While the app is backgrounded the clock is stopped, so a phone left on the
/// Discover tab overnight reads as the seconds the player actually looked at
/// it. A pause emits what has been seen so far as a partial view and the clock
/// restarts on resume.
class ScreenClock {
  String? _current;
  String? _from;
  Duration _accumulated = Duration.zero;
  DateTime? _runningSince;
  bool _foreground = true;

  String? get current => _current;

  Duration _elapsed(DateTime now) {
    final since = _runningSince;
    return since == null ? _accumulated : _accumulated + now.difference(since);
  }

  int _clampedMs(DateTime now) {
    final ms = _elapsed(now).inMilliseconds;
    return ms < 0 ? 0 : (ms > maxDurationMs ? maxDurationMs : ms);
  }

  /// Moves to [name]; returns the screen just left, or null at the first
  /// screen or when [name] is already current.
  ScreenView? enter(String name, DateTime now) {
    if (name == _current) return null;
    final left = _current == null
        ? null
        : ScreenView(screen: _current!, from: _from, durationMs: _clampedMs(now));
    _from = _current;
    _current = name;
    _accumulated = Duration.zero;
    _runningSince = _foreground ? now : null;
    return left;
  }

  /// The current screen's time so far as a partial view, then stops the clock.
  ScreenView? pause(DateTime now) {
    _foreground = false;
    final screen = _current;
    if (screen == null) return null;
    final ms = _clampedMs(now);
    _accumulated = Duration.zero;
    _runningSince = null;
    if (ms == 0) return null;
    return ScreenView(screen: screen, from: _from, durationMs: ms, partial: true);
  }

  void resume(DateTime now) {
    _foreground = true;
    if (_current != null) _runningSince = now;
  }
}
