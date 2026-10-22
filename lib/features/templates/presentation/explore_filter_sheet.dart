import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/nexus_theme.dart';
import '../../../shared/models/explore_genre.dart';
import '../../../shared/narrative_styles.dart';
import '../../../shared/widgets/everlore_sheet.dart';

/// State of Explore filters for one tab.
@immutable
class ExploreFilterState {
  /// 'world' | 'character' | null (all)
  final String? kind;

  /// Selected voice/style keys.
  final Set<String> styles;

  /// 'foryou' | 'new'
  final String sort;

  const ExploreFilterState({
    this.kind,
    this.styles = const {},
    this.sort = 'foryou',
  });

  bool get isDefault =>
      (kind == null || kind == 'all') &&
      styles.isEmpty &&
      (sort == 'foryou' || sort.isEmpty);

  bool get hasActiveFilter => !isDefault;

  ExploreFilterState copyWith({
    String? kind,
    bool clearKind = false,
    Set<String>? styles,
    String? sort,
  }) {
    return ExploreFilterState(
      kind: clearKind ? null : (kind ?? this.kind),
      styles: styles ?? this.styles,
      sort: sort ?? this.sort,
    );
  }

  /// Retains only styles that exist in [availableStyles].
  ExploreFilterState cleanForAvailableStyles(Set<String> availableStyles) {
    final retained = styles.where(availableStyles.contains).toSet();
    if (retained.length == styles.length) return this;
    return copyWith(styles: retained);
  }

  /// Retains only styles that have a non-zero count for [kind] (or this state's kind).
  ExploreFilterState cleanForAvailableStyleCounts(
    Map<String, GenreStyleCount> availableStyleCounts, {
    String? kind,
  }) {
    final effectiveKind = kind ?? this.kind;
    final available = availableStyleCounts.entries
        .where((e) => e.value.countForKind(effectiveKind) > 0)
        .map((e) => e.key)
        .toSet();
    return cleanForAvailableStyles(available);
  }

  /// Descriptive label for the thin summary line under Explore tabs,
  /// e.g. "Characters · 2 interests", "Worlds · Tsundere", "Worlds · Newest".
  String buildSummary() {
    final parts = <String>[];
    if (kind == 'world') {
      parts.add('Worlds');
    } else if (kind == 'character') {
      parts.add('Characters');
    }
    if (styles.isNotEmpty) {
      if (styles.length == 1) {
        final key = styles.first;
        final label = narrativeStyleLabel(key);
        parts.add(label != 'Default' ? label : key);
      } else {
        parts.add('${styles.length} interests');
      }
    }
    if (sort == 'new') {
      parts.add('Newest');
    }
    return parts.join(' · ');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExploreFilterState &&
          runtimeType == other.runtimeType &&
          kind == other.kind &&
          setEquals(styles, other.styles) &&
          sort == other.sort;

  @override
  int get hashCode =>
      Object.hash(kind, Object.hashAllUnordered(styles), sort);
}

/// Presents the explore filter sheet on the root navigator.
Future<ExploreFilterState?> showExploreFilterSheet({
  required BuildContext context,
  required ExploreFilterState currentFilter,
  required Map<String, GenreStyleCount> availableStyles,
}) {
  return showEverloreSheet<ExploreFilterState>(
    context: context,
    builder: (_) => ExploreFilterSheet(
      initialFilter: currentFilter,
      availableStyles: availableStyles,
    ),
  );
}

class ExploreFilterSheet extends StatefulWidget {
  final ExploreFilterState initialFilter;
  final Map<String, GenreStyleCount> availableStyles;

  const ExploreFilterSheet({
    super.key,
    required this.initialFilter,
    required this.availableStyles,
  });

  @override
  State<ExploreFilterSheet> createState() => _ExploreFilterSheetState();
}

class _ExploreFilterSheetState extends State<ExploreFilterSheet> {
  late ExploreFilterState _state;

  @override
  void initState() {
    super.initState();
    final available = _availableStyleKeysForKind(widget.initialFilter.kind);
    _state = widget.initialFilter.cleanForAvailableStyles(available);
  }

  Set<String> _availableStyleKeysForKind(String? kind) {
    final result = <String>{};
    for (final entry in widget.availableStyles.entries) {
      if (entry.value.countForKind(kind) > 0) {
        result.add(entry.key);
      }
    }
    return result;
  }

  /// Filters out unknown styles from the server, keeping only known ones
  /// from `narrative_styles.dart` with a non-zero count for [kind].
  List<NarrativeStyle> _displayableStylesForKind(String? kind) {
    final available = _availableStyleKeysForKind(kind);
    final known = <NarrativeStyle>[];
    for (final key in available) {
      if (key.isEmpty) continue;
      for (final style in kNarrativeStyles) {
        if (style.key == key) {
          known.add(style);
          break;
        }
      }
    }
    return known;
  }

  void _onKindChanged(String? newKind) {
    if (_state.kind == newKind) return;
    final availableKeys = _availableStyleKeysForKind(newKind);
    final nextState = _state
        .copyWith(kind: newKind, clearKind: newKind == null)
        .cleanForAvailableStyles(availableKeys);
    setState(() {
      _state = nextState;
    });
  }

  @override
  Widget build(BuildContext context) {
    final displayableStyles = _displayableStylesForKind(_state.kind);

    return SheetFrame(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      footer: _buildFooter(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          const SizedBox(height: 18),
          _buildShowSection(),
          if (displayableStyles.isNotEmpty) ...[
            const SizedBox(height: 22),
            _buildInterestsSection(displayableStyles),
          ],
          const SizedBox(height: 22),
          _buildSortSection(),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Filters',
            style: EverloreTheme.screenTitle,
          ),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(
            Icons.close_rounded,
            color: EverloreTheme.ash,
            size: 20,
          ),
          tooltip: 'Close',
        ),
      ],
    );
  }

  Widget _buildShowSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SHOW', style: EverloreTheme.sectionHeader),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _choicePill(
                label: 'All',
                selected: _state.kind == null || _state.kind == 'all',
                onTap: () => _onKindChanged(null),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _choicePill(
                label: 'Worlds',
                selected: _state.kind == 'world',
                onTap: () => _onKindChanged('world'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _choicePill(
                label: 'Characters',
                selected: _state.kind == 'character',
                onTap: () => _onKindChanged('character'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInterestsSection(List<NarrativeStyle> styles) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('INTERESTS', style: EverloreTheme.sectionHeader),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final style in styles)
              _interestChip(
                label: style.label,
                selected: _state.styles.contains(style.key),
                onTap: () {
                  final next = Set<String>.from(_state.styles);
                  if (next.contains(style.key)) {
                    next.remove(style.key);
                  } else {
                    next.add(style.key);
                  }
                  setState(() => _state = _state.copyWith(styles: next));
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSortSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SORT', style: EverloreTheme.sectionHeader),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _choicePill(
                label: 'For You',
                selected: _state.sort == 'foryou' || _state.sort.isEmpty,
                onTap: () => setState(() => _state = _state.copyWith(sort: 'foryou')),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _choicePill(
                label: 'Newest',
                selected: _state.sort == 'new',
                onTap: () => setState(() => _state = _state.copyWith(sort: 'new')),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _choicePill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? EverloreTheme.gold.withValues(alpha: 0.12)
              : EverloreTheme.void3,
          border: Border.all(
            color: selected
                ? EverloreTheme.gold
                : EverloreTheme.goldDim.withValues(alpha: 0.2),
            width: selected ? 1.2 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: EverloreTheme.ui(
            size: 13,
            color: selected ? EverloreTheme.goldGlow : EverloreTheme.ash,
            weight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _interestChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: selected
              ? EverloreTheme.gold.withValues(alpha: 0.14)
              : EverloreTheme.void3,
          border: Border.all(
            color: selected
                ? EverloreTheme.gold
                : EverloreTheme.goldDim.withValues(alpha: 0.22),
            width: selected ? 1.2 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: EverloreTheme.ui(
            size: 12.5,
            color: selected ? EverloreTheme.goldGlow : EverloreTheme.ash,
            weight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: _state.isDefault
                ? null
                : () => setState(() => _state = const ExploreFilterState()),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Clear',
              style: EverloreTheme.ui(
                size: 14,
                color: _state.isDefault ? EverloreTheme.ash : EverloreTheme.parchment,
                weight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(_state),
            style: ElevatedButton.styleFrom(
              backgroundColor: EverloreTheme.gold,
              foregroundColor: EverloreTheme.void0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              'Apply',
              style: EverloreTheme.ui(
                size: 14,
                color: EverloreTheme.void0,
                weight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
