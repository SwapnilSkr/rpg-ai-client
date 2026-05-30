import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../state/play_cubit.dart';
import 'widgets/narrative_bubble.dart';
import 'widgets/player_input.dart';
import 'widgets/world_state_bar.dart';
import '../../../../app/theme/nexus_theme.dart';
import '../../../shared/models/event.dart';

class PlayScreen extends StatelessWidget {
  final String instanceId;

  const PlayScreen({super.key, required this.instanceId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PlayCubit(instanceId: instanceId),
      child: const _PlayView(),
    );
  }
}

class _PlayView extends StatefulWidget {
  const _PlayView();

  @override
  State<_PlayView> createState() => _PlayViewState();
}

class _PlayViewState extends State<_PlayView> {
  final _scrollController = ScrollController();
  bool _statsExpanded = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _showTurnMenu(BuildContext context, GameEvent event) {
    final cubit = context.read<PlayCubit>();
    showModalBottomSheet(
      context: context,
      backgroundColor: EverloreTheme.void2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: EverloreTheme.void4,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.history_toggle_off,
                  color: EverloreTheme.crimson),
              title: Text('Rewind to here',
                  style: EverloreTheme.ui(
                      size: 15, color: EverloreTheme.parchment)),
              subtitle: Text(
                'Removes this turn and everything after it.',
                style: EverloreTheme.ui(size: 12, color: EverloreTheme.ash),
              ),
              onTap: () {
                Navigator.pop(sheetCtx);
                _confirmRewind(context, cubit, event.sequence);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmRewind(BuildContext context, PlayCubit cubit, int sequence) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: EverloreTheme.void2,
        title: Text('Rewind the tale?',
            style: EverloreTheme.serifDisplay(
                size: 18, color: EverloreTheme.parchment)),
        content: Text(
          'This turn and everything after it will be permanently removed, and the '
          'world will roll back to this point. This cannot be undone.',
          style: EverloreTheme.ui(
              size: 14, color: EverloreTheme.ash, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel',
                style: EverloreTheme.ui(color: EverloreTheme.ash)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              cubit.rewind(sequence);
            },
            child: Text('Rewind',
                style: EverloreTheme.ui(
                    color: EverloreTheme.crimson, weight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _scrollToBottom() {
    // Runs both for new turns and for each streamed token. Follow the bottom
    // only if the player is already near it, so streaming never yanks them away
    // from text they've scrolled up to read.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final pos = _scrollController.position;
      if (pos.maxScrollExtent - pos.pixels < 320) {
        _scrollController.jumpTo(pos.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PlayCubit, PlayState>(
      listenWhen: (prev, curr) =>
          prev.events.length != curr.events.length ||
          (curr.events.isNotEmpty &&
              (prev.events.isNotEmpty ? prev.events.last.aiResponse : null) !=
                  curr.events.last.aiResponse),
      listener: (_, __) => _scrollToBottom(),
      builder: (context, state) {
        final title = state.template?.title ?? '';
        final latestTag =
            state.events.isNotEmpty ? state.events.last.sceneTag : null;
        final accent = EverloreTheme.sceneAccent(latestTag);

        return Scaffold(
          backgroundColor: EverloreTheme.void0,
          body: Stack(
            children: [
              // Immersive, scene-tinted backdrop (full-bleed)
              Positioned.fill(child: _AtmosphereBackground(accent: accent)),

              // Content
              Column(
                children: [
                  _PlayHeader(
                    title: title,
                    accent: accent,
                    isConnected: state.isConnected,
                    hasInstance: state.instance != null,
                    onBack: () => context.pop(),
                    onChronicle: () => context.push(
                      '/chronicle/${context.read<PlayCubit>().instanceId}',
                    ),
                  ),

                  if (state.instance != null &&
                      state.instance!.worldState.isNotEmpty)
                    WorldStateBar(
                      worldState: state.instance!.worldState,
                      expanded: _statsExpanded,
                      onToggle: () =>
                          setState(() => _statsExpanded = !_statsExpanded),
                    ),

                  if (state.error != null)
                    _ErrorBar(
                      message: state.error!,
                      onDismiss: () =>
                          context.read<PlayCubit>().clearError(),
                    ),

                  Expanded(
                    child: state.isLoading && state.events.isEmpty
                        ? const _LoadingNarrative()
                        : state.events.isEmpty
                            ? const _EmptyNarrative()
                            : ListView.builder(
                                controller: _scrollController,
                                padding:
                                    const EdgeInsets.fromLTRB(2, 16, 2, 20),
                                itemCount: state.events.length,
                                itemBuilder: (context, index) {
                                  final event = state.events[index];
                                  return NarrativeBubble(
                                    event: event,
                                    onLongPress: (!event.isOptimistic &&
                                            event.sequence > 0)
                                        ? () => _showTurnMenu(context, event)
                                        : null,
                                  );
                                },
                              ),
                  ),

                  PlayerInput(
                    isGenerating: state.isGenerating,
                    isConnected: state.isConnected,
                    onSend: (msg) =>
                        context.read<PlayCubit>().sendMessage(msg),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Full-bleed atmospheric background whose hue follows the active scene.
class _AtmosphereBackground extends StatelessWidget {
  final Color accent;
  const _AtmosphereBackground({required this.accent});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(
                accent.withValues(alpha: 0.16), EverloreTheme.void0),
            EverloreTheme.void1,
            EverloreTheme.void0,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Soft halo of scene colour bleeding down from the top
          Positioned(
            top: -140,
            left: -60,
            right: -60,
            height: 420,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 0.95,
                  colors: [
                    accent.withValues(alpha: 0.20),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Deep vignette anchoring the bottom
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.2),
                  radius: 1.3,
                  colors: [Colors.transparent, Color(0xCC06060D)],
                  stops: [0.55, 1.0],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayHeader extends StatelessWidget {
  final String title;
  final Color accent;
  final bool isConnected;
  final bool hasInstance;
  final VoidCallback onBack;
  final VoidCallback onChronicle;

  const _PlayHeader({
    required this.title,
    required this.accent,
    required this.isConnected,
    required this.hasInstance,
    required this.onBack,
    required this.onChronicle,
  });

  @override
  Widget build(BuildContext context) {
    // Translucent scrim so the backdrop bleeds through (full-bleed feel)
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xF206060D), Color(0x0006060D)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 10, 10),
          child: Row(
            children: [
              _RuneButton(
                icon: Icons.arrow_back_ios_new,
                onTap: onBack,
                accent: accent,
                subtle: true,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (title.isNotEmpty)
                      Text(
                        title,
                        style: EverloreTheme.serifDisplay(
                          size: 18,
                          color: EverloreTheme.parchment,
                          weight: FontWeight.w600,
                          spacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isConnected
                                ? EverloreTheme.verdant
                                : EverloreTheme.crimson,
                            boxShadow: isConnected
                                ? EverloreTheme.glow(EverloreTheme.verdant,
                                    blur: 6, alpha: 0.6)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isConnected ? 'Realm Active' : 'Reconnecting…',
                          style: EverloreTheme.ui(
                            size: 11,
                            spacing: 0.5,
                            color: isConnected
                                ? EverloreTheme.ash.withValues(alpha: 0.75)
                                : EverloreTheme.crimson.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (hasInstance)
                _RuneButton(
                  icon: Icons.history_edu,
                  onTap: onChronicle,
                  accent: EverloreTheme.gold,
                  tooltip: 'Lore Tome',
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small glowing icon button used in the header chrome.
class _RuneButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color accent;
  final String? tooltip;
  final bool subtle;

  const _RuneButton({
    required this.icon,
    required this.onTap,
    required this.accent,
    this.tooltip,
    this.subtle = false,
  });

  @override
  Widget build(BuildContext context) {
    final btn = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: subtle
              ? Colors.transparent
              : EverloreTheme.void2.withValues(alpha: 0.6),
          border: Border.all(
            color: subtle
                ? Colors.transparent
                : accent.withValues(alpha: 0.25),
          ),
        ),
        child: Icon(
          icon,
          color: subtle ? EverloreTheme.ash : accent,
          size: subtle ? 18 : 19,
        ),
      ),
    );
    if (tooltip != null) return Tooltip(message: tooltip!, child: btn);
    return btn;
  }
}

class _LoadingNarrative extends StatelessWidget {
  const _LoadingNarrative();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: EverloreTheme.gold,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Opening the tome…',
            style: EverloreTheme.ui(
              size: 14,
              color: EverloreTheme.ash,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyNarrative extends StatelessWidget {
  const _EmptyNarrative();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: EverloreTheme.goldDim.withValues(alpha: 0.35)),
                gradient: RadialGradient(
                  colors: [
                    EverloreTheme.gold.withValues(alpha: 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Icon(
                Icons.auto_stories,
                color: EverloreTheme.gold.withValues(alpha: 0.6),
                size: 34,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Your Tale Awaits',
              textAlign: TextAlign.center,
              style: EverloreTheme.serifDisplay(
                size: 20,
                color: EverloreTheme.parchment,
                spacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The story begins with your first words.',
              textAlign: TextAlign.center,
              style: EverloreTheme.ui(
                size: 14,
                color: EverloreTheme.ash,
                height: 1.5,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBar extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _ErrorBar({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: EverloreTheme.crimson.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: EverloreTheme.crimson.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              color: EverloreTheme.crimson, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: EverloreTheme.ui(
                  size: 13, color: EverloreTheme.crimson, height: 1.4),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close,
                color: EverloreTheme.crimson, size: 16),
            onPressed: onDismiss,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(4),
          ),
        ],
      ),
    );
  }
}
