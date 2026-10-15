import 'package:equatable/equatable.dart';

/// A quoted spoken line detected in an AI response.
///
/// [start] and [end] are UTF-16 code unit offsets into `ai_response`, quotes included.
class SpokenLine extends Equatable {
  final String lineId;
  final int start;
  final int end;

  /// The server already found this line can't be voiced; it stays inert.
  final bool unvoiceable;

  const SpokenLine({
    required this.lineId,
    required this.start,
    required this.end,
    this.unvoiceable = false,
  });

  factory SpokenLine.fromJson(Map<String, dynamic> json) {
    return SpokenLine(
      lineId: (json['line_id'] ?? json['lineId'] ?? '').toString(),
      start: (json['start'] as num?)?.toInt() ?? 0,
      end: (json['end'] as num?)?.toInt() ?? 0,
      unvoiceable: json['voice'] is Map &&
          (json['voice'] as Map)['status'] == 'unvoiceable',
    );
  }

  static List<SpokenLine> listFromAny(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => SpokenLine.fromJson(Map<String, dynamic>.from(m)))
        .where((l) => l.lineId.isNotEmpty && l.end >= l.start)
        .toList(growable: false);
  }

  Map<String, dynamic> toJson() => {
    'line_id': lineId,
    'start': start,
    'end': end,
    if (unvoiceable) 'voice': {'status': 'unvoiceable'},
  };

  @override
  List<Object?> get props => [lineId, start, end, unvoiceable];
}
