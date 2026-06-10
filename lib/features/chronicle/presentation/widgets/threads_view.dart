import 'package:flutter/material.dart';
import '../../../../app/theme/nexus_theme.dart';
import '../../data/threads_data.dart';

/// Promise/Quest Tracker: the story's open threads — unkept promises, looming
/// threats, unanswered questions — and the ones recently laid to rest. Built on
/// the same `unresolved_thread` atoms that feed the open-threads prompt section.
class ThreadsView extends StatelessWidget {
  final ThreadsData data;

  const ThreadsView({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.open.isEmpty && data.resolved.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Text(
            'No threads yet. Promises made, debts owed, and questions left '
            'hanging will gather here, waiting to be answered.',
            textAlign: TextAlign.center,
            style: TextStyle(color: EverloreTheme.ash, fontSize: 13, height: 1.5),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      children: [
        if (data.open.isNotEmpty) ...[
          _SectionLabel(
            icon: Icons.flag_outlined,
            label: 'STILL UNRESOLVED',
            count: data.open.length,
          ),
          const SizedBox(height: 12),
          for (final t in data.open) _ThreadCard(thread: t, open: true),
          const SizedBox(height: 12),
        ],
        if (data.resolved.isNotEmpty) ...[
          _SectionLabel(
            icon: Icons.check_circle_outline,
            label: 'LAID TO REST',
            count: data.resolved.length,
          ),
          const SizedBox(height: 12),
          for (final t in data.resolved) _ThreadCard(thread: t, open: false),
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;

  const _SectionLabel({
    required this.icon,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: EverloreTheme.ash.withValues(alpha: 0.8), size: 14),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: EverloreTheme.ash.withValues(alpha: 0.8),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$count',
          style: TextStyle(
            color: EverloreTheme.gold.withValues(alpha: 0.7),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ThreadCard extends StatelessWidget {
  final StoryThread thread;
  final bool open;

  const _ThreadCard({required this.thread, required this.open});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: EverloreTheme.void2,
        border: Border.all(
          color: open
              ? EverloreTheme.goldDim.withValues(alpha: 0.45)
              : EverloreTheme.white10,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              open ? Icons.radio_button_unchecked : Icons.task_alt,
              size: 16,
              color: open
                  ? EverloreTheme.gold
                  : EverloreTheme.ash.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  thread.text,
                  style: TextStyle(
                    color: open
                        ? EverloreTheme.parchment
                        : EverloreTheme.ash,
                    fontSize: 14,
                    height: 1.5,
                    decoration:
                        open ? null : TextDecoration.lineThrough,
                    decorationColor: EverloreTheme.ash.withValues(alpha: 0.4),
                  ),
                ),
                if (thread.emotionalValence != null &&
                    thread.emotionalValence!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    thread.emotionalValence!.toLowerCase(),
                    style: TextStyle(
                      color: EverloreTheme.gold.withValues(alpha: 0.6),
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
