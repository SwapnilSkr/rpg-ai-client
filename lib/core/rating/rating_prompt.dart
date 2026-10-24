import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import '../telemetry/telemetry.dart';
import 'rating_prompt_policy.dart';
import 'rating_prompt_store.dart';

export 'rating_prompt_policy.dart';
export 'rating_prompt_store.dart';

/// Minimal interface over Google Play in-app review operations.
abstract class RatingReviewClient {
  Future<bool> isAvailable();
  Future<void> requestReview();
}

/// Default implementation wrapping `in_app_review`.
class InAppReviewClient implements RatingReviewClient {
  final InAppReview _plugin;

  InAppReviewClient([InAppReview? plugin])
    : _plugin = plugin ?? InAppReview.instance;

  @override
  Future<bool> isAvailable() => _plugin.isAvailable();

  @override
  Future<void> requestReview() => _plugin.requestReview();
}

/// Service managing when to request in-app review from Google Play.
///
/// Prompts after a good run of turns: 20 lifetime turns, at least 3 clean
/// turns with no setbacks, at most once per install, with a 60-day cooldown
/// on unavailable/failed attempts.
class RatingPrompt {
  final RatingPromptStore _store;
  final RatingPromptPolicy _policy;
  final RatingReviewClient _client;
  final DateTime Function() _now;

  static final RatingPrompt instance = RatingPrompt();

  RatingPrompt({
    RatingPromptStore? store,
    RatingPromptPolicy? policy,
    RatingReviewClient? client,
    DateTime Function()? now,
  }) : _store = store ?? const RatingPromptStore(),
       _policy = policy ?? const RatingPromptPolicy(),
       _client = client ?? InAppReviewClient(),
       _now = now ?? DateTime.now;

  Future<void> _opQueue = Future.value();

  /// Serializes operations in a simple in-flight Future chain so rapid turns
  /// cannot both pass the gate concurrently.
  Future<void> _synchronized(Future<void> Function() action) {
    final prev = _opQueue;
    final nextCompleter = Completer<void>();
    _opQueue = nextCompleter.future;

    return prev.catchError((_) {}).then((_) => action()).whenComplete(() {
      nextCompleter.complete();
    });
  }

  /// Records a successful story turn, updates counters, and checks the policy
  /// to request an in-app review if eligible.
  Future<void> recordSuccessfulTurn() => _synchronized(() async {
    final currentState = await _store.read();
    var nextState = currentState.copyWith(
      successfulTurns: currentState.successfulTurns + 1,
      cleanStreak: currentState.cleanStreak + 1,
    );
    await _store.write(nextState);
    debugPrint(
      '[rating] Turn recorded: successfulTurns=${nextState.successfulTurns}, '
      'cleanStreak=${nextState.cleanStreak}',
    );

    final currentTime = _now();
    final blocker = _policy.blocker(nextState, currentTime);
    final shouldAsk = blocker == null;
    final reason = blocker ?? 'eligible';
    debugPrint('[rating] Gate check: shouldAsk=$shouldAsk ($reason)');

    if (!shouldAsk) return;

    // Record the attempt timestamp immediately. Even if the plugin reports
    // unavailable or throws, this attempt starts the 60-day cooldown.
    nextState = nextState.copyWith(lastAttemptAt: currentTime);
    await _store.write(nextState);
    debugPrint('[rating] Attempt recorded at $currentTime');

    try {
      debugPrint('[rating] Checking review availability...');
      final available = await _client.isAvailable();
      debugPrint('[rating] Review availability: $available');

      if (available) {
        debugPrint('[rating] Requesting in-app review...');
        Telemetry.instance.track('review_prompt_shown');
        await _client.requestReview();
        nextState = nextState.copyWith(requested: true);
        await _store.write(nextState);
        debugPrint(
          '[rating] Review requested successfully; marked requested=true',
        );
      } else {
        debugPrint(
          '[rating] In-app review unavailable; 60-day cooldown active',
        );
      }
    } catch (e) {
      debugPrint('[rating] Review request failed: $e; 60-day cooldown active');
    }
  });

  /// Records a setback (error, resting, refund, or paywall), resetting the
  /// clean streak.
  Future<void> recordSetback() => _synchronized(() async {
    final currentState = await _store.read();
    final nextState = currentState.copyWith(cleanStreak: 0);
    await _store.write(nextState);
    debugPrint(
      '[rating] Setback recorded: cleanStreak reset to 0 '
      '(successfulTurns=${nextState.successfulTurns})',
    );
  });

  @visibleForTesting
  Future<RatingPromptState> getStateForTesting() => _store.read();
}
