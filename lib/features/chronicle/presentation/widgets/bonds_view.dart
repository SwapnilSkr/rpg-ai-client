import 'package:flutter/material.dart';
import '../../../../app/theme/nexus_theme.dart';
import '../../data/relationship_ledger.dart';
import '../character_memory_screen.dart';
import '../side_chat_screen.dart';

/// Relationship Ledger: where each member of the cast stands toward the
/// player. Meters (trust/affection/fear/rivalry, 0-100) come straight from the
/// codex relationship ledger; "moments" are the narrative edges that moved them.
/// Tapping a character opens "what they remember about you".
class BondsView extends StatelessWidget {
  final String instanceId;
  final RelationshipLedger ledger;

  const BondsView({super.key, required this.instanceId, required this.ledger});

  @override
  Widget build(BuildContext context) {
    final entries = ledger.characters;
    if (entries.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Text(
            'No bonds yet. As you meet others and your dealings with them '
            'deepen, where they stand with you will be charted here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: EverloreTheme.ash,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: entries.length,
      itemBuilder: (context, i) => _BondCard(
        entry: entries[i],
        onMemories: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CharacterMemoryScreen(
                instanceId: instanceId,
                characterId: entries[i].id,
                characterName: entries[i].name,
              ),
            ),
          );
        },
        onChat: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SideChatScreen(
                instanceId: instanceId,
                characterId: entries[i].id,
                characterName: entries[i].name,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BondCard extends StatelessWidget {
  final RelationshipEntry entry;
  final VoidCallback onMemories;
  final VoidCallback onChat;

  const _BondCard({
    required this.entry,
    required this.onMemories,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    final m = entry.meters;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: EverloreTheme.void2,
        border: Border.all(color: EverloreTheme.white10),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onMemories,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.name,
                            style: const TextStyle(
                              color: EverloreTheme.parchment,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (entry.role != null &&
                              entry.role!.trim().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              entry.role!,
                              style: const TextStyle(
                                color: EverloreTheme.ash,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Private chat',
                      visualDensity: VisualDensity.compact,
                      onPressed: onChat,
                      icon: const Icon(
                        Icons.forum_outlined,
                        color: EverloreTheme.gold,
                        size: 20,
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: EverloreTheme.ash,
                      size: 18,
                    ),
                  ],
                ),
                if (entry.disposition != null &&
                    entry.disposition!.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    entry.disposition!,
                    style: const TextStyle(
                      color: EverloreTheme.parchment,
                      fontSize: 13,
                      height: 1.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                if (m != null) ...[
                  const SizedBox(height: 14),
                  _Meter(
                    label: 'Trust',
                    value: m.trust,
                    color: EverloreTheme.aether,
                  ),
                  _Meter(
                    label: 'Affection',
                    value: m.affection,
                    color: EverloreTheme.rose,
                  ),
                  _Meter(
                    label: 'Fear',
                    value: m.fear,
                    color: EverloreTheme.ember,
                  ),
                  _Meter(
                    label: 'Rivalry',
                    value: m.rivalry,
                    color: EverloreTheme.crimson,
                  ),
                ],
                if (entry.moments.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Divider(color: EverloreTheme.white10, height: 1),
                  const SizedBox(height: 12),
                  Text(
                    'WHAT PASSED BETWEEN YOU',
                    style: TextStyle(
                      color: EverloreTheme.ash.withValues(alpha: 0.8),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final moment in entry.moments)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: EverloreTheme.goldDim.withValues(
                                  alpha: 0.7,
                                ),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              moment.label,
                              style: const TextStyle(
                                color: EverloreTheme.ash,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Meter extends StatelessWidget {
  final String label;
  final int value; // 0-100
  final Color color;

  const _Meter({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final fraction = (value.clamp(0, 100)) / 100.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 68,
            child: Text(
              label,
              style: const TextStyle(color: EverloreTheme.ash, fontSize: 12),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                children: [
                  Container(height: 6, color: EverloreTheme.void4),
                  FractionallySizedBox(
                    widthFactor: fraction,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 30,
            child: Text(
              '$value',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: color.withValues(alpha: 0.9),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
