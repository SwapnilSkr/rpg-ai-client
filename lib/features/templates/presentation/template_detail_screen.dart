import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/models/world_template.dart';
import '../data/template_repository.dart';
import '../../home/presentation/realm_entry_flow.dart';
import '../../../../app/theme/nexus_theme.dart';
import '../../../../shared/widgets/mature_content_chip.dart';
import '../../../../shared/widgets/everlore_network_image.dart';
import '../../../../shared/widgets/everlore_session_loader.dart';
import '../../../../shared/widgets/everlore_empty_state.dart';
import '../../../../shared/widgets/story_prose.dart';
import '../../../../shared/widgets/realm_backdrop.dart';
import '../../../core/guide/guide_anchor.dart';
import '../../../core/guide/guide_flows.dart';
import '../../../core/guide/guide_ids.dart';
import '../../../core/guide/guide_trigger.dart';
import '../../../core/auth/auth_service.dart';
import '../../moderation/presentation/content_actions_sheet.dart';
import '../../../shared/text_format.dart';
import '../../../shared/widgets/status_bar_scrim.dart';

class TemplateDetailScreen extends StatefulWidget {
  final String templateId;

  const TemplateDetailScreen({super.key, required this.templateId});

  @override
  State<TemplateDetailScreen> createState() => _TemplateDetailScreenState();
}

class _TemplateDetailScreenState extends State<TemplateDetailScreen> {
  WorldTemplate? _template;
  bool _isLoading = true;

  /// The signed-in account, so the safety menu is offered on other people's
  /// worlds and hidden on your own — there is nothing to report or block there.
  String? _viewerId;

  @override
  void initState() {
    super.initState();
    _load();
    _loadViewer();
  }

  Future<void> _loadViewer() async {
    final user = await AuthService.getCachedUser();
    if (mounted) setState(() => _viewerId = user?.id);
  }

  bool get _canModerate {
    final template = _template;
    if (template == null || _viewerId == null) return false;
    return template.creatorId.isNotEmpty && template.creatorId != _viewerId;
  }

  Future<void> _openSafetyMenu() async {
    final template = _template;
    if (template == null) return;

    final result = await showContentActionsSheet(
      context,
      worldId: template.id,
      worldTitle: template.title,
      creatorId: template.creatorId,
    );
    if (!mounted) return;

    // Hiding a world or blocking its creator makes this page a dead end, so
    // leave it. A report alone does not — the world is still there while it is
    // reviewed, and popping would imply it had already been taken down.
    if (result == ContentActionResult.worldHidden ||
        result == ContentActionResult.creatorBlocked) {
      TemplateRepository.invalidate();
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/discover');
      }
    }
  }

  Future<void> _load() async {
    try {
      final t = await TemplateRepository.getById(widget.templateId);
      if (mounted) {
        setState(() {
          _template = t;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _enterWorld() async {
    final title = _template?.title ?? 'this world';
    await enterRealmFromTemplate(
      context,
      templateId: widget.templateId,
      worldTitle: title,
      isSentient: _template?.isSentient ?? false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EverloreTheme.void1,
      body: _isLoading
          ? const Center(
              child: EverloreSessionLoader(message: 'Opening the realm'),
            )
          : _template == null
          ? _buildNotFound(context)
          // The threshold arc waits for the world itself. Firing it against a
          // loading spinner would spend the one visit it gets on an empty
          // screen.
          : GuideOnEnter(
              flow: GuideFlows.worldDetail,
              child: _buildContent(context, _template!),
            ),
    );
  }

  Widget _buildNotFound(BuildContext context) {
    return Scaffold(
      backgroundColor: EverloreTheme.void1,
      appBar: AppBar(
        backgroundColor: EverloreTheme.void0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: EverloreTheme.ash,
            size: 18,
          ),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('World Not Found'),
      ),
      body: EverloreEmptyState(
        icon: Icons.auto_stories_outlined,
        eyebrow: 'LOST REALM',
        title: 'This world is beyond the veil',
        message:
            'It may have been moved or withdrawn. Return to the shelves to find another story.',
        actionLabel: 'Explore worlds',
        actionIcon: Icons.explore_rounded,
        onAction: () => context.go('/discover'),
        accent: EverloreTheme.gold,
        artAsset: 'assets/art/forge-muse.webp',
        fullBleedArt: true,
      ),
    );
  }

  Widget _buildContent(BuildContext context, WorldTemplate t) {
    final accentColor = t.isSentient
        ? EverloreTheme.violetBright
        : EverloreTheme.cyanBright;

    return Stack(
      fit: StackFit.expand,
      children: [
        // The world's own art, full bleed behind everything — the same
        // backdrop Explore, Realms and a realm's own page are built on. This
        // was a 180pt banner with a circular portrait pinned to its lower
        // edge, which is the grammar of a social profile: a header you look
        // at, with a face on it. A place you are about to walk into should be
        // the ground the page stands on.
        if (t.imageUrl.isNotEmpty)
          EverloreNetworkImage(
            imageUrl: t.imageUrl,
            fit: BoxFit.cover,
            memCacheWidth: 1080,
            errorWidget: const _DetailFallbackArt(),
            semanticLabel: t.title,
          )
        else
          const _DetailFallbackArt(),
        const EmberOverlay(),
        // The scrim is shaped to where the reading starts, not spread evenly
        // down the screen. It stays light over the hero so the art is
        // actually visible, then darkens hard just below it — the description
        // is dim ash on a busy painting otherwise, which is a legibility cost
        // the old flat panel did not have. Four stops so it *holds* at near
        // solid for the whole scroll instead of easing there only at the very
        // bottom of the viewport.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                EverloreTheme.void0.withValues(alpha: 0.12),
                EverloreTheme.void0.withValues(alpha: 0.4),
                EverloreTheme.void0.withValues(alpha: 0.9),
                EverloreTheme.void0.withValues(alpha: 0.95),
              ],
              stops: const [0, 0.2, 0.52, 1],
            ),
          ),
        ),
        CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: Colors.transparent,
              expandedHeight: 280,
              pinned: true,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: EverloreTheme.parchment,
                  size: 18,
                ),
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/templates'),
              ),
              actions: [
                if (_canModerate)
                  IconButton(
                    onPressed: _openSafetyMenu,
                    tooltip: 'Report or hide this world',
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      color: EverloreTheme.parchment,
                      size: 20,
                    ),
                  ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                // No second gradient inside the bar. One layered on top of the
                // page-wide scrim ends where the bar ends, and the step
                // between the two drew a visible horizontal seam straight
                // across the artwork. The scrim below is continuous, and the
                // title carries its own shadow instead.
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 22,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            t.title,
                            style:
                                EverloreTheme.serifDisplay(
                                  size: 30,
                                  color: EverloreTheme.parchment,
                                  weight: FontWeight.w600,
                                ).copyWith(
                                  // Local contrast where it is needed and
                                  // nowhere else: a world's cover can be
                                  // bright directly behind its own name, and a
                                  // shadow holds the letters without dimming
                                  // the painting.
                                  shadows: const [
                                    Shadow(
                                      color: Color(0xCC0A0807),
                                      blurRadius: 18,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  color: accentColor.withValues(alpha: 0.14),
                                  border: Border.all(
                                    color: accentColor.withValues(alpha: 0.34),
                                  ),
                                ),
                                child: Text(
                                  t.isCharacter
                                      ? 'Character Story'
                                      : t.isSentient
                                      ? 'Sentient World'
                                      : 'Game Master World',
                                  style: TextStyle(
                                    color: accentColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (t.isNsfwCapable)
                                const MatureContentChip(
                                  density: MatureChipDensity.compact,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverPadding(
              // Clears the pinned CTA, which grows with the player's text
              // size and the home indicator — a flat 120 left the last lines
              // of the description sliced in half underneath it.
              padding: EdgeInsets.fromLTRB(20, 20, 20, _ctaClearance(context)),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Description. The pitch, and the one thing on the screen
                  // that is read before anything else — so it is cut later
                  // than the panels below it.
                  ExpandableProse(
                    text: t.description,
                    accent: accentColor,
                    collapsedLines: 8,
                    style: const TextStyle(
                      color: EverloreTheme.ash,
                      fontSize: 15,
                      height: 1.7,
                    ),
                  ),

                  const SizedBox(height: 24),
                  GuideAnchor(
                    id: GuideIds.worldInvitation,
                    child: _WorldDetailPanel(
                      icon: Icons.auto_stories_outlined,
                      label: 'WHAT AWAITS',
                      text: _invitationFor(t),
                      accent: accentColor,
                      // The world's opening line, written the way the narrator
                      // writes. It is the hook, so it gets more room before it
                      // is cut than the reference material below.
                      prose: true,
                      collapsedLines: 9,
                    ),
                  ),

                  const SizedBox(height: 28),
                  _SectionHeader(label: 'WORLD AT A GLANCE'),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _WorldFact(
                        icon: t.isSentient
                            ? Icons.psychology_alt_outlined
                            : Icons.menu_book_outlined,
                        label: t.isCharacter
                            ? 'Character-first story'
                            : t.isSentient
                            ? 'Full world · lead character'
                            : 'Full world · neutral narrator',
                        accent: accentColor,
                      ),
                      _WorldFact(
                        icon: Icons.auto_awesome_outlined,
                        label: t.narrativeStyle.trim().isEmpty
                            ? 'Open-ended story'
                            : t.narrativeStyle,
                        accent: accentColor,
                      ),
                      _WorldFact(
                        icon: Icons.account_tree_outlined,
                        label: t.sceneTags.isEmpty
                            ? 'Choices shape the path'
                            : '${t.sceneTags.length} story thread${t.sceneTags.length == 1 ? '' : 's'}',
                        accent: accentColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _scopeDescriptionFor(t),
                    style: const TextStyle(
                      color: EverloreTheme.ash,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),

                  if (t.globalLore.trim().isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _WorldDetailPanel(
                      icon: Icons.menu_book_outlined,
                      label: 'FROM THE WORLD GUIDE',
                      text: t.globalLore.trim(),
                      accent: accentColor,
                      // Background an author may write at any length. Six lines
                      // is enough to judge a world by and short enough that the
                      // stats and the way in stay on the same screen.
                      collapsedLines: 6,
                    ),
                  ],

                  // Stats section
                  if (t.baseStatsTemplate.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    _SectionHeader(label: 'STARTING STATS'),
                    const SizedBox(height: 14),
                    ...t.baseStatsTemplate.entries.map((e) {
                      final max = e.value.max;
                      final pct = (e.value.defaultValue / max)
                          .clamp(0.0, 1.0)
                          .toDouble();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _StatPreview(
                          name: e.key.replaceAll('_', ' '),
                          description: e.value.description,
                          pct: pct,
                          value: e.value.defaultValue,
                          max: max,
                        ),
                      );
                    }),
                  ],

                  // Scene types
                  if (t.sceneTags.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    _SectionHeader(label: 'SCENE TYPES'),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: t.sceneTags.map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: EverloreTheme.void3,
                            border: Border.all(
                              color: EverloreTheme.goldDim.withValues(
                                alpha: 0.2,
                              ),
                            ),
                          ),
                          child: Text(
                            humanizeTag(tag),
                            style: const TextStyle(
                              color: EverloreTheme.ash,
                              fontSize: 12,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ]),
              ),
            ),
          ],
        ),

        const StatusBarScrim(),
        // Bottom CTA
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  EverloreTheme.void1.withValues(alpha: 0),
                  EverloreTheme.void1,
                  EverloreTheme.void1,
                ],
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: GuideAnchor(
                  id: GuideIds.worldEnter,
                  child: ElevatedButton(
                    onPressed: _enterWorld,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EverloreTheme.gold,
                      foregroundColor: EverloreTheme.void0,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.explore, size: 18),
                        SizedBox(width: 10),
                        Text(
                          'ENTER THIS WORLD',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Height the pinned "Enter this world" bar actually occupies: its padding,
/// the button's own padding, one line of its label at the current text scale,
/// and the home indicator.
double _ctaClearance(BuildContext context) {
  final media = MediaQuery.of(context);
  final label = media.textScaler.scale(15) * 1.3;
  return media.padding.bottom + 16 + 20 + 36 + label + 16;
}

String _invitationFor(WorldTemplate template) {
  if (template.openingLine.trim().isNotEmpty) {
    return template.openingLine.trim();
  }
  return 'Begin a realm and let your choices reveal what this world has in store.';
}

String _scopeDescriptionFor(WorldTemplate template) {
  if (template.isCharacter) {
    return 'A focused character-first story. Their backstory can naturally bring supporting characters and scenes into play.';
  }
  if (template.isSentient) {
    return 'A complete RPG setting guided by a lead AI character, with room for lore, cast, and scene threads.';
  }
  return 'A complete RPG setting narrated by a neutral AI Game Master.';
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: EverloreTheme.sectionHeader),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            color: EverloreTheme.goldDim.withValues(alpha: 0.2),
          ),
        ),
      ],
    );
  }
}

class _WorldDetailPanel extends StatelessWidget {
  final IconData icon;
  final String label;
  final String text;
  final Color accent;

  /// Render [text] as the world's own voice — `*action*` in italics, spoken
  /// lines upright — rather than as literal characters. True for a passage
  /// written by the narrator (a world's opening line); false for editorial
  /// copy such as a lore entry, which is prose about the world rather than
  /// prose from inside it.
  final bool prose;

  /// Lines shown before the reader asks for the rest.
  final int collapsedLines;

  const _WorldDetailPanel({
    required this.icon,
    required this.label,
    required this.text,
    required this.accent,
    this.prose = false,
    this.collapsedLines = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: EverloreTheme.void2,
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accent),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ExpandableProse(
            style: bodyStyle,
            accent: accent,
            collapsedLines: collapsedLines,
            text: prose ? null : text,
            spans: prose
                ? storyProseSpans(
                    text,
                    // The panel's own measure, not the play surface's: this
                    // sits inside a bordered card on a browsing screen, so the
                    // two voices are separated by weight and slant while both
                    // stay at the card's own size and rhythm.
                    narrationStyle: bodyStyle.copyWith(
                      fontStyle: FontStyle.italic,
                      color: EverloreTheme.parchment.withValues(
                        alpha: kNarrationMutedAlpha,
                      ),
                    ),
                    dialogueStyle: bodyStyle.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  static const bodyStyle = TextStyle(
    color: EverloreTheme.parchment,
    fontSize: 14,
    height: 1.55,
  );
}

class _WorldFact extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;

  const _WorldFact({
    required this.icon,
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: EverloreTheme.void2,
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accent),
          const SizedBox(width: 7),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 190),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: EverloreTheme.ash,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPreview extends StatelessWidget {
  final String name;
  final String description;
  final double pct;
  final num value;
  final num max;

  const _StatPreview({
    required this.name,
    required this.description,
    required this.pct,
    required this.value,
    required this.max,
  });

  @override
  Widget build(BuildContext context) {
    final color = pct >= 0.6
        ? EverloreTheme.verdant
        : pct >= 0.3
        ? EverloreTheme.ember
        : EverloreTheme.crimson;

    final displayName = name
        .split(' ')
        .map(
          (w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '',
        )
        .join(' ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              displayName,
              style: const TextStyle(
                color: EverloreTheme.parchment,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              '${value.round()} / ${max.round()}',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Stack(
          children: [
            Container(
              height: 5,
              decoration: BoxDecoration(
                color: EverloreTheme.void4,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            FractionallySizedBox(
              widthFactor: pct,
              child: Container(
                height: 5,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  gradient: LinearGradient(
                    colors: [color.withValues(alpha: 0.7), color],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              color: EverloreTheme.ash,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}

/// Stand-in art when a world has no cover of its own, matching the realm
/// screen's fallback so the two surfaces degrade the same way.
class _DetailFallbackArt extends StatelessWidget {
  const _DetailFallbackArt();

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Image.asset(
        'assets/art/forge-muse.webp',
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
      ),
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0x3326213A), EverloreTheme.void1],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    ],
  );
}
