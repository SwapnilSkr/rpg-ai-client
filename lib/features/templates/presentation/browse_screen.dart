import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/models/world_template.dart';
import '../../../core/onboarding/interests_store.dart';
import '../data/template_repository.dart';
import '../data/interest_ranking.dart';
import '../../../../app/theme/nexus_theme.dart';

class BrowseTemplatesScreen extends StatefulWidget {
  const BrowseTemplatesScreen({super.key});

  @override
  State<BrowseTemplatesScreen> createState() => _BrowseTemplatesScreenState();
}

class _BrowseTemplatesScreenState extends State<BrowseTemplatesScreen> {
  List<WorldTemplate> _templates = [];
  bool _isLoading = true;
  String? _error;
  String _kindFilter = 'all'; // 'all' | 'world' | 'character'
  final _searchController = TextEditingController();

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
    _loadTemplates();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTemplates({String? search}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await TemplateRepository.listPublished(search: search);
      // Boost worlds matching the player's interests (read-only reorder).
      final interests = await InterestsStore.getInterests();
      final ranked = rankByInterests(
        List<WorldTemplate>.from(result['templates']),
        interests,
      );
      setState(() {
        _templates = ranked;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EverloreTheme.void1,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/characters/new'),
        backgroundColor: EverloreTheme.violet,
        icon: const Icon(Icons.person_add_alt_1, color: EverloreTheme.parchment, size: 18),
        label: Text('Character',
            style: EverloreTheme.ui(
                size: 13,
                color: EverloreTheme.parchment,
                weight: FontWeight.w700)),
      ),
      body: CustomScrollView(
        slivers: [
          _buildHeader(context),
          _buildSearchBar(),
          _buildSegments(),
          _buildContent(context),
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
        child: Text(label,
            style: EverloreTheme.ui(
                size: 12.5,
                color: active ? accent : EverloreTheme.ash,
                weight: active ? FontWeight.w700 : FontWeight.w500)),
      ),
    );
  }

  SliverAppBar _buildHeader(BuildContext context) {
    return SliverAppBar(
      backgroundColor: EverloreTheme.void0,
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new,
            color: EverloreTheme.ash, size: 18),
        onPressed: () =>
            context.canPop() ? context.pop() : context.go('/'),
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
            style: TextStyle(
              color: EverloreTheme.ash,
              fontSize: 11,
            ),
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
                color: EverloreTheme.goldDim.withValues(alpha: 0.25)),
          ),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: EverloreTheme.parchment, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search for a world...',
              hintStyle: const TextStyle(
                  color: EverloreTheme.ash, fontStyle: FontStyle.italic),
              prefixIcon: const Icon(Icons.search,
                  color: EverloreTheme.goldDim, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear,
                          color: EverloreTheme.ash, size: 18),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                    strokeWidth: 1.5, color: EverloreTheme.gold),
              ),
              SizedBox(height: 14),
              Text(
                'Discovering worlds...',
                style: TextStyle(
                    color: EverloreTheme.ash,
                    fontSize: 13,
                    fontStyle: FontStyle.italic),
              ),
            ],
          ),
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
                const Icon(Icons.wifi_off,
                    color: EverloreTheme.ash, size: 40),
                const SizedBox(height: 16),
                const Text(
                  'Could not reach the realm',
                  style: TextStyle(
                      color: EverloreTheme.parchment,
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: EverloreTheme.ash, fontSize: 12, height: 1.5),
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
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isChar ? Icons.person_off_outlined : Icons.explore_off,
                  color: EverloreTheme.goldDim, size: 48),
              const SizedBox(height: 16),
              Text(
                isChar ? 'No characters yet' : 'No worlds found',
                style: const TextStyle(
                    color: EverloreTheme.parchment,
                    fontSize: 16,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                isChar
                    ? 'Tap “Character” to create someone to talk to.'
                    : 'Try a different search term.',
                style: const TextStyle(color: EverloreTheme.ash, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final label = _kindFilter == 'character'
        ? '${visible.length} CHARACTER${visible.length == 1 ? '' : 'S'}'
        : '${visible.length} WORLD${visible.length == 1 ? '' : 'S'} FOUND';

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 90),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
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
          },
          childCount: visible.length + 1,
        ),
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
            border: Border.all(
              color: accentColor.withValues(alpha: 0.15),
            ),
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
                                color: accentColor.withValues(alpha: 0.3)),
                            image: template.imageUrl.isNotEmpty
                                ? DecorationImage(
                                    image: NetworkImage(template.imageUrl),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: template.imageUrl.isNotEmpty
                              ? null
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
                              Text(
                                template.isCharacter
                                    ? 'Character'
                                    : template.isSentient
                                        ? 'Sentient World'
                                        : 'Game Master World',
                                style: TextStyle(
                                  color: accentColor.withValues(alpha: 0.8),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (template.isNsfwCapable)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              color: EverloreTheme.crimson
                                  .withValues(alpha: 0.1),
                              border: Border.all(
                                  color: EverloreTheme.crimson
                                      .withValues(alpha: 0.3)),
                            ),
                            child: const Text(
                              '18+',
                              style: TextStyle(
                                  color: EverloreTheme.crimson, fontSize: 9),
                            ),
                          ),
                        const SizedBox(width: 8),
                        Icon(Icons.chevron_right,
                            color: EverloreTheme.ash.withValues(alpha: 0.5),
                            size: 18),
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
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: EverloreTheme.void4,
                              border: Border.all(
                                  color: EverloreTheme.white10),
                            ),
                            child: Text(
                              tag,
                              style: const TextStyle(
                                  color: EverloreTheme.ash, fontSize: 10),
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
