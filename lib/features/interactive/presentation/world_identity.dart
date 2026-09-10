import 'package:flutter/material.dart';

import '../../../app/theme/nexus_theme.dart';
import '../domain/interactive_world.dart';
import 'stage/stage.dart';

/// Pick who walks — three figures on a floor, not a list of cards.
///
/// Until this is bound, the map will not move.
class WorldIdentitySheet extends StatefulWidget {
  const WorldIdentitySheet({
    super.key,
    required this.leads,
    required this.busy,
    required this.onChoose,
    required this.onLeave,
  });

  final List<WorldLeadCard> leads;
  final bool busy;
  final ValueChanged<WorldLeadCard> onChoose;
  final VoidCallback onLeave;

  @override
  State<WorldIdentitySheet> createState() => _WorldIdentitySheetState();
}

class _WorldIdentitySheetState extends State<WorldIdentitySheet> {
  late final PageController _pages = PageController(viewportFraction: 0.72);
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _pages.addListener(_onPage);
  }

  @override
  void dispose() {
    _pages.removeListener(_onPage);
    _pages.dispose();
    super.dispose();
  }

  void _onPage() {
    if (!_pages.hasClients) return;
    final next = _pages.page ?? _page;
    if ((next - _page).abs() < 0.008) return;
    setState(() => _page = next);
  }

  WorldLeadCard? get _selected {
    if (widget.leads.isEmpty) return null;
    return widget.leads[_page.round().clamp(0, widget.leads.length - 1)];
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return Stack(
      fit: StackFit.expand,
      children: [
        StageBackdrop(url: selected?.sceneUrl, veil: StageVeil.arena),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x66000000),
                Color(0x00000000),
                Color(0xCC0A0908),
              ],
              stops: [0, 0.42, 1],
            ),
          ),
        ),
        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: widget.onLeave,
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: EverloreTheme.parchment,
                  tooltip: 'Back',
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WHO WALKS',
                      style: EverloreTheme.caption.copyWith(
                        color: StageMeasure.brass,
                        letterSpacing: 1.6,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Turn them. Stand with one.',
                      style: EverloreTheme.serifDisplay(
                        size: 22,
                        color: EverloreTheme.parchment,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: widget.leads.isEmpty
                    ? const SizedBox.shrink()
                    : PageView.builder(
                        controller: _pages,
                        itemCount: widget.leads.length,
                        itemBuilder: (context, index) {
                          return _LobbyFigure(
                            lead: widget.leads[index],
                            delta: index - _page,
                          );
                        },
                      ),
              ),
              if (selected != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: _LobbyPlate(
                    lead: selected,
                    busy: widget.busy,
                    onWalk: () => widget.onChoose(selected),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LobbyFigure extends StatelessWidget {
  const _LobbyFigure({required this.lead, required this.delta});

  final WorldLeadCard lead;
  final double delta;

  @override
  Widget build(BuildContext context) {
    final away = delta.abs().clamp(0.0, 1.0);
    final scale = 1.0 - away * 0.22;
    final yaw = delta * 0.62;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Transform(
        alignment: Alignment.bottomCenter,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.00115)
          ..rotateY(yaw)
          ..scaleByDouble(scale, scale, scale, 1),
        child: Opacity(
          opacity: (1.0 - away * 0.45).clamp(0.38, 1.0),
          child: StageFigure(
            name: lead.name,
            portraitUrl: lead.portraitUrl,
            side: delta >= 0 ? StageSide.left : StageSide.right,
            rise: StageRise.speak,
            active: away < 0.45,
          ),
        ),
      ),
    );
  }
}

class _LobbyPlate extends StatelessWidget {
  const _LobbyPlate({
    required this.lead,
    required this.busy,
    required this.onWalk,
  });

  final WorldLeadCard lead;
  final bool busy;
  final VoidCallback onWalk;

  @override
  Widget build(BuildContext context) {
    final traits = lead.traits;
    return StagePanel(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            lead.name,
            style: EverloreTheme.serifDisplay(
              size: 22,
              color: StageMeasure.ink,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            lead.role.toUpperCase(),
            style: EverloreTheme.caption.copyWith(
              color: StageMeasure.brassDeep,
              fontSize: 10,
              letterSpacing: 1.2,
            ),
          ),
          if (traits != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 4,
              children: [
                _meter('Str', traits.strength),
                _meter('Cha', traits.charisma),
                _meter('Lead', traits.leadership),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Text(
            lead.want,
            style: EverloreTheme.aiText.copyWith(
              color: StageMeasure.inkMuted,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: StageChoice(
              label: 'Walk as ${lead.name}',
              busy: busy,
              onPressed: busy ? null : onWalk,
            ),
          ),
        ],
      ),
    );
  }

  Widget _meter(String label, int value) {
    return Text(
      '$label $value'.toUpperCase(),
      style: EverloreTheme.caption.copyWith(
        color: StageMeasure.brassDeep,
        fontSize: 11,
        letterSpacing: 1.1,
      ),
    );
  }
}
