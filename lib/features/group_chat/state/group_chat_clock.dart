import 'dart:async';

/// Time as the group chat reads it, so tests can move it by hand instead of
/// waiting for a line to be revealed.
abstract class GroupChatClock {
  DateTime now();

  /// Runs [action] after [delay]. The returned function cancels it.
  void Function() schedule(Duration delay, void Function() action);
}

class SystemGroupChatClock implements GroupChatClock {
  const SystemGroupChatClock();

  @override
  DateTime now() => DateTime.now();

  @override
  void Function() schedule(Duration delay, void Function() action) {
    final timer = Timer(delay, action);
    return timer.cancel;
  }
}
