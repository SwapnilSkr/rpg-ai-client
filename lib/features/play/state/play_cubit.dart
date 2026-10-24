import 'dart:async';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../core/network/ws_manager.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/storage/local_db.dart';
import '../../../core/rating/rating_prompt.dart';
import '../../chronicle/data/chronicle_repository.dart';
import '../../home/data/home_repository.dart';
import '../../../shared/models/event.dart';
import '../../../shared/models/world_instance.dart';
import '../../../shared/models/world_template.dart';
import '../../../shared/models/memory.dart';
import '../../../shared/models/character_profile.dart';
import '../../../shared/models/relation_candidate.dart';
import '../../billing/data/billing_repository.dart';
import 'package:flutter/services.dart';
import '../../media/models/spoken_line.dart';
import '../../media/models/turn_media.dart';
import '../../media/data/media_repository.dart';
import '../../media/services/audio_playback_controller.dart';
import '../../../shared/widgets/everlore_notice.dart';

/// Socket error codes whose `message` was written for a player to read.
///
/// The server replaces every other failure with a generic line (see
/// `toClientError` on the server), so anything outside this set must never be
/// rendered — it used to be whatever the driver or the model SDK produced, and
/// on the replay path it went straight into the story surface.
const _authoredErrorCodes = {
  'INSUFFICIENT_INK',
  'RATE_LIMITED',
  'ACCOUNT_BANNED',
  'BAD_REQUEST',
  'UNAUTHENTICATED',
  'FORBIDDEN',
  'NOT_FOUND',
  'CONFLICT',
};

@visibleForTesting
bool isAuthoredSocketError(Map<String, dynamic> msg) {
  final code = msg['code']?.toString();
  if (code != null && code.isNotEmpty) return _authoredErrorCodes.contains(code);
  // A server predating coded errors. The one message that was ever safe to
  // show is the spent reserve, matched the way it always was — an app update
  // and a deploy do not land together.
  final text = (msg['message']?.toString() ?? '').toLowerCase();
  return text.contains('story ink') || text.contains('not enough ink');
}

/// The server's own words when they were written for the player, [fallback]
/// otherwise.
@visibleForTesting
String playerErrorMessage(Map<String, dynamic> msg, String fallback) {
  final text = msg['message']?.toString().trim() ?? '';
  if (text.isEmpty || !isAuthoredSocketError(msg)) return fallback;
  return text;
}

/// Sentinel so [PlayState.copyWith] can distinguish "leave unchanged" from
/// "set to null" for nullable fields like [replayingEventId].
const Object _kUnset = Object();
const int _activeEventLimit = 100;
const int _activeMemoryLimit = 50;
const int _olderEventsPageSize = 20;

/// A one-shot transient notice for media outcomes (unseen, resting, failed).
///
/// Kept separate from the composer's [PlayState.notice] so media outcomes
/// never stick in the composer's placeholder. Consumed by a `BlocListener`
/// on the play screen and keyed by [sequence] so repeated identical
/// notices still fire.
class MediaNotice extends Equatable {
  final String message;
  final NoticeTone tone;
  final int sequence;

  const MediaNotice({
    required this.message,
    this.tone = NoticeTone.info,
    required this.sequence,
  });

  @override
  List<Object?> get props => [message, tone, sequence];
}

class PlayState extends Equatable {
  final WorldInstance? instance;
  final WorldTemplate? template;
  final List<GameEvent> events;
  final List<Memory> memories;
  final List<CharacterProfile> characters;
  final bool isGenerating;

  /// A destructive rewind is rebuilding server projections. It is distinct from
  /// prose generation but must gate competing story mutations just as strictly.
  final bool isRewinding;

  /// True only while the NARRATIVE prose is still streaming/revealing into the
  /// bubble — drives the in-bubble "still writing" indicator and locks the
  /// composer. Distinct from [isGenerating], which stays true through post-prose
  /// server work (choices, codex, kinship, persist). The composer unlocks the
  /// instant this flips false; continue/travel stay gated on [isGenerating].
  final bool narrativeStreaming;

  /// True once the narrator's choices have arrived early (the `choices_ready`
  /// event), before generation_complete. Lets the chips render on the still-in-
  /// flight optimistic turn so options appear with the prose. Cleared when the
  /// turn finalizes or a new one starts.
  final bool choicesPreview;

  /// A player send is waiting for the in-flight turn to persist. Chips must
  /// not fire into that held line, and the composer hint should say so.
  final bool hasQueuedSend;

  /// The in-flight turn's prose has ended and the server names its turns, so
  /// the next send, continue or travel can go now instead of waiting for this
  /// turn's bookkeeping. The server holds the next turn until this one is saved.
  final bool nextTurnReady;

  /// One-shot composer restore when a held next line cannot be dispatched
  /// because the in-flight turn failed. The play screen copies this into the
  /// field and the next successful send clears it.
  final String? restoreComposerText;

  final bool isConnected;
  final bool isLoading;
  final String? error;
  final int totalEvents;
  final bool hasOlderEvents;
  final bool isLoadingOlder;

  /// The player input of a turn that failed to send (lock held, error, or
  /// offline), preserved so it can be resent with one tap instead of being
  /// silently lost. Cleared on a successful send or when the error is dismissed.
  final String? lastFailedInput;

  /// Whether [error] is worth retrying verbatim.
  ///
  /// Only an internal or transport failure is — the same words may well succeed
  /// on a second attempt. An AUTHORED failure (a spent reserve, a rate limit, a
  /// blocked line) already told the player exactly what is wrong in its own
  /// words, and resending the identical turn would fail identically. Offering
  /// retry there reads as a broken button and hides the real remedy, so the
  /// error bar drops the action and the composer gets the draft back instead.
  final bool canRetry;

  /// Transient status shown while a turn is still in flight — e.g. the server
  /// hit a hiccup and is retrying. Distinct from [error]: the turn isn't dead,
  /// the loader stays up. Cleared once tokens resume or the turn ends/fails.
  final String? notice;

  /// Id of the event whose AI turn is currently being re-woven (streaming a
  /// replay variant). Drives the in-bubble weaving/streaming treatment and is
  /// independent of [isGenerating] (which gates continue/travel until persist).
  final String? replayingEventId;

  /// Stat changes from the most recent completed turn — drives the floating
  /// delta chips and bar pulses in the HUD. Cleared when the next turn starts.
  final Map<String, num>? lastStatDeltas;

  /// Milestone label crossed on the latest turn (brass-seal toast), one-shot.
  final String? lastMilestone;

  /// Bumped with every milestone so identical labels still retrigger the toast.
  final int milestoneStamp;

  /// Full story-landmark log (oldest first) for the timeline surface — seeded
  /// from instance meta on load, appended live as milestones unlock.
  final List<Milestone> milestones;

  final String? restingResetAt;

  /// Whether the media feature switch is enabled for this session (GET /media/usage returned 200).
  final bool isMediaAvailable;

  /// Set of "${eventId}:${lineId}" marked 422 unvoiceable this session.
  final Set<String> unvoiceableLines;

  final String? playingVoiceEventId;
  final String? playingVoiceLineId;
  final String? loadingVoiceEventId;
  final String? loadingVoiceLineId;
  final MediaNotice? mediaNotice;

  const PlayState({
    this.instance,
    this.template,
    this.events = const [],
    this.memories = const [],
    this.characters = const [],
    this.isGenerating = false,
    this.isRewinding = false,
    this.narrativeStreaming = false,
    this.choicesPreview = false,
    this.hasQueuedSend = false,
    this.nextTurnReady = false,
    this.restoreComposerText,
    this.isConnected = false,
    this.isLoading = true,
    this.error,
    this.totalEvents = 0,
    this.hasOlderEvents = false,
    this.isLoadingOlder = false,
    this.lastFailedInput,
    this.canRetry = false,
    this.notice,
    this.replayingEventId,
    this.lastStatDeltas,
    this.lastMilestone,
    this.milestoneStamp = 0,
    this.milestones = const [],
    this.restingResetAt,
    this.isMediaAvailable = false,
    this.unvoiceableLines = const {},
    this.playingVoiceEventId,
    this.playingVoiceLineId,
    this.loadingVoiceEventId,
    this.loadingVoiceLineId,
    this.mediaNotice,
  });

  PlayState copyWith({
    WorldInstance? instance,
    WorldTemplate? template,
    List<GameEvent>? events,
    List<Memory>? memories,
    List<CharacterProfile>? characters,
    bool? isGenerating,
    bool? isRewinding,
    bool? narrativeStreaming,
    bool? choicesPreview,
    bool? hasQueuedSend,
    bool? nextTurnReady,
    Object? restoreComposerText = _kUnset,
    bool? isConnected,
    bool? isLoading,
    Object? error = _kUnset,
    int? totalEvents,
    bool? hasOlderEvents,
    bool? isLoadingOlder,
    Object? lastFailedInput = _kUnset,
    bool? canRetry,
    Object? notice = _kUnset,
    Object? replayingEventId = _kUnset,
    Object? lastStatDeltas = _kUnset,
    Object? lastMilestone = _kUnset,
    int? milestoneStamp,
    List<Milestone>? milestones,
    Object? restingResetAt = _kUnset,
    bool? isMediaAvailable,
    Set<String>? unvoiceableLines,
    Object? playingVoiceEventId = _kUnset,
    Object? playingVoiceLineId = _kUnset,
    Object? loadingVoiceEventId = _kUnset,
    Object? loadingVoiceLineId = _kUnset,
    Object? mediaNotice = _kUnset,
  }) {
    return PlayState(
      instance: instance ?? this.instance,
      template: template ?? this.template,
      events: events ?? this.events,
      memories: memories ?? this.memories,
      characters: characters ?? this.characters,
      isGenerating: isGenerating ?? this.isGenerating,
      isRewinding: isRewinding ?? this.isRewinding,
      narrativeStreaming: narrativeStreaming ?? this.narrativeStreaming,
      choicesPreview: choicesPreview ?? this.choicesPreview,
      hasQueuedSend: hasQueuedSend ?? this.hasQueuedSend,
      nextTurnReady: nextTurnReady ?? this.nextTurnReady,
      restoreComposerText: identical(restoreComposerText, _kUnset)
          ? this.restoreComposerText
          : restoreComposerText as String?,
      isConnected: isConnected ?? this.isConnected,
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _kUnset) ? this.error : error as String?,
      totalEvents: totalEvents ?? this.totalEvents,
      hasOlderEvents: hasOlderEvents ?? this.hasOlderEvents,
      isLoadingOlder: isLoadingOlder ?? this.isLoadingOlder,
      lastFailedInput: identical(lastFailedInput, _kUnset)
          ? this.lastFailedInput
          : lastFailedInput as String?,
      canRetry: canRetry ?? this.canRetry,
      notice: identical(notice, _kUnset) ? this.notice : notice as String?,
      replayingEventId: identical(replayingEventId, _kUnset)
          ? this.replayingEventId
          : replayingEventId as String?,
      lastStatDeltas: identical(lastStatDeltas, _kUnset)
          ? this.lastStatDeltas
          : lastStatDeltas as Map<String, num>?,
      lastMilestone: identical(lastMilestone, _kUnset)
          ? this.lastMilestone
          : lastMilestone as String?,
      milestoneStamp: milestoneStamp ?? this.milestoneStamp,
      milestones: milestones ?? this.milestones,
      restingResetAt: identical(restingResetAt, _kUnset)
          ? this.restingResetAt
          : restingResetAt as String?,
      isMediaAvailable: isMediaAvailable ?? this.isMediaAvailable,
      unvoiceableLines: unvoiceableLines ?? this.unvoiceableLines,
      playingVoiceEventId: identical(playingVoiceEventId, _kUnset)
          ? this.playingVoiceEventId
          : playingVoiceEventId as String?,
      playingVoiceLineId: identical(playingVoiceLineId, _kUnset)
          ? this.playingVoiceLineId
          : playingVoiceLineId as String?,
      loadingVoiceEventId: identical(loadingVoiceEventId, _kUnset)
          ? this.loadingVoiceEventId
          : loadingVoiceEventId as String?,
      loadingVoiceLineId: identical(loadingVoiceLineId, _kUnset)
          ? this.loadingVoiceLineId
          : loadingVoiceLineId as String?,
      mediaNotice: identical(mediaNotice, _kUnset)
          ? this.mediaNotice
          : mediaNotice as MediaNotice?,
    );
  }

  @override
  List<Object?> get props => [
    instance,
    template,
    events,
    memories,
    characters,
    isGenerating,
    isRewinding,
    narrativeStreaming,
    choicesPreview,
    hasQueuedSend,
    nextTurnReady,
    restoreComposerText,
    isConnected,
    isLoading,
    error,
    totalEvents,
    hasOlderEvents,
    isLoadingOlder,
    lastFailedInput,
    canRetry,
    notice,
    replayingEventId,
    lastStatDeltas,
    lastMilestone,
    milestoneStamp,
    milestones,
    restingResetAt,
    isMediaAvailable,
    unvoiceableLines,
    playingVoiceEventId,
    playingVoiceLineId,
    loadingVoiceEventId,
    loadingVoiceLineId,
    mediaNotice,
  ];

  /// Composer is only locked while prose is still appearing, during rewind,
  /// or while a replay is weaving. Post-prose bookkeeping keeps [isGenerating]
  /// true but must not trap the player's next line.
  bool get composerLocked =>
      isRewinding || replayingEventId != null || narrativeStreaming;

  /// Continue, travel, and other world mutations wait until the in-flight
  /// turn is persisted, unless [nextTurnReady] lets them follow its prose.
  /// A queued chat send is not a world action.
  bool get worldActionsLocked =>
      isRewinding ||
      replayingEventId != null ||
      (isGenerating && !(nextTurnReady && !narrativeStreaming));
}

class PlayCubit extends Cubit<PlayState> {
  final WsManager _ws;
  final String instanceId;
  late StreamSubscription _generationSub;
  late StreamSubscription _generationStartedSub;
  late StreamSubscription _deltaSub;
  late StreamSubscription _streamEndSub;
  late StreamSubscription _choicesReadySub;
  late StreamSubscription _ackSub;
  late StreamSubscription _retryingSub;
  late StreamSubscription _generationResetSub;
  late StreamSubscription _memorySub;
  late StreamSubscription _errorSub;
  late StreamSubscription _connectionSub;
  late StreamSubscription _instanceSub;
  late StreamSubscription _characterCodexSub;
  late StreamSubscription _replayDeltaSub;
  late StreamSubscription _replayCompleteSub;
  late StreamSubscription _milestoneSub;
  final MediaRepository _mediaRepo;
  final AudioPlaybackController audioController;
  late StreamSubscription _spokenLinesSub;
  late StreamSubscription _mediaReadySub;
  late StreamSubscription _mediaUnseenSub;
  late StreamSubscription _mediaFailedSub;
  int _mediaNoticeSeq = 0;

  /// Accumulates streamed narrative tokens for the in-progress turn.
  String _streamBuffer = '';
  String _streamTarget = '';
  // A stale instance_loaded frame can arrive while the rewind HTTP request is
  // still running. Only the load requested after that call resolves may unveil
  // the rebuilt history.
  bool _rewindRequestCompleted = false;
  bool _loadingOlderEvents = false;

  /// A failed provider attempt may have already painted a provisional fragment.
  /// Keep that fragment visible while the worker retries, then replace it
  /// atomically with the first token of the new attempt. This avoids the jarring
  /// empty-bubble flash that previously happened between attempts.
  bool _awaitingRetryReplacement = false;
  Timer? _streamRevealTimer;
  Timer? _generationWatchdog;
  Timer? _reconciliationTimer;

  /// A message waiting to dispatch. Two producers share the slot:
  ///
  /// - Reconnect / rewind / `GENERATION_IN_PROGRESS`: send after a load
  ///   confirms the prior turn settled ([_scheduleReconciliation]).
  /// - Post-prose hold: the player replied once the narrator's words were on
  ///   screen, but the in-flight turn has not persisted yet. Dispatch on
  ///   `generation_complete` without polling.
  ///
  /// Newest player intent wins. No invisible chain of actions.
  String? _queuedMessage;
  static const _reconciliationInterval = Duration(seconds: 3);

  /// Set when the server signals the prose is complete (the choices/bookkeeping
  /// tail may still be generating). Lets the reveal loop know that once it
  /// catches up to the target it can clear [PlayState.narrativeStreaming] — the
  /// story is done even though [isGenerating] stays up for the rest of the turn.
  bool _proseStreamEnded = false;

  /// Turn ids from the server (`jobId`). [_activeJobId] names the turn the
  /// stream state above belongs to; it is null until that send's `ack` lands.
  String? _activeJobId;
  bool _awaitingAck = false;
  bool _abandonNextAck = false;

  /// The active turn's own frames carry its id, so a next turn may overlap it.
  /// An older server never sets this, which keeps the post-prose hold.
  bool _activeTurnTagged = false;

  /// The active turn's prose has ended (unlike [_proseStreamEnded], not reset
  /// when the reveal finishes painting).
  bool _activeProseEnded = false;

  /// Turn N after the player moved on: its prose is on screen, its bubble is
  /// no longer the optimistic one, and only its completion or failure is still
  /// to come. At most one turn settles behind the active one.
  String? _settlingJobId;
  String? _settlingEventId;
  Timer? _settlingWatchdog;
  static const _settlingTimeout = Duration(seconds: 90);

  /// Turns whose remaining frames no longer belong on screen.
  final Set<String> _abandonedJobIds = {};

  /// In-progress streaming replay of an existing turn.
  String? _replayEventId;
  String _replayBuffer = '';
  String? _replayOriginalResponse;

  /// Safety net: if no replay frames arrive within this window we reset the
  /// loader so the bubble can never spin forever (dropped frame, stale lock,
  /// dead worker, …). Re-armed on every delta as a liveness signal.
  Timer? _replayWatchdog;
  Timer? _replayRevealTimer;
  static const _replayTimeout = Duration(seconds: 45);
  static const _generationFirstTokenTimeout = Duration(seconds: 75);
  static const _generationQuietTimeout = Duration(seconds: 45);
  static const _generationFinalizationTimeout = Duration(seconds: 90);
  static const _streamRevealInterval = Duration(milliseconds: 18);

  /// A locally-chosen replay variant awaiting commit. The selection only
  /// becomes the canonical turn ("the truth") when the player takes their next
  /// action (sends a message / continues), at which point it is flushed.
  String? _pendingVariantEventId;
  int? _pendingVariantIndex;

  /// Held spoken lines that arrived before their event landed (keyed by eventId).
  final Map<String, List<SpokenLine>> _heldSpokenLines = {};
  final Map<String, Timer> _heldSpokenLinesTimers = {};
  static const _heldSpokenLinesTimeout = Duration(seconds: 30);

  @visibleForTesting
  Map<String, List<SpokenLine>> get heldSpokenLinesForTesting =>
      Map.unmodifiable(_heldSpokenLines);

  void _holdSpokenLines(String eventId, List<SpokenLine> lines) {
    if (eventId.isEmpty) return;
    _heldSpokenLinesTimers[eventId]?.cancel();
    _heldSpokenLines[eventId] = lines;
    _heldSpokenLinesTimers[eventId] = Timer(_heldSpokenLinesTimeout, () {
      _heldSpokenLines.remove(eventId);
      _heldSpokenLinesTimers.remove(eventId);
    });
  }

  List<SpokenLine>? _takeHeldSpokenLines(String eventId) {
    _heldSpokenLinesTimers[eventId]?.cancel();
    _heldSpokenLinesTimers.remove(eventId);
    return _heldSpokenLines.remove(eventId);
  }

  void _clearHeldSpokenLines() {
    for (final timer in _heldSpokenLinesTimers.values) {
      timer.cancel();
    }
    _heldSpokenLinesTimers.clear();
    _heldSpokenLines.clear();
  }

  final Future<void> Function()? _onRefreshInk;
  final RatingPrompt _rating;

  PlayCubit({
    required this.instanceId,
    WsManager? ws,
    MediaRepository? mediaRepo,
    AudioPlaybackController? audio,
    Future<void> Function()? onRefreshInk,
    RatingPrompt? rating,
  })  : _ws = ws ?? WsManager(),
        _mediaRepo = mediaRepo ?? MediaRepository(),
        audioController = audio ?? AudioPlaybackController.instance,
        _onRefreshInk = onRefreshInk,
        _rating = rating ?? RatingPrompt.instance,
        super(const PlayState()) {
    _init();
  }

  Future<void> _refreshInk() async {
    if (_onRefreshInk != null) {
      await _onRefreshInk();
      return;
    }
    try {
      await BillingRepository.instance.refreshWallet();
    } catch (_) {
      // Story playback remains usable when a background balance refresh is
      // temporarily unavailable; the next header resume/open retries it.
    }
  }

  List<GameEvent> _trimEvents(List<GameEvent> events) {
    if (events.length <= _activeEventLimit) return events;
    return events.sublist(events.length - _activeEventLimit);
  }

  List<Memory> _trimMemories(List<Memory> memories) {
    if (memories.length <= _activeMemoryLimit) return memories;
    return memories.sublist(memories.length - _activeMemoryLimit);
  }

  void _init() {
    audioController.addListener(_onAudioChanged);
    _loadCachedEvents();
    _connectAndLoad();

    _instanceSub = _ws.onInstanceLoaded.listen((msg) {
      final data = msg['data'];
      if (data == null) return;

      final instance = WorldInstance.fromJson(data['instance']);
      if (instance.id != instanceId) {
        _clearHeldSpokenLines();
        return;
      }
      final template = data['template'] != null
          ? WorldTemplate.fromJson(data['template'])
          : null;
      final events =
          (data['recentEvents'] as List?)
              ?.map((e) => GameEvent.fromJson(e))
              .toList() ??
          [];
      for (var i = 0; i < events.length; i++) {
        final held = _takeHeldSpokenLines(events[i].id);
        if (held != null && events[i].spokenLines.isEmpty) {
          events[i] = events[i].copyWith(spokenLines: held);
        }
      }
      // The snapshot replaces every bubble. A settling turn that was not saved
      // yet still lands through its own completion, matched by its server id.
      _settlingEventId = null;
      final memories =
          (data['memories'] as List?)
              ?.map((e) => Memory.fromJson(e))
              .toList() ??
          [];
      final characters =
          (data['characters'] as List?)
              ?.map(
                (e) => CharacterProfile.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList() ??
          [];
      final eventWindow = data['eventWindow'] as Map?;
      final totalEvents =
          (eventWindow?['total'] as num?)?.toInt() ?? instance.meta.totalEvents;
      final hasOlderEvents =
          eventWindow?['hasOlder'] == true || totalEvents > events.length;
      final operation = data['operation'] as Map?;
      final operationKind = operation?['kind']?.toString();
      final rewindSnapshotReady = state.isRewinding && _rewindRequestCompleted;

      emit(
        state.copyWith(
          instance: instance,
          template: template,
          events: _trimEvents(events),
          memories: _trimMemories(memories),
          characters: characters,
          totalEvents: totalEvents,
          hasOlderEvents: hasOlderEvents,
          isLoadingOlder: false,
          milestones: instance.meta.milestones,
          isLoading: false,
          // A fresh load answers any earlier load or reconnect failure.
          error: null,
          // A rewind is complete only when the load requested AFTER its HTTP
          // rebuild completes arrives — never on an older socket snapshot.
          isRewinding: rewindSnapshotReady ? false : state.isRewinding,
          notice: rewindSnapshotReady ? null : state.notice,
        ),
      );
      unawaited(_refreshInk());
      if (rewindSnapshotReady) _rewindRequestCompleted = false;
      _loadingOlderEvents = false;

      if (_queuedMessage != null) {
        if (operationKind != null) {
          emit(
            state.copyWith(
              notice: operationKind == 'rewind'
                  ? 'Rewind still settling — your message is queued.'
                  : 'Finishing the previous turn — your message is queued.',
            ),
          );
          _scheduleReconciliation();
        } else {
          _sendQueuedMessage();
        }
      }
    });

    _characterCodexSub = _ws.onCharacterCodexUpdated.listen((msg) {
      if (msg['instanceId']?.toString() != instanceId) return;
      final incoming =
          (msg['characters'] as List?)
              ?.map(
                (e) => CharacterProfile.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList() ??
          [];
      final focused = msg['focused_character_id']?.toString();
      emit(
        state.copyWith(
          characters: incoming,
          instance: state.instance?.copyWith(
            focusCharacterId: focused == 'null' ? null : focused,
          ),
        ),
      );
    });

    // Tokens stream in here as the world weaves the tale. We buffer raw chunks
    // and reveal them on a short cadence so large network frames do not snap
    // abruptly into the narrator panel.
    _deltaSub = _ws.onGenerationDelta.listen((msg) {
      if (_ownerOf(msg) != _FrameOwner.active) return;
      _armGenerationWatchdog(_generationQuietTimeout);
      // Tokens are flowing again — drop any "retrying" notice.
      if (state.notice != null && !state.hasQueuedSend) {
        emit(state.copyWith(notice: null));
      }
      final delta = msg['delta']?.toString() ?? '';
      if (delta.isEmpty) return;

      // A retry must never append to the discarded attempt. Do the visible
      // hand-off only once a real replacement token exists, so the bubble is
      // never cleared to an empty placeholder between two attempts.
      if (_awaitingRetryReplacement) {
        _awaitingRetryReplacement = false;
        _streamRevealTimer?.cancel();
        _streamRevealTimer = null;
        _streamBuffer = delta;
        _streamTarget = delta;
        _proseStreamEnded = false;
        _replaceOptimisticAiResponse(delta);
        return;
      }
      _queueGenerationText(delta);
    });

    // The worker has accepted this turn and is assembling its context packet.
    // This happens before the provider can return a first token, especially on
    // a cold retrieval path, so give the otherwise-empty optimistic bubble an
    // accurate status instead of making it look stalled.
    _generationStartedSub = _ws.onGenerationStarted.listen((msg) {
      if (_ownerOf(msg) != _FrameOwner.active) return;
      if (!state.isGenerating || state.replayingEventId != null) return;
      emit(state.copyWith(notice: 'Gathering the scene…'));
    });

    // A turn hit a transient failure and is being retried server-side. Keep the
    // loader up and tell the player it's still coming, rather than a dead stream.
    _retryingSub = _ws.onGenerationRetrying.listen((msg) {
      if (_ownerOf(msg) != _FrameOwner.active) return;
      if (!state.isGenerating) return;
      _armGenerationWatchdog(_generationQuietTimeout);
      emit(state.copyWith(notice: 'The world stumbled — trying again…'));
    });

    // A provider attempt can fail after it has painted a provisional fragment.
    // Keep that fragment on screen while a retry is in flight; it is explicitly
    // not playable (choices are removed and the composer remains disabled).
    // Once replacement text arrives, [_deltaSub] swaps it atomically. This is
    // a recovery state, not a second canonical story turn.
    _generationResetSub = _ws.onGenerationReset.listen((msg) {
      // A settling turn's reset needs nothing on screen: its chips are already
      // gone, and its completion (or failure) still decides the bubble.
      if (_ownerOf(msg) != _FrameOwner.active) return;
      if (!state.isGenerating || state.replayingEventId != null) return;
      _activeProseEnded = false;

      final events = [...state.events];
      final idx = events.lastIndexWhere((event) => event.isOptimistic);
      final visibleNarrative = idx >= 0 ? events[idx].aiResponse ?? '' : '';

      _awaitingRetryReplacement = true;
      _streamRevealTimer?.cancel();
      _streamRevealTimer = null;
      _streamBuffer = visibleNarrative;
      _streamTarget = visibleNarrative;
      _proseStreamEnded = false;
      if (idx >= 0) {
        events[idx] = events[idx].copyWith(
          // Any chips came from the discarded attempt and must not be usable.
          choices: const [],
        );
      }
      emit(
        state.copyWith(
          events: events,
          narrativeStreaming: true,
          choicesPreview: false,
          nextTurnReady: false,
          notice: visibleNarrative.trim().isEmpty
              ? 'The world stumbled — trying again…'
              : 'Reconnecting this scene…',
        ),
      );
      _armGenerationWatchdog(_generationFirstTokenTimeout);
    });

    _streamEndSub = _ws.onGenerationStreamEnd.listen((msg) {
      if (_ownerOf(msg) != _FrameOwner.active) return;
      final narrative = msg['narrative']?.toString();
      if (narrative != null) {
        // The server may have removed only a provider's unfinished trailing
        // clause. A stream-end frame is authoritative, even when it is shorter
        // than text already painted from deltas; never leave that fragment on
        // screen while post-prose bookkeeping completes.
        _streamTarget = narrative;
        if (_streamBuffer.length > narrative.length) {
          _streamBuffer = narrative;
          _replaceOptimisticAiResponse(narrative);
        }
      }
      // The story prose is complete (any choices/bookkeeping tail is hidden and
      // still generating). Mark it so the reveal loop can drop the "writing"
      // indicator — and unlock the composer — once it finishes painting the
      // remaining buffered text. Continue/travel stay locked via isGenerating
      // until generation_complete.
      _proseStreamEnded = true;
      _activeProseEnded = true;
      _armGenerationWatchdog(_generationFinalizationTimeout);
      _refreshNextTurnReady();
      _startGenerationReveal();
    });

    _ackSub = _ws.onAck.listen((msg) {
      final jobId = msg['jobId']?.toString();
      if (jobId == null || jobId.isEmpty || !_awaitingAck) return;
      _awaitingAck = false;
      if (_abandonNextAck) {
        _abandonNextAck = false;
        _abandonedJobIds.add(jobId);
        return;
      }
      _activeJobId = jobId;
      _refreshNextTurnReady();
    });

    // The narrator's choices arrive ahead of generation_complete. Attach them to
    // the in-flight optimistic turn so the chips appear with the settled prose,
    // instead of after the post-prose bookkeeping. generation_complete will later
    // replace the event with the final (audited) choices.
    _choicesReadySub = _ws.onChoicesReady.listen((msg) {
      // A settling turn's chips stay off: the player has already moved on.
      if (_ownerOf(msg) != _FrameOwner.active) return;
      // A held next line already dismissed these chips; don't bring them back.
      if (state.hasQueuedSend) return;
      final choices = Choice.listFromAny(msg['choices']);
      if (choices.isEmpty) return;
      final events = [...state.events];
      final idx = events.lastIndexWhere((e) => e.isOptimistic);
      if (idx < 0) return;
      events[idx] = events[idx].copyWith(choices: choices);
      emit(state.copyWith(events: events, choicesPreview: true));
    });

    _generationSub = _ws.onGenerationComplete.listen((msg) {
      final owner = _ownerOf(msg);
      if (owner == _FrameOwner.settling) {
        _completeSettlingTurn(msg);
        return;
      }
      if (owner != _FrameOwner.active) return;

      final eventData = msg['event'] as Map<String, dynamic>;
      final narrative = eventData['narrative']?.toString() ?? _streamTarget;
      _finishGenerationReveal(narrative);
      final events = [...state.events];
      final idx = events.lastIndexWhere((e) => e.isOptimistic);
      final finalEvent = _finalEventFrom(
        msg,
        narrative: narrative,
        bubble: idx >= 0 ? events[idx] : null,
      );
      final statDeltas = _statDeltasFrom(eventData);

      if (idx >= 0) {
        events[idx] = finalEvent;
      } else {
        events.add(finalEvent);
      }

      LocalDb.insertEvent(_stripTempMedia(finalEvent)).ignore();
      _clearGenerationTimers();
      _streamBuffer = '';
      _streamTarget = '';
      _awaitingRetryReplacement = false;
      final trimmedEvents = _trimEvents(events);
      final nextTotalEvents = finalEvent.sequence > state.totalEvents
          ? finalEvent.sequence
          : state.totalEvents;

      _activeJobId = null;
      _activeProseEnded = false;
      emit(
        state.copyWith(
          events: trimmedEvents,
          isGenerating: false,
          narrativeStreaming: false,
          choicesPreview: false,
          hasQueuedSend: false,
          nextTurnReady: false,
          notice: null,
          instance: state.instance?.applyStateDiff(eventData['state_diff']),
          totalEvents: nextTotalEvents,
          hasOlderEvents:
              state.hasOlderEvents || nextTotalEvents > trimmedEvents.length,
          lastStatDeltas: statDeltas,
          restoreComposerText: null,
        ),
      );
      unawaited(_rating.recordSuccessfulTurn());
      unawaited(_refreshInk());
      _sendQueuedMessage();
    });

    _milestoneSub = _ws.onMilestoneUnlocked.listen((msg) {
      if (msg['instanceId']?.toString() != instanceId) return;
      final raw = msg['milestone'];
      final label = (raw is Map ? raw['label'] : raw)?.toString();
      if (label == null || label.isEmpty) return;
      // Append to the timeline log (dedup by sequence) so the story-spine grows
      // live, in addition to firing the one-shot toast.
      final seq = (raw is Map ? raw['sequence'] as num? : null)?.toInt();
      final milestones = [...state.milestones];
      if (seq != null && !milestones.any((m) => m.sequence == seq)) {
        milestones.add(
          Milestone(label: label, sequence: seq, at: DateTime.now()),
        );
      }
      emit(
        state.copyWith(
          lastMilestone: label,
          milestoneStamp: DateTime.now().millisecondsSinceEpoch,
          milestones: milestones,
        ),
      );
    });

    // Replay streams an alternative for an existing turn — grow that event's
    // narrator panel in place as tokens arrive (same feel as a fresh turn).
    _replayDeltaSub = _ws.onReplayDelta.listen((msg) {
      if (msg['instanceId']?.toString() != instanceId) return;
      final eventId = msg['eventId']?.toString();
      if (eventId == null || eventId != _replayEventId) return;
      _armReplayWatchdog(); // tokens are flowing — keep the timeout fresh
      _queueReplayText(eventId, msg['delta']?.toString() ?? '');
    });

    _replayCompleteSub = _ws.onReplayComplete.listen((msg) {
      if (msg['instanceId']?.toString() != instanceId) return;
      final eventId = msg['eventId']?.toString();
      if (eventId == null) return;

      final variants =
          (msg['variants'] as List?)
              ?.map(
                (v) =>
                    ReplayVariant.fromJson(Map<String, dynamic>.from(v as Map)),
              )
              .toList() ??
          const <ReplayVariant>[];
      final selected = (msg['selected_index'] as num?)?.toInt() ?? 0;
      final narrative = msg['narrative']?.toString() ?? _replayBuffer;
      _finishReplayReveal(eventId, narrative);
      final selectedVariant = selected >= 0 && selected < variants.length
          ? variants[selected]
          : null;

      final events = [...state.events];
      final idx = events.indexWhere((e) => e.id == eventId);
      if (idx >= 0) {
        final payloadLines = SpokenLine.listFromAny(msg['spoken_lines']);
        final heldLines = _takeHeldSpokenLines(eventId);
        final spokenLines = payloadLines.isNotEmpty
            ? payloadLines
            : (heldLines ?? const <SpokenLine>[]);

        events[idx] = events[idx].copyWith(
          aiResponse: narrative,
          modelUsed: selectedVariant?.modelUsed,
          replayVariants: variants,
          selectedReplayIndex: selected,
          // Fresh chips + scene presence, regenerated server-side from the new
          // variant (the old ones reflected the replaced prose).
          choices: Choice.listFromAny(msg['choices']),
          presentCharacters: GameEvent.presentFromAny(
            msg['present_characters'],
          ),
          presenceKnown: msg.containsKey('present_characters'),
          trackableMentions: TrackableMention.listFromAny(
            msg['trackable_mentions'],
          ),
          spokenLines: spokenLines,
        );
        LocalDb.insertEvent(_stripTempMedia(events[idx])).ignore();
      }
      _endReplay();

      // A replay can re-fold instance state (world_state / flags / scene /
      // location / time). The server now ships that snapshot on the frame; apply
      // it inline so the HUD + scene reflect the chosen variant without a
      // round-trip. If the snapshot is absent (older server), fall back to a
      // full reload to stay consistent.
      final instanceState = msg['instance_state'];
      if (instanceState is Map &&
          instanceState.isNotEmpty &&
          state.instance != null) {
        final updated = state.instance!.applyInstanceState(
          Map<String, dynamic>.from(instanceState),
        );
        emit(
          state.copyWith(
            events: events,
            instance: updated,
            isGenerating: false,
          ),
        );
      } else {
        emit(state.copyWith(events: events, isGenerating: false));
        _ws.loadInstance(instanceId);
      }
    });

    _memorySub = _ws.onMemoriesCurated.listen((msg) {
      if (msg['instanceId'] != instanceId) return;
      final newMems =
          (msg['memories'] as List?)?.map((m) => Memory.fromJson(m)).toList() ??
          [];
      emit(
        state.copyWith(
          memories: _trimMemories([...state.memories, ...newMems]),
        ),
      );
    });

    _errorSub = _ws.onError.listen((msg) {
      // Only a turn's own failure frame names its turn; direct socket errors
      // (no id) answer the latest send, as before.
      final failedJobId = msg['jobId']?.toString();
      if (failedJobId != null && failedJobId.isNotEmpty) {
        final owner = _ownerOf(msg);
        if (owner == _FrameOwner.none) return;
        if (owner == _FrameOwner.settling) {
          unawaited(_rating.recordSetback());
          unawaited(_refreshInk());
          _failSettlingTurn(msg);
          return;
        }
      }
      unawaited(_rating.recordSetback());
      // Reservations are released on failed turns; refresh the header so it
      // reflects the settled/refunded ledger immediately.
      unawaited(_refreshInk());

      if (msg['code'] == 'STORY_RESTING') {
        final replayId = _replayEventId;
        final replayOriginal = _replayOriginalResponse;
        _replayWatchdog?.cancel();
        _replayWatchdog = null;
        _replayRevealTimer?.cancel();
        _replayRevealTimer = null;
        _replayEventId = null;
        _replayBuffer = '';
        _replayOriginalResponse = null;

        _streamBuffer = '';
        _streamTarget = '';
        _awaitingRetryReplacement = false;
        _clearGenerationTimers();
        final events = [...state.events];
        if (replayId != null && replayOriginal != null) {
          final idx = events.indexWhere((e) => e.id == replayId);
          if (idx >= 0) {
            events[idx] = events[idx].copyWith(aiResponse: replayOriginal);
          }
        }
        final droppedOptimistic = events
            .where((e) => e.isOptimistic)
            .toList();
        final droppedInput = droppedOptimistic.isNotEmpty
            ? droppedOptimistic.last.playerInput
            : null;
        final cleanEvents = events.where((e) => !e.isOptimistic).toList();
        emit(
          state.copyWith(
            events: cleanEvents,
            isGenerating: false,
            narrativeStreaming: false,
            choicesPreview: false,
            replayingEventId: null,
            notice: null,
            error: null,
            canRetry: false,
            lastFailedInput: droppedInput,
            hasQueuedSend: false,
            restoreComposerText: _takeQueuedSend(),
            restingResetAt: msg['resets_at']?.toString() ?? '',
          ),
        );
        return;
      }

      // An authored failure explains itself and is not worth resending; an
      // internal one is the only kind a verbatim retry can fix. This single
      // question decides both the copy and whether the bar offers an action.
      final authored = isAuthoredSocketError(msg);
      // A replay in flight takes precedence: ANY error frame (including
      // GENERATION_IN_PROGRESS) must tear the replay down so the loader can
      // never get stranded. Restore the turn's original prose.
      if (_replayEventId != null) {
        _restoreReplayedEvent(
          playerErrorMessage(msg, 'Could not replay this response.'),
        );
        return;
      }

      if (msg['code'] == 'GENERATION_IN_PROGRESS') {
        final events = [...state.events];
        final idx = events.lastIndexWhere(
          (e) => e.isOptimistic && ((e.aiResponse ?? '').trim().isEmpty),
        );
        // The prior server operation may have completed while the socket was
        // down. Preserve this next action and reconcile instead of making the
        // player wait, retype, and manually resend it.
        final droppedInput = idx >= 0 ? events[idx].playerInput : null;
        if (idx >= 0) events.removeAt(idx);
        _clearGenerationTimers();
        _takeQueuedSend();
        emit(
          state.copyWith(
            events: events,
            isGenerating: false,
            notice: null,
            error: null,
            lastFailedInput: null,
            canRetry: false,
            hasQueuedSend: false,
            restoreComposerText: null,
          ),
        );
        if (droppedInput != null && droppedInput.trim().isNotEmpty) {
          _queueMessage(droppedInput);
        }
        _ws.loadInstance(instanceId);
        return;
      }

      final optimisticEvents = [...state.events];
      final optimisticIdx = optimisticEvents.lastIndexWhere(
        (e) => e.isOptimistic,
      );
      final hasVisibleOptimisticText =
          optimisticIdx >= 0 &&
          ((optimisticEvents[optimisticIdx].aiResponse ?? '')
              .trim()
              .isNotEmpty);
      final failedInput = optimisticIdx >= 0
          ? optimisticEvents[optimisticIdx].playerInput
          : null;
      if (hasVisibleOptimisticText) {
        // The prose remains as a visibly provisional draft rather than being
        // erased just before the error bar appears. It was never persisted, so
        // leave choices off and give the player one-tap retry for their action.
        _clearGenerationTimers();
        _awaitingRetryReplacement = false;
        emit(
          state.copyWith(
            events: optimisticEvents,
            isGenerating: false,
            narrativeStreaming: false,
            choicesPreview: false,
            notice: null,
            error: playerErrorMessage(
              msg,
              'This scene could not be saved. Please try again.',
            ),
            canRetry: !authored,
            lastFailedInput: failedInput,
            hasQueuedSend: false,
            restoreComposerText: _takeQueuedSend(),
          ),
        );
        return;
      }

      _streamBuffer = '';
      _streamTarget = '';
      _awaitingRetryReplacement = false;
      _clearGenerationTimers();
      // Drop the in-progress optimistic turn but KEEP its text so the player can
      // resend with one tap rather than re-typing the whole message.
      final droppedOptimistic = state.events
          .where((e) => e.isOptimistic)
          .toList();
      final droppedInput = droppedOptimistic.isNotEmpty
          ? droppedOptimistic.last.playerInput
          : null;
      final events = state.events.where((e) => !e.isOptimistic).toList();
      emit(
        state.copyWith(
          events: events,
          isGenerating: false,
          notice: null,
          error: playerErrorMessage(
            msg,
            'The scene could not start. Please try again.',
          ),
          canRetry: !authored,
          lastFailedInput: droppedInput,
          hasQueuedSend: false,
          restoreComposerText: _takeQueuedSend(),
        ),
      );
    });

    _connectionSub = _ws.onConnectionState.listen((connected) {
      emit(state.copyWith(isConnected: connected));
      if (connected && _queuedMessage != null) _ws.loadInstance(instanceId);
    });

    unawaited(_checkMediaUsage());

    _spokenLinesSub = _ws.onSpokenLines.listen((msg) {
      if (msg['instanceId']?.toString() != instanceId) return;
      final eventId = (msg['eventId'] ?? '').toString();
      final lines = SpokenLine.listFromAny(msg['lines']);
      final events = [...state.events];
      final idx = events.indexWhere((e) => e.id == eventId);
      if (idx >= 0) {
        _takeHeldSpokenLines(eventId);
        events[idx] = events[idx].copyWith(spokenLines: lines);
        LocalDb.insertEvent(_stripTempMedia(events[idx])).ignore();
        emit(state.copyWith(events: events));
      } else if (eventId.isNotEmpty) {
        _holdSpokenLines(eventId, lines);
      }
    });

    _mediaReadySub = _ws.onMediaReady.listen((msg) {
      if (msg['instanceId'] != instanceId) return;
      final eventId = (msg['eventId'] ?? '').toString();
      final mediaId = (msg['media_id'] ?? msg['mediaId'] ?? '').toString();
      final kindStr = (msg['kind'] ?? '').toString();
      final url = msg['url']?.toString();
      final lineId = (msg['line_id'] ?? msg['lineId'])?.toString();
      final characterId =
          (msg['character_id'] ?? msg['characterId'])?.toString();

      if (kindStr == 'voice') {
        if (state.loadingVoiceEventId == eventId &&
            state.loadingVoiceLineId == lineId &&
            url != null &&
            url.isNotEmpty) {
          audioController.play(eventId: eventId, lineId: lineId!, url: url);
          emit(
            state.copyWith(
              loadingVoiceEventId: null,
              loadingVoiceLineId: null,
            ),
          );
        }
        return;
      }

      // Portraits show on cards, which fetch them when the chronicle opens.
      if (kindStr == 'portrait') return;

      final kind = kindStr == 'video' ? MediaKind.video : MediaKind.picture;
      final events = [...state.events];
      final idx = events.indexWhere((e) => e.id == eventId);
      if (idx >= 0) {
        final ev = events[idx];
        final mediaList = [...ev.media];
        final mIdx = mediaList.indexWhere(
          (m) =>
              m.mediaId == mediaId ||
              (m.isQueued &&
                  m.kind == kind &&
                  (lineId == null ? m.lineId == null : m.lineId == lineId)),
        );

        final readyItem = TurnMedia(
          mediaId: mediaId,
          kind: kind,
          status: MediaStatus.ready,
          url: url,
          lineId: lineId,
          characterId: characterId,
          justRequested: true,
        );

        if (mIdx >= 0) {
          mediaList[mIdx] = readyItem;
        } else {
          mediaList.add(readyItem);
        }

        events[idx] = ev.copyWith(media: mediaList);
        LocalDb.insertEvent(_stripTempMedia(events[idx])).ignore();
        emit(state.copyWith(events: events));
      }
    });

    _mediaUnseenSub = _ws.onMediaUnseen.listen((msg) {
      if (msg['instanceId'] != instanceId) return;
      final eventId = (msg['eventId'] ?? '').toString();
      final mediaId = (msg['media_id'] ?? msg['mediaId'] ?? '').toString();
      final notice = _nextMediaNotice(
        'This moment stays unseen.',
        NoticeTone.info,
      );
      emit(
        state.copyWith(
          events: _eventsWithoutMedia(eventId, mediaId, persist: true),
          mediaNotice: notice,
        ),
      );
    });

    _mediaFailedSub = _ws.onMediaFailed.listen((msg) {
      if (msg['instanceId'] != instanceId) return;
      final eventId = (msg['eventId'] ?? '').toString();
      final mediaId = (msg['media_id'] ?? msg['mediaId'] ?? '').toString();
      final lineId = (msg['line_id'] ?? msg['lineId'])?.toString();
      final kind = (msg['kind'] ?? '').toString();
      final isVoiceMatch =
          state.loadingVoiceEventId == eventId &&
          state.loadingVoiceLineId == lineId;
      if (isVoiceMatch) {
        audioController.setLoading(null, null);
      }
      final notice = _nextMediaNotice(
        _mediaFailureCopy(kind),
        NoticeTone.error,
      );
      emit(
        state.copyWith(
          events: _eventsWithoutMedia(eventId, mediaId, persist: true),
          mediaNotice: notice,
          loadingVoiceEventId: isVoiceMatch
              ? null
              : state.loadingVoiceEventId,
          loadingVoiceLineId: isVoiceMatch ? null : state.loadingVoiceLineId,
        ),
      );
    });
  }

  /// Each media notice gets a fresh [MediaNotice.sequence] so the screen's
  /// listener fires even when the same message repeats.
  MediaNotice _nextMediaNotice(String message, NoticeTone tone) =>
      MediaNotice(message: message, tone: tone, sequence: ++_mediaNoticeSeq);

  /// [state.events] with [mediaId] dropped from [eventId]'s media, or null
  /// when that event isn't loaded (so `copyWith` leaves the events alone).
  List<GameEvent>? _eventsWithoutMedia(
    String eventId,
    String mediaId, {
    required bool persist,
  }) {
    final events = [...state.events];
    final idx = events.indexWhere((e) => e.id == eventId);
    if (idx < 0) return null;
    final ev = events[idx];
    events[idx] = ev.copyWith(
      media: ev.media.where((m) => m.mediaId != mediaId).toList(),
    );
    if (persist) LocalDb.insertEvent(_stripTempMedia(events[idx])).ignore();
    return events;
  }

  String _mediaFailureCopy(String kind) {
    return switch (kind) {
      'picture' => 'Could not create this picture.',
      'video' => 'Could not create this film.',
      'voice' => 'Could not play this voice.',
      _ => 'This moment stays unseen.',
    };
  }

  @visibleForTesting
  static Future<Map<String, dynamic>> Function(
    String instanceId, {
    int limit,
    int? beforeSequence,
  })? olderEventsLoaderForTesting;

  /// Fetch an older page without using offsets. The cursor is the first loaded
  /// sequence, so a concurrently-created latest turn cannot shift this page.
  Future<void> loadOlderEvents() async {
    if (_loadingOlderEvents ||
        state.isLoadingOlder ||
        !state.hasOlderEvents ||
        state.events.isEmpty) {
      return;
    }
    final beforeSequence = state.events.first.sequence;
    if (beforeSequence <= 0) return;

    _loadingOlderEvents = true;
    emit(state.copyWith(isLoadingOlder: true));
    try {
      final page = olderEventsLoaderForTesting != null
          ? await olderEventsLoaderForTesting!(
              instanceId,
              limit: _olderEventsPageSize,
              beforeSequence: beforeSequence,
            )
          : await ChronicleRepository.getEvents(
              instanceId,
              limit: _olderEventsPageSize,
              beforeSequence: beforeSequence,
            );
      final incoming =
          (page['events'] as List<GameEvent>?) ?? const <GameEvent>[];
      // Ids survive reconnects; sequence is a fallback for legacy seed rows.
      final seen = <String>{
        for (final event in state.events)
          event.id.isNotEmpty ? 'id:${event.id}' : 'sequence:${event.sequence}',
      };
      final merged = <GameEvent>[
        ...incoming.where(
          (event) => seen.add(
            event.id.isNotEmpty
                ? 'id:${event.id}'
                : 'sequence:${event.sequence}',
          ),
        ),
        ...state.events,
      ]..sort((a, b) => a.sequence.compareTo(b.sequence));
      emit(
        state.copyWith(
          // Do not trim upward-paged history: a reader who deliberately loads
          // it must be able to scroll back down through the same window.
          events: merged,
          totalEvents: (page['total'] as num?)?.toInt() ?? state.totalEvents,
          hasOlderEvents: page['hasOlder'] == true && incoming.isNotEmpty,
          isLoadingOlder: false,
        ),
      );
    } catch (_) {
      // A transient history-page failure must not surface as a story failure;
      // leave the current window intact and allow the next upward scroll to retry.
      emit(state.copyWith(isLoadingOlder: false));
    } finally {
      _loadingOlderEvents = false;
    }
  }

  Future<void> _connectAndLoad() async {
    final String? token;
    try {
      token = await SecureStore.getToken();
    } catch (_) {
      emit(
        state.copyWith(
          isLoading: false,
          error: 'Please sign in to load this world.',
        ),
      );
      return;
    }

    if (token == null || token.isEmpty) {
      emit(
        state.copyWith(
          isLoading: false,
          error: 'Please sign in to load this world.',
        ),
      );
      return;
    }

    try {
      await _ws.connect(token, force: true);
      _ws.loadInstance(instanceId);
    } catch (_) {
      // Connect and load failures are handled by socket reconnection/state;
      // a transport or network issue must never tell the player to sign in.
    }
  }

  Future<void> _loadCachedEvents() async {
    try {
      final cached = await LocalDb.getEvents(instanceId, limit: 50);
      if (cached.isNotEmpty && state.events.isEmpty) {
        final sanitized = cached.map(_stripTempMedia).toList();
        emit(
          state.copyWith(
            events: sanitized,
            totalEvents: sanitized.length,
            hasOlderEvents: false,
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> sendMessage(String message) async {
    if (message.trim().isEmpty) return;
    if (state.isRewinding) {
      _queueMessage(message);
      return;
    }
    if (state.replayingEventId != null) return;
    // Prose is still appearing — the composer is locked, so this is a no-op
    // rather than a silent queue.
    if (state.narrativeStreaming) return;
    // The narrator's words are on screen but the turn has not persisted. Send
    // now when the server can hold the next turn for it; otherwise hold this
    // line locally and do not start the next generation job.
    if (state.isGenerating && !_canOverlapNextTurn()) {
      _holdSendUntilTurnSettles(message);
      return;
    }

    // Lock in any variant the player browsed to before this turn is generated,
    // so the world weaves forward from the prose they actually chose.
    await _flushPendingVariant();
    // The in-flight turn may have retried while that settled.
    if (state.isGenerating && !_canOverlapNextTurn()) {
      _holdSendUntilTurnSettles(message);
      return;
    }

    final priorEvents = _beginTurn();
    _streamBuffer = '';
    _streamTarget = '';
    _awaitingRetryReplacement = false;
    _proseStreamEnded = false;
    _clearGenerationTimers();
    final optimisticEvent = GameEvent.optimistic(
      instanceId: instanceId,
      playerInput: message,
    );

    emit(
      state.copyWith(
        events: _trimEvents([...priorEvents, optimisticEvent]),
        isGenerating: true,
        narrativeStreaming: true,
        choicesPreview: false,
        hasQueuedSend: false,
        nextTurnReady: false,
        restoreComposerText: null,
        hasOlderEvents:
            state.hasOlderEvents || state.events.length >= _activeEventLimit,
        error: null,
        notice: null,
        lastFailedInput: null,
        canRetry: false,
        lastStatDeltas: null,
      ),
    );

    _armGenerationWatchdog(_generationFirstTokenTimeout);
    _ws.sendChatMessage(instanceId, message);
  }

  /// Resend the input from a turn that failed to send (lock held, error, or
  /// offline) without making the player re-type it.
  void retryLastFailed() {
    final pending = state.lastFailedInput;
    if (pending == null || pending.trim().isEmpty) return;
    if (state.isGenerating || state.replayingEventId != null) return;
    // The retained prose was a recovery draft, never a persisted turn. Remove
    // it immediately before resending so the retried turn cannot leave two
    // copies of the same player action in the visible timeline.
    final events = state.events.where((event) => !event.isOptimistic).toList();
    emit(state.copyWith(events: events, error: null, lastFailedInput: null, canRetry: false));
    sendMessage(pending);
  }

  /// Let the world advance the story autonomously — no player message.
  /// [advance] turns the quiet continue into a time skip (calendar tick):
  /// 'hours' | 'day' | 'days' | 'season'.
  Future<void> continueStory({String? advance}) async {
    if (state.worldActionsLocked) return;

    await _flushPendingVariant();
    if (state.worldActionsLocked) return;

    final priorEvents = _beginTurn();
    _streamBuffer = '';
    _streamTarget = '';
    _awaitingRetryReplacement = false;
    _proseStreamEnded = false;
    _clearGenerationTimers();
    final optimisticEvent = GameEvent.optimistic(
      instanceId: instanceId,
      playerInput: '',
    );

    emit(
      state.copyWith(
        events: _trimEvents([...priorEvents, optimisticEvent]),
        isGenerating: true,
        narrativeStreaming: true,
        choicesPreview: false,
        nextTurnReady: false,
        hasOlderEvents:
            state.hasOlderEvents || state.events.length >= _activeEventLimit,
        error: null,
        lastStatDeltas: null,
      ),
    );

    _armGenerationWatchdog(_generationFirstTokenTimeout);
    _ws.sendContinue(instanceId, advance: advance);
  }

  /// Start a server-validated travel action. Destination, party, and optional
  /// time passage are all explicit player choices rather than prose inference.
  Future<void> travelTo({
    required String destination,
    required List<String> companions,
    String? advance,
  }) => _sendWorldAction(
    // Travel is a structured world-state command, not a chat line. The route
    // and destination are represented by the travel event / world_action
    // payload, while the narrator shows the resulting journey.
    optimisticInput: '',
    payload: {
      'kind': 'travel',
      'destination': destination,
      'companions': companions,
      if (advance != null) 'time_advance': advance,
    },
  );

  /// Confirm or correct a relationship as player-authored canon.
  Future<bool> setRelationship({
    required String character,
    required String relation,
    required bool correction,
    String? replacesRelation,
  }) async {
    if (state.isGenerating) return false;
    try {
      await ChronicleRepository.setKinship(
        instanceId,
        character: character,
        relation: relation,
        correction: correction,
        replacesRelation: replacesRelation,
      );
      return true;
    } catch (_) {
      emit(state.copyWith(error: 'Could not save the relationship.'));
      return false;
    }
  }

  Future<void> _sendWorldAction({
    required String optimisticInput,
    required Map<String, dynamic> payload,
  }) async {
    if (state.worldActionsLocked) return;
    await _flushPendingVariant();
    if (state.worldActionsLocked) return;
    final priorEvents = _beginTurn();
    _streamBuffer = '';
    _streamTarget = '';
    _awaitingRetryReplacement = false;
    _proseStreamEnded = false;
    _clearGenerationTimers();
    final optimisticEvent = GameEvent.optimistic(
      instanceId: instanceId,
      playerInput: optimisticInput,
    );
    emit(
      state.copyWith(
        events: _trimEvents([...priorEvents, optimisticEvent]),
        isGenerating: true,
        narrativeStreaming: true,
        choicesPreview: false,
        nextTurnReady: false,
        hasOlderEvents:
            state.hasOlderEvents || state.events.length >= _activeEventLimit,
        error: null,
        notice: null,
        lastFailedInput: null,
        canRetry: false,
        lastStatDeltas: null,
      ),
    );
    _armGenerationWatchdog(_generationFirstTokenTimeout);
    _ws.sendWorldAction(instanceId, payload);
  }

  /// One-shot acknowledgement of the milestone toast.
  void clearMilestone() {
    if (state.lastMilestone != null) {
      emit(state.copyWith(lastMilestone: null));
    }
  }

  void clearError() {
    // Dismissing the error also abandons the retry — drop the held input.
    emit(state.copyWith(
      error: null,
      lastFailedInput: null,
      canRetry: false,
      restingResetAt: null,
    ));
  }

  void clearResting() {
    if (state.restingResetAt != null) {
      emit(state.copyWith(restingResetAt: null));
    }
  }

  bool _protagonistPrompted = false;

  /// GM worlds (non-sentient) need the player to define their own character
  /// (the locked protagonist) on first play. True until done or skipped.
  bool get shouldOnboardProtagonist {
    final t = state.template;
    if (t == null || state.isLoading || _protagonistPrompted) return false;
    if (t.isSentient) return false; // sentient protagonist is the AI persona
    return !state.characters.any((c) => c.isProtagonist);
  }

  void skipProtagonistOnboarding() => _protagonistPrompted = true;

  /// Persist a player edit to a character/protagonist card and reflect it locally.
  Future<bool> editCharacter(
    String characterId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final updated = await ChronicleRepository.editCharacter(
        characterId,
        updates,
      );
      final list = state.characters
          .map((c) => c.id == characterId ? updated : c)
          .toList();
      emit(state.copyWith(characters: list));
      return true;
    } catch (_) {
      emit(state.copyWith(error: 'Could not save character changes.'));
      return false;
    }
  }

  Future<List<RelationCandidate>> loadRelationCandidates() =>
      ChronicleRepository.getRelationCandidates(instanceId);

  Future<Map<String, String>> loadConfirmedKinship() =>
      ChronicleRepository.getConfirmedKinship(instanceId);

  Future<bool> resolveRelationCandidate(
    String candidateId,
    String action,
    String? relation,
  ) async {
    try {
      await ChronicleRepository.resolveRelationCandidate(
        candidateId,
        action: action,
        relation: relation,
      );
      return true;
    } catch (_) {
      emit(state.copyWith(error: 'Could not update the story detail.'));
      return false;
    }
  }

  /// Establish the player's character as the instance protagonist.
  Future<void> setPlayerProtagonist(String name, {String? identity}) async {
    _protagonistPrompted = true;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    // Optimistically add a protagonist card so onboarding won't re-trigger.
    final optimistic = CharacterProfile(
      id: 'pending-protagonist',
      canonicalName: trimmed,
      role: 'protagonist (the player)',
      isProtagonist: true,
    );
    emit(state.copyWith(characters: [optimistic, ...state.characters]));
    try {
      await ChronicleRepository.setProtagonist(
        instanceId,
        name: trimmed,
        identity: identity,
      );
    } catch (_) {
      // Best-effort: the card still seeds emergently on the next turn.
    }
  }

  Future<List<ReusableProtagonist>> loadReusableProtagonists() =>
      ChronicleRepository.getReusableProtagonists(instanceId);

  /// Copy a protagonist from another save of this exact GM world. The server
  /// enforces both the owner and template boundary; no mutable card is shared.
  Future<bool> reusePlayerProtagonist(ReusableProtagonist source) async {
    _protagonistPrompted = true;
    final optimistic = CharacterProfile(
      id: 'pending-protagonist',
      canonicalName: source.name,
      role: 'protagonist (the player)',
      isProtagonist: true,
    );
    emit(state.copyWith(characters: [optimistic, ...state.characters]));
    try {
      await ChronicleRepository.setProtagonist(
        instanceId,
        reuseFromInstanceId: source.sourceInstanceId,
      );
      return true;
    } catch (_) {
      emit(
        state.copyWith(
          characters: state.characters
              .where((character) => character.id != 'pending-protagonist')
              .toList(),
          error: 'Could not reuse that protagonist.',
        ),
      );
      _protagonistPrompted = false;
      return false;
    }
  }

  /// Player-driven CORRECTION / PROMOTE surface ("Track this character" /
  /// "This person is my sister"). Mints/updates a codex card for a name visible
  /// in the prose that the projection pipeline missed, optionally asserting a
  /// typed kinship tie. Server-side this writes an EVENT-DERIVED projection
  /// (delta fold + stub promotion + typed edge + ledger entry), so the card is
  /// canonical and rewind-replayable. On success the codex list is refreshed;
  /// the WS `character_codex_updated` frame will also arrive to reconcile.
  Future<bool> trackEntity(
    String name, {
    String? role,
    String? appearance,
    String? persona,
    String? relationKind,
    String? relationLabel,
    String? relationTo,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    try {
      final result = await ChronicleRepository.trackEntity(
        instanceId,
        name: trimmed,
        role: role,
        appearance: appearance,
        persona: persona,
        relationKind: relationKind,
        relationLabel: relationLabel,
        relationTo: relationTo,
      );
      // Optimistically splice the tracked card in (dedup by id); the WS frame
      // will reconcile authoritatively when it arrives.
      final list = [
        ...state.characters.where((c) => c.id != result.character.id),
        result.character,
      ];
      emit(state.copyWith(characters: list));
      return true;
    } catch (_) {
      emit(
        state.copyWith(
          error: 'Could not track this character. Please try again.',
        ),
      );
      return false;
    }
  }

  /// Update in-chat settings (POV, mode, voice, narration tone, reply length). Optimistically reflects the
  /// change locally, then persists; the server busts its session cache so the
  /// next turn uses the new values.
  Future<bool> updateSettings({
    String? narrationPov,
    String? mode,
    String? messageLength,
    String? narrativeStyleOverride,
    String? narrationTone,
    String? focusCharacterId,
    String? personaId,
    bool clearFocusCharacter = false,
    bool clearNarrativeStyleOverride = false,
    bool clearPersona = false,
  }) async {
    final inst = state.instance;
    if (inst != null) {
      // Apply non-focus fields first, then touch focus ONLY when explicitly
      // clearing or setting it (copyWith's _unset sentinel keeps it otherwise).
      var nextInst = inst.copyWith(
        narrationPov: narrationPov,
        mode: mode,
        messageLength: messageLength,
        narrativeStyleOverride: clearNarrativeStyleOverride
            ? null
            : narrativeStyleOverride,
        narrationTone: narrationTone,
      );
      if (clearFocusCharacter) {
        nextInst = nextInst.copyWith(focusCharacterId: null);
      } else if (focusCharacterId != null) {
        nextInst = nextInst.copyWith(focusCharacterId: focusCharacterId);
      }
      if (clearPersona) {
        nextInst = nextInst.copyWith(personaId: null);
      } else if (personaId != null) {
        nextInst = nextInst.copyWith(personaId: personaId);
      }
      emit(state.copyWith(instance: nextInst));
    }
    try {
      await ChronicleRepository.updateSettings(
        instanceId,
        narrationPov: narrationPov,
        mode: mode,
        messageLength: messageLength,
        narrativeStyleOverride: narrativeStyleOverride,
        narrationTone: narrationTone,
        focusCharacterId: focusCharacterId,
        personaId: personaId,
        clearFocusCharacter: clearFocusCharacter,
        clearNarrativeStyleOverride: clearNarrativeStyleOverride,
        clearPersona: clearPersona,
      );
      return true;
    } catch (_) {
      emit(
        state.copyWith(
          instance: inst,
          error: 'Could not update settings. Please try again.',
        ),
      );
      return false;
    }
  }

  /// Reset the entire playthrough to its opening line. Server wipes all events,
  /// memories, scene summaries, characters (+ Pinecone vectors) and restores
  /// default state; we clear local cache and reload the fresh opening turn.
  Future<void> resetChat() async {
    if (state.isGenerating || state.replayingEventId != null) return;
    _pendingVariantEventId = null;
    _pendingVariantIndex = null;
    _clearHeldSpokenLines();
    emit(
      state.copyWith(
        events: const [],
        totalEvents: 0,
        hasOlderEvents: false,
        isLoading: true,
        error: null,
      ),
    );
    try {
      await HomeRepository.resetInstance(instanceId);
      await LocalDb.clearInstanceCache(instanceId);
      _ws.loadInstance(instanceId); // pull the re-seeded opening line + state
    } catch (_) {
      emit(
        state.copyWith(
          isLoading: false,
          error: 'Could not reset this playthrough. Please try again.',
        ),
      );
      _ws.loadInstance(instanceId); // resync to server truth on failure
    }
  }

  /// Rewind the story to [sequence]: removes that turn and everything after it.
  /// The existing transcript remains visible behind a blocking veil until the
  /// authoritative post-rewind window arrives. This prevents a failed rewind
  /// from looking as though history was already deleted.
  Future<void> rewind(int sequence) async {
    if (state.isGenerating ||
        state.isRewinding ||
        state.replayingEventId != null) {
      return;
    }

    emit(
      state.copyWith(
        error: null,
        isRewinding: true,
        notice: 'Rewinding to this turn…',
      ),
    );
    _rewindRequestCompleted = false;
    _clearHeldSpokenLines();

    try {
      await ChronicleRepository.rewind(instanceId, sequence);
      await LocalDb.clearInstanceCache(instanceId);
      // Pull the rolled-back state (events, stats, memories) back from the server.
      _rewindRequestCompleted = true;
      _ws.loadInstance(instanceId);
    } catch (_) {
      _rewindRequestCompleted = false;
      emit(
        state.copyWith(
          isRewinding: false,
          notice: null,
          error: 'Could not confirm the rewind. Reconnecting to your story…',
        ),
      );
      _ws.loadInstance(instanceId); // resync to server truth on failure
      return;
    }
    // Keep the loading veil up until _instanceSub receives the canonical
    // post-rewind snapshot and clears isRewinding.
  }

  /// Edit a generated AI response and persist it to the backend. Memories
  /// sourced from that turn are re-curated server-side.
  Future<void> editAiResponse(GameEvent event, String aiResponse) async {
    if (state.isGenerating || event.id.isEmpty || event.isOptimistic) return;

    final next = aiResponse.trim();
    if (next.isEmpty || next == (event.aiResponse ?? '').trim()) return;

    final idx = state.events.indexWhere((e) => e.id == event.id);
    if (idx < 0) return;

    final before = state.events[idx];
    final after = before.copyWith(aiResponse: next, isUserEdited: true);
    final optimistic = [...state.events];
    optimistic[idx] = after;
    emit(state.copyWith(events: optimistic, error: null));

    try {
      final meta = await ChronicleRepository.editEvent(
        event.id,
        aiResponse: next,
      );
      // Swap in the server-regenerated chips + presence for the rewritten prose
      // (the optimistic copy carried the old ones).
      final settled = meta == null
          ? after
          : after.copyWith(
              choices: meta.choices,
              presentCharacters: meta.presentCharacters,
              // Refresh underline data for the rewritten prose; the optimistic
              // copy carried the pre-edit mentions.
              trackableMentions: meta.trackableMentions,
            );
      final committed = [...state.events];
      final cIdx = committed.indexWhere((e) => e.id == event.id);
      if (cIdx >= 0) {
        committed[cIdx] = settled;
        emit(state.copyWith(events: committed));
      }
      await LocalDb.insertEvent(_stripTempMedia(settled));
    } catch (_) {
      final reverted = [...state.events];
      final revertIdx = reverted.indexWhere((e) => e.id == before.id);
      if (revertIdx >= 0) {
        reverted[revertIdx] = before;
      }
      emit(
        state.copyWith(
          events: reverted,
          error: 'Could not save edit. Please try again.',
        ),
      );
    }
  }

  /// Stream a fresh alternative for [event] in place, the same way a normal
  /// turn streams. The bubble drops into a "weaving" state and the narration
  /// rewrites itself token-by-token.
  void replayAiResponse(GameEvent event) {
    if (state.isGenerating ||
        state.replayingEventId != null ||
        event.id.isEmpty ||
        event.isOptimistic) {
      return;
    }

    _replayEventId = event.id;
    _replayBuffer = '';
    _replayOriginalResponse = event.aiResponse;

    // Clear the displayed prose so the bubble shows the weaving indicator until
    // the first token lands, then streams in — exactly like a fresh turn.
    final events = [...state.events];
    final idx = events.indexWhere((e) => e.id == event.id);
    if (idx >= 0) events[idx] = events[idx].copyWith(aiResponse: '');

    emit(
      state.copyWith(
        events: events,
        replayingEventId: event.id,
        isGenerating: true,
        error: null,
      ),
    );
    _armReplayWatchdog();
    _ws.sendReplay(instanceId, event.id);
  }

  /// (Re)start the liveness timer for an in-flight replay.
  void _armReplayWatchdog() {
    _replayWatchdog?.cancel();
    _replayWatchdog = Timer(_replayTimeout, () {
      if (_replayEventId == null) return;
      _restoreReplayedEvent('The replay timed out. Please try again.');
    });
  }

  void _armGenerationWatchdog(Duration timeout) {
    _generationWatchdog?.cancel();
    _generationWatchdog = Timer(timeout, () {
      if (!state.isGenerating || state.replayingEventId != null) return;
      _generationWatchdog = null;

      _finishGenerationReveal(_streamTarget);
      final events = [...state.events];
      final idx = events.lastIndexWhere((e) => e.isOptimistic);
      final hasVisibleText =
          idx >= 0 && ((events[idx].aiResponse ?? '').trim().isNotEmpty);

      if (hasVisibleText) {
        // A dropped socket can look identical to a failed provider stream. Do
        // not silently discard the prose the player just saw; retain it as an
        // explicitly unsaved draft and let the existing retry affordance carry
        // their action forward.
        final failedInput = events[idx].playerInput;
        _awaitingRetryReplacement = false;
        emit(
          state.copyWith(
            events: events,
            isGenerating: false,
            narrativeStreaming: false,
            choicesPreview: false,
            notice: null,
            error:
                'We lost the connection before this scene could be saved. Please try again.',
            canRetry: true,
            lastFailedInput: failedInput,
            hasQueuedSend: false,
            restoreComposerText: _takeQueuedSend(),
          ),
        );
        return;
      }

      _streamBuffer = '';
      _streamTarget = '';
      _awaitingRetryReplacement = false;
      _ws.loadInstance(instanceId);
      emit(
        state.copyWith(
          events: events.where((e) => !e.isOptimistic).toList(),
          isGenerating: false,
          error: null,
          hasQueuedSend: false,
          restoreComposerText: _takeQueuedSend(),
        ),
      );
    });
  }

  void _queueMessage(String message) {
    final next = message.trim();
    if (next.isEmpty) return;
    _queuedMessage = next;
    emit(
      state.copyWith(
        hasQueuedSend: true,
        notice: 'Your message is queued until the story reconnects.',
        error: null,
        lastFailedInput: null,
        canRetry: false,
      ),
    );
    _scheduleReconciliation();
  }

  /// Hold a player line until the in-flight turn persists. Does not start a
  /// generation job, does not add a second optimistic bubble, and does not
  /// poll — [generation_complete] dispatches it.
  /// Which turn a frame belongs to. A frame without `jobId` (an older server)
  /// is the active turn's, as it always was. Before the active send's `ack`
  /// lands, any id that is not the settling turn's is taken as the active one:
  /// only one new turn is ever outstanding.
  _FrameOwner _ownerOf(Map<String, dynamic> msg) {
    if (msg['instanceId']?.toString() != instanceId) return _FrameOwner.none;
    final jobId = msg['jobId']?.toString();
    if (jobId == null || jobId.isEmpty) return _FrameOwner.active;
    if (_abandonedJobIds.contains(jobId)) return _FrameOwner.none;
    if (jobId == _settlingJobId) return _FrameOwner.settling;
    if (_activeJobId != null && jobId != _activeJobId) return _FrameOwner.none;
    _activeTurnTagged = true;
    return _FrameOwner.active;
  }

  /// The next turn may start now: the active turn's prose has fully ended, the
  /// server names this turn's frames, and no other turn is still settling.
  bool _canOverlapNextTurn() =>
      state.isGenerating &&
      !state.narrativeStreaming &&
      !state.isRewinding &&
      state.replayingEventId == null &&
      _activeProseEnded &&
      _activeTurnTagged &&
      _activeJobId != null &&
      _settlingJobId == null;

  void _refreshNextTurnReady() {
    final ready =
        state.isGenerating &&
        _activeProseEnded &&
        _activeTurnTagged &&
        _activeJobId != null &&
        _settlingJobId == null;
    if (ready != state.nextTurnReady) emit(state.copyWith(nextTurnReady: ready));
  }

  /// Starts tracking a new send and returns the events to append its bubble
  /// to. When the current turn is still settling after its prose, its bubble
  /// stops being the optimistic one (so every path that drives "the" in-flight
  /// bubble now drives the new one) and its chips go, as the player moved on.
  List<GameEvent> _beginTurn() {
    final events = [...state.events];
    if (_canOverlapNextTurn()) {
      final idx = events.lastIndexWhere((e) => e.isOptimistic);
      if (idx >= 0) {
        _settlingEventId = events[idx].id;
        events[idx] = events[idx].copyWith(
          isOptimistic: false,
          choices: const [],
        );
      }
      _settlingJobId = _activeJobId;
      _settlingWatchdog?.cancel();
      // Its completion normally lands within seconds. If it never does, a
      // fresh snapshot is the truth.
      _settlingWatchdog = Timer(_settlingTimeout, () {
        if (_settlingJobId == null || isClosed) return;
        _abandonedJobIds.add(_settlingJobId!);
        _settlingJobId = null;
        _settlingEventId = null;
        _ws.loadInstance(instanceId);
      });
    }
    _activeJobId = null;
    _awaitingAck = true;
    _abandonNextAck = false;
    _activeTurnTagged = false;
    _activeProseEnded = false;
    return events;
  }

  void _clearSettlingTurn() {
    _settlingWatchdog?.cancel();
    _settlingWatchdog = null;
    _settlingJobId = null;
    _settlingEventId = null;
  }

  /// The settling turn was saved: put the final event in its bubble's place
  /// (or, after a snapshot replaced the bubbles, by its server id) without
  /// touching the active turn's loader, stream or timers.
  void _completeSettlingTurn(Map<String, dynamic> msg) {
    final eventData = msg['event'] as Map<String, dynamic>;
    final eventId = (eventData['id'] ?? '').toString();
    final events = [...state.events];
    var idx = _settlingEventId == null
        ? -1
        : events.indexWhere((e) => e.id == _settlingEventId);
    if (idx < 0 && eventId.isNotEmpty) {
      idx = events.indexWhere((e) => e.id == eventId);
    }
    final bubble = idx >= 0 ? events[idx] : null;
    final narrative =
        eventData['narrative']?.toString() ?? bubble?.aiResponse ?? '';
    final finalEvent = _finalEventFrom(msg, narrative: narrative, bubble: bubble);
    if (idx >= 0) {
      events[idx] = finalEvent;
    } else {
      // Not on screen at all: it belongs just before the active turn's bubble.
      final activeIdx = events.lastIndexWhere((e) => e.isOptimistic);
      events.insert(activeIdx >= 0 ? activeIdx : events.length, finalEvent);
    }
    _clearSettlingTurn();
    LocalDb.insertEvent(_stripTempMedia(finalEvent)).ignore();
    final trimmedEvents = _trimEvents(events);
    final nextTotalEvents = finalEvent.sequence > state.totalEvents
        ? finalEvent.sequence
        : state.totalEvents;
    emit(
      state.copyWith(
        events: trimmedEvents,
        instance: state.instance?.applyStateDiff(eventData['state_diff']),
        totalEvents: nextTotalEvents,
        hasOlderEvents:
            state.hasOlderEvents || nextTotalEvents > trimmedEvents.length,
        lastStatDeltas: _statDeltasFrom(eventData),
      ),
    );
    unawaited(_rating.recordSuccessfulTurn());
    unawaited(_refreshInk());
  }

  /// The settling turn failed after its prose. It was never saved, so the next
  /// turn (which the server holds behind it) fails too and never streams. Show
  /// the settling prose as the provisional draft with a one-tap retry, and
  /// hand the player's next line back to the composer instead of losing it.
  void _failSettlingTurn(Map<String, dynamic> msg) {
    final events = [...state.events];
    final idx = _settlingEventId == null
        ? -1
        : events.indexWhere((e) => e.id == _settlingEventId);
    final failedInput = idx >= 0 ? events[idx].playerInput : null;
    final nextIdx = events.lastIndexWhere((e) => e.isOptimistic);
    final nextInput = nextIdx >= 0 ? events[nextIdx].playerInput : null;
    if (nextIdx >= 0) events.removeAt(nextIdx);
    if (idx >= 0) {
      events[idx] = events[idx].copyWith(isOptimistic: true, choices: const []);
    }
    _abandonedJobIds.add(_settlingJobId!);
    if (_activeJobId != null) {
      _abandonedJobIds.add(_activeJobId!);
    } else if (_awaitingAck) {
      _abandonNextAck = true;
    }
    _clearSettlingTurn();
    _activeJobId = null;
    _activeProseEnded = false;
    _streamBuffer = '';
    _streamTarget = '';
    _awaitingRetryReplacement = false;
    _clearGenerationTimers();
    final queued = _takeQueuedSend();
    emit(
      state.copyWith(
        events: events,
        isGenerating: false,
        narrativeStreaming: false,
        choicesPreview: false,
        nextTurnReady: false,
        notice: null,
        error: playerErrorMessage(
          msg,
          'This scene could not be saved. Please try again.',
        ),
        canRetry: !isAuthoredSocketError(msg),
        lastFailedInput: failedInput,
        hasQueuedSend: false,
        restoreComposerText: (nextInput != null && nextInput.trim().isNotEmpty)
            ? nextInput
            : queued,
      ),
    );
  }

  /// One finished turn as the server persisted it (player input + response).
  GameEvent _finalEventFrom(
    Map<String, dynamic> msg, {
    required String narrative,
    GameEvent? bubble,
  }) {
    final eventData = msg['event'] as Map<String, dynamic>;
    // Structured world actions have no player-authored chat bubble. Prefer
    // the server's persisted field even when it is intentionally empty;
    // older servers omit it, in which case the optimistic input remains the
    // backwards-compatible fallback.
    final playerInput = eventData.containsKey('player_input')
        ? eventData['player_input']?.toString()
        : bubble?.playerInput;

    final eventId = (eventData['id'] ?? '').toString();
    final payloadLines = SpokenLine.listFromAny(
      eventData['spoken_lines'] ?? msg['spoken_lines'],
    );
    final heldLines = _takeHeldSpokenLines(eventId);
    final spokenLines = payloadLines.isNotEmpty
        ? payloadLines
        : (heldLines ?? const <SpokenLine>[]);

    return GameEvent(
      id: eventId,
      instanceId: instanceId,
      sequence: eventData['sequence'] ?? 0,
      type: eventData['event_type']?.toString() ?? 'narration',
      playerInput: playerInput,
      aiResponse: narrative,
      sceneTag: eventData['scene_tag'],
      emotionalTone: eventData['emotional_tone'],
      modelUsed: eventData['model_used']?.toString() ?? '',
      createdAt: DateTime.now(),
      choices: Choice.listFromAny(eventData['choices']),
      milestone: eventData['milestone']?.toString(),
      timeAdvanced: eventData['time_advanced']?.toString(),
      fateThread: eventData['fate_thread']?.toString(),
      presentCharacters: GameEvent.presentFromAny(
        eventData['present_characters'],
      ),
      presenceKnown: eventData.containsKey('present_characters'),
      trackableMentions: TrackableMention.listFromAny(
        eventData['trackable_mentions'],
      ),
      spokenLines: spokenLines,
    );
  }

  /// Stat deltas vs the pre-turn state — drives HUD pulses + delta chips.
  Map<String, num>? _statDeltasFrom(Map<String, dynamic> eventData) {
    final stateDiff = eventData['state_diff'];
    if (stateDiff is! Map ||
        stateDiff['world_state'] is! Map ||
        state.instance == null) {
      return null;
    }
    final old = state.instance!.worldState;
    final next = Map<String, dynamic>.from(stateDiff['world_state'] as Map);
    final deltas = <String, num>{};
    next.forEach((key, value) {
      final nv = value is num ? value : num.tryParse(value.toString());
      if (nv == null) return;
      final ov = old[key];
      if (ov != null && nv != ov) deltas[key] = nv - ov;
    });
    return deltas.isEmpty ? null : deltas;
  }

  void _holdSendUntilTurnSettles(String message) {
    final next = message.trim();
    if (next.isEmpty) return;
    _queuedMessage = next;
    final events = [...state.events];
    final idx = events.lastIndexWhere((e) => e.isOptimistic);
    if (idx >= 0 && events[idx].choices.isNotEmpty) {
      events[idx] = events[idx].copyWith(choices: const []);
    }
    emit(
      state.copyWith(
        events: events,
        hasQueuedSend: true,
        choicesPreview: false,
        notice: 'Sending when this scene settles…',
        error: null,
        lastFailedInput: null,
        canRetry: false,
      ),
    );
  }

  String? _takeQueuedSend() {
    final held = _queuedMessage;
    _queuedMessage = null;
    _reconciliationTimer?.cancel();
    _reconciliationTimer = null;
    return held;
  }

  void _scheduleReconciliation() {
    if (_queuedMessage == null || _reconciliationTimer != null) return;
    _reconciliationTimer = Timer.periodic(_reconciliationInterval, (_) {
      if (_queuedMessage == null || isClosed) {
        _reconciliationTimer?.cancel();
        _reconciliationTimer = null;
        return;
      }
      if (_ws.isConnected) _ws.loadInstance(instanceId);
    });
  }

  void _sendQueuedMessage() {
    final queued = _queuedMessage;
    if (queued == null ||
        state.isGenerating ||
        state.isRewinding ||
        !state.isConnected) {
      return;
    }
    _queuedMessage = null;
    _reconciliationTimer?.cancel();
    _reconciliationTimer = null;
    emit(state.copyWith(notice: null, hasQueuedSend: false));
    unawaited(sendMessage(queued));
  }

  void _clearGenerationTimers() {
    _generationWatchdog?.cancel();
    _generationWatchdog = null;
    _streamRevealTimer?.cancel();
    _streamRevealTimer = null;
  }

  void _queueGenerationText(String chunk) {
    if (chunk.isEmpty) return;
    _streamTarget += chunk;
    _startGenerationReveal();
  }

  void _startGenerationReveal() {
    if (_streamRevealTimer != null) return;
    _streamRevealTimer = Timer.periodic(_streamRevealInterval, (_) {
      if (_streamBuffer.length >= _streamTarget.length) {
        _streamRevealTimer?.cancel();
        _streamRevealTimer = null;
        // Reveal has caught up to the prose. If the server already signalled the
        // prose is done, the story is fully painted — drop the "writing"
        // indicator now instead of holding it until generation_complete.
        if (_proseStreamEnded && state.narrativeStreaming) {
          emit(state.copyWith(narrativeStreaming: false));
        }
        return;
      }

      final remaining = _streamTarget.length - _streamBuffer.length;
      final step = remaining <= 18
          ? remaining
          : (remaining / 3).ceil().clamp(8, 36);
      _streamBuffer = _streamTarget.substring(0, _streamBuffer.length + step);
      _replaceOptimisticAiResponse(_streamBuffer);
    });
  }

  void _finishGenerationReveal(String narrative) {
    _streamRevealTimer?.cancel();
    _streamRevealTimer = null;
    _proseStreamEnded = false;
    if (narrative.isEmpty) return;
    _streamTarget = narrative;
    _streamBuffer = narrative;
    _replaceOptimisticAiResponse(narrative);
  }

  void _replaceOptimisticAiResponse(String text) {
    if (text.isEmpty || isClosed) return;
    final events = [...state.events];
    final idx = events.lastIndexWhere((e) => e.isOptimistic);
    if (idx < 0) return;
    events[idx] = events[idx].copyWith(aiResponse: text);
    emit(state.copyWith(events: events));
  }

  void _queueReplayText(String eventId, String chunk) {
    if (chunk.isEmpty) return;
    _replayBuffer += chunk;
    if (_replayRevealTimer != null) return;
    _replayRevealTimer = Timer.periodic(_streamRevealInterval, (_) {
      final events = [...state.events];
      final idx = events.indexWhere((e) => e.id == eventId);
      if (idx < 0) {
        _replayRevealTimer?.cancel();
        _replayRevealTimer = null;
        return;
      }

      final current = events[idx].aiResponse ?? '';
      if (current.length >= _replayBuffer.length) {
        _replayRevealTimer?.cancel();
        _replayRevealTimer = null;
        return;
      }

      final remaining = _replayBuffer.length - current.length;
      final step = remaining <= 18
          ? remaining
          : (remaining / 3).ceil().clamp(8, 36);
      events[idx] = events[idx].copyWith(
        aiResponse: _replayBuffer.substring(0, current.length + step),
      );
      emit(state.copyWith(events: events));
    });
  }

  void _finishReplayReveal(String eventId, String narrative) {
    _replayRevealTimer?.cancel();
    _replayRevealTimer = null;
    _replayBuffer = narrative;
    final events = [...state.events];
    final idx = events.indexWhere((e) => e.id == eventId);
    if (idx >= 0) {
      events[idx] = events[idx].copyWith(aiResponse: narrative);
      emit(state.copyWith(events: events));
    }
  }

  /// Clear all in-flight replay bookkeeping (success path).
  void _endReplay() {
    _replayWatchdog?.cancel();
    _replayWatchdog = null;
    _replayRevealTimer?.cancel();
    _replayRevealTimer = null;
    _replayEventId = null;
    _replayBuffer = '';
    _replayOriginalResponse = null;
    if (state.replayingEventId != null) {
      emit(state.copyWith(replayingEventId: null));
    }
  }

  /// Failure path: put the turn's original prose back, surface a message, and
  /// release the loader.
  void _restoreReplayedEvent(String message) {
    final id = _replayEventId;
    final original = _replayOriginalResponse;
    final events = [...state.events];
    if (id != null && original != null) {
      final idx = events.indexWhere((e) => e.id == id);
      if (idx >= 0) events[idx] = events[idx].copyWith(aiResponse: original);
    }
    _replayWatchdog?.cancel();
    _replayWatchdog = null;
    _replayRevealTimer?.cancel();
    _replayRevealTimer = null;
    _replayEventId = null;
    _replayBuffer = '';
    _replayOriginalResponse = null;
    emit(
      state.copyWith(
        events: events,
        isGenerating: false,
        replayingEventId: null,
        error: message,
      ),
    );
  }

  /// Browse to a replay variant. This is LOCAL ONLY — it previews the variant
  /// and remembers it as pending; the choice is committed as canonical when the
  /// player next acts (see [_flushPendingVariant]).
  void selectReplayVariant(GameEvent event, int index) {
    if (state.isGenerating || state.replayingEventId != null) return;
    if (index < 0 || index >= event.replayVariants.length) return;

    _pendingVariantEventId = event.id;
    _pendingVariantIndex = index;

    final next = [...state.events];
    final idx = next.indexWhere((e) => e.id == event.id);
    if (idx >= 0) {
      next[idx] = next[idx].copyWith(
        aiResponse: event.replayVariants[index].narrative,
        modelUsed: event.replayVariants[index].modelUsed,
        selectedReplayIndex: index,
        // Show the browsed variant's OWN chips + presence + underline mentions
        // (all stored per variant) so the preview is internally consistent.
        choices: event.replayVariants[index].choices,
        presentCharacters: event.replayVariants[index].presentCharacters,
        trackableMentions: event.replayVariants[index].trackableMentions,
      );
    }
    emit(state.copyWith(events: next, error: null));
  }

  /// Commit a pending variant selection to the backend so the chosen prose
  /// becomes the canonical turn the next generation reads as history. Awaited
  /// before dispatching the next turn so there is no read-after-write race.
  Future<void> _flushPendingVariant() async {
    final id = _pendingVariantEventId;
    final index = _pendingVariantIndex;
    _pendingVariantEventId = null;
    _pendingVariantIndex = null;
    if (id == null || index == null) return;
    try {
      final updated = await ChronicleRepository.selectReplayVariant(id, index);
      final next = [...state.events];
      final idx = next.indexWhere((e) => e.id == id);
      if (idx >= 0) next[idx] = updated;
      await LocalDb.insertEvent(_stripTempMedia(updated));
      emit(state.copyWith(events: next));
    } catch (_) {
      // Non-fatal: the locally-previewed variant still shows; selection simply
      // wasn't persisted. Surfacing an error here would block the next turn.
    }
  }

  @override
  Future<void> close() async {
    _replayWatchdog?.cancel();
    _reconciliationTimer?.cancel();
    _reconciliationTimer = null;
    _clearGenerationTimers();
    _settlingWatchdog?.cancel();
    _replayRevealTimer?.cancel();
    await _ackSub.cancel();
    await _generationSub.cancel();
    await _generationStartedSub.cancel();
    await _deltaSub.cancel();
    await _streamEndSub.cancel();
    await _choicesReadySub.cancel();
    await _retryingSub.cancel();
    await _generationResetSub.cancel();
    await _memorySub.cancel();
    await _errorSub.cancel();
    await _connectionSub.cancel();
    await _instanceSub.cancel();
    await _characterCodexSub.cancel();
    await _replayDeltaSub.cancel();
    await _replayCompleteSub.cancel();
    await _milestoneSub.cancel();
    await _spokenLinesSub.cancel();
    await _mediaReadySub.cancel();
    await _mediaUnseenSub.cancel();
    await _mediaFailedSub.cancel();
    await _ws.disconnect();
    _clearHeldSpokenLines();
    audioController.removeListener(_onAudioChanged);
    await super.close();
  }

  Future<void> _checkMediaUsage() async {
    try {
      final usage = await _mediaRepo.getUsage();
      emit(state.copyWith(isMediaAvailable: usage != null));
    } catch (_) {
      emit(state.copyWith(isMediaAvailable: false));
    }
  }

  Future<void> playVoiceLine(String eventId, String lineId) async {
    final lineKey = '$eventId:$lineId';
    if (state.unvoiceableLines.contains(lineKey)) {
      return;
    }

    if (audioController.isLinePlaying(eventId, lineId)) {
      await audioController.stop();
      emit(
        state.copyWith(
          playingVoiceEventId: null,
          playingVoiceLineId: null,
          loadingVoiceEventId: null,
          loadingVoiceLineId: null,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        loadingVoiceEventId: eventId,
        loadingVoiceLineId: lineId,
      ),
    );
    audioController.setLoading(eventId, lineId);

    try {
      final res = await _mediaRepo.requestVoice(
        instanceId: instanceId,
        eventId: eventId,
        lineId: lineId,
      );

      if (res.isReady) {
        // Clear loading before playing: play() resolves only when the line
        // ends, and the playing ids follow the controller (_onAudioChanged).
        emit(
          state.copyWith(
            loadingVoiceEventId: null,
            loadingVoiceLineId: null,
          ),
        );
        await audioController.play(
          eventId: eventId,
          lineId: lineId,
          url: res.url!,
        );
      }
    } on MediaUnvoiceableException {
      HapticFeedback.lightImpact();
      final updated = Set<String>.from(state.unvoiceableLines)..add(lineKey);
      audioController.setLoading(null, null);
      emit(
        state.copyWith(
          unvoiceableLines: updated,
          loadingVoiceEventId: null,
          loadingVoiceLineId: null,
        ),
      );
    } on MediaRestingException catch (e) {
      audioController.setLoading(null, null);
      emit(
        state.copyWith(
          mediaNotice: _nextMediaNotice(e.restingCopy, NoticeTone.info),
          loadingVoiceEventId: null,
          loadingVoiceLineId: null,
        ),
      );
    } catch (_) {
      audioController.setLoading(null, null);
      emit(
        state.copyWith(
          mediaNotice: _nextMediaNotice(
            _mediaFailureCopy('voice'),
            NoticeTone.error,
          ),
          loadingVoiceEventId: null,
          loadingVoiceLineId: null,
        ),
      );
    }
  }

  Future<void> stopVoicePlayback() async {
    await audioController.stop();
    emit(
      state.copyWith(
        playingVoiceEventId: null,
        playingVoiceLineId: null,
        loadingVoiceEventId: null,
        loadingVoiceLineId: null,
      ),
    );
  }

  Future<void> requestPicture(String eventId) {
    return _requestTurnMedia(
      eventId,
      kind: MediaKind.picture,
      request: () => _mediaRepo.requestPicture(
        instanceId: instanceId,
        eventId: eventId,
      ),
    );
  }

  Future<void> requestVideo(String eventId, String lineId) {
    return _requestTurnMedia(
      eventId,
      kind: MediaKind.video,
      lineId: lineId,
      request: () => _mediaRepo.requestVideo(
        instanceId: instanceId,
        eventId: eventId,
        lineId: lineId,
      ),
    );
  }

  Future<void> requestTurnVideo(String eventId) {
    return _requestTurnMedia(
      eventId,
      kind: MediaKind.video,
      request: () => _mediaRepo.requestTurnVideo(
        instanceId: instanceId,
        eventId: eventId,
      ),
    );
  }

  /// Puts a queued placeholder under [eventId] at once, then swaps it for the
  /// server's answer; a refusal removes it again and explains why.
  Future<void> _requestTurnMedia(
    String eventId, {
    required MediaKind kind,
    String? lineId,
    required Future<MediaRequestResponse> Function() request,
  }) async {
    final tempPrefix = kind == MediaKind.picture ? 'temp_pic' : 'temp_vid';
    final tempId = '${tempPrefix}_${DateTime.now().millisecondsSinceEpoch}';
    final placeholder = TurnMedia(
      mediaId: tempId,
      kind: kind,
      status: MediaStatus.queued,
      lineId: lineId,
    );

    final events = [...state.events];
    final idx = events.indexWhere((e) => e.id == eventId);
    if (idx >= 0) {
      final ev = events[idx];
      events[idx] = ev.copyWith(media: [...ev.media, placeholder]);
      emit(state.copyWith(events: events));
    }

    try {
      final res = await request();

      final nextEvents = [...state.events];
      final nIdx = nextEvents.indexWhere((e) => e.id == eventId);
      if (nIdx >= 0) {
        final ev = nextEvents[nIdx];
        final mediaList = [...ev.media];
        final pIdx = mediaList.indexWhere((m) => m.mediaId == tempId);
        if (pIdx >= 0) {
          mediaList[pIdx] = TurnMedia(
            mediaId: res.mediaId ?? tempId,
            kind: kind,
            status: res.isReady ? MediaStatus.ready : MediaStatus.queued,
            url: res.isReady ? res.url : null,
            lineId: lineId,
            // A film the player just asked for plays once, muted, on arrival.
            justRequested: res.isReady && kind == MediaKind.video,
          );
          nextEvents[nIdx] = ev.copyWith(media: mediaList);
          LocalDb.insertEvent(_stripTempMedia(nextEvents[nIdx])).ignore();
          emit(state.copyWith(events: nextEvents));
        }
      }
    } on MediaRestingException catch (e) {
      _removeTempMedia(
        eventId,
        tempId,
        _nextMediaNotice(e.restingCopy, NoticeTone.info),
      );
    } catch (_) {
      _removeTempMedia(
        eventId,
        tempId,
        _nextMediaNotice(_mediaFailureCopy(kind.name), NoticeTone.error),
      );
    }
  }

  void _removeTempMedia(String eventId, String tempId, MediaNotice notice) {
    emit(
      state.copyWith(
        events: _eventsWithoutMedia(eventId, tempId, persist: false),
        mediaNotice: notice,
      ),
    );
  }

  static GameEvent _stripTempMedia(GameEvent event) {
    if (!event.media.any((m) => m.mediaId.startsWith('temp_'))) {
      return event;
    }
    return event.copyWith(
      media: event.media.where((m) => !m.mediaId.startsWith('temp_')).toList(),
    );
  }

  @visibleForTesting
  static GameEvent stripTempMedia(GameEvent event) => _stripTempMedia(event);

  /// The playing line mirrors the controller, so a line that ends on its
  /// own (or is buffering) is never shown as playing.
  void _onAudioChanged() {
    if (isClosed) return;
    final playing = audioController.isPlaying;
    final eventId = playing ? audioController.activeEventId : null;
    final lineId = playing ? audioController.activeLineId : null;
    if (eventId == state.playingVoiceEventId &&
        lineId == state.playingVoiceLineId) {
      return;
    }
    emit(
      state.copyWith(
        playingVoiceEventId: eventId,
        playingVoiceLineId: lineId,
      ),
    );
  }
}

/// Which turn a socket frame belongs to while two can overlap.
enum _FrameOwner { active, settling, none }
