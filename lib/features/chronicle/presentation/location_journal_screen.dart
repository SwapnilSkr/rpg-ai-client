import 'package:flutter/material.dart';
import '../../../app/theme/nexus_theme.dart';
import '../data/chronicle_repository.dart';
import '../data/location_journal.dart';

/// "What happened here before?" — one place's recorded history, loaded on
/// demand. Events along the top as a faint timeline, then the memories the
/// place holds (highest-importance first, matching the server ordering).
class LocationJournalScreen extends StatefulWidget {
  final String instanceId;
  final String locationEntityId;
  final String placeName;

  const LocationJournalScreen({
    super.key,
    required this.instanceId,
    required this.locationEntityId,
    required this.placeName,
  });

  @override
  State<LocationJournalScreen> createState() => _LocationJournalScreenState();
}

class _LocationJournalScreenState extends State<LocationJournalScreen> {
  late Future<LocationJournal> _future;

  @override
  void initState() {
    super.initState();
    _future = ChronicleRepository.getLocationJournal(
      widget.instanceId,
      widget.locationEntityId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EverloreTheme.void1,
      body: Column(
        children: [
          _Header(placeName: widget.placeName),
          Expanded(
            child: FutureBuilder<LocationJournal>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: EverloreTheme.gold,
                      ),
                    ),
                  );
                }
                if (snap.hasError || !snap.hasData) {
                  return _message(
                    'The place keeps its silence for now.',
                  );
                }
                final journal = snap.data!;
                if (journal.events.isEmpty &&
                    journal.memories.isEmpty &&
                    journal.permanentFacts.isEmpty &&
                    journal.currentState.isEmpty) {
                  return _message(
                    'Nothing has been recorded here yet.',
                  );
                }
                return _JournalBody(journal: journal);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _message(String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: EverloreTheme.ash, fontSize: 14, height: 1.5),
          ),
        ),
      );
}

class _Header extends StatelessWidget {
  final String placeName;
  const _Header({required this.placeName});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: EverloreTheme.void0,
        border: Border(bottom: BorderSide(color: EverloreTheme.white10)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 16, 14),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: EverloreTheme.ash, size: 18),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const Icon(Icons.place, color: EverloreTheme.gold, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      placeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: EverloreTheme.parchment,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    Text(
                      'What happened here before',
                      style: TextStyle(
                        color: EverloreTheme.ash.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JournalBody extends StatelessWidget {
  final LocationJournal journal;
  const _JournalBody({required this.journal});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
        if (journal.permanentFacts.isNotEmpty) ...[
          _SectionLabel(icon: Icons.menu_book, label: 'WHAT IS TRUE OF THIS PLACE'),
          const SizedBox(height: 12),
          for (final f in journal.permanentFacts)
            _CanonTile(text: f, icon: Icons.brightness_1, accent: EverloreTheme.gold),
          const SizedBox(height: 24),
        ],
        if (journal.currentState.isNotEmpty) ...[
          _SectionLabel(icon: Icons.change_history, label: 'HOW IT STANDS NOW'),
          const SizedBox(height: 12),
          for (final s in journal.currentState)
            _CanonTile(text: s, icon: Icons.circle, accent: EverloreTheme.aether),
          const SizedBox(height: 24),
        ],
        if (journal.memories.isNotEmpty) ...[
          _SectionLabel(icon: Icons.bookmark, label: 'WHAT THIS PLACE HOLDS'),
          const SizedBox(height: 12),
          for (final m in journal.memories) _MemoryTile(memory: m),
          const SizedBox(height: 24),
        ],
        if (journal.events.isNotEmpty) ...[
          _SectionLabel(icon: Icons.timeline, label: 'MOMENTS HERE'),
          const SizedBox(height: 12),
          for (final e in journal.events) _EventTile(event: e),
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: EverloreTheme.ash.withValues(alpha: 0.8), size: 13),
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
      ],
    );
  }
}

class _CanonTile extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color accent;
  const _CanonTile({required this.text, required this.icon, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Icon(icon, size: 7, color: accent.withValues(alpha: 0.85)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: EverloreTheme.parchment,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoryTile extends StatelessWidget {
  final LocationMemoryEntry memory;
  const _MemoryTile({required this.memory});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: EverloreTheme.void2,
        border: Border.all(color: EverloreTheme.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            memory.text,
            style: const TextStyle(
              color: EverloreTheme.parchment,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          if (memory.emotionalValence != null &&
              memory.emotionalValence!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              memory.emotionalValence!.toLowerCase(),
              style: TextStyle(
                color: EverloreTheme.gold.withValues(alpha: 0.7),
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  final LocationEventEntry event;
  const _EventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final isMilestone =
        event.milestone != null && event.milestone!.trim().isNotEmpty;
    final hasPreview =
        event.preview != null && event.preview!.trim().isNotEmpty;
    final kind = _pretty(event.sceneTag, event.type);
    final timeLabel = event.anchor?.eventTimeLabel;

    // Lead with what actually happened (player's beat → narration snippet →
    // milestone), and demote the generic type/time to a small caption so the
    // timeline reads with substance instead of a column of "Dialogue".
    final mainLine =
        isMilestone ? event.milestone! : (hasPreview ? event.preview! : kind);
    final captionParts = <String>[
      if (!isMilestone && hasPreview) kind,
      if (timeLabel != null && timeLabel.isNotEmpty) timeLabel,
    ];
    final caption = captionParts.isEmpty ? null : captionParts.join('  ·  ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: isMilestone ? 1 : 5),
            child: Icon(
              isMilestone ? Icons.auto_awesome : Icons.circle,
              size: isMilestone ? 13 : 6,
              color: isMilestone
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
                  mainLine,
                  style: TextStyle(
                    color: (isMilestone || hasPreview)
                        ? EverloreTheme.parchment
                        : EverloreTheme.ash,
                    fontSize: 14,
                    fontWeight:
                        isMilestone ? FontWeight.w600 : FontWeight.normal,
                    height: 1.45,
                  ),
                ),
                if (caption != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    caption,
                    style: TextStyle(
                      color: EverloreTheme.ash.withValues(alpha: 0.7),
                      fontSize: 11,
                      letterSpacing: 0.3,
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

  String _pretty(String? sceneTag, String type) {
    final raw = (sceneTag != null && sceneTag.isNotEmpty) ? sceneTag : type;
    if (raw.isEmpty) return 'A moment';
    return raw[0].toUpperCase() + raw.substring(1).replaceAll('_', ' ');
  }
}
