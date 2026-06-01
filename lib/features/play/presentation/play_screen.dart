import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../state/play_cubit.dart';
import 'widgets/narrative_bubble.dart';
import 'widgets/player_input.dart';
import 'widgets/world_state_bar.dart';
import '../../../../app/theme/nexus_theme.dart';
import '../../../shared/models/event.dart';
import '../../../shared/models/character_profile.dart';
import '../../../shared/chat_modes.dart';
import '../../../core/storage/local_db.dart';
import '../../home/data/home_repository.dart';

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
  bool _onboardingShown = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _maybeShowOnboarding(BuildContext context) {
    final cubit = context.read<PlayCubit>();
    if (_onboardingShown || !cubit.shouldOnboardProtagonist) return;
    _onboardingShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showProtagonistOnboarding(context, cubit);
    });
  }

  void _showProtagonistOnboarding(BuildContext context, PlayCubit cubit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: EverloreTheme.void2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => _ProtagonistOnboardingSheet(
        onBegin: (name, identity) {
          cubit.setPlayerProtagonist(name, identity: identity);
          Navigator.pop(sheetCtx);
        },
        onSkip: () {
          cubit.skipProtagonistOnboarding();
          Navigator.pop(sheetCtx);
        },
      ),
    );
  }

  void _showChatMenu(BuildContext context) {
    final cubit = context.read<PlayCubit>();
    final instance = cubit.state.instance;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: EverloreTheme.void2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => _SettingsSheet(
        initialPov: instance?.narrationPov ?? 'third',
        initialMode: instance?.mode ?? kDefaultChatMode,
        initialLength: instance?.messageLength ?? 'medium',
        onApply: (pov, mode, length) {
          cubit.updateSettings(
            narrationPov: pov,
            mode: mode,
            messageLength: length,
          );
          Navigator.pop(sheetCtx);
          _showSettingsSnack(context, pov: pov, mode: mode, length: length);
        },
        onReset: () {
          Navigator.pop(sheetCtx);
          _confirmResetChat(context, cubit);
        },
        onDelete: () {
          Navigator.pop(sheetCtx);
          _confirmDeleteChat(context, cubit.instanceId);
        },
      ),
    );
  }

  /// Friendly confirmation that staged scene settings were saved and when they
  /// take effect (POV/tone only shape future turns, never past narration).
  void _showSettingsSnack(BuildContext context,
      {required String pov, required String mode, required String length}) {
    final povLabel = pov == 'first' ? 'First person' : 'Third person';
    final modeLabel = chatModeLabel(mode);
    final lenLabel = length[0].toUpperCase() + length.substring(1);
    _showSceneSnack(context,
        '$povLabel · $modeLabel · $lenLabel — applies from your next message.');
  }

  /// Shared floating confirmation for scene-setting changes.
  void _showSceneSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: EverloreTheme.void3,
          duration: const Duration(seconds: 3),
          content: Row(
            children: [
              const Icon(Icons.auto_awesome,
                  color: EverloreTheme.gold, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: EverloreTheme.ui(
                      size: 13, color: EverloreTheme.parchment),
                ),
              ),
            ],
          ),
        ),
      );
  }

  void _showThoughtsSheet(BuildContext context) {
    final cubit = context.read<PlayCubit>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: EverloreTheme.void2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => BlocProvider.value(
        value: cubit,
        child: BlocBuilder<PlayCubit, PlayState>(
          builder: (ctx, state) => _ThoughtsSheet(
            characters: state.characters,
            focusedCharacterId: state.instance?.focusCharacterId,
            // In sentient/character worlds the protagonist is the creator's
            // locked main character — not player-editable. (GM worlds: the
            // protagonist is the player's own character, so it stays editable.)
            isSentientWorld: state.template?.isSentient ?? false,
            onFocus: (id) {
              cubit.updateSettings(focusCharacterId: id);
              Navigator.pop(sheetCtx);
              String? name;
              for (final c in state.characters) {
                if (c.id == id) {
                  name = c.canonicalName;
                  break;
                }
              }
              _showSceneSnack(
                context,
                name != null
                    ? 'Now focusing on $name — applies from your next message.'
                    : 'Focus updated — applies from your next message.',
              );
            },
            onClearFocus: () {
              cubit.updateSettings(clearFocusCharacter: true);
              Navigator.pop(sheetCtx);
              _showSceneSnack(
                context, 'Focus cleared — applies from your next message.');
            },
            onEdit: (c) => _showCharacterEdit(ctx, cubit, c),
          ),
        ),
      ),
    );
  }

  void _showCharacterEdit(
      BuildContext context, PlayCubit cubit, CharacterProfile character) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: EverloreTheme.void2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (editCtx) => _CharacterEditSheet(
        character: character,
        onSave: (updates) {
          cubit.editCharacter(character.id, updates);
          Navigator.pop(editCtx);
        },
      ),
    );
  }

  void _confirmResetChat(BuildContext context, PlayCubit cubit) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: EverloreTheme.void2,
        title: Text('Reset this chat?',
            style: EverloreTheme.serifDisplay(
                size: 18, color: EverloreTheme.parchment)),
        content: Text(
          'The entire story, its memories, and everything that happened will be '
          'wiped, and the chat will start over from the opening line. The world '
          'and character themselves are kept. This cannot be undone.',
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
              final messenger = ScaffoldMessenger.of(context);
              cubit.resetChat();
              messenger.showSnackBar(
                SnackBar(
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: EverloreTheme.void3,
                  content: Text('Chat reset — starting over from the beginning.',
                      style: EverloreTheme.ui(
                          size: 13, color: EverloreTheme.parchment)),
                ),
              );
            },
            child: Text('Reset',
                style: EverloreTheme.ui(color: EverloreTheme.gold)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteChat(BuildContext context, String instanceId) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: EverloreTheme.void2,
        title: Text('Delete this chat?',
            style: EverloreTheme.serifDisplay(
                size: 18, color: EverloreTheme.parchment)),
        content: Text(
          'This playthrough, its entire story, and all its memories will be '
          'permanently deleted. This cannot be undone.',
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
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final messenger = ScaffoldMessenger.of(context);
              final router = GoRouter.of(context);
              try {
                await HomeRepository.deleteInstance(instanceId);
                await LocalDb.clearInstanceCache(instanceId);
                router.go('/'); // home route is '/', not '/home'
              } catch (_) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Could not delete the chat. Try again.',
                        style: EverloreTheme.ui(
                            size: 13, color: EverloreTheme.parchment)),
                    backgroundColor: EverloreTheme.void3,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Text('Delete',
                style: EverloreTheme.ui(
                    color: EverloreTheme.crimson, weight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showTurnMenu(BuildContext context, GameEvent event, bool canReplay) {
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
            if (canReplay)
              ListTile(
                leading: const Icon(Icons.refresh_rounded,
                    color: EverloreTheme.cyanBright),
                title: Text('Replay response',
                    style: EverloreTheme.ui(
                        size: 15, color: EverloreTheme.parchment)),
                subtitle: Text(
                  'Generate an improved alternative for this turn.',
                  style: EverloreTheme.ui(size: 12, color: EverloreTheme.ash),
                ),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  cubit.replayAiResponse(event);
                },
              ),
            if (canReplay)
              const Divider(color: EverloreTheme.white10, height: 1),
            if ((event.aiResponse ?? '').trim().isNotEmpty)
              ListTile(
                leading: const Icon(Icons.edit_outlined,
                    color: EverloreTheme.violetBright),
                title: Text('Edit response',
                    style: EverloreTheme.ui(
                        size: 15, color: EverloreTheme.parchment)),
                subtitle: Text(
                  'Rewrite this AI turn and re-curate its memories.',
                  style: EverloreTheme.ui(size: 12, color: EverloreTheme.ash),
                ),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _showEditResponseDialog(context, cubit, event);
                },
              ),
            if ((event.aiResponse ?? '').trim().isNotEmpty)
              const Divider(color: EverloreTheme.white10, height: 1),
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

  void _showEditResponseDialog(
    BuildContext context,
    PlayCubit cubit,
    GameEvent event,
  ) {
    final controller = TextEditingController(text: event.aiResponse ?? '');
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: EverloreTheme.void2,
        title: Text('Edit AI response',
            style: EverloreTheme.serifDisplay(
                size: 18, color: EverloreTheme.parchment)),
        content: SizedBox(
          width: 560,
          child: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 14,
            minLines: 6,
            maxLength: 10000,
            style: EverloreTheme.aiText.copyWith(
              color: EverloreTheme.parchment,
              height: 1.45,
            ),
            decoration: InputDecoration(
              hintText: 'Rewrite the response...',
              hintStyle: EverloreTheme.ui(size: 13, color: EverloreTheme.ash),
              filled: true,
              fillColor: EverloreTheme.void3,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: EverloreTheme.goldDim.withValues(alpha: 0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: EverloreTheme.goldDim.withValues(alpha: 0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: EverloreTheme.violet.withValues(alpha: 0.5)),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child:
                Text('Cancel', style: EverloreTheme.ui(color: EverloreTheme.ash)),
          ),
          TextButton(
            onPressed: () {
              final edited = controller.text.trim();
              Navigator.pop(dialogCtx);
              cubit.editAiResponse(event, edited);
            },
            child: Text('Save edit',
                style: EverloreTheme.ui(
                    color: EverloreTheme.violetBright,
                    weight: FontWeight.w700)),
          ),
        ],
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
          prev.isLoading != curr.isLoading ||
          prev.template != curr.template ||
          prev.characters.length != curr.characters.length ||
          (curr.events.isNotEmpty &&
              (prev.events.isNotEmpty ? prev.events.last.aiResponse : null) !=
                  curr.events.last.aiResponse),
      listener: (ctx, __) {
        _scrollToBottom();
        _maybeShowOnboarding(ctx);
      },
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
                    onMenu: () => _showChatMenu(context),
                    onThoughts: () => _showThoughtsSheet(context),
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
                                  // Replay is only valid for the LATEST turn that
                                  // has player input (server rejects earlier turns
                                  // and the opening greeting). Gate the UI to match
                                  // so the action never surfaces where it errors.
                                  final isLatest =
                                      index == state.events.length - 1;
                                  final isReplaying =
                                      state.replayingEventId == event.id;
                                  // Replay only on the latest player-input turn,
                                  // and never while another replay is streaming.
                                  final canReplay = !event.isOptimistic &&
                                      isLatest &&
                                      state.replayingEventId == null &&
                                      !state.isGenerating &&
                                      (event.playerInput?.trim().isNotEmpty ??
                                          false);
                                  return NarrativeBubble(
                                    event: event,
                                    isReplaying: isReplaying,
                                    onLongPress: (!event.isOptimistic &&
                                            event.sequence > 0 &&
                                            state.replayingEventId == null)
                                        ? () => _showTurnMenu(
                                            context, event, canReplay)
                                        : null,
                                    onReplay: canReplay
                                        ? () => context
                                            .read<PlayCubit>()
                                            .replayAiResponse(event)
                                        : null,
                                    onSelectReplayVariant: (index) => context
                                        .read<PlayCubit>()
                                        .selectReplayVariant(event, index),
                                  );
                                },
                              ),
                  ),

                  PlayerInput(
                    isGenerating: state.isGenerating,
                    isConnected: state.isConnected,
                    onSend: (msg) =>
                        context.read<PlayCubit>().sendMessage(msg),
                    onContinue: () =>
                        context.read<PlayCubit>().continueStory(),
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
  final VoidCallback onMenu;
  final VoidCallback onThoughts;

  const _PlayHeader({
    required this.title,
    required this.accent,
    required this.isConnected,
    required this.hasInstance,
    required this.onBack,
    required this.onChronicle,
    required this.onMenu,
    required this.onThoughts,
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
              if (hasInstance) ...[
                _RuneButton(
                  icon: Icons.history_edu,
                  onTap: onChronicle,
                  accent: EverloreTheme.gold,
                  tooltip: 'Lore Tome',
                ),
                const SizedBox(width: 4),
                _RuneButton(
                  icon: Icons.psychology_alt_outlined,
                  onTap: onThoughts,
                  accent: EverloreTheme.cyanBright,
                  tooltip: 'Character Thoughts',
                ),
                const SizedBox(width: 4),
                _RuneButton(
                  icon: Icons.more_vert,
                  onTap: onMenu,
                  accent: EverloreTheme.ash,
                  tooltip: 'More',
                ),
              ],
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

/// In-chat scene settings: narration POV, tone, and delete.
///
/// Changes are STAGED locally and only committed when the player taps "Apply".
/// The button stays disabled until something actually differs from the saved
/// values, so the player gets a clear, deliberate save action plus feedback.
class _SettingsSheet extends StatefulWidget {
  final String initialPov;
  final String initialMode;
  final String initialLength;
  final void Function(String pov, String mode, String length) onApply;
  final VoidCallback onReset;
  final VoidCallback onDelete;

  const _SettingsSheet({
    required this.initialPov,
    required this.initialMode,
    required this.initialLength,
    required this.onApply,
    required this.onReset,
    required this.onDelete,
  });

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late String _pov;
  late String _mode;
  late String _length;

  bool get _dirty =>
      _pov != widget.initialPov ||
      _mode != widget.initialMode ||
      _length != widget.initialLength;

  @override
  void initState() {
    super.initState();
    _pov = widget.initialPov;
    _mode = widget.initialMode;
    _length = widget.initialLength;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: EverloreTheme.void4,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Scene Settings',
                style: EverloreTheme.serifDisplay(
                    size: 18, color: EverloreTheme.parchment)),
            const SizedBox(height: 18),

            // Narration POV
            Text('NARRATION',
                style: EverloreTheme.ui(
                    size: 11,
                    weight: FontWeight.w700,
                    spacing: 1.5,
                    color: EverloreTheme.gold)),
            const SizedBox(height: 8),
            Row(
              children: [
                _SegOption(
                  label: 'Third person',
                  selected: _pov == 'third',
                  onTap: () => setState(() => _pov = 'third'),
                ),
                const SizedBox(width: 8),
                _SegOption(
                  label: 'First person',
                  selected: _pov == 'first',
                  onTap: () => setState(() => _pov = 'first'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Chat Mode — how the chat flows (pacing/intent). Orthogonal to the
            // creator-locked narrative voice, which players cannot change here.
            Text('MODE',
                style: EverloreTheme.ui(
                    size: 11,
                    weight: FontWeight.w700,
                    spacing: 1.5,
                    color: EverloreTheme.gold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kChatModes.map((m) {
                final selected = _mode == m.key;
                return GestureDetector(
                  onTap: () => setState(() => _mode = m.key),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: selected
                          ? EverloreTheme.gold.withValues(alpha: 0.12)
                          : EverloreTheme.void3,
                      border: Border.all(
                        color: selected
                            ? EverloreTheme.gold.withValues(alpha: 0.5)
                            : EverloreTheme.goldDim.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      m.label,
                      style: EverloreTheme.ui(
                        size: 13,
                        color: selected
                            ? EverloreTheme.gold
                            : EverloreTheme.ash,
                        weight:
                            selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Text(
              _mode == 'ardent'
                  ? 'Ardent escalates intensity — explicit content only in mature worlds with NSFW enabled in your preferences.'
                  : kChatModes
                      .firstWhere((m) => m.key == _mode,
                          orElse: () => kChatModes.first)
                      .blurb,
              style: EverloreTheme.ui(
                  size: 11, color: EverloreTheme.ash, height: 1.4),
            ),
            const SizedBox(height: 20),

            // Message length — drives both the prompt directive and max tokens.
            Text('REPLY LENGTH',
                style: EverloreTheme.ui(
                    size: 11,
                    weight: FontWeight.w700,
                    spacing: 1.5,
                    color: EverloreTheme.gold)),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final l in kMessageLengths) ...[
                  _SegOption(
                    label: l.$2,
                    selected: _length == l.$1,
                    onTap: () => setState(() => _length = l.$1),
                  ),
                  if (l != kMessageLengths.last) const SizedBox(width: 8),
                ],
              ],
            ),
            const SizedBox(height: 22),

            // Deliberate save: disabled until a setting actually changes, so the
            // player always knows the apply took effect (snackbar confirms when).
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap:
                    _dirty ? () => widget.onApply(_pov, _mode, _length) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: _dirty
                        ? EverloreTheme.gold.withValues(alpha: 0.16)
                        : EverloreTheme.void3,
                    border: Border.all(
                      color: _dirty
                          ? EverloreTheme.gold.withValues(alpha: 0.6)
                          : EverloreTheme.goldDim.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _dirty ? 'Apply changes' : 'No changes',
                      style: EverloreTheme.ui(
                        size: 14,
                        weight: FontWeight.w600,
                        color: _dirty
                            ? EverloreTheme.gold
                            : EverloreTheme.ash.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Divider(color: EverloreTheme.white10, height: 1),
            const SizedBox(height: 6),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.restart_alt_rounded,
                  color: EverloreTheme.gold),
              title: Text('Reset this chat',
                  style: EverloreTheme.ui(
                      size: 15, color: EverloreTheme.parchment)),
              subtitle: Text(
                'Start over from the opening line. Keeps the world & character.',
                style: EverloreTheme.ui(size: 12, color: EverloreTheme.ash),
              ),
              onTap: widget.onReset,
            ),
            const Divider(color: EverloreTheme.white10, height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.delete_outline,
                  color: EverloreTheme.crimson),
              title: Text('Delete this chat',
                  style: EverloreTheme.ui(
                      size: 15, color: EverloreTheme.crimson)),
              onTap: widget.onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _SegOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SegOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selected
                ? EverloreTheme.violet.withValues(alpha: 0.15)
                : EverloreTheme.void3,
            border: Border.all(
              color: selected
                  ? EverloreTheme.violet.withValues(alpha: 0.5)
                  : EverloreTheme.goldDim.withValues(alpha: 0.2),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: EverloreTheme.ui(
                size: 13,
                color: selected
                    ? EverloreTheme.parchment
                    : EverloreTheme.ash,
                weight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThoughtsSheet extends StatelessWidget {
  final List<CharacterProfile> characters;
  final String? focusedCharacterId;
  final ValueChanged<String> onFocus;
  final VoidCallback onClearFocus;
  final ValueChanged<CharacterProfile> onEdit;
  final bool isSentientWorld;

  const _ThoughtsSheet({
    required this.characters,
    required this.focusedCharacterId,
    required this.onFocus,
    required this.onClearFocus,
    required this.onEdit,
    required this.isSentientWorld,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: EverloreTheme.void4,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Character Thoughts',
                style: EverloreTheme.serifDisplay(
                    size: 18, color: EverloreTheme.parchment)),
            const SizedBox(height: 6),
            Text(
              'Private attitudes and inner thoughts inferred from the story. '
              'These are not spoken dialogue.',
              style: EverloreTheme.ui(
                  size: 12, color: EverloreTheme.ash, height: 1.4),
            ),
            const SizedBox(height: 12),
            if (focusedCharacterId != null)
              TextButton.icon(
                onPressed: onClearFocus,
                icon: const Icon(Icons.clear, size: 16, color: EverloreTheme.ash),
                label: Text('Clear focus',
                    style: EverloreTheme.ui(size: 13, color: EverloreTheme.ash)),
              ),
            if (characters.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No side-character profiles yet. Keep playing and the codex will build itself.',
                  style: EverloreTheme.ui(
                      size: 13, color: EverloreTheme.ash, height: 1.5),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: characters.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: EverloreTheme.white10, height: 1),
                  itemBuilder: (_, i) {
                    final c = characters[i];
                    final isFocused = c.id == focusedCharacterId;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              c.canonicalName,
                              style: EverloreTheme.ui(
                                size: 15,
                                color: EverloreTheme.parchment,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (c.isProtagonist) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: EverloreTheme.gold.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color:
                                      EverloreTheme.goldDim.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Text(
                                'PROTAGONIST',
                                style: EverloreTheme.ui(
                                  size: 9,
                                  color: EverloreTheme.gold,
                                  weight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (c.dispositionToPlayer.trim().isNotEmpty)
                              Text(
                                'Disposition: ${c.dispositionToPlayer}',
                                style: EverloreTheme.ui(
                                    size: 12, color: EverloreTheme.goldDim),
                              ),
                            if (c.hiddenThought.trim().isNotEmpty)
                              Text(
                                '"${c.hiddenThought}"',
                                style: EverloreTheme.ui(
                                  size: 13,
                                  color: EverloreTheme.ash,
                                  height: 1.45,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                          ],
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // The creator's locked protagonist (sentient/character
                          // worlds) can't be edited; everything else can.
                          if (!(c.isProtagonist && isSentientWorld))
                            IconButton(
                              onPressed: () => onEdit(c),
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.edit_outlined,
                                  size: 17, color: EverloreTheme.ash),
                              tooltip: 'Edit',
                            ),
                          if (!c.isProtagonist)
                            TextButton(
                              onPressed: isFocused ? null : () => onFocus(c.id),
                              child: Text(
                                isFocused ? 'Focused' : 'Focus',
                                style: EverloreTheme.ui(
                                  size: 12,
                                  color: isFocused
                                      ? EverloreTheme.gold
                                      : EverloreTheme.violetBright,
                                  weight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
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

/// GM onboarding: the player names their own character (the protagonist) on
/// first entry into a Game Master world. Minimal + skippable.
class _ProtagonistOnboardingSheet extends StatefulWidget {
  final void Function(String name, String? identity) onBegin;
  final VoidCallback onSkip;

  const _ProtagonistOnboardingSheet({required this.onBegin, required this.onSkip});

  @override
  State<_ProtagonistOnboardingSheet> createState() =>
      _ProtagonistOnboardingSheetState();
}

class _ProtagonistOnboardingSheetState
    extends State<_ProtagonistOnboardingSheet> {
  final _nameCtrl = TextEditingController();
  final _identityCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _identityCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _nameCtrl.text.trim().length >= 2;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 18,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: EverloreTheme.void4,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Who are you in this world?',
              style: EverloreTheme.serifDisplay(
                  size: 18, color: EverloreTheme.parchment)),
          const SizedBox(height: 6),
          Text(
            'Name your character — the world will remember you and the story '
            'will revolve around your journey.',
            style: EverloreTheme.ui(
                size: 12.5, color: EverloreTheme.ash, height: 1.45),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            style: EverloreTheme.ui(size: 15, color: EverloreTheme.parchment),
            onChanged: (_) => setState(() {}),
            decoration: _dec('Your name (e.g. Kael, Aria…)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _identityCtrl,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 2,
            minLines: 1,
            style: EverloreTheme.ui(size: 14, color: EverloreTheme.parchment),
            decoration: _dec('Optional: who are you? (a wandering knight…)'),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              TextButton(
                onPressed: widget.onSkip,
                child: Text('Skip',
                    style: EverloreTheme.ui(size: 14, color: EverloreTheme.ash)),
              ),
              const Spacer(),
              GestureDetector(
                onTap: ready
                    ? () => widget.onBegin(
                          _nameCtrl.text.trim(),
                          _identityCtrl.text.trim().isEmpty
                              ? null
                              : _identityCtrl.text.trim(),
                        )
                    : null,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: ready
                        ? const LinearGradient(colors: [
                            EverloreTheme.goldGlow,
                            EverloreTheme.gold
                          ])
                        : null,
                    color: ready ? null : EverloreTheme.void3,
                  ),
                  child: Text('Begin',
                      style: EverloreTheme.ui(
                          size: 14,
                          color: ready
                              ? EverloreTheme.void1
                              : EverloreTheme.ash,
                          weight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: EverloreTheme.ui(size: 13, color: EverloreTheme.ash),
        filled: true,
        fillColor: EverloreTheme.void4.withValues(alpha: 0.5),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              BorderSide(color: EverloreTheme.goldDim.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              BorderSide(color: EverloreTheme.goldDim.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: EverloreTheme.gold, width: 1.2),
        ),
      );
}

/// Player edit of a character/protagonist card. Facts & current-state are edited
/// as one-per-line text. Removing a fact triggers server-side memory
/// supersession so stale memories can't resurface and fight the edit.
class _CharacterEditSheet extends StatefulWidget {
  final CharacterProfile character;
  final ValueChanged<Map<String, dynamic>> onSave;

  const _CharacterEditSheet({required this.character, required this.onSave});

  @override
  State<_CharacterEditSheet> createState() => _CharacterEditSheetState();
}

class _CharacterEditSheetState extends State<_CharacterEditSheet> {
  late final TextEditingController _name;
  late final TextEditingController _role;
  late final TextEditingController _appearance;
  late final TextEditingController _persona;
  late final TextEditingController _facts;
  late final TextEditingController _state;
  late final TextEditingController _disposition;
  late final TextEditingController _thought;

  @override
  void initState() {
    super.initState();
    final c = widget.character;
    _name = TextEditingController(text: c.canonicalName);
    _role = TextEditingController(text: c.role);
    _appearance = TextEditingController(text: c.appearance);
    _persona = TextEditingController(text: c.persona);
    _facts = TextEditingController(text: c.immutableFacts.join('\n'));
    _state = TextEditingController(text: c.mutableState.join('\n'));
    _disposition = TextEditingController(text: c.dispositionToPlayer);
    _thought = TextEditingController(text: c.hiddenThought);
  }

  @override
  void dispose() {
    for (final ctrl in [
      _name, _role, _appearance, _persona, _facts, _state, _disposition, _thought
    ]) {
      ctrl.dispose();
    }
    super.dispose();
  }

  List<String> _lines(String raw) => raw
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  void _save() {
    final updates = <String, dynamic>{
      'canonical_name': _name.text.trim(),
      'role': _role.text.trim(),
      'appearance': _appearance.text.trim(),
      'persona': _persona.text.trim(),
      'immutable_facts': _lines(_facts.text),
      'mutable_state': _lines(_state.text),
      'disposition_to_player': _disposition.text.trim(),
      'hidden_thought': _thought.text.trim(),
    };
    widget.onSave(updates);
  }

  @override
  Widget build(BuildContext context) {
    final isProtagonist = widget.character.isProtagonist;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 14,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: EverloreTheme.void4,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(isProtagonist ? 'Edit Protagonist' : 'Edit Character',
                      style: EverloreTheme.serifDisplay(
                          size: 18, color: EverloreTheme.parchment)),
                  if (isProtagonist) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.star, size: 14, color: EverloreTheme.gold),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Your edits are canon — the story honors them next turn. '
                'Removing a fact also clears stale memories about it.',
                style: EverloreTheme.ui(
                    size: 12, color: EverloreTheme.ash, height: 1.4),
              ),
              const SizedBox(height: 14),
              _field('Name', _name),
              _field('Role', _role),
              _field('Appearance', _appearance, maxLines: 2),
              _field('Persona', _persona, maxLines: 3),
              _field('Facts (one per line)', _facts, maxLines: 5),
              _field('Current state (one per line)', _state, maxLines: 3),
              if (!isProtagonist) ...[
                _field('Disposition toward you', _disposition, maxLines: 2),
                _field('Hidden thought', _thought, maxLines: 2),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel',
                        style:
                            EverloreTheme.ui(size: 14, color: EverloreTheme.ash)),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _name.text.trim().length >= 2 ? _save : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: const LinearGradient(
                            colors: [EverloreTheme.goldGlow, EverloreTheme.gold]),
                      ),
                      child: Text('Save',
                          style: EverloreTheme.ui(
                              size: 14,
                              color: EverloreTheme.void1,
                              weight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: EverloreTheme.ui(
                  size: 12,
                  color: EverloreTheme.parchment,
                  weight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            maxLines: maxLines,
            minLines: 1,
            onChanged: (_) => setState(() {}),
            textCapitalization: TextCapitalization.sentences,
            style: EverloreTheme.ui(
                size: 14, color: EverloreTheme.parchment, height: 1.4),
            decoration: InputDecoration(
              filled: true,
              fillColor: EverloreTheme.void4.withValues(alpha: 0.5),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color: EverloreTheme.goldDim.withValues(alpha: 0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color: EverloreTheme.goldDim.withValues(alpha: 0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: EverloreTheme.gold, width: 1.2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
