/// Keeps one broken widget from turning into thousands of reports.
///
/// A build method that throws on every frame, or `userFacingError` called on
/// every rebuild of a screen showing the same failure, would otherwise fill
/// the queue and the server with copies of one problem. The same problem is
/// reported once per [window], at most [perKeyPerSession] times a session, and
/// all errors together are capped per minute.
library;

class ErrorLimiter {
  ErrorLimiter({
    this.window = const Duration(seconds: 10),
    this.perKeyPerSession = 5,
    this.perMinute = 30,
  });

  final Duration window;
  final int perKeyPerSession;
  final int perMinute;

  final Map<String, DateTime> _last = {};
  final Map<String, int> _counts = {};
  final List<DateTime> _recent = [];

  bool allow(String key, DateTime now) {
    final last = _last[key];
    if (last != null && now.difference(last) < window) return false;
    if ((_counts[key] ?? 0) >= perKeyPerSession) return false;
    _recent.removeWhere((t) => now.difference(t) >= const Duration(minutes: 1));
    if (_recent.length >= perMinute) return false;
    _last[key] = now;
    _counts[key] = (_counts[key] ?? 0) + 1;
    _recent.add(now);
    return true;
  }

  /// A new session starts the per-session counts over.
  void newSession() {
    _counts.clear();
    _last.clear();
  }
}
