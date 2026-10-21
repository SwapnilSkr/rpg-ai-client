import 'package:flutter/foundation.dart';

/// Persisted state tracking story turns and review prompt eligibility.
@immutable
class RatingPromptState {
  /// Lifetime successful story turns on this install.
  final int successfulTurns;

  /// Consecutive successful story turns since the last setback
  /// (error, paywall, story resting, rate limit, refund).
  final int cleanStreak;

  /// Timestamp of the last review attempt (successful or failed/unavailable).
  final DateTime? lastAttemptAt;

  /// Whether `requestReview()` has ever been called on this install.
  final bool requested;

  const RatingPromptState({
    this.successfulTurns = 0,
    this.cleanStreak = 0,
    this.lastAttemptAt,
    this.requested = false,
  });

  static const zero = RatingPromptState();

  RatingPromptState copyWith({
    int? successfulTurns,
    int? cleanStreak,
    DateTime? lastAttemptAt,
    bool? requested,
  }) {
    return RatingPromptState(
      successfulTurns: successfulTurns ?? this.successfulTurns,
      cleanStreak: cleanStreak ?? this.cleanStreak,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      requested: requested ?? this.requested,
    );
  }

  Map<String, dynamic> toJson() => {
    'successful_turns': successfulTurns,
    'clean_streak': cleanStreak,
    'last_attempt_at': lastAttemptAt?.toIso8601String(),
    'requested': requested,
  };

  factory RatingPromptState.fromJson(Map<String, dynamic> json) {
    final turns = json['successful_turns'];
    final streak = json['clean_streak'];
    final lastAttempt = json['last_attempt_at'];
    final req = json['requested'];

    int parsedTurns = 0;
    if (turns is num) {
      parsedTurns = turns.toInt();
    } else if (turns is String) {
      parsedTurns = int.tryParse(turns) ?? 0;
    }

    int parsedStreak = 0;
    if (streak is num) {
      parsedStreak = streak.toInt();
    } else if (streak is String) {
      parsedStreak = int.tryParse(streak) ?? 0;
    }

    DateTime? parsedAttempt;
    if (lastAttempt is String && lastAttempt.isNotEmpty) {
      parsedAttempt = DateTime.tryParse(lastAttempt);
    }

    bool parsedRequested = false;
    if (req is bool) {
      parsedRequested = req;
    } else if (req is String) {
      parsedRequested = req.toLowerCase() == 'true';
    }

    return RatingPromptState(
      successfulTurns: parsedTurns >= 0 ? parsedTurns : 0,
      cleanStreak: parsedStreak >= 0 ? parsedStreak : 0,
      lastAttemptAt: parsedAttempt,
      requested: parsedRequested,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RatingPromptState &&
          runtimeType == other.runtimeType &&
          successfulTurns == other.successfulTurns &&
          cleanStreak == other.cleanStreak &&
          lastAttemptAt == other.lastAttemptAt &&
          requested == other.requested;

  @override
  int get hashCode =>
      successfulTurns.hashCode ^
      cleanStreak.hashCode ^
      lastAttemptAt.hashCode ^
      requested.hashCode;

  @override
  String toString() =>
      'RatingPromptState(successfulTurns: $successfulTurns, '
      'cleanStreak: $cleanStreak, '
      'lastAttemptAt: $lastAttemptAt, '
      'requested: $requested)';
}

/// Pure policy governing when Google Play in-app review may be requested.
///
/// Rules:
/// - At least [minSuccessfulTurns] (20) lifetime turns.
/// - At least [minCleanStreak] (3) consecutive clean turns without any setback.
/// - Never requested before on this install ([requested] must be false).
/// - No prior attempt within [retryCooldown] (60 days).
class RatingPromptPolicy {
  /// Minimum lifetime successful story turns before prompting.
  static const int minSuccessfulTurns = 20;

  /// Minimum consecutive clean turns required (no error, resting, paywall).
  static const int minCleanStreak = 3;

  /// Cooldown period after an attempt (unavailable or thrown) before retrying.
  static const Duration retryCooldown = Duration(days: 60);

  const RatingPromptPolicy();

  /// Returns the blocking reason if in-app review should not be requested,
  /// or null if eligible.
  String? blocker(RatingPromptState state, DateTime now) {
    // Once requestReview has been invoked, never prompt again on this install.
    if (state.requested) {
      return 'already requested on this install';
    }

    // Player needs a sufficient run of turns to appreciate the story.
    if (state.successfulTurns < minSuccessfulTurns) {
      return 'successful turns (${state.successfulTurns}/$minSuccessfulTurns) '
          'below threshold';
    }

    // Never prompt right after a setback (error, refund, resting, or paywall).
    if (state.cleanStreak < minCleanStreak) {
      return 'clean streak (${state.cleanStreak}/$minCleanStreak) '
          'below threshold';
    }

    // Cooldown prevents spamming when Play previously reported flow unavailable.
    if (state.lastAttemptAt != null) {
      final elapsed = now.difference(state.lastAttemptAt!);
      if (elapsed < retryCooldown) {
        return 'in cooldown since last attempt '
            '(${elapsed.inDays}/${retryCooldown.inDays} days)';
      }
    }

    return null;
  }

  /// Whether the policy permits asking for a review at [now].
  bool shouldAsk(RatingPromptState state, DateTime now) =>
      blocker(state, now) == null;
}
