import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../app/theme/nexus_theme.dart';
import '../../data/calendar_data.dart';
import '../../state/chronicle_cubit.dart';

/// The Almanac: surfaces the story-time backend (calendars, timeline branches,
/// the current in-world cursor) that the engine has always tracked but the
/// player never saw. Read-only except for switching the active timeline.
class AlmanacView extends StatelessWidget {
  final CalendarData data;

  const AlmanacView({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final calendar = data.primaryCalendar;
    final groups = _groupByDate(data.events, calendar);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      children: [
        _CurrentTimeCard(anchor: data.currentAnchor, calendar: calendar),
        if (data.timelines.length > 1) ...[
          const SizedBox(height: 20),
          _TimelineSwitcher(timelines: data.timelines),
        ],
        const SizedBox(height: 20),
        if (groups.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Text(
              'No dated events yet. As your story unfolds, its days will be '
              'recorded here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: EverloreTheme.ash, fontSize: 13, height: 1.5),
            ),
          )
        else
          for (final group in groups) _DateSection(group: group),
      ],
    );
  }

  List<_DateGroup> _groupByDate(
    List<CalendarEvent> events,
    StoryCalendar? calendar,
  ) {
    final ordered = [...events]..sort((a, b) => a.sequence.compareTo(b.sequence));
    final groups = <_DateGroup>[];
    for (final e in ordered) {
      final label = calendar?.formatDate(e.anchor?.storyDate) ??
          (e.anchor?.eventTimeLabel ?? 'Unrecorded time');
      if (groups.isNotEmpty && groups.last.label == label) {
        groups.last.events.add(e);
      } else {
        groups.add(_DateGroup(label: label, events: [e]));
      }
    }
    return groups;
  }
}

class _DateGroup {
  final String label;
  final List<CalendarEvent> events;
  _DateGroup({required this.label, required this.events});
}

class _CurrentTimeCard extends StatelessWidget {
  final TimeAnchor? anchor;
  final StoryCalendar? calendar;

  const _CurrentTimeCard({required this.anchor, required this.calendar});

  @override
  Widget build(BuildContext context) {
    final dateLabel = calendar?.formatDate(anchor?.storyDate) ?? 'Unrecorded time';
    final subLabel = anchor?.eventTimeLabel;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            EverloreTheme.gold.withValues(alpha: 0.12),
            EverloreTheme.void2,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: EverloreTheme.goldDim.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.wb_twilight, color: EverloreTheme.gold, size: 16),
              const SizedBox(width: 6),
              Text(
                'PRESENT MOMENT',
                style: TextStyle(
                  color: EverloreTheme.gold.withValues(alpha: 0.8),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            dateLabel,
            style: const TextStyle(
              color: EverloreTheme.parchment,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          if (subLabel != null && subLabel.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              subLabel,
              style: const TextStyle(
                color: EverloreTheme.ash,
                fontSize: 13,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ],
          if (calendar != null) ...[
            const SizedBox(height: 12),
            Text(
              calendar!.name,
              style: TextStyle(
                color: EverloreTheme.ash.withValues(alpha: 0.7),
                fontSize: 11,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TimelineSwitcher extends StatelessWidget {
  final List<TimelineBranch> timelines;

  const _TimelineSwitcher({required this.timelines});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.call_split, color: EverloreTheme.ash, size: 14),
            const SizedBox(width: 6),
            Text(
              'REALITIES',
              style: TextStyle(
                color: EverloreTheme.ash.withValues(alpha: 0.8),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in timelines)
              _TimelineChip(
                branch: t,
                onTap: t.isActive
                    ? null
                    : () => _confirmSwitch(context, t),
              ),
          ],
        ),
      ],
    );
  }

  void _confirmSwitch(BuildContext context, TimelineBranch branch) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EverloreTheme.void2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: EverloreTheme.goldDim.withValues(alpha: 0.3)),
        ),
        title: const Text(
          'Step Into This Reality?',
          style: TextStyle(color: EverloreTheme.parchment, fontSize: 18),
        ),
        content: Text(
          'Your story will continue along "${branch.name}". The path you are '
          'on now remains preserved, untouched.',
          style: const TextStyle(
              color: EverloreTheme.ash, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Stay', style: TextStyle(color: EverloreTheme.ash)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<ChronicleCubit>().setActiveTimeline(branch.timelineId);
            },
            child: const Text('Cross Over',
                style: TextStyle(color: EverloreTheme.gold)),
          ),
        ],
      ),
    );
  }
}

class _TimelineChip extends StatelessWidget {
  final TimelineBranch branch;
  final VoidCallback? onTap;

  const _TimelineChip({required this.branch, this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = branch.isActive;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: active
              ? EverloreTheme.gold.withValues(alpha: 0.14)
              : EverloreTheme.void2,
          border: Border.all(
            color: active
                ? EverloreTheme.goldDim.withValues(alpha: 0.6)
                : EverloreTheme.goldDim.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active ? Icons.check_circle : Icons.circle_outlined,
              size: 13,
              color: active ? EverloreTheme.gold : EverloreTheme.ash,
            ),
            const SizedBox(width: 6),
            Text(
              branch.name,
              style: TextStyle(
                color: active ? EverloreTheme.gold : EverloreTheme.ash,
                fontSize: 13,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateSection extends StatelessWidget {
  final _DateGroup group;

  const _DateSection({required this.group});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 10),
          child: Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: EverloreTheme.gold,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  group.label,
                  style: const TextStyle(
                    color: EverloreTheme.parchment,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.only(left: 3, bottom: 8),
          padding: const EdgeInsets.only(left: 14),
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: EverloreTheme.white10, width: 1.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final e in group.events) _EventRow(event: e),
            ],
          ),
        ),
      ],
    );
  }
}

class _EventRow extends StatelessWidget {
  final CalendarEvent event;

  const _EventRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final isMilestone = event.milestone != null && event.milestone!.isNotEmpty;
    final timeJump = event.timeAdvanced;
    final label = isMilestone
        ? event.milestone!
        : (event.anchor?.eventTimeLabel ?? _prettyTag(event.sceneTag, event.type));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isMilestone
                ? Icons.auto_awesome
                : (timeJump != null ? Icons.fast_forward : Icons.circle),
            size: isMilestone ? 14 : (timeJump != null ? 14 : 6),
            color: isMilestone
                ? EverloreTheme.gold
                : EverloreTheme.ash.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isMilestone
                        ? EverloreTheme.parchment
                        : EverloreTheme.ash,
                    fontSize: 13,
                    fontWeight:
                        isMilestone ? FontWeight.w600 : FontWeight.normal,
                    height: 1.4,
                  ),
                ),
                if (timeJump != null && timeJump.isNotEmpty)
                  Text(
                    'time passes — $timeJump',
                    style: TextStyle(
                      color: EverloreTheme.gold.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _prettyTag(String? sceneTag, String type) {
    final raw = (sceneTag != null && sceneTag.isNotEmpty) ? sceneTag : type;
    if (raw.isEmpty) return 'A moment';
    return raw[0].toUpperCase() + raw.substring(1).replaceAll('_', ' ');
  }
}
