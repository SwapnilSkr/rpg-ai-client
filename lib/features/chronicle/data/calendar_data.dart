import 'package:equatable/equatable.dart';

/// Client mirror of `timeService.listCalendar` — the calendar definitions,
/// timeline branches, the instance's current story-time cursor, and every
/// time-anchored event. Backend shape: src/services/time.service.ts.

class CalendarMonth extends Equatable {
  final String name;
  final int days;

  const CalendarMonth({required this.name, required this.days});

  factory CalendarMonth.fromJson(Map<String, dynamic> json) => CalendarMonth(
        name: json['name'] as String? ?? '',
        days: (json['days'] as num?)?.toInt() ?? 0,
      );

  @override
  List<Object?> get props => [name, days];
}

class StoryCalendar extends Equatable {
  final String id;
  final String name;
  final List<String> eras;
  final List<CalendarMonth> months;
  final List<String> weekdays;
  final bool isDefault;

  const StoryCalendar({
    required this.id,
    required this.name,
    this.eras = const [],
    this.months = const [],
    this.weekdays = const [],
    this.isDefault = false,
  });

  factory StoryCalendar.fromJson(Map<String, dynamic> json) => StoryCalendar(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Calendar',
        eras: (json['eras'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        months: (json['months'] as List?)
                ?.map((m) => CalendarMonth.fromJson(Map<String, dynamic>.from(m)))
                .toList() ??
            const [],
        weekdays:
            (json['weekdays'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        isDefault: json['is_default'] == true,
      );

  /// Render a story-calendar date into a readable in-world label using this
  /// calendar's month/era names. Falls back to whatever partial fields exist.
  String formatDate(StoryDate? date) {
    if (date == null) return 'Unrecorded time';
    if (date.label != null && date.label!.trim().isNotEmpty) return date.label!;

    final parts = <String>[];
    if (date.day != null) parts.add('Day ${date.day}');
    if (date.month != null && date.month! >= 1 && date.month! <= months.length) {
      parts.add('of ${months[date.month! - 1].name}');
    }
    final yearEra = <String>[];
    if (date.year != null) yearEra.add('Year ${date.year}');
    if (date.era != null && date.era!.trim().isNotEmpty) yearEra.add(date.era!);
    final head = parts.join(' ');
    final tail = yearEra.join(' ');
    if (head.isEmpty && tail.isEmpty) return 'Unrecorded time';
    if (head.isEmpty) return tail;
    if (tail.isEmpty) return head;
    return '$head, $tail';
  }

  @override
  List<Object?> get props => [id, name, eras, months, weekdays, isDefault];
}

class StoryDate extends Equatable {
  final int? year;
  final int? month;
  final int? day;
  final String? era;
  final String? label;

  const StoryDate({this.year, this.month, this.day, this.era, this.label});

  factory StoryDate.fromJson(Map<String, dynamic> json) => StoryDate(
        year: (json['year'] as num?)?.toInt(),
        month: (json['month'] as num?)?.toInt(),
        day: (json['day'] as num?)?.toInt(),
        era: json['era'] as String?,
        label: json['label'] as String?,
      );

  @override
  List<Object?> get props => [year, month, day, era, label];
}

class TimeAnchor extends Equatable {
  final int sequence;
  final String timelineId;
  final StoryDate? storyDate;
  final String? eventTimeLabel;

  const TimeAnchor({
    required this.sequence,
    required this.timelineId,
    this.storyDate,
    this.eventTimeLabel,
  });

  factory TimeAnchor.fromJson(Map<String, dynamic> json) => TimeAnchor(
        sequence: (json['sequence'] as num?)?.toInt() ?? 0,
        timelineId: json['timeline_id'] as String? ?? 'main',
        storyDate: json['story_calendar'] != null
            ? StoryDate.fromJson(Map<String, dynamic>.from(json['story_calendar']))
            : null,
        eventTimeLabel: json['event_time_label'] as String?,
      );

  @override
  List<Object?> get props => [sequence, timelineId, storyDate, eventTimeLabel];
}

class TimelineBranch extends Equatable {
  final String id;
  final String timelineId;
  final String name;
  final String? parentTimelineId;
  final int forkedAtSequence;
  final String status; // active | collapsed | alternate | erased

  const TimelineBranch({
    required this.id,
    required this.timelineId,
    required this.name,
    this.parentTimelineId,
    required this.forkedAtSequence,
    required this.status,
  });

  bool get isActive => status == 'active';

  factory TimelineBranch.fromJson(Map<String, dynamic> json) => TimelineBranch(
        id: json['id'] as String? ?? '',
        timelineId: json['timeline_id'] as String? ?? 'main',
        name: json['name'] as String? ?? 'Timeline',
        parentTimelineId: json['parent_timeline_id'] as String?,
        forkedAtSequence: (json['forked_at_sequence'] as num?)?.toInt() ?? 0,
        status: json['status'] as String? ?? 'active',
      );

  @override
  List<Object?> get props =>
      [id, timelineId, name, parentTimelineId, forkedAtSequence, status];
}

class CalendarEvent extends Equatable {
  final String id;
  final int sequence;
  final String type;
  final String? sceneTag;
  final TimeAnchor? anchor;
  final String? milestone;
  final String? timeAdvanced;

  const CalendarEvent({
    required this.id,
    required this.sequence,
    required this.type,
    this.sceneTag,
    this.anchor,
    this.milestone,
    this.timeAdvanced,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) => CalendarEvent(
        id: json['id'] as String? ?? '',
        sequence: (json['sequence'] as num?)?.toInt() ?? 0,
        type: json['type'] as String? ?? 'event',
        sceneTag: json['scene_tag'] as String?,
        anchor: json['time_anchor'] != null
            ? TimeAnchor.fromJson(Map<String, dynamic>.from(json['time_anchor']))
            : null,
        milestone: json['milestone'] as String?,
        timeAdvanced: json['time_advanced'] as String?,
      );

  @override
  List<Object?> get props =>
      [id, sequence, type, sceneTag, milestone, timeAdvanced];
}

class CalendarData extends Equatable {
  final List<StoryCalendar> calendars;
  final List<TimelineBranch> timelines;
  final TimeAnchor? currentAnchor;
  final List<CalendarEvent> events;

  const CalendarData({
    this.calendars = const [],
    this.timelines = const [],
    this.currentAnchor,
    this.events = const [],
  });

  factory CalendarData.fromJson(Map<String, dynamic> json) => CalendarData(
        calendars: (json['calendars'] as List?)
                ?.map((c) => StoryCalendar.fromJson(Map<String, dynamic>.from(c)))
                .toList() ??
            const [],
        timelines: (json['timelines'] as List?)
                ?.map((t) => TimelineBranch.fromJson(Map<String, dynamic>.from(t)))
                .toList() ??
            const [],
        currentAnchor: json['current_time_anchor'] != null
            ? TimeAnchor.fromJson(
                Map<String, dynamic>.from(json['current_time_anchor']))
            : null,
        events: (json['events'] as List?)
                ?.map((e) => CalendarEvent.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            const [],
      );

  /// The calendar to render dates with: the default, else the first defined.
  StoryCalendar? get primaryCalendar {
    if (calendars.isEmpty) return null;
    return calendars.firstWhere((c) => c.isDefault, orElse: () => calendars.first);
  }

  TimelineBranch? get activeTimeline {
    if (timelines.isEmpty) return null;
    return timelines.firstWhere((t) => t.isActive, orElse: () => timelines.first);
  }

  @override
  List<Object?> get props => [calendars, timelines, currentAnchor, events];
}
