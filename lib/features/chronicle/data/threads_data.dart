import 'package:equatable/equatable.dart';

/// Client mirror of `memoryService.listThreads` (Phase 10 Promise/Quest
/// Tracker). A thread is an open promise/conflict/question/debt/threat.

class StoryThread extends Equatable {
  final String id;
  final String text;
  final String type;
  final int importance;
  final String? emotionalValence;
  final DateTime? resolvedAt;

  const StoryThread({
    required this.id,
    required this.text,
    required this.type,
    required this.importance,
    this.emotionalValence,
    this.resolvedAt,
  });

  factory StoryThread.fromJson(Map<String, dynamic> json) => StoryThread(
        id: json['id'] as String? ?? '',
        text: json['text'] as String? ?? '',
        type: json['type'] as String? ?? 'thread',
        importance: (json['importance'] as num?)?.toInt() ?? 0,
        emotionalValence: json['emotional_valence'] as String?,
        resolvedAt: json['resolved_at'] != null
            ? DateTime.tryParse(json['resolved_at'].toString())
            : null,
      );

  @override
  List<Object?> get props => [id, text, type, importance, emotionalValence, resolvedAt];
}

class ThreadsData extends Equatable {
  final List<StoryThread> open;
  final List<StoryThread> resolved;

  const ThreadsData({this.open = const [], this.resolved = const []});

  factory ThreadsData.fromJson(Map<String, dynamic> json) => ThreadsData(
        open: (json['open'] as List?)
                ?.map((t) => StoryThread.fromJson(Map<String, dynamic>.from(t)))
                .toList() ??
            const [],
        resolved: (json['resolved'] as List?)
                ?.map((t) => StoryThread.fromJson(Map<String, dynamic>.from(t)))
                .toList() ??
            const [],
      );

  @override
  List<Object?> get props => [open, resolved];
}
