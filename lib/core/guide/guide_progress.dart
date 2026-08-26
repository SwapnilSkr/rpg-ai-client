import 'package:flutter/foundation.dart';

/// Where a player stands with one guide arc.
///
/// [seen] is written the moment a flow starts, not when it ends — a crash,
/// a force-quit, or navigating away mid-arc must never cause a replay. Only a
/// server-side version bump runs an arc again; there is no player-facing way
/// to ask for one.
enum GuideStatus { seen, skipped, done }

GuideStatus _statusFrom(String? raw) => switch (raw) {
  'done' => GuideStatus.done,
  'skipped' => GuideStatus.skipped,
  _ => GuideStatus.seen,
};

String _statusTo(GuideStatus status) => switch (status) {
  GuideStatus.done => 'done',
  GuideStatus.skipped => 'skipped',
  GuideStatus.seen => 'seen',
};

@immutable
class GuideFlowProgress {
  /// Flow version the player actually saw. A newer declared version replays.
  final int version;

  /// Last beat index reached, for funnel analytics and resume.
  final int step;

  final GuideStatus status;
  final DateTime at;

  const GuideFlowProgress({
    required this.version,
    required this.step,
    required this.status,
    required this.at,
  });

  factory GuideFlowProgress.fromJson(Map<String, dynamic> json) {
    return GuideFlowProgress(
      version: (json['version'] as num?)?.toInt() ?? 1,
      step: (json['step'] as num?)?.toInt() ?? 0,
      status: _statusFrom(json['status'] as String?),
      at: DateTime.tryParse(json['at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'step': step,
    'status': _statusTo(status),
    'at': at.toUtc().toIso8601String(),
  };

  /// Field-wise reconciliation of the same arc from two devices.
  ///
  /// Deliberately NOT last-write-wins: a stale device that merely started an
  /// arc must not walk back a finished one, which is precisely how a tour ends
  /// up replaying on a second phone.
  GuideFlowProgress mergeWith(GuideFlowProgress other) {
    // A newer flow version supersedes: the older record described a different
    // arc, so its step and terminal status no longer describe this one.
    if (other.version > version) return other;
    if (version > other.version) return this;

    const rank = {
      GuideStatus.seen: 0,
      GuideStatus.skipped: 1,
      GuideStatus.done: 2,
    };
    final winner = rank[other.status]! > rank[status]! ? other.status : status;
    return GuideFlowProgress(
      version: version,
      step: step > other.step ? step : other.step,
      status: winner,
      at: at.isAfter(other.at) ? at : other.at,
    );
  }
}

/// The whole guide record for one account.
@immutable
class GuideProgress {
  final Map<String, GuideFlowProgress> flows;

  /// Player asked to be left alone. Suppresses every auto-start; explicit
  /// replay still works.
  final bool optOut;

  const GuideProgress({this.flows = const {}, this.optOut = false});

  static const empty = GuideProgress();

  factory GuideProgress.fromJson(
    Map<String, dynamic>? json, {
    bool optOut = false,
  }) {
    if (json == null) return GuideProgress(optOut: optOut);
    final flows = <String, GuideFlowProgress>{};
    json.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        flows[key] = GuideFlowProgress.fromJson(value);
      } else if (value is Map) {
        flows[key] = GuideFlowProgress.fromJson(
          value.map((k, v) => MapEntry(k.toString(), v)),
        );
      }
    });
    return GuideProgress(flows: flows, optOut: optOut);
  }

  Map<String, dynamic> toJson() => {
    for (final entry in flows.entries) entry.key: entry.value.toJson(),
  };

  GuideFlowProgress? operator [](String flowId) => flows[flowId];

  /// How many arcs the player has actively waved off — the signal behind the
  /// one-time "skip everything?" courtesy.
  int get skipCount =>
      flows.values.where((f) => f.status == GuideStatus.skipped).length;

  GuideProgress copyWith({
    Map<String, GuideFlowProgress>? flows,
    bool? optOut,
  }) =>
      GuideProgress(flows: flows ?? this.flows, optOut: optOut ?? this.optOut);

  GuideProgress withFlow(String id, GuideFlowProgress progress) {
    final next = Map<String, GuideFlowProgress>.from(flows);
    // Fold rather than overwrite so an out-of-order write (a late server
    // response landing after a local advance) cannot regress the record.
    next[id] = flows[id]?.mergeWith(progress) ?? progress;
    return copyWith(flows: next);
  }

  /// Union of two records — device cache and account, in either order.
  GuideProgress mergeWith(GuideProgress other) {
    final merged = Map<String, GuideFlowProgress>.from(flows);
    other.flows.forEach((id, progress) {
      merged[id] = merged[id]?.mergeWith(progress) ?? progress;
    });
    // Opt-out is sticky: silence asked for on any device is honoured on all.
    return GuideProgress(flows: merged, optOut: optOut || other.optOut);
  }
}
