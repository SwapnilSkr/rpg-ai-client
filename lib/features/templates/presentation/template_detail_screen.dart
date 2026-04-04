import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/models/world_template.dart';
import '../data/template_repository.dart';
import '../../home/data/home_repository.dart';
import '../../../../app/theme/nexus_theme.dart';

class TemplateDetailScreen extends StatefulWidget {
  final String templateId;

  const TemplateDetailScreen({super.key, required this.templateId});

  @override
  State<TemplateDetailScreen> createState() => _TemplateDetailScreenState();
}

class _TemplateDetailScreenState extends State<TemplateDetailScreen> {
  WorldTemplate? _template;
  bool _isLoading = true;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final t = await TemplateRepository.getById(widget.templateId);
      if (mounted) setState(() { _template = t; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createInstance() async {
    if (_isCreating) return;
    setState(() => _isCreating = true);
    try {
      final instance = await HomeRepository.createInstance(widget.templateId);
      if (mounted) context.go('/play/${instance.id}');
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: EverloreTheme.crimson.withValues(alpha: 0.9),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EverloreTheme.void1,
      body: _isLoading
          ? const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                    strokeWidth: 1.5, color: EverloreTheme.gold),
              ),
            )
          : _template == null
              ? _buildNotFound(context)
              : _buildContent(context, _template!),
    );
  }

  Widget _buildNotFound(BuildContext context) {
    return Scaffold(
      backgroundColor: EverloreTheme.void1,
      appBar: AppBar(
        backgroundColor: EverloreTheme.void0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: EverloreTheme.ash, size: 18),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('World Not Found'),
      ),
      body: const Center(
        child: Text(
          'This world could not be found.',
          style: TextStyle(color: EverloreTheme.ash),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WorldTemplate t) {
    final accentColor =
        t.isSentient ? EverloreTheme.violetBright : EverloreTheme.cyanBright;

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            // App bar with hero header
            SliverAppBar(
              backgroundColor: EverloreTheme.void0,
              expandedHeight: 180,
              pinned: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: EverloreTheme.ash, size: 18),
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/templates'),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Gradient bg
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            accentColor.withValues(alpha: 0.12),
                            EverloreTheme.void0,
                          ],
                        ),
                      ),
                    ),
                    // Ambient circle
                    Positioned(
                      top: -40,
                      right: -40,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              accentColor.withValues(alpha: 0.1),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Content
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 50, 20, 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: accentColor.withValues(alpha: 0.12),
                                border: Border.all(
                                    color:
                                        accentColor.withValues(alpha: 0.4),
                                    width: 1.5),
                              ),
                              child: Icon(
                                t.isSentient
                                    ? Icons.psychology_alt
                                    : Icons.auto_stories,
                                color: accentColor,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    t.title,
                                    style: const TextStyle(
                                      color: EverloreTheme.parchment,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          color: accentColor
                                              .withValues(alpha: 0.1),
                                          border: Border.all(
                                              color: accentColor
                                                  .withValues(alpha: 0.3)),
                                        ),
                                        child: Text(
                                          t.isSentient
                                              ? 'Sentient World'
                                              : 'Game Master',
                                          style: TextStyle(
                                            color: accentColor,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      if (t.isNsfwCapable) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 3),
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            color: EverloreTheme.crimson
                                                .withValues(alpha: 0.1),
                                            border: Border.all(
                                                color: EverloreTheme.crimson
                                                    .withValues(alpha: 0.3)),
                                          ),
                                          child: const Text(
                                            '18+',
                                            style: TextStyle(
                                                color: EverloreTheme.crimson,
                                                fontSize: 9),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Description
                  Text(
                    t.description,
                    style: const TextStyle(
                      color: EverloreTheme.ash,
                      fontSize: 15,
                      height: 1.7,
                    ),
                  ),

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
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: EverloreTheme.void3,
                            border: Border.all(
                                color: EverloreTheme.goldDim
                                    .withValues(alpha: 0.2)),
                          ),
                          child: Text(
                            tag,
                            style: const TextStyle(
                                color: EverloreTheme.ash, fontSize: 12),
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
                child: ElevatedButton(
                  onPressed: _isCreating ? null : _createInstance,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EverloreTheme.gold,
                    foregroundColor: EverloreTheme.void0,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _isCreating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: EverloreTheme.void0,
                          ),
                        )
                      : const Row(
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
      ],
    );
  }
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
        .map((w) => w.isNotEmpty
            ? '${w[0].toUpperCase()}${w.substring(1)}'
            : '')
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
                    colors: [
                      color.withValues(alpha: 0.7),
                      color,
                    ],
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
