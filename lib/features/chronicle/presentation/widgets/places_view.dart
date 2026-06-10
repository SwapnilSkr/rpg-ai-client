import 'package:flutter/material.dart';
import '../../../../app/theme/nexus_theme.dart';
import '../../data/location_journal.dart';
import '../location_journal_screen.dart';

/// Location Journal index: every place the story has touched, current place
/// surfaced first. Tapping a place opens "what happened here before?".
class PlacesView extends StatelessWidget {
  final String instanceId;
  final LocationsData data;

  const PlacesView({super.key, required this.instanceId, required this.data});

  @override
  Widget build(BuildContext context) {
    final current = data.currentLocation;
    final currentId = current?.entityId;
    // Keep the current place pinned to the top even though listLocations
    // already sorts most-recent first.
    final places = [...data.places]..sort((a, b) {
        if (a.entityId == currentId) return -1;
        if (b.entityId == currentId) return 1;
        return (b.lastSeenSequence ?? -1).compareTo(a.lastSeenSequence ?? -1);
      });

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      children: [
        if (current != null) ...[
          _CurrentPlaceBanner(name: current.name),
          const SizedBox(height: 16),
        ],
        if (places.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Text(
              'No places recorded yet. As your journey takes you somewhere, '
              'each place will remember what happened there.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: EverloreTheme.ash, fontSize: 13, height: 1.5),
            ),
          )
        else
          for (final place in places)
            _PlaceCard(
              place: place,
              isCurrent: place.entityId == currentId,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LocationJournalScreen(
                      instanceId: instanceId,
                      placeName: place.name,
                      locationEntityId: place.entityId,
                    ),
                  ),
                );
              },
            ),
      ],
    );
  }
}

class _CurrentPlaceBanner extends StatelessWidget {
  final String name;
  const _CurrentPlaceBanner({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
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
      child: Row(
        children: [
          const Icon(Icons.place, color: EverloreTheme.gold, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'YOU ARE HERE',
                  style: TextStyle(
                    color: EverloreTheme.gold.withValues(alpha: 0.8),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  style: const TextStyle(
                    color: EverloreTheme.parchment,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  final LocationPlace place;
  final bool isCurrent;
  final VoidCallback onTap;

  const _PlaceCard({
    required this.place,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: EverloreTheme.void2,
              border: Border.all(
                color: isCurrent
                    ? EverloreTheme.goldDim.withValues(alpha: 0.5)
                    : EverloreTheme.white10,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isCurrent ? Icons.place : Icons.location_on_outlined,
                  color: isCurrent ? EverloreTheme.gold : EverloreTheme.ash,
                  size: 18,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        style: const TextStyle(
                          color: EverloreTheme.parchment,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _subtitle(place),
                        style: const TextStyle(
                          color: EverloreTheme.ash,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: EverloreTheme.ash, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _subtitle(LocationPlace p) {
    final parts = <String>[];
    if (p.eventCount > 0) {
      parts.add('${p.eventCount} ${p.eventCount == 1 ? "moment" : "moments"}');
    }
    if (p.memoryCount > 0) {
      parts.add('${p.memoryCount} ${p.memoryCount == 1 ? "echo" : "echoes"}');
    }
    return parts.isEmpty ? 'Visited' : parts.join(' · ');
  }
}
