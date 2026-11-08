import 'dart:async';

import 'package:flutter/material.dart';

import 'package:everlore/app/theme/nexus_theme.dart';
import 'package:everlore/features/group_chat/state/create_group_state.dart';
import 'package:everlore/shared/widgets/realm_backdrop.dart';

/// Full-bleed wait screen while the server drafts the group chat.
/// Features forge-group-cover.webp, 3-stop void0 gradient scrim, EmberOverlay,
/// rotating lines using real names from the draft form, and a thin progress indicator.
class GroupDraftingView extends StatefulWidget {
  final CreateGroupState state;

  const GroupDraftingView({super.key, required this.state});

  @override
  State<GroupDraftingView> createState() => _GroupDraftingViewState();
}

class _GroupDraftingViewState extends State<GroupDraftingView> {
  Timer? _rotationTimer;
  int _lineIndex = 0;
  late List<String> _lines;

  @override
  void initState() {
    super.initState();
    _lines = _buildRotatingLines();
    _rotationTimer = Timer.periodic(const Duration(milliseconds: 2800), (_) {
      if (mounted && _lines.isNotEmpty) {
        setState(() {
          _lineIndex = (_lineIndex + 1) % _lines.length;
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant GroupDraftingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.form.people != oldWidget.state.form.people) {
      _lines = _buildRotatingLines();
    }
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    super.dispose();
  }

  List<String> _buildRotatingLines() {
    final names = widget.state.form.people
        .map((p) => p.name.trim())
        .where((n) => n.isNotEmpty)
        .toList();

    if (names.isEmpty) {
      return const [
        'Finding out what they want',
        'Working out how they talk',
        'Deciding who they look at first',
        'Giving them something to argue about',
      ];
    }

    final lines = <String>[];
    for (var i = 0; i < names.length; i++) {
      final name = names[i];
      lines.add('Finding out what $name wants');
      lines.add('Working out how $name talks');
      lines.add('Deciding who $name looks at first');
    }
    lines.add('Giving them something to argue about');
    return lines;
  }

  @override
  Widget build(BuildContext context) {
    final currentLine = _lines.isNotEmpty
        ? _lines[_lineIndex % _lines.length]
        : '';

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Full-bleed cover art
        Image.asset(
          'assets/art/forge-group-cover.webp',
          fit: BoxFit.cover,
          alignment: Alignment.center,
          cacheWidth: 1080,
        ),

        // 2. 3-stop void0 gradient scrim
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  EverloreTheme.void0.withValues(alpha: 0.25),
                  EverloreTheme.void0.withValues(alpha: 0.50),
                  EverloreTheme.void0.withValues(alpha: 0.94),
                ],
                stops: const [0.0, 0.50, 1.0],
              ),
            ),
          ),
        ),

        // 3. Drifting embers
        const EmberOverlay(),

        // 4. Centered text block starting about 62% down with side padding 32
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final topOffset = constraints.maxHeight * 0.62;

              return Padding(
                padding: EdgeInsets.fromLTRB(32, topOffset, 32, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Writing your group',
                      textAlign: TextAlign.center,
                      style: EverloreTheme.aiText.copyWith(
                        fontSize: 28,
                        color: EverloreTheme.parchment,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 14),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      child: Text(
                        currentLine,
                        key: ValueKey('line_${_lineIndex}_$currentLine'),
                        textAlign: TextAlign.center,
                        style: EverloreTheme.aiText.copyWith(
                          fontSize: 17,
                          color: EverloreTheme.gold,
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    const SizedBox(
                      width: 120,
                      height: 2,
                      child: LinearProgressIndicator(
                        backgroundColor: EverloreTheme.void4,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          EverloreTheme.gold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Usually under a minute.',
                      textAlign: TextAlign.center,
                      style: EverloreTheme.ui(
                        size: 12,
                        color: EverloreTheme.ash,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
