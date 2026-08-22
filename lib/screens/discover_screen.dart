import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../app/theme/nexus_theme.dart';
import '../core/auth/auth_service.dart';
import '../shared/app_icons.dart';
import '../shared/models/world_template.dart';
import '../shared/narrative_styles.dart';
import '../shared/widgets/everlore_session_loader.dart';
import '../shared/widgets/everlore_network_image.dart';
import '../shared/widgets/everlore_empty_state.dart';
import '../shared/widgets/everlore_top_bar.dart';
import '../shared/widgets/mature_content_chip.dart';
import '../shared/widgets/neu.dart';
import '../shared/widgets/realm_backdrop.dart';
import '../features/templates/data/template_repository.dart';
import '../features/templates/data/interest_ranking.dart';

/// The default landing after auth — an art-led, interest-ranked explore feed.
/// Two-column masonry of forged cards, champagne pill tabs, and the primary
/// bottom nav. Realms / creator / profile are reachable from the nav, not here.
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  static const _tabs = ['For You', 'Worlds', 'Characters'];
  int _tab = 0;

  List<WorldTemplate> _templates = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _page = 1;
  int _total = 0;
  String? _error;
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _searchOpen = false;

  @override
  void initState() {
    super.initState();
    AuthService.sessionEpoch.addListener(_onSessionChanged);
    _scrollController.addListener(_maybeLoadMore);
    _load();
  }

  @override
  void dispose() {
    AuthService.sessionEpoch.removeListener(_onSessionChanged);
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSessionChanged() {
    if (mounted) _load();
  }

  Future<void> _load({bool forceRefresh = false, String? search}) async {
    setState(() {
      // Preserve the visible feed while an inline search is resolving. The
      // initial load still uses the full-screen loader.
      _isLoading = _templates.isEmpty;
      _error = null;
    });
    try {
      final result = await TemplateRepository.listPublished(
        page: 1,
        limit: 20,
        search: search ?? _searchController.text.trim(),
        forceRefresh: forceRefresh,
      );
      final ranked = await orderTemplatesForFeed(
        List<WorldTemplate>.from(result['templates']),
      );
      if (!mounted) return;
      setState(() {
        _templates = ranked;
        _page = 1;
        _total = (result['total'] as num?)?.toInt() ?? ranked.length;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
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
    if (_isLoading || _isLoadingMore || _templates.length >= _total) return;
    setState(() => _isLoadingMore = true);
    try {
      final result = await TemplateRepository.listPublished(
        page: _page + 1,
        limit: 20,
        search: _searchController.text.trim(),
      );
      final next = await orderTemplatesForFeed(
        List<WorldTemplate>.from(result['templates']),
      );
      if (!mounted) return;
      final known = _templates.map((t) => t.id).toSet();
      setState(() {
        _templates = [..._templates, ...next.where((t) => known.add(t.id))];
        _page += 1;
        _total = (result['total'] as num?)?.toInt() ?? _templates.length;
      });
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  List<WorldTemplate> get _visible {
    final List<WorldTemplate> byTab;
    switch (_tab) {
      case 1:
        byTab = _templates.where((t) => !t.isCharacter).toList();
        break;
      case 2:
        byTab = _templates.where((t) => t.isCharacter).toList();
        break;
      default:
        byTab = _templates;
    }
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return byTab;
    return byTab
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
      _load(search: '');
    }
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 280),
      () => _load(search: value.trim()),
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
          Column(
            children: [
              EverloreTopBar(
                title: 'Explore',
                subtitle: 'Find worlds and characters',
                backgroundOpacity: 0.68,
                actions: [
                  EverloreTopBarIcon(
                    icon: _searchOpen
                        ? Icons.close_rounded
                        : Icons.search_rounded,
                    tooltip: _searchOpen ? 'Close search' : 'Search Explore',
                    onTap: _toggleSearch,
                  ),
                  EverloreTopBarIcon(
                    icon: Icons.refresh_rounded,
                    tooltip: 'Refresh explore',
                    isLoading: _isLoading && _templates.isNotEmpty,
                    onTap: () => _load(forceRefresh: true),
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
              const SizedBox(height: 14),
              _buildTabs(),
              const SizedBox(height: 4),
              Expanded(child: _buildBody()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) => _tabPill(i, _tabs[i]),
      ),
    );
  }

  Widget _tabPill(int i, String label) {
    final active = _tab == i;
    return GestureDetector(
      onTap: () => setState(() => _tab = i),
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
      final isCharacters = _tab == 2;
      return EverloreEmptyState(
        icon: isCharacters
            ? Icons.person_search_rounded
            : Icons.explore_outlined,
        eyebrow: isCharacters ? 'CHARACTER SHELF' : 'WORLD SHELF',
        title: isCharacters ? 'No characters to meet yet' : 'No worlds in view',
        message: isCharacters
            ? 'New companions and characters will appear here as the collection grows.'
            : 'Try another shelf or return soon—new realms are always being forged.',
        actionLabel: isCharacters ? 'Browse worlds' : 'Show everything',
        actionIcon: isCharacters
            ? Icons.explore_rounded
            : Icons.auto_awesome_rounded,
        accent: isCharacters ? EverloreTheme.violetBright : EverloreTheme.gold,
        onAction: isCharacters
            ? () => setState(() => _tab = 0)
            : () => setState(() => _tab = 0),
      );
    }

    // Two-column masonry: distribute cards across columns by parity.
    final left = <WorldTemplate>[];
    final right = <WorldTemplate>[];
    for (var i = 0; i < visible.length; i++) {
      (i.isEven ? left : right).add(visible[i]);
    }

    return RefreshIndicator(
      color: EverloreTheme.gold,
      backgroundColor: EverloreTheme.void2,
      onRefresh: () => _load(forceRefresh: true),
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
                Expanded(child: _column(left)),
                const SizedBox(width: 12),
                Expanded(child: _column(right)),
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

  Widget _column(List<WorldTemplate> items) {
    return Column(
      children: [
        for (final t in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _DiscoverCard(
              template: t,
              onTap: () => context.push('/templates/${t.id}'),
            ),
          ),
      ],
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
              ? 'Sentient'
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
          Text(
            label,
            style: TextStyle(
              fontFamily: EverloreTheme.uiFamily,
              color: EverloreTheme.goldGlow,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
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
