import 'package:flutter/material.dart';
import '../../../../app/theme/nexus_theme.dart';
import '../../data/location_journal.dart';
import '../location_journal_screen.dart';

/// Location Atlas (P2): the world's places as a nested containment tree —
/// rooms under their building, buildings under their settlement, and so on up to
/// each world/realm root. Fog-of-war: only discovered places appear, and an
/// undiscovered container simply isn't there yet. The current place is surfaced
/// in a banner and its branch auto-expands. Tapping a place opens
/// "what happened here before?".
class PlacesView extends StatefulWidget {
  final String instanceId;
  final LocationsData data;

  const PlacesView({super.key, required this.instanceId, required this.data});

  @override
  State<PlacesView> createState() => _PlacesViewState();
}

class _PlacesViewState extends State<PlacesView> {
  /// Collapsed node ids. Nodes are expanded by default (small worlds); the user
  /// can fold a branch. The current place's branch is always shown.
  final Set<String> _collapsed = <String>{};

  late Map<String, List<LocationPlace>> _childrenByParent;
  late List<LocationPlace> _roots;

  @override
  void initState() {
    super.initState();
    _buildTree();
  }

  @override
  void didUpdateWidget(covariant PlacesView old) {
    super.didUpdateWidget(old);
    if (old.data != widget.data) _buildTree();
  }

  void _buildTree() {
    final places = widget.data.places;
    final byId = {for (final p in places) p.entityId: p};
    final children = <String, List<LocationPlace>>{};
    final roots = <LocationPlace>[];

    for (final p in places) {
      final parent = p.parentId;
      // A node whose parent is unknown OR points outside the known set is a root.
      if (parent != null && byId.containsKey(parent)) {
        children.putIfAbsent(parent, () => []).add(p);
      } else {
        roots.add(p);
      }
    }

    int byRecency(LocationPlace a, LocationPlace b) =>
        (b.lastSeenSequence ?? -1).compareTo(a.lastSeenSequence ?? -1);
    roots.sort(byRecency);
    for (final list in children.values) {
      list.sort(byRecency);
    }

    _childrenByParent = children;
    _roots = roots;
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.data.currentLocation;
    final currentId = current?.entityId;

    if (widget.data.places.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        children: [
          if (current != null) ...[
            _CurrentPlaceBanner(name: current.name),
            const SizedBox(height: 16),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Text(
              'No places recorded yet. As your journey takes you somewhere, '
              'each place will remember what happened there.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: EverloreTheme.ash, fontSize: 13, height: 1.5),
            ),
          ),
        ],
      );
    }

    final rows = <Widget>[];
    for (final root in _roots) {
      _emit(rows, root, 0, currentId);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      children: [
        if (current != null) ...[
          _CurrentPlaceBanner(name: current.name),
          const SizedBox(height: 16),
        ],
        ...rows,
      ],
    );
  }

  /// Depth-first emit of a node and (when expanded) its descendants.
  void _emit(List<Widget> out, LocationPlace node, int depth, String? currentId) {
    final kids = _childrenByParent[node.entityId] ?? const [];
    final hasKids = kids.isNotEmpty;
    // Expanded by default; any parent can be folded. The current place stays
    // reachable via the "YOU ARE HERE" banner even when its container is folded.
    final expanded = hasKids && !_collapsed.contains(node.entityId);

    out.add(_PlaceTreeRow(
      place: node,
      depth: depth,
      isCurrent: node.entityId == currentId,
      hasChildren: hasKids,
      expanded: expanded,
      onToggle: hasKids
          ? () => setState(() {
                if (!_collapsed.add(node.entityId)) _collapsed.remove(node.entityId);
              })
          : null,
      onOpen: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LocationJournalScreen(
              instanceId: widget.instanceId,
              placeName: node.name,
              locationEntityId: node.entityId,
            ),
          ),
        );
      },
    ));

    if (expanded) {
      for (final child in kids) {
        _emit(out, child, depth + 1, currentId);
      }
    }
  }
}

/// One node in the atlas tree: indentation by depth, a fold caret when it has
/// children, a place-kind glyph, name, and a moments/echoes subtitle.
class _PlaceTreeRow extends StatelessWidget {
  final LocationPlace place;
  final int depth;
  final bool isCurrent;
  final bool hasChildren;
  final bool expanded;
  final VoidCallback? onToggle;
  final VoidCallback onOpen;

  const _PlaceTreeRow({
    required this.place,
    required this.depth,
    required this.isCurrent,
    required this.hasChildren,
    required this.expanded,
    required this.onToggle,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8, left: (depth * 18).toDouble()),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: isCurrent
                  ? EverloreTheme.gold.withValues(alpha: 0.08)
                  : EverloreTheme.void2,
              border: Border.all(
                color: isCurrent
                    ? EverloreTheme.goldDim.withValues(alpha: 0.5)
                    : EverloreTheme.white10,
              ),
            ),
            child: Row(
              children: [
                // Fold caret (or a spacer to keep glyphs aligned).
                SizedBox(
                  width: 24,
                  child: hasChildren
                      ? InkWell(
                          onTap: onToggle,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Icon(
                              expanded ? Icons.expand_more : Icons.chevron_right,
                              color: isCurrent ? EverloreTheme.gold : EverloreTheme.ash,
                              size: 20,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                Icon(
                  _kindIcon(place.placeKind, isCurrent),
                  color: isCurrent ? EverloreTheme.gold : EverloreTheme.ash,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        style: TextStyle(
                          color: EverloreTheme.parchment,
                          fontSize: 15,
                          fontWeight:
                              isCurrent ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _subtitle(place),
                        style: const TextStyle(
                            color: EverloreTheme.ash, fontSize: 12),
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

  static IconData _kindIcon(String? kind, bool isCurrent) {
    switch (kind) {
      case 'world':
        return Icons.public;
      case 'region':
        return Icons.map_outlined;
      case 'settlement':
        return Icons.location_city_outlined;
      case 'building':
        return Icons.account_balance_outlined;
      case 'area':
        return Icons.park_outlined;
      case 'room':
        return Icons.meeting_room_outlined;
      default:
        return isCurrent ? Icons.place : Icons.location_on_outlined;
    }
  }

  static String _subtitle(LocationPlace p) {
    final parts = <String>[];
    if (p.placeKind != null && p.placeKind!.isNotEmpty) {
      parts.add(p.placeKind![0].toUpperCase() + p.placeKind!.substring(1));
    }
    if (p.eventCount > 0) {
      parts.add('${p.eventCount} ${p.eventCount == 1 ? "moment" : "moments"}');
    }
    if (p.memoryCount > 0) {
      parts.add('${p.memoryCount} ${p.memoryCount == 1 ? "echo" : "echoes"}');
    }
    return parts.isEmpty ? 'Not yet visited' : parts.join(' · ');
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
