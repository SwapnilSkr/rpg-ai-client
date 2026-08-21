import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/app_icons.dart';
import '../../../shared/models/world_template.dart';
import '../../../shared/narrative_styles.dart';
import '../data/template_repository.dart';
import '../data/interest_ranking.dart';
import '../../../../app/theme/nexus_theme.dart';
import '../../../../shared/widgets/everlore_session_loader.dart';
import '../../../../shared/widgets/everlore_network_image.dart';
import '../../../../shared/widgets/everlore_empty_state.dart';
import '../../../../shared/widgets/realm_backdrop.dart';
import '../../../../shared/widgets/mature_content_chip.dart';

class BrowseTemplatesScreen extends StatefulWidget {
  const BrowseTemplatesScreen({super.key});

  @override
  State<BrowseTemplatesScreen> createState() => _BrowseTemplatesScreenState();
}

class _BrowseTemplatesScreenState extends State<BrowseTemplatesScreen> {
  List<WorldTemplate> _templates = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _page = 1;
  int _total = 0;
  String? _error;
  String _kindFilter = 'all'; // 'all' | 'world' | 'character'
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  List<WorldTemplate> get _visible {
    if (_kindFilter == 'character') {
      return _templates.where((t) => t.isCharacter).toList();
    }
    if (_kindFilter == 'world') {
      return _templates.where((t) => !t.isCharacter).toList();
    }
    return _templates;
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybeLoadMore);
    _loadTemplates();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadTemplates({String? search}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await TemplateRepository.listPublished(
        page: 1,
        limit: 20,
        search: search,
      );
      final ranked = await orderTemplatesForFeed(
        List<WorldTemplate>.from(result['templates']),
      );
      setState(() {
        _templates = ranked;
        _page = 1;
        _total = (result['total'] as num?)?.toInt() ?? ranked.length;
        _isLoading = false;
      });
    } catch (e) {
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
      final ids = _templates.map((t) => t.id).toSet();
      setState(() {
        _templates = [..._templates, ...next.where((t) => ids.add(t.id))];
        _page += 1;
        _total = (result['total'] as num?)?.toInt() ?? _templates.length;
      });
    } catch (_) {
      // The existing list remains usable; the next scroll can retry.
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EverloreTheme.void1,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/characters/new'),
        backgroundColor: EverloreTheme.violet,
        icon: const Icon(
          Icons.person_add_alt_1,
          color: EverloreTheme.parchment,
          size: 18,
        ),
        label: Text(
          'Character',
          style: EverloreTheme.ui(
            size: 13,
            color: EverloreTheme.parchment,
            weight: FontWeight.w700,
          ),
        ),
      ),
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
                  EverloreTheme.void0.withValues(alpha: 0.22),
                  EverloreTheme.void0.withValues(alpha: 0.58),
                  EverloreTheme.void0.withValues(alpha: 0.84),
                ],
                stops: const [0, 0.42, 1],
              ),
            ),
          ),
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              _buildHeader(context),
              _buildSearchBar(),
              _buildSegments(),
              _buildContent(context),
              if (_isLoadingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 24),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          color: EverloreTheme.gold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  SliverToBoxAdapter _buildSegments() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
        child: Row(
          children: [
            _segChip('all', 'All'),
            const SizedBox(width: 8),
            _segChip('world', 'Worlds'),
            const SizedBox(width: 8),
            _segChip('character', 'Characters'),
          ],
        ),
      ),
    );
  }

  Widget _segChip(String value, String label) {
    final active = _kindFilter == value;
    final accent = value == 'character'
        ? EverloreTheme.violetBright
        : EverloreTheme.gold;
    return GestureDetector(
      onTap: () => setState(() => _kindFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: active ? accent.withValues(alpha: 0.14) : EverloreTheme.void2,
          border: Border.all(
            color: active
                ? accent.withValues(alpha: 0.5)
                : EverloreTheme.white10,
          ),
        ),
        child: Text(
          label,
          style: EverloreTheme.ui(
            size: 12.5,
            color: active ? accent : EverloreTheme.ash,
            weight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  SliverAppBar _buildHeader(BuildContext context) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new,
          color: EverloreTheme.ash,
          size: 18,
        ),
        onPressed: () => context.canPop() ? context.pop() : context.go('/'),
      ),
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Explore Worlds',
            style: TextStyle(
              color: EverloreTheme.parchment,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            'Choose your next adventure',
            style: TextStyle(color: EverloreTheme.ash, fontSize: 11),
          ),
        ],
      ),
    );
  }

  SliverToBoxAdapter _buildSearchBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Container(
          decoration: BoxDecoration(
            color: EverloreTheme.void2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: EverloreTheme.goldDim.withValues(alpha: 0.25),
            ),
          ),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(
              color: EverloreTheme.parchment,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: 'Search for a world...',
              hintStyle: const TextStyle(
                color: EverloreTheme.ash,
                fontStyle: FontStyle.italic,
              ),
              prefixIcon: const Icon(
                Icons.search,
                color: EverloreTheme.goldDim,
                size: 20,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.clear,
                        color: EverloreTheme.ash,
                        size: 18,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        _loadTemplates();
                        setState(() {});
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onSubmitted: (val) => _loadTemplates(search: val),
            onChanged: (_) => setState(() {}),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_isLoading) {
      return const SliverFillRemaining(
        child: Center(
          child: EverloreSessionLoader(message: 'Discovering worlds'),
        ),
      );
    }

    if (_error != null) {
      return SliverFillRemaining(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const EvIcon(AppIcons.errorRune, size: 110),
                const SizedBox(height: 16),
                const Text(
                  'Could not reach the server',
                  style: TextStyle(
                    color: EverloreTheme.parchment,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: EverloreTheme.ash,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _loadTemplates,
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final visible = _visible;
    if (visible.isEmpty) {
      final isChar = _kindFilter == 'character';
      return SliverFillRemaining(
        child: EverloreEmptyState(
          icon: isChar
              ? Icons.person_add_alt_1_rounded
              : Icons.search_off_rounded,
          eyebrow: isChar ? 'CHARACTER FORGE' : 'EXPLORE',
          title: isChar
              ? 'No characters here yet'
              : 'Nothing answered that search',
          message: isChar
              ? 'Create a character to give this shelf its first voice.'
              : 'Try a different phrase, or clear the search to see every realm.',
          actionLabel: isChar ? 'Create character' : 'Clear search',
          actionIcon: isChar ? Icons.add_rounded : Icons.restart_alt_rounded,
          accent: isChar ? EverloreTheme.violetBright : EverloreTheme.gold,
          onAction: isChar
              ? () => context.push('/characters/new')
              : () {
                  _searchController.clear();
                  _loadTemplates();
                },
        ),
      );
    }

    final label = _kindFilter == 'character'
        ? '${visible.length} CHARACTER${visible.length == 1 ? '' : 'S'}'
        : '${visible.length} WORLD${visible.length == 1 ? '' : 'S'} FOUND';

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 90),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(label, style: EverloreTheme.sectionHeader),
            );
          }
          final t = visible[index - 1];
          return _WorldCard(
            template: t,
            onTap: () => context.push('/templates/${t.id}'),
          );
        }, childCount: visible.length + 1),
      ),
    );
  }
}

class _WorldCard extends StatelessWidget {
  final WorldTemplate template;
  final VoidCallback onTap;

  const _WorldCard({required this.template, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accentColor = template.isSentient
        ? EverloreTheme.violetBright
        : EverloreTheme.cyanBright;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: EverloreTheme.void2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accentColor.withValues(alpha: 0.15)),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              splashColor: accentColor.withValues(alpha: 0.06),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accentColor.withValues(alpha: 0.1),
                            border: Border.all(
                              color: accentColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: template.imageUrl.isNotEmpty
                              ? EverloreNetworkImage(
                                  imageUrl: template.imageUrl,
                                  memCacheWidth: 160,
                                  semanticLabel: template.title,
                                )
                              : Icon(
                                  template.isCharacter
                                      ? Icons.person
                                      : template.isSentient
                                      ? Icons.psychology_alt
                                      : Icons.auto_stories,
                                  color: accentColor,
                                  size: 18,
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                template.title,
                                style: const TextStyle(
                                  color: EverloreTheme.parchment,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Row(
                                children: [
                                  EvIcon(
                                    AppIcons.familyForStyle(
                                      template.narrativeStyle,
                                    ),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      template.narrativeStyle.isNotEmpty
                                          ? narrativeStyleLabel(
                                              template.narrativeStyle,
                                            )
                                          : template.isCharacter
                                          ? 'Character'
                                          : template.isSentient
                                          ? 'Sentient World'
                                          : 'Game Master World',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: accentColor.withValues(
                                          alpha: 0.8,
                                        ),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (template.isNsfwCapable)
                          const MatureContentChip(
                            density: MatureChipDensity.compact,
                          ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.chevron_right,
                          color: EverloreTheme.ash.withValues(alpha: 0.5),
                          size: 18,
                        ),
                      ],
                    ),

                    if (template.description.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        template.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: EverloreTheme.ash,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ],

                    if (template.sceneTags.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: template.sceneTags.take(5).map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: EverloreTheme.void4,
                              border: Border.all(color: EverloreTheme.white10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                EvIcon(AppIcons.scene(tag), size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  tag,
                                  style: const TextStyle(
                                    color: EverloreTheme.ash,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
