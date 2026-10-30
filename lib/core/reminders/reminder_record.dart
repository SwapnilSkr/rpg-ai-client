import 'dart:convert';

/// The story the reminders point at.
class ReminderAnchor {
  const ReminderAnchor({
    required this.instanceId,
    required this.worldTitle,
    required this.at,
  });

  final String instanceId;
  final String worldTitle;
  final DateTime at;

  Map<String, Object?> toJson() => {
    'instanceId': instanceId,
    'worldTitle': worldTitle,
    'at': at.toIso8601String(),
  };

  static ReminderAnchor? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['instanceId'];
    final at = DateTime.tryParse('${raw['at']}');
    if (id is! String || id.isEmpty || at == null) return null;
    return ReminderAnchor(
      instanceId: id,
      worldTitle: raw['worldTitle'] is String ? raw['worldTitle'] as String : '',
      at: at,
    );
  }
}

/// What the device remembers about reminders. Cleared on sign-out and account
/// deletion; none of it goes to the server.
class ReminderRecord {
  const ReminderRecord({
    this.enabled = false,
    this.askCount = 0,
    this.lastAskedAt,
    this.anchor,
  });

  static const empty = ReminderRecord();

  final bool enabled;
  final int askCount;
  final DateTime? lastAskedAt;
  final ReminderAnchor? anchor;

  ReminderRecord copyWith({
    bool? enabled,
    int? askCount,
    DateTime? lastAskedAt,
    ReminderAnchor? anchor,
  }) => ReminderRecord(
    enabled: enabled ?? this.enabled,
    askCount: askCount ?? this.askCount,
    lastAskedAt: lastAskedAt ?? this.lastAskedAt,
    anchor: anchor ?? this.anchor,
  );

  String encode() => jsonEncode({
    'remindersEnabled': enabled,
    'askCount': askCount,
    if (lastAskedAt != null) 'lastAskedAt': lastAskedAt!.toIso8601String(),
    if (anchor != null) 'anchor': anchor!.toJson(),
  });

  /// A corrupt or missing blob is an empty record, never an error: the worst
  /// case is one more ask.
  static ReminderRecord decode(String? raw) {
    if (raw == null || raw.isEmpty) return empty;
    try {
      final map = jsonDecode(raw);
      if (map is! Map) return empty;
      final asks = map['askCount'];
      return ReminderRecord(
        enabled: map['remindersEnabled'] == true,
        askCount: asks is int ? asks.clamp(0, 2) : 0,
        lastAskedAt: DateTime.tryParse('${map['lastAskedAt']}'),
        anchor: ReminderAnchor.fromJson(map['anchor']),
      );
    } catch (_) {
      return empty;
    }
  }
}
