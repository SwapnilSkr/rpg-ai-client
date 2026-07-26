import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../state/play_cubit.dart';
import 'widgets/narrative_bubble.dart';
import 'widgets/player_input.dart';
import 'widgets/world_state_bar.dart';
import 'widgets/choice_chips.dart';
import 'widgets/milestone_toast.dart';
import 'widgets/bond_meters.dart';
import 'widgets/bond_rail.dart';
import 'widgets/story_timeline_sheet.dart';
import '../../../../app/theme/nexus_theme.dart';
import '../../../shared/app_icons.dart';
import '../../../shared/models/event.dart';
import '../../../shared/models/character_profile.dart';
import '../../../shared/models/persona.dart';
import '../../personas/data/persona_repository.dart';
import '../../../shared/chat_modes.dart';
import '../../../shared/narrative_styles.dart';
import '../../../shared/narration_tones.dart';
import '../../../shared/widgets/top_confirmation_toast.dart';
import '../../../shared/widgets/everlore_network_image.dart';
import '../../../core/storage/local_db.dart';
import '../../home/data/home_repository.dart';
import '../../chronicle/data/chronicle_repository.dart';
import 'realm_screen.dart';

/// Whether [c] should be treated as in the current scene. [presence] is the set
/// of lowercased names the latest turn reported present, or null when presence
/// is unknown (legacy turns) — in which case we assume present rather than mark
/// everyone absent. Matches against the card's canonical name AND its aliases:
/// the server normalizes `present_characters` to canonical names, but matching
/// aliases too keeps presence correct if an alias/role string slips through
/// (an LLM hiccup, a legacy event, a not-yet-re-seeded world). The protagonist
/// is always present.
bool _scenePresent(CharacterProfile c, Set<String>? presence) {
  if (presence == null) return true;
  if (c.isProtagonist) return true;
  final name = c.canonicalName.trim().toLowerCase();
  if (name.isNotEmpty && presence.contains(name)) return true;
  return c.aliases.any((a) {
    final alias = a.trim().toLowerCase();
    return alias.isNotEmpty && presence.contains(alias);
  });
}

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
  int? _lastSeenEventCount;
  bool? _lastSeenLoading;
  Object? _lastSeenTemplate;
  bool _followLatest = true;
  double? _olderLoadAnchorPixels;
  double? _olderLoadAnchorExtent;

  /// One-shot composer prefill consumed by [PlayerInput] (bond actions).
  final _composerDraft = ValueNotifier<String?>(null);

  /// Set when the player opens Chronicle / Thoughts / Settings from the realm
  /// menu. Cleared if they dismiss the menu outright or finish an in-sheet action.
  bool _pendingRealmMenuReturn = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateFollowLatest);
  }

  void _updateFollowLatest() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    // Readers can inspect earlier turns without new tokens pulling them back.
    // Reaching the tail automatically resumes follow mode.
    _followLatest = position.maxScrollExtent - position.pixels < 96;
    if (!_followLatest &&
        position.maxScrollExtent > 0 &&
        position.pixels <= position.minScrollExtent + 140) {
      _loadOlderHistoryIfNeeded();
    }
  }

  void _loadOlderHistoryIfNeeded() {
    if (!mounted || !_scrollController.hasClients) return;
    final cubit = context.read<PlayCubit>();
    final state = cubit.state;
    if (!state.hasOlderEvents || state.isLoadingOlder) return;
    final position = _scrollController.position;
    _olderLoadAnchorPixels = position.pixels;
    _olderLoadAnchorExtent = position.maxScrollExtent;
    cubit.loadOlderEvents();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateFollowLatest);
    _composerDraft.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Contextual bond actions for [character] — every action is sugar over a
  /// normal player turn (prefilled composer) or a memory lens, never a
  /// separate game system. "Ask about" topics are grounded in the character's
  /// current state so the prompts are specific, not a dangling quote. The
  /// server owns that display copy; raw current-state strings remain internal
  /// continuity data and are never rendered as action labels.
  void _showBondActions(BuildContext context, CharacterProfile character) {
    final cubit = context.read<PlayCubit>();
    final name = character.canonicalName;
    // Scene-aware: when the latest turn reports who is present, a character not
    // in it is "elsewhere" — you seek them out rather than turning to thin air.
    final presence = _presentNames(cubit.state);
    final isPresent = _scenePresent(character, presence);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: EverloreTheme.void2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: EverloreTheme.serifDisplay(
                  size: 18,
                  color: EverloreTheme.parchment,
                ),
              ),
              if (character.relationship != null) ...[
                const SizedBox(height: 8),
                BondMeters(
                  meters: character.relationship!,
                  moments: character.relationshipMoments,
                ),
              ],
              if (character.relationshipState?.summary.trim().isNotEmpty ??
                  false) ...[
                const SizedBox(height: 10),
                Text(
                  character.relationshipState!.summary,
                  style: EverloreTheme.ui(
                    size: 12,
                    color: EverloreTheme.ash,
                    height: 1.35,
                  ),
                ),
              ],
              // Tell the player where this character stands relative to the
              // scene, so "Seek out" vs "Approach" reads as intentional.
              if (presence != null) ...[
                const SizedBox(height: 10),
                _PresenceTag(present: isPresent),
              ],
              const SizedBox(height: 12),
              if (isPresent) ...[
                _BondActionTile(
                  icon: Icons.record_voice_over_outlined,
                  label: 'Approach $name',
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _composerDraft.value = '*I approach $name.* ';
                  },
                ),
                // These are server-authored and validated alongside the
                // character's canonical state. Never turn raw mutable_state
                // strings into UI copy here: values like "irritated" are
                // continuity facts, not necessarily grammatical topics.
                ...(() {
                  final hints = character.interactionHints;
                  if (hints.isEmpty) {
                    return [
                      _BondActionTile(
                        icon: Icons.help_outline,
                        label: 'Check in with $name',
                        onTap: () {
                          Navigator.pop(sheetCtx);
                          _composerDraft.value =
                              '*I turn to $name.* "How are you feeling?" ';
                        },
                      ),
                    ];
                  }
                  return [
                    for (final hint in hints)
                      _BondActionTile(
                        icon: Icons.help_outline,
                        label: hint.label,
                        onTap: () {
                          Navigator.pop(sheetCtx);
                          _composerDraft.value = hint.draft;
                        },
                      ),
                  ];
                })(),
              ] else
                // Elsewhere — the move is to go find them, not address the room.
                _BondActionTile(
                  icon: Icons.directions_walk_outlined,
                  label: 'Seek out $name',
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _composerDraft.value = '*I set out to find $name.* ';
                  },
                ),
              _BondActionTile(
                icon: Icons.history_edu_outlined,
                label: 'What $name remembers of you',
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _showEntityMemories(
                    context,
                    cubit,
                    name,
                    title: 'What $name remembers',
                    emptyText:
                        'Nothing yet — your story together is still unwritten.',
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Non-character world entities (places, things, factions) tagged on memory
  /// atoms, deduped case-insensitively and bounded. These become the tappable
  /// lore links in the prose; character names are handled separately.
  List<String> _loreEntities(PlayState state) {
    final charLower = {
      for (final c in state.characters) c.canonicalName.toLowerCase(),
    };
    final seen = <String>{};
    final out = <String>[];
    for (final m in state.memories) {
      for (final e in m.entities) {
        final t = e.trim();
        if (t.length < 4) continue;
        final l = t.toLowerCase();
        if (charLower.contains(l) || seen.contains(l)) continue;
        seen.add(l);
        out.add(t);
        if (out.length >= 40) return out;
      }
    }
    return out;
  }

  /// Who is in the scene right now, lowercased — read from the latest settled
  /// turn's `present_characters`. Returns null only when presence is unknown
  /// (legacy events that predate the projection). A known empty list means the
  /// player is alone, so the roster correctly shows everyone else as elsewhere.
  Set<String>? _presentNames(PlayState state) {
    for (var i = state.events.length - 1; i >= 0; i--) {
      final e = state.events[i];
      if (e.isOptimistic) continue;
      if (!e.presenceKnown) return null;
      return e.presentCharacters.map((n) => n.trim().toLowerCase()).toSet();
    }
    return null;
  }

  /// Preserve the original display names for the journey sheet. This is kept
  /// separate from [_presentNames], whose normalized values are for matching.
  List<String> _presentCharacterNames(PlayState state) {
    for (var i = state.events.length - 1; i >= 0; i--) {
      final event = state.events[i];
      if (event.isOptimistic) continue;
      return event.presentCharacters;
    }
    return const [];
  }

  /// A memory lens for any entity (character, place, thing) — the rich-atom
  /// memories that concern [name], titled by the caller.
  void _showEntityMemories(
    BuildContext context,
    PlayCubit cubit,
    String name, {
    required String title,
    required String emptyText,
  }) {
    final relevant =
        cubit.state.memories.where((m) => m.concerns(name)).toList()
          ..sort((a, b) => b.importance.compareTo(a.importance));
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: EverloreTheme.void2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: EverloreTheme.serifDisplay(
                  size: 18,
                  color: EverloreTheme.parchment,
                ),
              ),
              const SizedBox(height: 12),
              if (relevant.isEmpty)
                Text(
                  emptyText,
                  style: EverloreTheme.ui(
                    size: 13,
                    color: EverloreTheme.ash,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 380),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: relevant.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final m = relevant[i];
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            m.unresolvedThread
                                ? Icons.pending_outlined
                                : Icons.bookmark_border,
                            size: 14,
                            color: m.unresolvedThread
                                ? EverloreTheme.ember
                                : EverloreTheme.goldDim,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              m.text,
                              style: EverloreTheme.ui(
                                size: 13,
                                color: EverloreTheme.parchment.withValues(
                                  alpha: 0.9,
                                ),
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
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

  Future<void> _showProtagonistOnboarding(
    BuildContext context,
    PlayCubit cubit,
  ) async {
    List<ReusableProtagonist> reusable = const [];
    try {
      reusable = await cubit.loadReusableProtagonists();
    } catch (_) {
      // A new protagonist must remain possible if this optional convenience
      // lookup is unavailable.
    }
    if (!mounted || !context.mounted) return;
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
        reusable: reusable,
        onBegin: (name, identity) {
          cubit.setPlayerProtagonist(name, identity: identity);
          Navigator.pop(sheetCtx);
        },
        onReuse: (source) async {
          final reused = await cubit.reusePlayerProtagonist(source);
          if (reused && sheetCtx.mounted) Navigator.pop(sheetCtx);
        },
        onSkip: () {
          cubit.skipProtagonistOnboarding();
          Navigator.pop(sheetCtx);
        },
      ),
    );
  }

  void _showRealmMenu(BuildContext context) {
    var navigatingFromMenu = false;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _RealmMenuSheet(
        onChronicle: () {
          navigatingFromMenu = true;
          _pendingRealmMenuReturn = true;
          Navigator.pop(sheetCtx);
          _openChronicleFromMenu(context);
        },
        onTimeline: () {
          navigatingFromMenu = true;
          _pendingRealmMenuReturn = true;
          Navigator.pop(sheetCtx);
          _showTimelineSheet(context);
        },
        onThoughts: () {
          navigatingFromMenu = true;
          _pendingRealmMenuReturn = true;
          Navigator.pop(sheetCtx);
          _showThoughtsSheet(context);
        },
        onSettings: () {
          navigatingFromMenu = true;
          _pendingRealmMenuReturn = true;
          Navigator.pop(sheetCtx);
          _showChatMenu(context);
        },
      ),
    ).then((_) {
      if (!navigatingFromMenu) _pendingRealmMenuReturn = false;
    });
  }

  /// Re-open the realm menu after the route / sheet the player backed out of.
  void _maybeRestoreRealmMenu(BuildContext context) {
    if (!mounted || !_pendingRealmMenuReturn) return;
    _pendingRealmMenuReturn = false;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 140));
      if (!mounted || !context.mounted) return;
      _showRealmMenu(context);
    });
  }

  Future<void> _openChronicleFromMenu(BuildContext context) async {
    final instanceId = context.read<PlayCubit>().instanceId;
    await context.push('/chronicle/$instanceId');
    if (!mounted || !context.mounted) return;
    _maybeRestoreRealmMenu(context);
  }

  Future<void> _showChatMenu(BuildContext context) async {
    final cubit = context.read<PlayCubit>();
    final instance = cubit.state.instance;
    List<Persona> personas = const [];
    try {
      personas = await PersonaRepository.list();
    } catch (_) {
      personas = const [];
    }
    if (!mounted || !context.mounted) return;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close scene settings',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (dialogContext, _, __) => Align(
        alignment: Alignment.centerRight,
        child: _DraggableSettingsDrawer(
          onDismiss: () => Navigator.of(dialogContext).pop(),
          child: Material(
            color: EverloreTheme.void2,
            child: SizedBox(
              width: MediaQuery.sizeOf(dialogContext).width.clamp(320.0, 430.0),
              height: double.infinity,
              child: _SettingsSheet(
                initialPov: instance?.narrationPov ?? 'third',
                initialMode: instance?.mode ?? kDefaultChatMode,
                initialVoiceOverride: instance?.narrativeStyleOverride,
                worldVoice: cubit.state.template?.narrativeStyle ?? '',
                initialTone: instance?.narrationTone ?? kDefaultNarrationTone,
                initialLength: instance?.messageLength ?? 'medium',
                initialPersonaId: instance?.personaId,
                // Global personas describe the player in sentient worlds. GM worlds use
                // template-scoped protagonist cards from the first-entry sheet instead.
                isGmWorld: !(cubit.state.template?.isSentient ?? false),
                personas: personas,
                onClose: () => Navigator.of(dialogContext).pop(),
                onApply:
                    (pov, mode, voiceOverride, tone, length, personaId) async {
                      final saved = await cubit.updateSettings(
                        narrationPov: pov,
                        mode: mode,
                        narrativeStyleOverride: voiceOverride,
                        clearNarrativeStyleOverride: voiceOverride == null,
                        narrationTone: tone,
                        messageLength: length,
                        personaId: personaId,
                        clearPersona: personaId == null,
                      );
                      if (!saved || !mounted || !context.mounted) return false;
                      _pendingRealmMenuReturn = false;
                      Navigator.of(dialogContext).pop();
                      _showSettingsSnack(
                        context,
                        pov: pov,
                        mode: mode,
                        voiceOverride: voiceOverride,
                        worldVoice: cubit.state.template?.narrativeStyle ?? '',
                        tone: tone,
                        length: length,
                      );
                      return true;
                    },
                onReset: () {
                  _pendingRealmMenuReturn = false;
                  Navigator.of(dialogContext).pop();
                  _confirmResetChat(context, cubit);
                },
                onDelete: () {
                  _pendingRealmMenuReturn = false;
                  Navigator.of(dialogContext).pop();
                  _confirmDeleteChat(context, cubit.instanceId);
                },
              ),
            ),
          ),
        ),
      ),
      transitionBuilder: (_, animation, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
        child: child,
      ),
    ).then((_) {
      if (mounted && context.mounted) _maybeRestoreRealmMenu(context);
    });
  }

  /// Friendly confirmation that staged scene settings were saved and when they
  /// take effect (settings only shape future turns, never past narration).
  void _showSettingsSnack(
    BuildContext context, {
    required String pov,
    required String mode,
    required String? voiceOverride,
    required String worldVoice,
    required String tone,
    required String length,
  }) {
    final povLabel = pov == 'first' ? 'First person' : 'Third person';
    final modeLabel = chatModeLabel(mode);
    final voiceLabel = narrativeStyleLabel(voiceOverride ?? worldVoice);
    final lenLabel = length[0].toUpperCase() + length.substring(1);
    _showSceneSnack(
      context,
      '$povLabel · $modeLabel · $voiceLabel · ${narrationToneLabel(tone)} · $lenLabel — applies from your next message.',
    );
  }

  /// Shared top confirmation for scene-setting changes; it stays clear of the
  /// composer and uses the same presentation as relationship confirmations.
  void _showSceneSnack(BuildContext context, String message) {
    showTopConfirmationToast(
      context,
      icon: Icons.auto_awesome,
      message: message,
    );
  }

  void _showTimelineSheet(BuildContext context) {
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
          builder: (ctx, state) => StoryTimelineSheet(
            milestones: state.milestones,
            onOpenChronicle: () {
              _pendingRealmMenuReturn = false;
              Navigator.pop(sheetCtx);
              context.push('/chronicle/${cubit.instanceId}');
            },
          ),
        ),
      ),
    ).then((_) {
      if (mounted && context.mounted) _maybeRestoreRealmMenu(context);
    });
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
            presentNames: _presentNames(state),
            focusedCharacterId: state.instance?.focusCharacterId,
            // In sentient/character worlds the protagonist is the creator's
            // locked main character — not player-editable. (GM worlds: the
            // protagonist is the player's own character, so it stays editable.)
            isSentientWorld: state.template?.isSentient ?? false,
            onFocus: (id) {
              _pendingRealmMenuReturn = false;
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
              _pendingRealmMenuReturn = false;
              cubit.updateSettings(clearFocusCharacter: true);
              Navigator.pop(sheetCtx);
              _showSceneSnack(
                context,
                'Focus cleared — applies from your next message.',
              );
            },
            onEdit: (c) => _showCharacterEdit(ctx, cubit, c),
            onAct: (c) {
              _pendingRealmMenuReturn = false;
              Navigator.pop(sheetCtx);
              _showBondActions(context, c);
            },
          ),
        ),
      ),
    ).then((_) {
      if (mounted && context.mounted) _maybeRestoreRealmMenu(context);
    });
  }

  void _showCharacterEdit(
    BuildContext context,
    PlayCubit cubit,
    CharacterProfile character,
  ) {
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
        title: Text(
          'Reset this chat?',
          style: EverloreTheme.serifDisplay(
            size: 18,
            color: EverloreTheme.parchment,
          ),
        ),
        content: Text(
          'The entire story, its memories, and everything that happened will be '
          'wiped, and the chat will start over from the opening line. The world '
          'and character themselves are kept. This cannot be undone.',
          style: EverloreTheme.ui(
            size: 14,
            color: EverloreTheme.ash,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              'Cancel',
              style: EverloreTheme.ui(color: EverloreTheme.ash),
            ),
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
                  content: Text(
                    'Chat reset — starting over from the beginning.',
                    style: EverloreTheme.ui(
                      size: 13,
                      color: EverloreTheme.parchment,
                    ),
                  ),
                ),
              );
            },
            child: Text(
              'Reset',
              style: EverloreTheme.ui(color: EverloreTheme.gold),
            ),
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
        title: Text(
          'Delete this chat?',
          style: EverloreTheme.serifDisplay(
            size: 18,
            color: EverloreTheme.parchment,
          ),
        ),
        content: Text(
          'This playthrough, its entire story, and all its memories will be '
          'permanently deleted. This cannot be undone.',
          style: EverloreTheme.ui(
            size: 14,
            color: EverloreTheme.ash,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              'Cancel',
              style: EverloreTheme.ui(color: EverloreTheme.ash),
            ),
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
                    content: Text(
                      'Could not delete the chat. Try again.',
                      style: EverloreTheme.ui(
                        size: 13,
                        color: EverloreTheme.parchment,
                      ),
                    ),
                    backgroundColor: EverloreTheme.void3,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Text(
              'Delete',
              style: EverloreTheme.ui(
                color: EverloreTheme.crimson,
                weight: FontWeight.w700,
              ),
            ),
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
                leading: const Icon(
                  Icons.refresh_rounded,
                  color: EverloreTheme.cyanBright,
                ),
                title: Text(
                  'Replay response',
                  style: EverloreTheme.ui(
                    size: 15,
                    color: EverloreTheme.parchment,
                  ),
                ),
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
                leading: const Icon(
                  Icons.copy_rounded,
                  color: EverloreTheme.ash,
                ),
                title: Text(
                  'Copy response',
                  style: EverloreTheme.ui(
                    size: 15,
                    color: EverloreTheme.parchment,
                  ),
                ),
                subtitle: Text(
                  'Copy this AI turn to the clipboard.',
                  style: EverloreTheme.ui(size: 12, color: EverloreTheme.ash),
                ),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  Clipboard.setData(
                    ClipboardData(text: event.aiResponse?.trim() ?? ''),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Copied to clipboard',
                        style: EverloreTheme.ui(
                          size: 13,
                          color: EverloreTheme.parchment,
                        ),
                      ),
                      duration: const Duration(seconds: 1),
                      backgroundColor: EverloreTheme.void3,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            if ((event.aiResponse ?? '').trim().isNotEmpty)
              const Divider(color: EverloreTheme.white10, height: 1),
            if ((event.aiResponse ?? '').trim().isNotEmpty)
              ListTile(
                leading: const Icon(
                  Icons.edit_outlined,
                  color: EverloreTheme.violetBright,
                ),
                title: Text(
                  'Edit response',
                  style: EverloreTheme.ui(
                    size: 15,
                    color: EverloreTheme.parchment,
                  ),
                ),
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
              leading: const Icon(
                Icons.history_toggle_off,
                color: EverloreTheme.crimson,
              ),
              title: Text(
                'Rewind to here',
                style: EverloreTheme.ui(
                  size: 15,
                  color: EverloreTheme.parchment,
                ),
              ),
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
        title: Text(
          'Edit AI response',
          style: EverloreTheme.serifDisplay(
            size: 18,
            color: EverloreTheme.parchment,
          ),
        ),
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
                borderSide: BorderSide(
                  color: EverloreTheme.goldDim.withValues(alpha: 0.2),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: EverloreTheme.goldDim.withValues(alpha: 0.2),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: EverloreTheme.violet.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              'Cancel',
              style: EverloreTheme.ui(color: EverloreTheme.ash),
            ),
          ),
          TextButton(
            onPressed: () {
              final edited = controller.text.trim();
              Navigator.pop(dialogCtx);
              cubit.editAiResponse(event, edited);
            },
            child: Text(
              'Save edit',
              style: EverloreTheme.ui(
                color: EverloreTheme.violetBright,
                weight: FontWeight.w700,
              ),
            ),
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
        title: Text(
          'Rewind the tale?',
          style: EverloreTheme.serifDisplay(
            size: 18,
            color: EverloreTheme.parchment,
          ),
        ),
        content: Text(
          'This turn and everything after it will be permanently removed, and the '
          'world will roll back to this point. This cannot be undone.',
          style: EverloreTheme.ui(
            size: 14,
            color: EverloreTheme.ash,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              'Cancel',
              style: EverloreTheme.ui(color: EverloreTheme.ash),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              cubit.rewind(sequence);
            },
            child: Text(
              'Rewind',
              style: EverloreTheme.ui(
                color: EverloreTheme.crimson,
                weight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _scrollToBottom({bool force = false, bool animated = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final pos = _scrollController.position;
      final isNearBottom = pos.maxScrollExtent - pos.pixels < 120;
      if (!force && !_followLatest && !isNearBottom) return;

      _followLatest = true;

      if (animated) {
        _scrollController.animateTo(
          pos.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scrollController.jumpTo(pos.maxScrollExtent);
      }

      // A choice row or the last revealed paragraph can increase the extent on
      // the next layout frame. Settle once more so it cannot appear stranded
      // above the composer until the reader drags the feed manually.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients || !_followLatest) return;
        final settled = _scrollController.position;
        if (settled.maxScrollExtent - settled.pixels > 1) {
          _scrollController.jumpTo(settled.maxScrollExtent);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PlayCubit, PlayState>(
      listenWhen: (prev, curr) {
        final lastResponseChanged =
            curr.events.isNotEmpty &&
            (prev.events.isNotEmpty ? prev.events.last.aiResponse : null) !=
                curr.events.last.aiResponse;
        final previousChoices = prev.events.isEmpty
            ? ''
            : prev.events.last.choices
                  .map(
                    (choice) =>
                        '${choice.label}\u0000${choice.kind}\u0000${choice.send}',
                  )
                  .join('\u0001');
        final currentChoices = curr.events.isEmpty
            ? ''
            : curr.events.last.choices
                  .map(
                    (choice) =>
                        '${choice.label}\u0000${choice.kind}\u0000${choice.send}',
                  )
                  .join('\u0001');
        return prev.events.length != curr.events.length ||
            prev.isLoading != curr.isLoading ||
            prev.isLoadingOlder != curr.isLoadingOlder ||
            prev.template != curr.template ||
            prev.characters.length != curr.characters.length ||
            previousChoices != currentChoices ||
            lastResponseChanged;
      },
      listener: (ctx, state) {
        final preserveOlderAnchor =
            _olderLoadAnchorExtent != null && !state.isLoadingOlder;
        if (preserveOlderAnchor) {
          final oldPixels = _olderLoadAnchorPixels!;
          final oldExtent = _olderLoadAnchorExtent!;
          _olderLoadAnchorPixels = null;
          _olderLoadAnchorExtent = null;
          // Prepending rows changes maxScrollExtent. Offset by that exact growth
          // so the paragraph under the reader's eye remains there.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_scrollController.hasClients) return;
            final position = _scrollController.position;
            final target = (oldPixels + position.maxScrollExtent - oldExtent)
                .clamp(position.minScrollExtent, position.maxScrollExtent);
            _scrollController.jumpTo(target);
          });
        }
        // This listener receives the new state from BlocConsumer, but the cubit
        // already holds it too. Track the previous values locally so entering a
        // realm or sending a message always reveals the latest beat.
        final structuralChange =
            _lastSeenEventCount != state.events.length ||
            _lastSeenLoading != state.isLoading ||
            _lastSeenTemplate != state.template;
        if (!preserveOlderAnchor) {
          _scrollToBottom(
            // New windows/turns belong at the tail. Token and choice updates only
            // follow when the reader remains at that tail.
            force: structuralChange,
            animated: structuralChange,
          );
        }
        _lastSeenEventCount = state.events.length;
        _lastSeenLoading = state.isLoading;
        _lastSeenTemplate = state.template;
        _maybeShowOnboarding(ctx);
      },
      builder: (context, state) {
        final title = state.template?.title ?? '';
        final bgUrl = state.template?.imageUrl ?? '';
        final latestTag = state.events.isNotEmpty
            ? state.events.last.sceneTag
            : null;
        final accent = EverloreTheme.sceneAccent(latestTag);

        return Scaffold(
          backgroundColor: EverloreTheme.void0,
          body: Stack(
            children: [
              // Full-bleed backdrop: the world's generated image (with a dark
              // readability scrim) when present, else the scene-tinted gradient.
              if (bgUrl.isNotEmpty) ...[
                Positioned.fill(
                  child: EverloreNetworkImage(
                    imageUrl: bgUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: 1440,
                    errorWidget: _AtmosphereBackground(accent: accent),
                    semanticLabel: title,
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          EverloreTheme.void0.withValues(alpha: 0.82),
                          EverloreTheme.void0.withValues(alpha: 0.62),
                          EverloreTheme.void0.withValues(alpha: 0.88),
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ),
              ] else
                // Scene tone shifts (combat reddens, romance warms) ease in
                // over a beat instead of snapping with the new scene tag.
                Positioned.fill(
                  child: TweenAnimationBuilder<Color?>(
                    tween: ColorTween(end: accent),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeInOut,
                    builder: (context, c, _) =>
                        _AtmosphereBackground(accent: c ?? accent),
                  ),
                ),

              // Content
              Column(
                children: [
                  _PlayHeader(
                    title: title,
                    accent: accent,
                    isConnected: state.isConnected,
                    onBack: () => context.pop(),
                    onOpenRealm:
                        state.instance != null && state.template != null
                        ? () => context.push(
                            '/realm/${state.instance!.id}',
                            extra: RealmScreenArgs(
                              instance: state.instance!,
                              template: state.template!,
                              characters: state.characters,
                              onReset: () => _confirmResetChat(
                                context,
                                context.read<PlayCubit>(),
                              ),
                              onDelete: () => _confirmDeleteChat(
                                context,
                                context.read<PlayCubit>().instanceId,
                              ),
                            ),
                          )
                        : null,
                    onOpenSettings: state.instance != null
                        ? () => _showChatMenu(context)
                        : null,
                  ),

                  if (state.instance != null &&
                      state.instance!.worldState.isNotEmpty)
                    WorldStateBar(
                      worldState: state.instance!.worldState,
                      definitions:
                          state.template?.baseStatsTemplate ?? const {},
                      expanded: _statsExpanded,
                      onToggle: () =>
                          setState(() => _statsExpanded = !_statsExpanded),
                      deltas: state.lastStatDeltas,
                    ),

                  // Always-on relationship presence — the active cast with live
                  // bond rings. Renders nothing until a bond actually exists.
                  BondRail(
                    characters: state.characters,
                    presentNames: _presentNames(state),
                    onTapCharacter: (c) => _showBondActions(context, c),
                  ),

                  if (state.error != null)
                    _ErrorBar(
                      message: state.error!,
                      onRetry:
                          (state.lastFailedInput?.trim().isNotEmpty ?? false)
                          ? () => context.read<PlayCubit>().retryLastFailed()
                          : null,
                      onDismiss: () => context.read<PlayCubit>().clearError(),
                    ),

                  Expanded(
                    child: state.isLoading && state.events.isEmpty
                        ? const _LoadingNarrative()
                        : state.events.isEmpty
                        ? const _EmptyNarrative()
                        : Builder(
                            builder: (context) {
                              // Tap-to-play chips bloom under the latest settled
                              // turn — a list row so they scroll with the story.
                              final latest = state.events.isNotEmpty
                                  ? state.events.last
                                  : null;
                              // Settled turn: the finalized event carries choices.
                              final settledChoices =
                                  latest != null &&
                                  !latest.isOptimistic &&
                                  latest.choices.isNotEmpty &&
                                  !state.isGenerating;
                              // Early path: the narrator's choices arrived ahead of
                              // generation_complete (choices_ready) and are attached
                              // to the still-in-flight optimistic turn — show them
                              // with the settled prose. Guards on isGenerating +
                              // isOptimistic so a stale flag can never misfire.
                              final previewChoices =
                                  latest != null &&
                                  latest.isOptimistic &&
                                  state.isGenerating &&
                                  state.choicesPreview &&
                                  latest.choices.isNotEmpty;
                              final showChoices =
                                  (settledChoices || previewChoices) &&
                                  state.replayingEventId == null &&
                                  state.isConnected;
                              // Fallback window: prose has settled but no choices yet
                              // (narrator emitted none → they come with the metadata
                              // pass at generation_complete). Show a quiet "preparing
                              // options" hint so the wait reads as intentional, not a
                              // frozen finished bubble.
                              final showChoicesLoading =
                                  !showChoices &&
                                  latest != null &&
                                  latest.isOptimistic &&
                                  state.isGenerating &&
                                  !state.narrativeStreaming &&
                                  state.replayingEventId == null &&
                                  state.isConnected;
                              final showTrailingSlot =
                                  showChoices || showChoicesLoading;
                              final itemCount =
                                  state.events.length +
                                  (state.hasOlderEvents ? 1 : 0) +
                                  (showTrailingSlot ? 1 : 0);
                              // World entities (places/things) harvested from
                              // memory atoms — computed once for all bubbles.
                              final loreEntities = _loreEntities(state);
                              return ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.fromLTRB(
                                  2,
                                  16,
                                  2,
                                  20,
                                ),
                                itemCount: itemCount,
                                itemBuilder: (context, index) {
                                  if (state.hasOlderEvents && index == 0) {
                                    return _OlderHistoryLoader(
                                      totalEvents: state.totalEvents,
                                      isLoading: state.isLoadingOlder,
                                      onTap: _loadOlderHistoryIfNeeded,
                                    );
                                  }
                                  if (showTrailingSlot &&
                                      index == itemCount - 1) {
                                    if (showChoices) {
                                      return ChoiceChips(
                                        choices: latest.choices,
                                        enabled: true,
                                        // Drop the pre-formatted move into the composer
                                        // (fills + focuses) so the player can edit the
                                        // narration/dialogue before sending it.
                                        onChoose: (choice) =>
                                            _composerDraft.value = choice,
                                      );
                                    }
                                    return const _ChoicesPreparingHint();
                                  }

                                  final eventIndex = state.hasOlderEvents
                                      ? index - 1
                                      : index;
                                  final event = state.events[eventIndex];
                                  // Replay is valid for the latest generated AI
                                  // turn, including Continue turns. The seed
                                  // greeting is not generated, so keep it excluded.
                                  final isLatest =
                                      eventIndex == state.events.length - 1;
                                  final isReplaying =
                                      state.replayingEventId == event.id;
                                  // Tie the in-bubble "writing" treatment to the
                                  // PROSE stream, not the whole turn: it clears the
                                  // moment the narrative is fully revealed, even
                                  // while post-prose bookkeeping (choices, codex)
                                  // still runs under isGenerating.
                                  final isStreaming =
                                      isReplaying ||
                                      (event.isOptimistic &&
                                          state.narrativeStreaming);
                                  final hasAiResponse = (event.aiResponse ?? '')
                                      .trim()
                                      .isNotEmpty;
                                  final isSeedGreeting =
                                      event.modelUsed == 'seed' ||
                                      (event.modelUsed.isEmpty &&
                                          event.sequence == 1 &&
                                          (event.playerInput?.trim().isEmpty ??
                                              true));
                                  final canReplay =
                                      !event.isOptimistic &&
                                      isLatest &&
                                      state.replayingEventId == null &&
                                      !state.isGenerating &&
                                      hasAiResponse &&
                                      !isSeedGreeting;
                                  final canContinue =
                                      !event.isOptimistic &&
                                      isLatest &&
                                      state.replayingEventId == null &&
                                      !state.isGenerating &&
                                      state.isConnected &&
                                      ((event.aiResponse ?? '')
                                          .trim()
                                          .isNotEmpty);
                                  return NarrativeBubble(
                                    event: event,
                                    isReplaying: isReplaying,
                                    isStreaming: isStreaming,
                                    characterNames: [
                                      for (final c in state.characters)
                                        if (!(c.isProtagonist &&
                                            !(state.template?.isSentient ??
                                                false)))
                                          c.canonicalName,
                                    ],
                                    onCharacterTap: (name) {
                                      final lower = name.toLowerCase();
                                      for (final c in state.characters) {
                                        if (c.canonicalName.toLowerCase() ==
                                            lower) {
                                          _showBondActions(context, c);
                                          return;
                                        }
                                      }
                                    },
                                    loreEntities: loreEntities,
                                    onEntityTap: (name) => _showEntityMemories(
                                      context,
                                      context.read<PlayCubit>(),
                                      name,
                                      title: name,
                                      emptyText:
                                          'The story has not marked $name yet.',
                                    ),
                                    // Tracking unnamed people, naming them later, and
                                    // resolving their kinship is now done ENTIRELY in
                                    // the backend (stubs + presence tiers + the kinship
                                    // graph) — the player no longer taps prose names to
                                    // "track" them. The inline affordance is removed;
                                    // correction still lives behind the turn long-press.
                                    onLongPress:
                                        (!event.isOptimistic &&
                                            event.sequence > 0 &&
                                            state.replayingEventId == null)
                                        ? () => _showTurnMenu(
                                            context,
                                            event,
                                            canReplay,
                                          )
                                        : null,
                                    onReplay: canReplay
                                        ? () => context
                                              .read<PlayCubit>()
                                              .replayAiResponse(event)
                                        : null,
                                    onContinue: canContinue
                                        ? () => context
                                              .read<PlayCubit>()
                                              .continueStory()
                                        : null,
                                    onSelectReplayVariant: (index) => context
                                        .read<PlayCubit>()
                                        .selectReplayVariant(event, index),
                                  );
                                },
                              );
                            },
                          ),
                  ),

                  PlayerInput(
                    isGenerating: state.isGenerating || state.isRewinding,
                    isConnected: state.isConnected,
                    notice: state.notice,
                    onSend: (msg) => context.read<PlayCubit>().sendMessage(msg),
                    onContinue: () => context.read<PlayCubit>().continueStory(),
                    onAdvance: (span) =>
                        context.read<PlayCubit>().continueStory(advance: span),
                    onTravel: (destination, companions, advance) =>
                        context.read<PlayCubit>().travelTo(
                          destination: destination,
                          companions: companions,
                          advance: advance,
                        ),
                    onRelationship:
                        (character, relation, correction, replacesRelation) =>
                            context.read<PlayCubit>().setRelationship(
                              character: character,
                              relation: relation,
                              correction: correction,
                              replacesRelation: replacesRelation,
                            ),
                    characters: state.characters,
                    presentCharacters: _presentCharacterNames(state),
                    loadKnownDestinations: () async {
                      final locations = await ChronicleRepository.getLocations(
                        context.read<PlayCubit>().instanceId,
                      );
                      final current = locations.currentLocation?.name
                          .trim()
                          .toLowerCase();
                      return locations.places
                          .map((place) => place.name)
                          .where((name) => name.trim().toLowerCase() != current)
                          .toList();
                    },
                    onRenameCharacter: (character, newName) =>
                        context.read<PlayCubit>().editCharacter(character.id, {
                          'canonical_name': newName,
                        }),
                    loadRelationCandidates: () =>
                        context.read<PlayCubit>().loadRelationCandidates(),
                    loadConfirmedKinship: () =>
                        context.read<PlayCubit>().loadConfirmedKinship(),
                    onResolveRelationCandidate:
                        (candidateId, action, relation) =>
                            context.read<PlayCubit>().resolveRelationCandidate(
                              candidateId,
                              action,
                              relation,
                            ),
                    draft: _composerDraft,
                  ),
                ],
              ),

              if (state.isRewinding)
                const Positioned.fill(child: _RewindVeil()),

              // Brass-seal milestone toast — one-shot, auto-dismissing.
              if (state.lastMilestone != null)
                MilestoneToast(
                  label: state.lastMilestone!,
                  stamp: state.milestoneStamp,
                  onDismissed: () => context.read<PlayCubit>().clearMilestone(),
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
              accent.withValues(alpha: 0.16),
              EverloreTheme.void0,
            ),
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
                  colors: [accent.withValues(alpha: 0.20), Colors.transparent],
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
  final VoidCallback onBack;
  final VoidCallback? onOpenRealm;
  final VoidCallback? onOpenSettings;

  const _PlayHeader({
    required this.title,
    required this.accent,
    required this.isConnected,
    required this.onBack,
    this.onOpenRealm,
    this.onOpenSettings,
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
                child: InkWell(
                  onTap: onOpenRealm,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
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
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child: EvIcon(
                                isConnected
                                    ? AppIcons.realmActive
                                    : AppIcons.reconnecting,
                                key: ValueKey(isConnected),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isConnected ? 'Connected' : 'Reconnecting…',
                              style: EverloreTheme.ui(
                                size: 11,
                                spacing: 0.5,
                                color: isConnected
                                    ? EverloreTheme.ash.withValues(alpha: 0.75)
                                    : EverloreTheme.crimson.withValues(
                                        alpha: 0.85,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (onOpenSettings != null)
                _RuneButton(
                  icon: Icons.menu_rounded,
                  onTap: onOpenSettings!,
                  accent: EverloreTheme.gold,
                  tooltip: 'Scene settings',
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quiet placeholder shown after the prose has settled but before the choices
/// arrive (the fallback path, where the narrator emitted no tail and the options
/// come from the metadata pass at generation_complete). Reads as "still preparing"
/// so the finished bubble never looks frozen with a locked composer and no moves.
class _ChoicesPreparingHint extends StatefulWidget {
  const _ChoicesPreparingHint();

  @override
  State<_ChoicesPreparingHint> createState() => _ChoicesPreparingHintState();
}

class _ChoicesPreparingHintState extends State<_ChoicesPreparingHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (!WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = Text(
      'Weaving your options…',
      style: EverloreTheme.ui(
        size: 13,
        color: EverloreTheme.ash,
        fontStyle: FontStyle.italic,
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.45, end: 0.95).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
        ),
        child: label,
      ),
    );
  }
}

class _OlderHistoryLoader extends StatelessWidget {
  final int totalEvents;
  final bool isLoading;
  final VoidCallback onTap;

  const _OlderHistoryLoader({
    required this.totalEvents,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      child: Center(
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: EverloreTheme.void2.withValues(alpha: 0.74),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: EverloreTheme.gold.withValues(alpha: 0.26),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: EverloreTheme.gold,
                    ),
                  )
                else
                  const EvIcon(AppIcons.chronicle, size: 18),
                const SizedBox(width: 8),
                Text(
                  isLoading
                      ? 'Unfurling earlier chapters…'
                      : totalEvents > 0
                      ? 'Load earlier chapters ($totalEvents turns)'
                      : 'Load earlier chapters',
                  style: EverloreTheme.ui(
                    size: 12,
                    weight: FontWeight.w700,
                    color: EverloreTheme.parchment,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Forged bottom sheet — Chronicle, Thoughts, and Scene Settings in one place.
class _RealmMenuSheet extends StatelessWidget {
  final VoidCallback onChronicle;
  final VoidCallback onTimeline;
  final VoidCallback onThoughts;
  final VoidCallback onSettings;

  const _RealmMenuSheet({
    required this.onChronicle,
    required this.onTimeline,
    required this.onThoughts,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: EverloreTheme.void2,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Color(0x33D8B878))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: EverloreTheme.goldDim.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Realm Menu',
                  style: EverloreTheme.serifDisplay(
                    size: 17,
                    color: EverloreTheme.parchment,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Chronicle, cast, and how this story flows.',
                  style: EverloreTheme.ui(size: 12, color: EverloreTheme.ash),
                ),
                const SizedBox(height: 18),
                _RealmMenuChoice(
                  icon: AppIcons.chronicle,
                  title: 'Chronicle',
                  subtitle: 'Read every turn in this story.',
                  onTap: onChronicle,
                ),
                const SizedBox(height: 12),
                _RealmMenuChoice(
                  materialIcon: Icons.timeline_outlined,
                  title: 'Story Timeline',
                  subtitle: 'The landmarks your story has crossed.',
                  onTap: onTimeline,
                ),
                const SizedBox(height: 12),
                _RealmMenuChoice(
                  materialIcon: Icons.psychology_alt_outlined,
                  title: 'Thoughts',
                  subtitle: 'Who is here and who you are speaking to.',
                  onTap: onThoughts,
                ),
                const SizedBox(height: 12),
                _RealmMenuChoice(
                  icon: AppIcons.voice,
                  title: 'Scene Settings',
                  subtitle: 'Voice, length, and narration style.',
                  onTap: onSettings,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RealmMenuChoice extends StatelessWidget {
  final String? icon;
  final IconData? materialIcon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _RealmMenuChoice({
    this.icon,
    this.materialIcon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  }) : assert(icon != null || materialIcon != null);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [EverloreTheme.void3, EverloreTheme.void2],
          ),
          border: Border.all(
            color: EverloreTheme.goldDim.withValues(alpha: 0.25),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(2, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(-0.3, -0.4),
                  colors: [
                    EverloreTheme.gold.withValues(alpha: 0.22),
                    EverloreTheme.void2,
                  ],
                ),
                border: Border.all(
                  color: EverloreTheme.gold.withValues(alpha: 0.4),
                ),
              ),
              child: icon != null
                  ? EvIcon(icon!, size: 24)
                  : Icon(materialIcon, color: EverloreTheme.gold, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: EverloreTheme.parchment,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: EverloreTheme.uiFamily,
                      color: EverloreTheme.ash,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: EverloreTheme.ash, size: 18),
          ],
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
            color: subtle ? Colors.transparent : accent.withValues(alpha: 0.25),
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

/// A rewind rebuilds several server-side projections. The old chat remains as
/// visual context, but this opaque barrier prevents it being read as settled or
/// interacted with until the authoritative replacement window is loaded.
class _RewindVeil extends StatelessWidget {
  const _RewindVeil();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: EverloreTheme.void0.withValues(alpha: 0.66),
      child: Center(
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
              'Rewinding to this turn…',
              style: EverloreTheme.ui(
                size: 14,
                color: EverloreTheme.ash,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
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
                  color: EverloreTheme.goldDim.withValues(alpha: 0.35),
                ),
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

/// Right-side drawer that visibly follows a horizontal gesture. A small pull
/// left is treated as resistance; pulling/flicking right closes the sheet.
class _DraggableSettingsDrawer extends StatefulWidget {
  final Widget child;
  final VoidCallback onDismiss;

  const _DraggableSettingsDrawer({
    required this.child,
    required this.onDismiss,
  });

  @override
  State<_DraggableSettingsDrawer> createState() =>
      _DraggableSettingsDrawerState();
}

class _DraggableSettingsDrawerState extends State<_DraggableSettingsDrawer> {
  double _offset = 0;
  bool _settling = false;

  void _update(DragUpdateDetails details) {
    // The panel is already fully open at x=0. Let a leftward pull show only a
    // little elastic resistance, while a rightward pull tracks the finger.
    final next = _offset + details.delta.dx;
    setState(() {
      _settling = false;
      _offset = next < 0 ? (next * 0.22).clamp(-16.0, 0.0) : next;
    });
  }

  void _end(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (_offset > 88 || velocity > 700) {
      widget.onDismiss();
      return;
    }
    setState(() {
      _settling = true;
      _offset = 0;
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: _update,
      onHorizontalDragEnd: _end,
      child: AnimatedSlide(
        duration: _settling ? const Duration(milliseconds: 180) : Duration.zero,
        curve: Curves.easeOut,
        offset: Offset(_offset / constraints.maxWidth, 0),
        child: widget.child,
      ),
    ),
  );
}

/// In-chat scene settings: narration POV, mode, voice, tone, and reply length.
///
/// Changes are STAGED locally and only committed when the player taps "Apply".
/// The button stays disabled until something actually differs from the saved
/// values, so the player gets a clear, deliberate save action plus feedback.
class _SettingsSheet extends StatefulWidget {
  final String initialPov;
  final String initialMode;
  final String? initialVoiceOverride;
  final String worldVoice;
  final String initialTone;
  final String initialLength;
  final String? initialPersonaId;
  final bool isGmWorld;
  final List<Persona> personas;
  final Future<bool> Function(
    String pov,
    String mode,
    String? voiceOverride,
    String tone,
    String length,
    String? personaId,
  )
  onApply;
  final VoidCallback? onClose;
  final VoidCallback onReset;
  final VoidCallback onDelete;

  const _SettingsSheet({
    required this.initialPov,
    required this.initialMode,
    required this.initialVoiceOverride,
    required this.worldVoice,
    required this.initialTone,
    required this.initialLength,
    required this.initialPersonaId,
    required this.isGmWorld,
    required this.personas,
    required this.onApply,
    required this.onReset,
    required this.onDelete,
    this.onClose,
  });

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late String _pov;
  late String _mode;
  String? _voiceOverride;
  late String _tone;
  late String _length;
  String? _personaId;
  bool _isApplying = false;

  bool get _dirty =>
      _pov != widget.initialPov ||
      _mode != widget.initialMode ||
      _voiceOverride != widget.initialVoiceOverride ||
      _tone != widget.initialTone ||
      _length != widget.initialLength ||
      (!widget.isGmWorld && _personaId != widget.initialPersonaId);

  @override
  void initState() {
    super.initState();
    _pov = widget.initialPov;
    _mode = widget.initialMode;
    _voiceOverride = widget.initialVoiceOverride;
    _tone = widget.initialTone;
    _length = widget.initialLength;
    // Clamp to a selectable value: the saved persona may have been deleted, or
    // the list may have failed to load. A non-null DropdownButton value that is
    // absent from the items asserts at build time.
    _personaId = widget.personas.any((p) => p.id == widget.initialPersonaId)
        ? widget.initialPersonaId
        : null;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Scene Settings',
                      style: EverloreTheme.serifDisplay(
                        size: 20,
                        color: EverloreTheme.parchment,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close, color: EverloreTheme.ash),
                    tooltip: 'Close settings',
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Narration POV
              const _SettingsLabel(icon: AppIcons.pov, label: 'NARRATION'),
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

              // Chat Mode — how the chat flows (pacing/intent). It does not
              // control prose register; that is the Narration Tone below.
              const _SettingsLabel(icon: AppIcons.voice, label: 'MODE'),
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
                        horizontal: 14,
                        vertical: 8,
                      ),
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
                          weight: selected ? FontWeight.w600 : FontWeight.w400,
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
                          .firstWhere(
                            (m) => m.key == _mode,
                            orElse: () => kChatModes.first,
                          )
                          .blurb,
                style: EverloreTheme.ui(
                  size: 11,
                  color: EverloreTheme.ash,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              // Voice is the broad authored style; unlike Tone, it can move a
              // save from Noir to Romance, for example. Null keeps the creator's
              // world default without mutating that template for anyone else.
              const _SettingsLabel(
                icon: AppIcons.voice,
                label: 'NARRATIVE VOICE',
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                value: _voiceOverride,
                isExpanded: true,
                dropdownColor: EverloreTheme.void2,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: EverloreTheme.void3,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(
                      'World default — ${narrativeStyleLabel(widget.worldVoice)}',
                      overflow: TextOverflow.ellipsis,
                      style: EverloreTheme.ui(
                        size: 13,
                        color: EverloreTheme.parchment,
                      ),
                    ),
                  ),
                  for (final voice in kNarrativeStyles)
                    DropdownMenuItem<String?>(
                      value: voice.key,
                      child: Text(
                        voice.key.isEmpty
                            ? 'Neutral / no voice preset'
                            : voice.label,
                        overflow: TextOverflow.ellipsis,
                        style: EverloreTheme.ui(
                          size: 13,
                          color: EverloreTheme.parchment,
                        ),
                      ),
                    ),
                ],
                onChanged: (voice) => setState(() => _voiceOverride = voice),
              ),
              const SizedBox(height: 8),
              Text(
                _voiceOverride == null
                    ? 'Uses this world\'s authored voice. Your choice affects only this save.'
                    : kNarrativeStyles
                          .firstWhere(
                            (voice) => voice.key == _voiceOverride,
                            orElse: () => kNarrativeStyles.first,
                          )
                          .blurb,
                style: EverloreTheme.ui(
                  size: 11,
                  color: EverloreTheme.ash,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              // Narration tone is intentionally independent from Mode: Mode
              // controls pacing/initiative, while tone controls the actual
              // wording and literary register of future turns.
              const _SettingsLabel(
                icon: AppIcons.voice,
                label: 'NARRATION TONE',
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kNarrationTones.map((tone) {
                  final selected = _tone == tone.key;
                  return GestureDetector(
                    onTap: () => setState(() => _tone = tone.key),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
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
                        tone.label,
                        style: EverloreTheme.ui(
                          size: 13,
                          color: selected
                              ? EverloreTheme.gold
                              : EverloreTheme.ash,
                          weight: selected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Text(
                kNarrationTones
                    .firstWhere(
                      (tone) => tone.key == _tone,
                      orElse: () => kNarrationTones.first,
                    )
                    .blurb,
                style: EverloreTheme.ui(
                  size: 11,
                  color: EverloreTheme.ash,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              if (!widget.isGmWorld) ...[
                const _SettingsLabel(
                  icon: AppIcons.createCharacter,
                  label: 'YOUR PERSONA',
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  value: _personaId,
                  isExpanded: true,
                  dropdownColor: EverloreTheme.void2,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: EverloreTheme.void3,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(
                        'None',
                        style: EverloreTheme.ui(
                          size: 13,
                          color: EverloreTheme.ash,
                        ),
                      ),
                    ),
                    for (final p in widget.personas)
                      DropdownMenuItem<String?>(
                        value: p.id,
                        child: Text(
                          p.name,
                          overflow: TextOverflow.ellipsis,
                          style: EverloreTheme.ui(
                            size: 13,
                            color: EverloreTheme.parchment,
                          ),
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _personaId = v),
                ),
                const SizedBox(height: 8),
                Text(
                  'This is your reusable player identity. It is copied into this '
                  'story, so later persona edits do not rewrite past turns.',
                  style: EverloreTheme.ui(
                    size: 11,
                    color: EverloreTheme.ash,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Message length — drives both the prompt directive and max tokens.
              const _SettingsLabel(
                icon: AppIcons.length,
                label: 'REPLY LENGTH',
              ),
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
                  onTap: _dirty && !_isApplying
                      ? () async {
                          setState(() => _isApplying = true);
                          await widget.onApply(
                            _pov,
                            _mode,
                            _voiceOverride,
                            _tone,
                            _length,
                            widget.isGmWorld
                                ? widget.initialPersonaId
                                : _personaId,
                          );
                          if (mounted) setState(() => _isApplying = false);
                        }
                      : null,
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
                        _isApplying
                            ? 'Saving settings…'
                            : _dirty
                            ? 'Apply changes'
                            : 'No changes',
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
              const SizedBox(height: 14),
              _PlaythroughManagement(
                onReset: widget.onReset,
                onDelete: widget.onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Destructive playthrough actions stay available from settings without being
/// presented as ordinary fields. This row opens a separate decision modal.
class _PlaythroughManagement extends StatelessWidget {
  final VoidCallback onReset;
  final VoidCallback onDelete;

  const _PlaythroughManagement({required this.onReset, required this.onDelete});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openManagementModal(context),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              EverloreTheme.void4.withValues(alpha: 0.76),
              EverloreTheme.void2.withValues(alpha: 0.92),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: EverloreTheme.goldDim.withValues(alpha: 0.22),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              offset: Offset(0, 2),
              blurRadius: 4,
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.more_horiz_rounded, color: EverloreTheme.ash),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manage this playthrough',
                    style: EverloreTheme.ui(size: 13, color: EverloreTheme.ash),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Reset or remove this chat',
                    style: EverloreTheme.ui(
                      size: 11,
                      color: EverloreTheme.ash.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  void _openManagementModal(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (modalContext) => AlertDialog(
        backgroundColor: EverloreTheme.void2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: EverloreTheme.goldDim.withValues(alpha: 0.32),
          ),
        ),
        title: Text(
          'Manage this playthrough',
          style: EverloreTheme.serifDisplay(
            size: 19,
            color: EverloreTheme.parchment,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _managementAction(
              modalContext,
              Icons.restart_alt_rounded,
              'Reset this chat',
              'Start again from the opening line.',
              EverloreTheme.gold,
              onReset,
            ),
            const SizedBox(height: 8),
            _managementAction(
              modalContext,
              Icons.delete_outline,
              'Delete this chat',
              'Permanently remove this playthrough.',
              EverloreTheme.crimson,
              onDelete,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(modalContext).pop(),
            child: Text(
              'Cancel',
              style: EverloreTheme.ui(color: EverloreTheme.ash),
            ),
          ),
        ],
      ),
    );
  }

  Widget _managementAction(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    Color color,
    VoidCallback action,
  ) => Material(
    color: EverloreTheme.void3,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.of(context).pop();
        action();
      },
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: EverloreTheme.ui(
                      size: 14,
                      color: color,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: EverloreTheme.ui(size: 11, color: EverloreTheme.ash),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
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
                color: selected ? EverloreTheme.parchment : EverloreTheme.ash,
                weight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsLabel extends StatelessWidget {
  final String icon;
  final String label;

  const _SettingsLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        EvIcon(icon, size: 18),
        const SizedBox(width: 7),
        Text(
          label,
          style: EverloreTheme.ui(
            size: 11,
            weight: FontWeight.w700,
            spacing: 1.5,
            color: EverloreTheme.gold,
          ),
        ),
      ],
    );
  }
}

class _ThoughtsSheet extends StatelessWidget {
  final List<CharacterProfile> characters;
  final String? focusedCharacterId;
  final ValueChanged<String> onFocus;
  final VoidCallback onClearFocus;
  final ValueChanged<CharacterProfile> onEdit;
  final ValueChanged<CharacterProfile> onAct;
  final bool isSentientWorld;

  /// Lowercased names present in the current scene, or null when presence is
  /// unknown (older worlds). Drives the Here-now / Elsewhere sectioning.
  final Set<String>? presentNames;

  const _ThoughtsSheet({
    required this.characters,
    required this.focusedCharacterId,
    required this.onFocus,
    required this.onClearFocus,
    required this.onEdit,
    required this.onAct,
    required this.isSentientWorld,
    required this.presentNames,
  });

  bool _isPresent(CharacterProfile c) => _scenePresent(c, presentNames);

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
            Text(
              'Character Thoughts',
              style: EverloreTheme.serifDisplay(
                size: 18,
                color: EverloreTheme.parchment,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Private attitudes and inner thoughts inferred from the story. '
              'These are not spoken dialogue.',
              style: EverloreTheme.ui(
                size: 12,
                color: EverloreTheme.ash,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            if (focusedCharacterId != null)
              TextButton.icon(
                onPressed: onClearFocus,
                icon: const Icon(
                  Icons.clear,
                  size: 16,
                  color: EverloreTheme.ash,
                ),
                label: Text(
                  'Clear focus',
                  style: EverloreTheme.ui(size: 13, color: EverloreTheme.ash),
                ),
              ),
            if (characters.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No side-character profiles yet. Keep playing and the codex will build itself.',
                  style: EverloreTheme.ui(
                    size: 13,
                    color: EverloreTheme.ash,
                    height: 1.5,
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _rosterChildren(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Roster body: a flat list when presence is unknown, otherwise split into
  /// "Here now" / "Elsewhere" (the protagonist always counts as present).
  List<Widget> _rosterChildren() {
    const divider = Divider(color: EverloreTheme.white10, height: 1);
    Widget header(String label) => Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 2, 6),
      child: Text(
        label.toUpperCase(),
        style: EverloreTheme.ui(
          size: 10,
          color: EverloreTheme.goldDim,
          weight: FontWeight.w700,
          spacing: 1.4,
        ),
      ),
    );
    List<Widget> section(List<CharacterProfile> list) {
      final out = <Widget>[];
      for (var i = 0; i < list.length; i++) {
        if (i > 0) out.add(divider);
        out.add(_characterTile(list[i], list[i].id == focusedCharacterId));
      }
      return out;
    }

    if (presentNames == null) return section(characters);
    final here = characters.where(_isPresent).toList(growable: false);
    final away = characters
        .where((c) => !_isPresent(c))
        .toList(growable: false);
    return [
      if (here.isNotEmpty) ...[header('Here now'), ...section(here)],
      if (away.isNotEmpty) ...[header('Elsewhere'), ...section(away)],
    ];
  }

  Widget _characterTile(CharacterProfile c, bool isFocused) {
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
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: EverloreTheme.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: EverloreTheme.goldDim.withValues(alpha: 0.4),
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
                style: EverloreTheme.ui(size: 12, color: EverloreTheme.goldDim),
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
            // The bond ledger: how this character stands with
            // the player, made inspectable and playable.
            if (c.relationship != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: BondMeters(
                  meters: c.relationship!,
                  moments: c.relationshipMoments,
                  dense: true,
                ),
              ),
          ],
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => onAct(c),
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.handshake_outlined,
              size: 17,
              color: EverloreTheme.gold,
            ),
            tooltip: 'Act',
          ),
          // The creator's locked protagonist (sentient/character
          // worlds) can't be edited; everything else can.
          if (!(c.isProtagonist && isSentientWorld))
            IconButton(
              onPressed: () => onEdit(c),
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.edit_outlined,
                size: 17,
                color: EverloreTheme.ash,
              ),
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
  }
}

/// One row in the bond-actions sheet.
class _BondActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _BondActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: EverloreTheme.gold.withValues(alpha: 0.75),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: EverloreTheme.ui(
                  size: 14,
                  color: EverloreTheme.parchment,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 16,
              color: EverloreTheme.ash.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small status pill telling the player whether a character is in the scene
/// ("Here now") or away from it ("Elsewhere"), so the action below reads right.
class _PresenceTag extends StatelessWidget {
  final bool present;

  const _PresenceTag({required this.present});

  @override
  Widget build(BuildContext context) {
    final color = present ? EverloreTheme.verdant : EverloreTheme.ash;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color.withValues(alpha: present ? 0.9 : 0.5),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 7),
        Text(
          present ? 'Here now' : 'Elsewhere',
          style: EverloreTheme.ui(
            size: 11,
            color: color.withValues(alpha: 0.85),
            weight: FontWeight.w700,
            spacing: 0.6,
          ),
        ),
      ],
    );
  }
}

class _ErrorBar extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;
  final VoidCallback? onRetry;

  const _ErrorBar({
    required this.message,
    required this.onDismiss,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: EverloreTheme.crimson.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EverloreTheme.crimson.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: EverloreTheme.crimson,
            size: 16,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: EverloreTheme.ui(
                size: 13,
                color: EverloreTheme.crimson,
                height: 1.4,
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: EverloreTheme.crimson,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Retry',
                style: EverloreTheme.ui(size: 13, color: EverloreTheme.crimson),
              ),
            ),
          IconButton(
            icon: const Icon(
              Icons.close,
              color: EverloreTheme.crimson,
              size: 16,
            ),
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
  final Future<void> Function(ReusableProtagonist source) onReuse;
  final List<ReusableProtagonist> reusable;
  final VoidCallback onSkip;

  const _ProtagonistOnboardingSheet({
    required this.onBegin,
    required this.onReuse,
    required this.reusable,
    required this.onSkip,
  });

  @override
  State<_ProtagonistOnboardingSheet> createState() =>
      _ProtagonistOnboardingSheetState();
}

class _ProtagonistOnboardingSheetState
    extends State<_ProtagonistOnboardingSheet> {
  final _nameCtrl = TextEditingController();
  final _identityCtrl = TextEditingController();
  bool _isReusing = false;

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
          Text(
            'Who are you in this world?',
            style: EverloreTheme.serifDisplay(
              size: 18,
              color: EverloreTheme.parchment,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Name your character — the world will remember you and the story '
            'will revolve around your journey.',
            style: EverloreTheme.ui(
              size: 12.5,
              color: EverloreTheme.ash,
              height: 1.45,
            ),
          ),
          if (widget.reusable.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              'RETURN AS',
              style: EverloreTheme.ui(
                size: 11,
                color: EverloreTheme.gold,
                weight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Copies a protagonist from another playthrough of this world. '
              'Their stories stay separate.',
              style: EverloreTheme.ui(
                size: 12,
                color: EverloreTheme.ash,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.reusable.map((source) {
                final label = source.identity.trim().isEmpty
                    ? source.name
                    : '${source.name} · ${source.identity.trim()}';
                return GestureDetector(
                  onTap: _isReusing
                      ? null
                      : () async {
                          setState(() => _isReusing = true);
                          await widget.onReuse(source);
                          if (mounted) setState(() => _isReusing = false);
                        },
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 300),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: EverloreTheme.gold.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: EverloreTheme.gold.withValues(alpha: 0.38),
                      ),
                    ),
                    child: Text(
                      _isReusing ? 'Bringing them forward…' : label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: EverloreTheme.ui(
                        size: 13,
                        color: EverloreTheme.parchment,
                        height: 1.3,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            Text(
              'OR CREATE SOMEONE NEW',
              style: EverloreTheme.ui(
                size: 11,
                color: EverloreTheme.gold,
                weight: FontWeight.w700,
              ),
            ),
          ],
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
                child: Text(
                  'Skip',
                  style: EverloreTheme.ui(size: 14, color: EverloreTheme.ash),
                ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: ready
                        ? const LinearGradient(
                            colors: [
                              EverloreTheme.goldGlow,
                              EverloreTheme.gold,
                            ],
                          )
                        : null,
                    color: ready ? null : EverloreTheme.void3,
                  ),
                  child: Text(
                    'Begin',
                    style: EverloreTheme.ui(
                      size: 14,
                      color: ready ? EverloreTheme.void1 : EverloreTheme.ash,
                      weight: FontWeight.w700,
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

  InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: EverloreTheme.ui(size: 13, color: EverloreTheme.ash),
    filled: true,
    fillColor: EverloreTheme.void4.withValues(alpha: 0.5),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(
        color: EverloreTheme.goldDim.withValues(alpha: 0.2),
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(
        color: EverloreTheme.goldDim.withValues(alpha: 0.2),
      ),
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
      _name,
      _role,
      _appearance,
      _persona,
      _facts,
      _state,
      _disposition,
      _thought,
    ]) {
      ctrl.dispose();
    }
    super.dispose();
  }

  List<String> _lines(String raw) =>
      raw.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

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
                  Text(
                    isProtagonist ? 'Edit Protagonist' : 'Edit Character',
                    style: EverloreTheme.serifDisplay(
                      size: 18,
                      color: EverloreTheme.parchment,
                    ),
                  ),
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
                  size: 12,
                  color: EverloreTheme.ash,
                  height: 1.4,
                ),
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
                    child: Text(
                      'Cancel',
                      style: EverloreTheme.ui(
                        size: 14,
                        color: EverloreTheme.ash,
                      ),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _name.text.trim().length >= 2 ? _save : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: const LinearGradient(
                          colors: [EverloreTheme.goldGlow, EverloreTheme.gold],
                        ),
                      ),
                      child: Text(
                        'Save',
                        style: EverloreTheme.ui(
                          size: 14,
                          color: EverloreTheme.void1,
                          weight: FontWeight.w700,
                        ),
                      ),
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
          Text(
            label,
            style: EverloreTheme.ui(
              size: 12,
              color: EverloreTheme.parchment,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            maxLines: maxLines,
            minLines: 1,
            onChanged: (_) => setState(() {}),
            textCapitalization: TextCapitalization.sentences,
            style: EverloreTheme.ui(
              size: 14,
              color: EverloreTheme.parchment,
              height: 1.4,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: EverloreTheme.void4.withValues(alpha: 0.5),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: EverloreTheme.goldDim.withValues(alpha: 0.2),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: EverloreTheme.goldDim.withValues(alpha: 0.2),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: EverloreTheme.gold,
                  width: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
