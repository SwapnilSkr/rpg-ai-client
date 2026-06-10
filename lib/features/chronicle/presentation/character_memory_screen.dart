import 'package:flutter/material.dart';
import '../../../app/theme/nexus_theme.dart';
import '../data/chronicle_repository.dart';
import '../data/relationship_ledger.dart';

/// "What this character remembers about you" — the memories a character is part
/// of, loaded on demand. Reached by tapping a character in the Bonds ledger.
class CharacterMemoryScreen extends StatefulWidget {
  final String instanceId;
  final String characterId;
  final String characterName;

  const CharacterMemoryScreen({
    super.key,
    required this.instanceId,
    required this.characterId,
    required this.characterName,
  });

  @override
  State<CharacterMemoryScreen> createState() => _CharacterMemoryScreenState();
}

class _CharacterMemoryScreenState extends State<CharacterMemoryScreen> {
  late Future<CharacterMemories> _future;

  @override
  void initState() {
    super.initState();
    _future = ChronicleRepository.getCharacterMemories(
      widget.instanceId,
      widget.characterId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EverloreTheme.void1,
      body: Column(
        children: [
          _Header(name: widget.characterName),
          Expanded(
            child: FutureBuilder<CharacterMemories>(
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
                  return _message('Their memories stay their own for now.');
                }
                final data = snap.data!;
                if (data.memories.isEmpty) {
                  return _message(
                    '${widget.characterName} carries nothing of you yet.',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: data.memories.length,
                  itemBuilder: (context, i) =>
                      _MemoryTile(memory: data.memories[i]),
                );
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
  final String name;
  const _Header({required this.name});

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
              const Icon(Icons.psychology_outlined,
                  color: EverloreTheme.gold, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
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
                      'What they remember about you',
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

class _MemoryTile extends StatelessWidget {
  final CharacterMemoryEntry memory;
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
        border: Border.all(
          color: memory.unresolvedThread
              ? EverloreTheme.goldDim.withValues(alpha: 0.4)
              : EverloreTheme.white10,
        ),
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
          if (memory.relationshipDelta != null &&
              memory.relationshipDelta!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              memory.relationshipDelta!,
              style: const TextStyle(
                color: EverloreTheme.ash,
                fontSize: 12,
                height: 1.4,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (_chips(memory).isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _chips(memory),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _chips(CharacterMemoryEntry m) {
    final chips = <Widget>[];
    if (m.emotionalValence != null && m.emotionalValence!.trim().isNotEmpty) {
      chips.add(_Chip(
        label: m.emotionalValence!.toLowerCase(),
        color: EverloreTheme.rose,
      ));
    }
    if (m.unresolvedThread) {
      chips.add(const _Chip(label: 'unresolved', color: EverloreTheme.gold));
    }
    return chips;
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color.withValues(alpha: 0.95),
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
