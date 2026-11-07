import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/layout/responsive.dart';
import '../app/theme/nexus_theme.dart';
import '../core/auth/auth_service.dart';
import '../core/errors/user_message.dart';
import '../core/guide/guide_anchor.dart';
import '../core/telemetry/telemetry.dart';
import '../core/telemetry/telemetry_vocabulary.dart';
import '../core/guide/guide_flows.dart';
import '../core/guide/guide_ids.dart';
import '../core/guide/guide_trigger.dart';
import '../features/group_chat/data/group_chat_repository.dart';
import '../features/group_chat/presentation/widgets/group_cover_card.dart';
import '../features/home/presentation/widgets/continue_story_card.dart';
import '../features/moderation/data/moderation_repository.dart';
import '../features/templates/data/genre_repository.dart';
import '../features/templates/data/interest_ranking.dart';
import '../features/templates/data/template_repository.dart';
import '../features/templates/presentation/explore_filter_sheet.dart';
import '../shared/app_icons.dart';
import '../shared/models/explore_genre.dart';
import '../shared/models/world_template.dart';
import '../shared/narrative_styles.dart';
import '../shared/widgets/everlore_empty_state.dart';
import '../shared/widgets/everlore_network_image.dart';
import '../shared/widgets/everlore_session_loader.dart';
import '../shared/widgets/everlore_top_bar.dart';
import '../shared/widgets/mature_content_chip.dart';
import '../shared/widgets/neu.dart';
import '../shared/widgets/realm_backdrop.dart';

/// The default landing after auth — an art-led, interest-ranked explore feed.
/// Two-column masonry of forged cards, champagne pill tabs, and the primary
/// bottom nav. Realms / creator / profile are reachable from the nav, not here.
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  int _tab = 0;
  List<ExploreGenre> _genres = [];
  final Map<int, ExploreFilterState> _filtersByTab = {};

  List<WorldTemplate> _templates = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _page = 1;
  int _total = 0;
  int _loadToken = 0;
  int _loadMoreToken = 0;
  // A tab swap keeps the old cards on screen, so a scroll during it must not
  // page the new query from the old page number.
  bool _loadInFlight = false;
  String? _error;
  final _scrollController = ScrollController();
  final _tabScrollController = ScrollController();
  final _searchController = TextEditingController();
  final _continueCardKey = GlobalKey<ContinueStoryCardState>();
  final Map<int, GlobalKey> _tabKeys = {};
  Timer? _searchDebounce;
  bool _searchOpen = false;
  List<WorldTemplate> _groupTemplates = const [];

  /// Templates the player already has a save of; null while the saves can't be
  /// read, in which case the feed offers no group rather than maybe one they
  /// joined.
  Set<String>? _savedGroupTemplateIds;

  ExploreFilterState _filterForTab(int tab) =>
      _filtersByTab[tab] ?? const ExploreFilterState();

  ExploreFilterState get _currentFilter => _filterForTab(_tab);

  String? get _currentGenre =>
      _tab < 2 ? null : (_tab - 2 < _genres.length ? _genres[_tab - 2].key : null);

  Map<String, GenreStyleCount> _styleCountsForTab(int tab) {
    if (tab == 0 || tab == 1) {
      final combined = <String, GenreStyleCount>{};
      for (final genre in _genres) {
        for (final entry in genre.styles.entries) {
          final existing = combined[entry.key];
          if (existing == null) {
            combined[entry.key] = entry.value;
          } else {
            combined[entry.key] = GenreStyleCount(
              worlds: existing.worlds + entry.value.worlds,
              characters: existing.characters + entry.value.characters,
            );
          }
        }
      }
      return combined;
    }
    if (tab - 2 < _genres.length) {
      return _genres[tab - 2].styles;
    }
    return const {};
  }

  Set<String> _availableStylesForTab(int tab, {String? kind}) {
    final counts = _styleCountsForTab(tab);
    final result = <String>{};
    for (final entry in counts.entries) {
      if (entry.value.countForKind(kind) > 0) {
        result.add(entry.key);
      }
    }
    return result;
  }

  @override
  void initState() {
    super.initState();
    // Blocking happens on other screens (a world's page, the blocked-content
    // list). This tab survives in an IndexedStack, so it has to be told.
    ModerationRepository.revision.addListener(_onBlocksChanged);
    AuthService.sessionEpoch.addListener(_onSessionChanged);
    _scrollController.addListener(_maybeLoadMore);
    _initData();
  }

  @override
  void dispose() {
    ModerationRepository.revision.removeListener(_onBlocksChanged);
    AuthService.sessionEpoch.removeListener(_onSessionChanged);
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _tabScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSessionChanged() {
    if (mounted) {
      _filtersByTab.clear();
      _refreshAll();
    }
  }

  Future<void> _initData() async {
    await _loadGenres();
    await Future.wait([
      _load(),
      _loadGroupData(),
    ]);
  }

  Future<void> _refreshAll() async {
    _continueCardKey.currentState?.refresh(forceRefresh: true);
    await Future.wait([
      _loadGenres(forceRefresh: true),
      _load(forceRefresh: true),
      _loadGroupData(forceRefresh: true),
    ]);
  }

  Future<void> _loadGroupData({bool forceRefresh = false}) async {
    try {
      final result = await TemplateRepository.listPublished(
        kind: 'group',
        limit: 50,
        forceRefresh: forceRefresh,
      );
      final templates = [
        for (final t in result['templates'] as List? ?? const [])
          if (t is WorldTemplate) t,
      ];
      Set<String>? savedIds;
      try {
        final chats = await const HttpGroupChatRepository().chats();
        savedIds = {for (final c in chats) c.templateId};
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _groupTemplates = templates;
        _savedGroupTemplateIds = savedIds;
      });
    } catch (_) {}
  }

  Future<void> _loadGenres({bool forceRefresh = false}) async {
    try {
      final genres = await GenreRepository.list(forceRefresh: forceRefresh);
      if (!mounted) return;
      setState(() {
        _genres = genres.where((g) => g.hasContent).toList();
        if (_tab > 1 + _genres.length) {
          _tab = 0;
        }
      });
    } catch (_) {
      // Keep working with For You
    }
  }

  Future<void> _load({bool forceRefresh = false, String? search}) async {
    final token = ++_loadToken;
    _loadInFlight = true;
    setState(() {
      // Preserve the visible feed while an inline search or tab swap is resolving.
      // The initial load still uses the full-screen loader.
      _isLoading = _templates.isEmpty;
      _isLoadingMore = false;
      _error = null;
    });
    final filter = _currentFilter;
    final genre = _currentGenre;
    try {
      final result = await TemplateRepository.listPublished(
        page: 1,
        limit: 20,
        search: search ?? _searchController.text.trim(),
        genre: genre,
        kind: filter.kind,
        styles: filter.styles.isEmpty ? null : filter.styles,
        sort: filter.sort,
        forceRefresh: forceRefresh,
      );
      if (!mounted || token != _loadToken) return;
      final ranked = await orderTemplatesForFeed(
        List<WorldTemplate>.from(result['templates']),
      );
      if (!mounted || token != _loadToken) return;
      setState(() {
        _templates = ranked;
        _page = 1;
        _total = (result['total'] as num?)?.toInt() ?? ranked.length;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || token != _loadToken) return;
      setState(() {
        _isLoading = false;
        _error = userFacingError(e, fallback: 'Could not load worlds.');
      });
    } finally {
      if (token == _loadToken) _loadInFlight = false;
    }
  }

  void _maybeLoadMore() {
    if (!_scrollController.hasClients ||
        _scrollController.position.extentAfter > 520) {
      return;
    }
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_isLoading || _loadInFlight || _isLoadingMore || _templates.length >= _total) return;
    setState(() => _isLoadingMore = true);
    final loadTokenAtStart = _loadToken;
    final moreToken = ++_loadMoreToken;
    final filter = _currentFilter;
    final genre = _currentGenre;
    try {
      final result = await TemplateRepository.listPublished(
        page: _page + 1,
        limit: 20,
        search: _searchController.text.trim(),
        genre: genre,
        kind: filter.kind,
        styles: filter.styles.isEmpty ? null : filter.styles,
        sort: filter.sort,
      );
      if (!mounted || _loadToken != loadTokenAtStart || moreToken != _loadMoreToken) return;
      final next = await orderTemplatesForFeed(
        List<WorldTemplate>.from(result['templates']),
      );
      if (!mounted || _loadToken != loadTokenAtStart || moreToken != _loadMoreToken) return;
      final known = _templates.map((t) => t.id).toSet();
      setState(() {
        _templates = [..._templates, ...next.where((t) => known.add(t.id))];
        _page += 1;
        _total = (result['total'] as num?)?.toInt() ?? _templates.length;
      });
    } finally {
      if (mounted && _loadToken == loadTokenAtStart && moreToken == _loadMoreToken) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  void _onBlocksChanged() {
    if (mounted) setState(() {});
  }

  void _selectTab(int i) {
    if (_tab == i) return;
    final existingFilter = _filterForTab(i);
    final available = _availableStylesForTab(i, kind: existingFilter.kind);
    final cleaned = existingFilter.cleanForAvailableStyles(available);
    setState(() {
      _tab = i;
      _filtersByTab[i] = cleaned;
    });
    _trackFiltered();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _tabKeys[i];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(
          key!.currentContext!,
          alignment: 0.5,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
    });
    if (i == 1) {
      if (_groupTemplates.isEmpty) _loadGroupData();
    } else {
      _load();
    }
  }

  /// Genre tab or filter applied. The label is the server's own genre name,
  /// never anything the player typed; the "All" tab has none.
  void _trackFiltered() {
    final label = _tab > 1 && _tab - 2 < _genres.length
        ? _genres[_tab - 2].label
        : null;
    Telemetry.instance.track('explore_filtered', {
      if (isGenreLabel(label)) 'genre': label,
    });
  }

  Future<void> _openFilterSheet() async {
    Telemetry.instance.track('sheet_opened', {'sheet': 'filters'});
    final current = _currentFilter;
    final availableCounts = _styleCountsForTab(_tab);
    final next = await showExploreFilterSheet(
      context: context,
      currentFilter: current,
      availableStyles: availableCounts,
    );
    if (next != null && next != current) {
      setState(() {
        _filtersByTab[_tab] = next;
      });
      _trackFiltered();
      _load();
    }
  }

  void _clearCurrentTabFilters() {
    setState(() {
      _filtersByTab[_tab] = const ExploreFilterState();
    });
    _load();
  }

  void _clearFiltersAndSearch() {
    setState(() {
      _filtersByTab[_tab] = const ExploreFilterState();
      _searchController.clear();
      _searchOpen = false;
    });
    if (_tab == 1) {
      _loadGroupData();
    } else {
      _load(search: '');
    }
  }

  List<WorldTemplate> get _visible {
    // A world the player just blocked has to leave the list they are looking
    // at, not on the next fetch. The server filters too; this is the immediate
    // half of the same rule.
    final unblocked = _templates
        .where(
          (t) => !ModerationRepository.isHidden(
            worldId: t.id,
            creatorId: t.creatorId,
          ),
        )
        .toList();

    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return unblocked;
    return unblocked
        .where(
          (template) =>
              template.title.toLowerCase().contains(query) ||
              template.description.toLowerCase().contains(query) ||
              template.sceneTags.any(
                (tag) => tag.toLowerCase().contains(query),
              ),
        )
        .toList();
  }

  void _toggleSearch() {
    setState(() => _searchOpen = !_searchOpen);
    if (!_searchOpen && _searchController.text.isNotEmpty) {
      _searchDebounce?.cancel();
      _searchController.clear();
      if (_tab == 1) {
        setState(() {});
      } else {
        _load(search: '');
      }
    }
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 280),
      () {
        if (_tab == 1) {
          if (mounted) setState(() {});
        } else {
          _load(search: value.trim());
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EverloreTheme.void0,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/art/explore-vista.webp',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
          const EmberOverlay(),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  EverloreTheme.void0.withValues(alpha: 0.2),
                  EverloreTheme.void0.withValues(alpha: 0.54),
                  EverloreTheme.void0.withValues(alpha: 0.8),
                ],
                stops: const [0, 0.42, 1],
              ),
            ),
          ),
          GuideOnEnter(
            // The arrival arc waits for the shelves to fill — pointing at an
            // empty grid would explain nothing.
            flow: GuideFlows.arrival,
            enabled: _templates.isNotEmpty,
            child: GuideOnEnter(
              flow: GuideFlows.exploreGenres,
              enabled: _templates.isNotEmpty,
              child: Column(
                children: [
                  EverloreTopBar(
                    title: 'Explore',
                    subtitle: 'Find worlds and characters',
                    backgroundOpacity: 0.68,
                    showNotifications: true,
                    actions: [
                      GuideAnchor(
                        id: GuideIds.discoverSearch,
                        child: EverloreTopBarIcon(
                          icon: _searchOpen
                              ? Icons.close_rounded
                              : Icons.search_rounded,
                          tooltip: _searchOpen
                              ? 'Close search'
                              : 'Search Explore',
                          onTap: _toggleSearch,
                        ),
                      ),
                    ],
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    child: _searchOpen
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
                            child: TextField(
                              controller: _searchController,
                              autofocus: true,
                              onChanged: _onSearchChanged,
                              textInputAction: TextInputAction.search,
                              style: EverloreTheme.ui(
                                size: 14,
                                color: EverloreTheme.parchment,
                              ),
                              decoration: _exploreSearchDecoration(),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  ContinueStoryCard(key: _continueCardKey),
                  const SizedBox(height: 14),
                  _buildTabs(),
                  if (_currentFilter.hasActiveFilter) ...[
                    const SizedBox(height: 8),
                    _buildFilterSummaryLine(),
                  ],
                  const SizedBox(height: 4),
                  Expanded(child: _buildBody()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSummaryLine() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _currentFilter.buildSummary(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: EverloreTheme.ui(
                size: 12,
                color: EverloreTheme.ash,
                weight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _clearCurrentTabFilters,
            behavior: HitTestBehavior.opaque,
            child: Text(
              'Clear',
              style: EverloreTheme.ui(
                size: 12,
                color: EverloreTheme.gold,
                weight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    // The pill row is a fixed strip, so it has to grow with the player's text
    // size or the labels are trimmed top and bottom.
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final totalTabs = 2 + _genres.length;
    final pillHeight = 44 * textScale.clamp(1.0, 1.4);

    return SizedBox(
      height: pillHeight,
      child: Row(
        children: [
          Expanded(
            child: GuideAnchor(
              id: GuideIds.discoverTabs,
              child: ShaderMask(
                shaderCallback: (rect) {
                  const fadeWidth = 24.0;
                  final fadeStart = (rect.width - fadeWidth).clamp(0.0, rect.width) /
                      (rect.width == 0 ? 1 : rect.width);
                  return LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: const [
                      Colors.white,
                      Colors.white,
                      Colors.transparent,
                    ],
                    stops: [0.0, fadeStart, 1.0],
                  ).createShader(rect);
                },
                blendMode: BlendMode.dstIn,
                child: ListView.separated(
                  controller: _tabScrollController,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 20, right: 24),
                  itemCount: totalTabs,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final label = i == 0
                        ? 'For You'
                        : (i == 1 ? 'Group chats' : _genres[i - 2].label);
                    final key = _tabKeys.putIfAbsent(i, GlobalKey.new);
                    return _tabPill(i, label, key);
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: GuideAnchor(
              id: GuideIds.discoverFilter,
              child: _buildFilterButton(pillHeight),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(double size) {
    return Tooltip(
      message: 'Filter Explore',
      child: GestureDetector(
        onTap: _openFilterSheet,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [EverloreTheme.void3, EverloreTheme.void1],
                ),
                border: Border.all(
                  color: EverloreTheme.goldDim.withValues(alpha: 0.25),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(1, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.tune_rounded,
                color: EverloreTheme.gold,
                size: 20,
              ),
            ),
            if (_currentFilter.hasActiveFilter)
              Positioned(
                top: 2,
                right: 2,
                child: IgnorePointer(
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: EverloreTheme.gold,
                      boxShadow: [
                        BoxShadow(
                          color: EverloreTheme.goldGlow,
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tabPill(int i, String label, Key key) {
    final active = _tab == i;
    return GestureDetector(
      key: key,
      onTap: () => _selectTab(i),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: active
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [EverloreTheme.goldGlow, EverloreTheme.gold],
                )
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [EverloreTheme.void3, EverloreTheme.void2],
                ),
          border: Border.all(
            color: active
                ? EverloreTheme.goldHot.withValues(alpha: 0.5)
                : EverloreTheme.goldDim.withValues(alpha: 0.2),
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: EverloreTheme.gold.withValues(alpha: 0.25),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: EverloreTheme.uiFamily,
            color: active ? EverloreTheme.void0 : EverloreTheme.ash,
            fontSize: 13.5,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_tab == 1) {
      if (_isLoading && _groupTemplates.isEmpty) {
        return const Center(
          child: EverloreSessionLoader(message: 'Discovering group chats'),
        );
      }
      final query = _searchController.text.trim().toLowerCase();
      final visibleGroups = query.isEmpty
          ? _groupTemplates
          : _groupTemplates
              .where((t) =>
                  t.title.toLowerCase().contains(query) ||
                  t.description.toLowerCase().contains(query))
              .toList();

      if (visibleGroups.isEmpty) {
        final hasSearch = _searchController.text.trim().isNotEmpty;
        return EverloreEmptyState(
          icon: hasSearch ? Icons.filter_alt_off_rounded : Icons.forum_outlined,
          eyebrow: 'GATHERING',
          title: hasSearch ? 'No matches found' : 'No group chats in view',
          message: hasSearch
              ? 'Try adjusting your search terms to uncover more group chats.'
              : 'New group chats are always being forged. Check back soon.',
          actionLabel: hasSearch ? 'Clear search' : null,
          actionIcon: hasSearch ? Icons.tune_rounded : null,
          accent: EverloreTheme.gold,
          onAction: hasSearch
              ? () {
                  setState(() {
                    _searchController.clear();
                    _searchOpen = false;
                  });
                }
              : null,
        );
      }

      final columnCount = switch (EvLayout.of(context).widthClass) {
        EvWidthClass.compact => 2,
        EvWidthClass.regular => 2,
        EvWidthClass.expanded => 3,
      };

      return RefreshIndicator(
        color: EverloreTheme.gold,
        backgroundColor: EverloreTheme.void2,
        onRefresh: _refreshAll,
        child: GridView.builder(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columnCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 132 / 198,
          ),
          itemCount: visibleGroups.length,
          itemBuilder: (context, index) => GroupCoverCard(
            template: visibleGroups[index],
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Center(
        child: EverloreSessionLoader(message: 'Discovering realms'),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const EvIcon(AppIcons.errorRune, size: 110),
              const SizedBox(height: 14),
              Text(
                'Could not reach the realm',
                style: EverloreTheme.ui(
                  size: 15,
                  color: EverloreTheme.parchment,
                  weight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: EverloreTheme.ui(size: 12, color: EverloreTheme.ash),
              ),
              const SizedBox(height: 18),
              NeuButton(label: 'Try Again', onTap: _load),
            ],
          ),
        ),
      );
    }

    final visible = _visible;
    if (visible.isEmpty) {
      final hasFiltersOrSearch =
          _currentFilter.hasActiveFilter || _searchController.text.trim().isNotEmpty;
      return EverloreEmptyState(
        icon: hasFiltersOrSearch
            ? Icons.filter_alt_off_rounded
            : Icons.explore_outlined,
        eyebrow: 'ARCHIVE',
        title: hasFiltersOrSearch ? 'No matches found' : 'No worlds in view',
        message: hasFiltersOrSearch
            ? 'Try adjusting your filters or search terms to uncover more realms.'
            : 'Try another shelf or return soon—new realms are always being forged.',
        actionLabel: hasFiltersOrSearch
            ? 'Clear filters'
            : (_tab != 0 ? 'Show everything' : null),
        actionIcon: hasFiltersOrSearch
            ? Icons.tune_rounded
            : (_tab != 0 ? Icons.auto_awesome_rounded : null),
        accent: EverloreTheme.gold,
        onAction: hasFiltersOrSearch
            ? _clearFiltersAndSearch
            : (_tab != 0 ? () => _selectTab(0) : null),
      );
    }

    // Masonry, with as many columns as the width can carry. Two was hard
    // coded, so on a tablet the same two columns simply grew until a cover
    // filled half the screen and only four worlds were browsable at once.
    final columnCount = switch (EvLayout.of(context).widthClass) {
      EvWidthClass.compact => 2,
      EvWidthClass.regular => 2,
      EvWidthClass.expanded => 3,
    };
    final columns = List.generate(columnCount, (_) => <Widget>[]);

    WorldTemplate? inFeedGroup;
    final saved = _savedGroupTemplateIds;
    if (saved != null && _tab == 0 && _searchController.text.trim().isEmpty) {
      for (final t in _groupTemplates) {
        if (!saved.contains(t.id)) {
          inFeedGroup = t;
          break;
        }
      }
    }

    final items = <Widget>[];
    for (var i = 0; i < visible.length; i++) {
      if (inFeedGroup != null && i == 4) {
        items.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GroupCoverCard(template: inFeedGroup),
          ),
        );
      }
      final t = visible[i];
      final isAnchor = i == 0;
      items.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: guideAnchorIf(
            isAnchor,
            GuideIds.discoverCard,
            _DiscoverCard(
              template: t,
              onTap: () => context.push('/templates/${t.id}'),
            ),
          ),
        ),
      );
    }
    if (inFeedGroup != null && visible.length <= 4) {
      items.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GroupCoverCard(template: inFeedGroup),
        ),
      );
    }
    for (var i = 0; i < items.length; i++) {
      columns[i % columnCount].add(items[i]);
    }

    return RefreshIndicator(
      color: EverloreTheme.gold,
      backgroundColor: EverloreTheme.void2,
      onRefresh: _refreshAll,
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          16,
          8,
          16,
          110,
        ), // clear floating nav
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (index, column) in columns.indexed) ...[
                  if (index > 0) const SizedBox(width: 12),
                  Expanded(child: Column(children: column)),
                ],
              ],
            ),
            if (_isLoadingMore)
              const Padding(
                padding: EdgeInsets.only(top: 8, bottom: 10),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    color: EverloreTheme.gold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

InputDecoration _exploreSearchDecoration() => InputDecoration(
  hintText: 'Search worlds and characters',
  hintStyle: EverloreTheme.ui(size: 14, color: EverloreTheme.ash),
  prefixIcon: const Icon(Icons.search_rounded, color: EverloreTheme.goldDim),
  filled: true,
  fillColor: EverloreTheme.void2.withValues(alpha: 0.72),
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(
      color: EverloreTheme.goldDim.withValues(alpha: 0.22),
    ),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(
      color: EverloreTheme.goldDim.withValues(alpha: 0.22),
    ),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: EverloreTheme.gold, width: 1.2),
  ),
);

/// A forged, art-led world card: cover image with a champagne-rimmed extrusion,
/// title + blurb + a genre chip. Dark neumorphism — raised off the void.
class _DiscoverCard extends StatelessWidget {
  final WorldTemplate template;
  final VoidCallback onTap;
  const _DiscoverCard({required this.template, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final genre = template.narrativeStyle.isNotEmpty
        ? narrativeStyleLabel(template.narrativeStyle)
        : (template.isCharacter
              ? 'Character'
              : template.isSentient
              ? 'Led by a soul'
              : 'World');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: EverloreTheme.void2,
          border: Border.all(
            color: EverloreTheme.goldDim.withValues(alpha: 0.18),
          ),
          boxShadow: [
            // deep bottom-right shadow + faint top-left light = raised bevel.
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 14,
              offset: const Offset(3, 5),
            ),
            BoxShadow(
              color: EverloreTheme.gold.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(-3, -4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(aspectRatio: 4 / 5, child: _cover()),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: EverloreTheme.parchment,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  if (template.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      template.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: EverloreTheme.uiFamily,
                        color: EverloreTheme.ash,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _genreChip(genre),
                      if (template.isNsfwCapable) const MatureContentChip(),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _genreChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: EverloreTheme.gold.withValues(alpha: 0.10),
        border: Border.all(color: EverloreTheme.gold.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          EvIcon(AppIcons.familyForStyle(template.narrativeStyle), size: 16),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: EverloreTheme.uiFamily,
                color: EverloreTheme.goldGlow,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cover() {
    if (template.imageUrl.isNotEmpty) {
      return EverloreNetworkImage(
        imageUrl: template.imageUrl,
        fit: BoxFit.cover,
        memCacheWidth: 720,
        errorWidget: _coverFallback(),
        semanticLabel: template.title,
      );
    }
    return _coverFallback();
  }

  Widget _coverFallback() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.2, -0.3),
          radius: 1.1,
          colors: [EverloreTheme.void3, EverloreTheme.void0],
        ),
      ),
      child: Center(
        child: EvIcon(
          template.isCharacter ? AppIcons.navProfile : AppIcons.chronicle,
          size: 40,
        ),
      ),
    );
  }
}
