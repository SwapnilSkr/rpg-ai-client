import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app/theme/nexus_theme.dart';
import '../core/onboarding/interests_store.dart';
import '../shared/app_icons.dart';
import '../shared/models/world_template.dart';
import '../shared/narrative_styles.dart';
import '../shared/widgets/neu.dart';
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
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await TemplateRepository.listPublished();
      final interests = await InterestsStore.getInterests();
      final ranked = rankByInterests(
        List<WorldTemplate>.from(result['templates']),
        interests,
      );
      if (!mounted) return;
      setState(() {
        _templates = ranked;
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

  List<WorldTemplate> get _visible {
    switch (_tab) {
      case 1:
        return _templates.where((t) => !t.isCharacter).toList();
      case 2:
        return _templates.where((t) => t.isCharacter).toList();
      default:
        return _templates;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EverloreTheme.void0,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopBar(),
            _buildTabs(),
            const SizedBox(height: 4),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 14, 6),
      child: Row(
        children: [
          const ForgeMark(size: 30),
          const SizedBox(width: 10),
          Text(
            'EVERLORE',
            style: GoogleFonts.cinzel(
              color: EverloreTheme.gold,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const Spacer(),
          _iconButton(Icons.search, () => context.push('/templates')),
        ],
      ),
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 40,
        height: 40,
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
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 6,
              offset: const Offset(1, 2),
            ),
          ],
        ),
        child: Icon(icon, color: EverloreTheme.gold, size: 19),
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
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: EverloreTheme.gold,
          ),
        ),
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
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const EvIcon(AppIcons.emptyRealms, size: 110),
            const SizedBox(height: 14),
            Text(
              _tab == 2 ? 'No characters yet.' : 'No worlds found.',
              style: EverloreTheme.ui(size: 14, color: EverloreTheme.ash),
            ),
          ],
        ),
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
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          16,
          8,
          16,
          110,
        ), // clear floating nav
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _column(left)),
            const SizedBox(width: 12),
            Expanded(child: _column(right)),
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
                      if (template.isNsfwCapable) _nsfwBadge(),
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

  Widget _nsfwBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: EverloreTheme.crimson.withValues(alpha: 0.10),
        border: Border.all(
          color: EverloreTheme.crimson.withValues(alpha: 0.25),
        ),
      ),
      child: const EvIcon(AppIcons.nsfw, size: 18),
    );
  }

  Widget _cover() {
    if (template.imageUrl.isNotEmpty) {
      return Image.network(
        template.imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _coverFallback(),
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : _coverFallback(),
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
