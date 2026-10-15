import 'package:equatable/equatable.dart';

enum MediaKind { voice, picture, video, portrait }

enum MediaStatus { queued, ready, unseen, failed }

/// A generated media item attached to a turn or character.
class TurnMedia extends Equatable {
  final String mediaId;
  final MediaKind kind;
  final MediaStatus status;
  final String? url;
  final String? lineId;
  final String? characterId;
  final int? durationMs;
  final bool justRequested;

  const TurnMedia({
    required this.mediaId,
    required this.kind,
    required this.status,
    this.url,
    this.lineId,
    this.characterId,
    this.durationMs,
    this.justRequested = false,
  });

  bool get isReady =>
      status == MediaStatus.ready && url != null && url!.isNotEmpty;
  bool get isQueued => status == MediaStatus.queued;
  bool get isPicture => kind == MediaKind.picture;
  bool get isVideo => kind == MediaKind.video;

  TurnMedia copyWith({
    String? mediaId,
    MediaKind? kind,
    MediaStatus? status,
    String? url,
    String? lineId,
    String? characterId,
    int? durationMs,
    bool? justRequested,
  }) {
    return TurnMedia(
      mediaId: mediaId ?? this.mediaId,
      kind: kind ?? this.kind,
      status: status ?? this.status,
      url: url ?? this.url,
      lineId: lineId ?? this.lineId,
      characterId: characterId ?? this.characterId,
      durationMs: durationMs ?? this.durationMs,
      justRequested: justRequested ?? this.justRequested,
    );
  }

  factory TurnMedia.fromJson(Map<String, dynamic> json) {
    final rawKind = (json['kind'] ?? '').toString();
    final kind = switch (rawKind) {
      'picture' => MediaKind.picture,
      'video' => MediaKind.video,
      'portrait' => MediaKind.portrait,
      _ => MediaKind.voice,
    };
    final rawStatus = (json['status'] ?? '').toString();
    final status = switch (rawStatus) {
      'ready' => MediaStatus.ready,
      'unseen' => MediaStatus.unseen,
      'failed' => MediaStatus.failed,
      _ => MediaStatus.queued,
    };
    return TurnMedia(
      mediaId:
          (json['media_id'] ?? json['mediaId'] ?? json['id'] ?? '').toString(),
      kind: kind,
      status: status,
      url: json['url']?.toString(),
      lineId: (json['line_id'] ?? json['lineId'])?.toString(),
      characterId: (json['character_id'] ?? json['characterId'])?.toString(),
      durationMs: (json['duration_ms'] ?? json['durationMs'] as num?)?.toInt(),
      justRequested: json['just_requested'] == true,
    );
  }

  static List<TurnMedia> listFromAny(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => TurnMedia.fromJson(Map<String, dynamic>.from(m)))
        .where((m) => m.mediaId.isNotEmpty)
        .toList(growable: false);
  }

  Map<String, dynamic> toJson() => {
    'media_id': mediaId,
    'kind': kind.name,
    'status': status.name,
    if (url != null) 'url': url,
    if (lineId != null) 'line_id': lineId,
    if (characterId != null) 'character_id': characterId,
    if (durationMs != null) 'duration_ms': durationMs,
    'just_requested': justRequested,
  };

  @override
  List<Object?> get props => [
    mediaId,
    kind,
    status,
    url,
    lineId,
    characterId,
    durationMs,
    justRequested,
  ];
}
