import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/nexus_theme.dart';
import '../../../shared/widgets/everlore_network_image.dart';
import '../domain/interactive_world.dart';
import 'stage/stage.dart';

/// Pick who walks — a figure in the slot under the title, not a crop of
/// the whole phone.
///
/// The paintings are tall cut-outs of different widths. Covering the
/// screen with them pinned every head to the header on a long phone and
/// blew a tablet out. The stage below the title is the frame; the card
/// sits on the feet.
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
  late final PageController _pages = PageController();
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
    final size = MediaQuery.sizeOf(context);
    final sideBySide = size.width >= 700 || size.width > size.height + 48;
    return ColoredBox(
      color: const Color(0xFF0A0908),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _LobbyHeader(onLeave: widget.onLeave),
            Expanded(
              child: sideBySide
                  ? _wideStage(selected)
                  : _tallStage(selected),
            ),
          ],
        ),
      ),
    );
  }

  Widget _figures() {
    if (widget.leads.isEmpty) return const SizedBox.expand();
    return PageView.builder(
      controller: _pages,
      physics: const BouncingScrollPhysics(parent: PageScrollPhysics()),
      itemCount: widget.leads.length,
      itemBuilder: (context, index) {
        return _LobbyPortrait(lead: widget.leads[index]);
      },
    );
  }

  Widget _pips() {
    if (widget.leads.length < 2) return const SizedBox.shrink();
    return IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < widget.leads.length; i++) ...[
              Container(
                width: i == _page.round() ? 16 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: StageMeasure.brass.withValues(
                    alpha: i == _page.round() ? 0.95 : 0.32,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              if (i < widget.leads.length - 1) const SizedBox(width: 6),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tallStage(WorldLeadCard? selected) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          fit: StackFit.expand,
          children: [
            _figures(),
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x00000000),
                      Color(0x00000000),
                      Color(0xCC0A0908),
                    ],
                    stops: [0, 0.45, 1],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _pips(),
                    if (selected != null)
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth,
                          maxHeight: math.max(168, constraints.maxHeight * 0.44),
                        ),
                        child: _LobbyPlate(
                          lead: selected,
                          busy: widget.busy,
                          compact: constraints.maxHeight < 520,
                          onWalk: () => widget.onChoose(selected),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _wideStage(WorldLeadCard? selected) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 3, child: _figures()),
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
            child: Column(
              children: [
                _pips(),
                if (selected != null)
                  Expanded(
                    child: _LobbyPlate(
                      lead: selected,
                      busy: widget.busy,
                      compact: false,
                      expand: true,
                      onWalk: () => widget.onChoose(selected),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LobbyHeader extends StatelessWidget {
  const _LobbyHeader({required this.onLeave});

  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 20, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onLeave,
            icon: const Icon(Icons.arrow_back_rounded),
            color: EverloreTheme.parchment,
            tooltip: 'Back',
          ),
          Expanded(
            child: IgnorePointer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WHO WALKS',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: EverloreTheme.caption.copyWith(
                      color: StageMeasure.brass,
                      letterSpacing: 1.6,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    'Turn them. Stand with one.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: EverloreTheme.serifDisplay(
                      size: 20,
                      color: EverloreTheme.parchment,
                      weight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LobbyPortrait extends StatelessWidget {
  const _LobbyPortrait({required this.lead});

  final WorldLeadCard lead;

  /// Width of the cut-out in this stage.
  ///
  /// The published faces are ~1:2.2, not 2:3, and not the same as each
  /// other. Fitting the stage width on a tall phone stretched them until
  /// the hair sat in the title; fitting height cropped Nara's sides off.
  /// Cap by height so the head starts under the header and the extra
  /// cloth runs under the card.
  static double _columnWidth(double stageW, double stageH) {
    final cap = math.max(220.0, stageH * 0.68);
    return math.min(stageW, cap);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final url = lead.portraitUrl;
        final width = _columnWidth(
          constraints.maxWidth,
          constraints.maxHeight,
        );
        if (url == null) {
          return Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SizedBox(
                width: math.min(width, 180),
                height: math.min(constraints.maxHeight, 270),
                child: StageStandard(name: lead.name),
              ),
            ),
          );
        }
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: ClipRect(
              child: SizedBox(
                width: width,
                height: math.max(0, constraints.maxHeight - 12),
                child: EverloreNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.fitWidth,
                  alignment: Alignment.topCenter,
                  semanticLabel: lead.name,
                  placeholder: const ColoredBox(color: Color(0xFF0A0908)),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LobbyPlate extends StatelessWidget {
  const _LobbyPlate({
    required this.lead,
    required this.busy,
    required this.onWalk,
    this.compact = false,
    this.expand = false,
  });

  final WorldLeadCard lead;
  final bool busy;
  final VoidCallback onWalk;
  final bool compact;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final traits = lead.traits;
    final titleSize = compact ? 20.0 : 22.0;
    final want = Text(
      lead.want,
      style: EverloreTheme.aiText.copyWith(
        color: StageMeasure.inkMuted,
        fontSize: compact ? 13 : 14,
        height: 1.35,
      ),
      maxLines: compact ? 2 : 3,
      overflow: TextOverflow.ellipsis,
    );
    return StagePanel(
      expand: expand,
      padding: EdgeInsets.fromLTRB(
        compact ? 16 : 20,
        compact ? 12 : 14,
        compact ? 16 : 20,
        compact ? 12 : 14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Text(
            lead.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: EverloreTheme.serifDisplay(
              size: titleSize,
              color: StageMeasure.ink,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            lead.role.toUpperCase(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: EverloreTheme.caption.copyWith(
              color: StageMeasure.brassDeep,
              fontSize: 10,
              letterSpacing: 1.2,
            ),
          ),
          if (traits != null) ...[
            const SizedBox(height: 8),
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
          const SizedBox(height: 8),
          if (expand) Expanded(child: SingleChildScrollView(child: want)) else want,
          SizedBox(height: compact ? 10 : 12),
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
