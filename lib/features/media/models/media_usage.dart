import 'package:equatable/equatable.dart';

class UsageQuota extends Equatable {
  final int used;
  final int limit;

  const UsageQuota({required this.used, required this.limit});

  factory UsageQuota.fromJson(Map<String, dynamic> json) => UsageQuota(
    used: (json['used'] as num?)?.toInt() ?? 0,
    limit: (json['limit'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {'used': used, 'limit': limit};

  @override
  List<Object?> get props => [used, limit];
}

class MediaUsage extends Equatable {
  final UsageQuota voice;
  final UsageQuota picture;
  final UsageQuota video;
  final UsageQuota portrait;
  final String resetsAt;

  const MediaUsage({
    required this.voice,
    required this.picture,
    required this.video,
    required this.portrait,
    required this.resetsAt,
  });

  factory MediaUsage.fromJson(Map<String, dynamic> json) => MediaUsage(
    voice: UsageQuota.fromJson(Map<String, dynamic>.from(json['voice'] ?? {})),
    picture: UsageQuota.fromJson(
      Map<String, dynamic>.from(json['picture'] ?? {}),
    ),
    video: UsageQuota.fromJson(Map<String, dynamic>.from(json['video'] ?? {})),
    portrait: UsageQuota.fromJson(
      Map<String, dynamic>.from(json['portrait'] ?? {}),
    ),
    resetsAt: (json['resets_at'] ?? json['resetsAt'] ?? '').toString(),
  );

  @override
  List<Object?> get props => [voice, picture, video, portrait, resetsAt];
}
