import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../config/env.dart';
import 'guide_anchor.dart';
import 'guide_beat.dart';
import 'guide_progress.dart';
import 'guide_store.dart';

/// Drives the Chronicler: which arc is running, which beat is showing, and
/// — the part that matters most — which arcs may never run again.
///
/// A single top-level instance, matching how `router` is held in
/// `app_routes.dart`. The overlay lives above the Navigator and screens call in
/// from inside routes, so there is no useful common ancestor to scope it to.
///
/// ## The never-repeat guarantee
///
/// A flow is recorded the instant it *starts*, not when it finishes. Force-quit
/// mid-arc, navigate away, background the app, lose the network — the arc is
/// already marked and will not auto-start again. Auto-start requires no record
/// at all; anything else is an explicit replay or a server-side version bump.
class GuideController extends ChangeNotifier {
  GuideController._() {
    GuideAnchorRegistry.instance.onSurfaceChanged = _onSurfaceChanged;
  }
  static final instance = GuideController._();

  static const _skipPromptId = 'system.skip_prompt';

  /// Arcs waved off before the app offers to silence the guide entirely.
  ///
  /// Two was a hair trigger: waving off a couple of arcs on the way to your
  /// story is ordinary impatience, not a verdict on the guide, and the offer
  /// it raised silences *everything* — the play and chronicle arcs included —
  /// behind a button that never says so. Four is a third of the arcs there
  /// are, which is a real signal.
  static const _skipsBeforeOffer = 4;

  /// Quiet gap between one arc ending and the next being allowed to open.
  ///
  /// Each surface still explains itself exactly once; this only stops the
  /// explanations landing back to back. Crossing play, realm and chronicle to
  /// reach a story used to hand over three arcs inside a minute, which is
  /// where the fatigue lives — not in any single arc's length.
  /// Mutable only so the widget tests can shrink it; nothing in the app
  /// writes to it.
  @visibleForTesting
  static Duration arcGap = const Duration(seconds: 8);

  GuideProgress _progress = GuideProgress.empty;
  bool _ready = false;

  GuideFlow? _flow;
  int _index = 0;
  bool _askingSkipAll = false;
  String? _location;

  /// Arcs started in this process. Guards against a rebuild or a duplicated
  /// trigger re-entering an arc before its record has been written.
  final Set<String> _startedThisSession = {};

  /// Arcs inside their settle delay. Two triggers for the same surface fire
  /// within a frame of each other; without this the second would be swallowed
  /// and — because it never actually painted — never recorded either, leaving
  /// the arc owed but unreachable for the rest of the session.
  final Set<String> _pending = {};

  /// Per-beat watchdog: waits for a target to appear, and ends the arc when
  /// one that had appeared goes away again.
  Timer? _beatWatch;

  /// Whether the running beat has ever had a target on screen. Distinguishes
  /// "not laid out yet" (worth waiting for) from "the surface it lived on is
  /// gone" (worth ending the arc over).
  bool _beatResolved = false;

  /// Beats of the running arc that had nothing to point at and were dropped.
  ///
  /// Only the progress rail cares. An arc declares six beats and delivers
  /// five when a surface has no persona picker on it, and counting the one
  /// that never appeared left the dots jumping a place and finishing on
  /// "6 of 6" after five. See [beatStep] and [beatTotal].
  final Set<int> _dropped = {};

  /// Whether rehearsal mode still owes this process a wipe.
  ///
  /// Rehearsal is meant to replay the walkthrough on a cold start and on a
  /// genuine sign-in — not on every `/auth/me`. The account is re-fetched on
  /// resume and on token refresh, and wiping there tore down whatever arc was
  /// on screen mid-beat and re-ran arcs at arbitrary moments, which is exactly
  /// what makes the guide look broken to someone testing with the flag on.
  /// Cleared after a wipe, re-armed by [onSignedOut].
  bool _rehearsalArmed = true;

  /// Live `GuideOnEnter` widgets, keyed by their state object.
  final Map<Object, ({GuideFlow flow, VoidCallback start})> _triggers = {};

  /// True while the quiet gap after an arc is still running. See [arcGap].
  bool _inArcGap = false;

  /// Ends the gap and re-offers whatever it held back.
  Timer? _gapTimer;

  /// Arcs whose surface was covered when they came due, waiting for whatever
  /// is over it to go away. Held rather than recorded, so nothing is spent.
  final Map<String, GuideFlow> _held = {};

  GuideProgress get progress => _progress;
  bool get isReady => _ready;
  GuideFlow? get activeFlow => _flow;
  int get beatIndex => _index;

  /// True while a target is being scrolled into view.
  ///
  /// The overlay stops easing the opening while this holds, so it tracks the
  /// moving target exactly instead of trailing a quarter-second behind it.
  bool get isRevealing => _revealing;
  bool _revealing = false;

  /// True while the guide is asking whether to silence every remaining tip.
  bool get isAskingSkipAll => _askingSkipAll;

  GuideBeat? get currentBeat {
    final flow = _flow;
    if (flow == null || _index < 0 || _index >= flow.beats.length) return null;
    return flow.beats[_index];
  }

  bool get isLastBeat => _flow != null && _index >= _flow!.beats.length - 1;

  /// Where the player is in the beats actually being delivered, counting from
  /// zero — not the raw index into [GuideFlow.beats].
  int get beatStep => _index - _dropped.where((i) => i < _index).length;

  /// How many beats this arc will actually deliver, as currently known.
  int get beatTotal {
    final flow = _flow;
    if (flow == null) return 1;
    return math.max(1, flow.beats.length - _dropped.length);
  }

  /// Load the device record. Safe to call more than once.
  Future<void> init() async {
    if (_ready) return;
    // Rehearsal: every cold start wipes the local record so the whole
    // walkthrough replays without needing to log out / back in. Without
    // this, a developer with GUIDE_REHEARSAL=true still sees nothing on
    // /play or /chronicle until the next successful hydrateFromAccount,
    // which is exactly the "hindered" report.
    if (AppConfig.guideRehearsal) {
      _progress = await GuideStore.reset();
      _ready = true;
      _rehearsalArmed = false;
      _startedThisSession.clear();
      _pending.clear();
      debugPrint('[guide] rehearsal mode: cold-start record cleared.');
      notifyListeners();
      return;
    }
    _progress = await GuideStore.load();
    _ready = true;
    notifyListeners();
  }

  /// Fold the account's record in after `/auth/me`. Union semantics, so a
  /// second device inherits everything already seen.
  Future<void> hydrateFromAccount(
    Map<String, dynamic>? remoteFlows, {
    bool remoteOptOut = false,
  }) async {
    // Rehearsal: sign-in hands you a blank slate instead of your own history,
    // so the whole guide can be watched end to end as often as it takes.
    // `GUIDE_REHEARSAL=true` in `.env`, debug builds only.
    if (AppConfig.guideRehearsal) {
      // Already rehearsed this process: this is a refresh, not a sign-in.
      // Leave the record — and anything on screen — exactly as it is.
      if (!_rehearsalArmed) {
        _ready = true;
        return;
      }
      _cancelBeatWatch();
      _flow = null;
      _index = 0;
      _askingSkipAll = false;
      _startedThisSession.clear();
      _pending.clear();
      _progress = await GuideStore.reset();
      _ready = true;
      _rehearsalArmed = false;
      debugPrint(
        '[guide] rehearsal mode: record cleared, every arc will run again.',
      );
      notifyListeners();
      return;
    }

    _progress = await GuideStore.syncFromRemote(
      remoteFlows,
      remoteOptOut: remoteOptOut,
    );
    _ready = true;
    notifyListeners();
  }

  /// Whether [flow] would run if asked right now.
  bool canAutoStart(GuideFlow flow) {
    if (_progress.optOut) return false;
    if (_startedThisSession.contains(flow.id)) return false;
    final record = _progress[flow.id];
    if (record == null) return true;
    // A materially changed surface replays exactly once, for everyone.
    return flow.version > record.version;
  }

  /// Start [flow] if it has never run. The ordinary entry point for screens.
  ///
  /// [delay] lets a surface settle — routes, sheets, and streamed narration all
  /// need a beat before there is anything stable to point at.
  Future<void> maybeStart(
    GuideFlow flow, {
    Duration delay = const Duration(milliseconds: 400),
  }) async {
    if (!_ready) await init();
    if (!canAutoStart(flow)) return;
    // Never talk over a running arc; the later trigger will come round again
    // on the next visit, and its record is still untouched.
    if (_flow != null || _pending.contains(flow.id)) return;

    final from = _location;
    _pending.add(flow.id);
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    _pending.remove(flow.id);

    // Everything below is re-checked after the wait, because a settle delay is
    // long enough for the player to have moved on. Starting anyway is what put
    // an arc for one surface on top of another — and recorded it spent, so the
    // surface it belonged to never got its walkthrough at all.
    if (_flow != null) return;
    if (!_stillHere(flow, from)) return;
    if (!canAutoStart(flow)) return;

    // The surface is there but something is over it — the protagonist sheet on
    // a first play, a dialog, a menu. Hold the arc rather than talking across
    // it; `_onSurfaceChanged` brings it back when the way is clear.
    if (GuideAnchorRegistry.instance.isCovered(flow.anchorIds)) {
      _held[flow.id] = flow;
      return;
    }

    // Too soon after the last arc. Held rather than recorded — exactly like a
    // covered surface — so the arc is still owed and opens when the gap ends.
    if (_inArcGap) {
      _held[flow.id] = flow;
      return;
    }
    _held.remove(flow.id);

    _startedThisSession.add(flow.id);
    _flow = flow;
    _index = -1;
    _dropped.clear();
    // Written before the first beat paints: from here on, this arc is spent
    // whatever happens next.
    _record(flow, step: 0, status: GuideStatus.seen, flush: false);
    _advanceToResolvableBeat(1);
  }

  /// Whether [flow] still belongs where the player is standing.
  ///
  /// A flow that names a route is checked against that route, so it does not
  /// matter whether the router had reported a location yet when the trigger
  /// fired. A sheet-bound flow names none, and is held to the location being
  /// unchanged since it was offered.
  bool _stillHere(GuideFlow flow, String? from) {
    final where = _location;
    final route = flow.route;
    if (route != null && where != null) {
      return route == '/' ? where == '/' : where.startsWith(route);
    }
    return from == null || where == from;
  }

  /// Run [flow] from the top regardless of its record.
  ///
  /// There is deliberately no way to reach this from the app. A player is
  /// walked through a surface the first time they open it and never again;
  /// the only switch they get is silence (see [setOptOut]). This exists so the
  /// widget tests can drive an arc without faking a first run.
  @visibleForTesting
  Future<void> replay(GuideFlow flow) async {
    if (!_ready) await init();
    _cancelBeatWatch();
    _flow = flow;
    _index = -1;
    _dropped.clear();
    _startedThisSession.add(flow.id);
    _advanceToResolvableBeat(1);
  }

  /// Advance one beat, ending the arc after the last.
  void next() {
    if (_flow == null) return;
    if (isLastBeat) {
      _end(GuideStatus.done);
      return;
    }
    _advanceToResolvableBeat(1);
  }

  /// Step back, for a player who wants to re-read the previous beat.
  void back() {
    if (_flow == null || _index <= 0) return;
    _advanceToResolvableBeat(-1);
  }

  /// Dismiss the running arc. Recorded as skipped — never replayed.
  Future<void> skip() async {
    final flow = _flow;
    if (flow == null) return;
    _end(GuideStatus.skipped);

    // One courtesy, once ever: a player who has waved two arcs off is telling
    // us something, and being asked again every screen is the failure mode.
    final asked = _progress[_skipPromptId] != null;
    if (!asked &&
        !_progress.optOut &&
        _progress.skipCount >= _skipsBeforeOffer) {
      _askingSkipAll = true;
      notifyListeners();
    }
  }

  /// Answer to the "silence everything?" offer. Asked at most once per account.
  Future<void> resolveSkipAll({required bool silence}) async {
    _askingSkipAll = false;
    _progress = _progress
        .withFlow(
          _skipPromptId,
          GuideFlowProgress(
            version: 1,
            step: 0,
            status: GuideStatus.done,
            at: DateTime.now(),
          ),
        )
        .copyWith(optOut: silence);
    notifyListeners();
    await GuideStore.save(_progress, flush: true);
  }

  /// Silence or restore the guide from settings.
  Future<void> setOptOut(bool value) async {
    if (value) {
      _cancelBeatWatch();
      _flow = null;
    }
    _progress = _progress.copyWith(optOut: value);
    notifyListeners();
    await GuideStore.save(_progress, flush: true);
  }

  /// Register a live `GuideOnEnter`. See [_offerTriggersFor].
  /// Retry anything held back once the surface over it clears.
  void _onSurfaceChanged() {
    if (_held.isEmpty || _flow != null) return;
    if (_inArcGap) return;
    final waiting = _held.values.toList();
    for (final flow in waiting) {
      if (GuideAnchorRegistry.instance.isCovered(flow.anchorIds)) continue;
      _held.remove(flow.id);
      unawaited(maybeStart(flow));
    }
  }

  void registerTrigger(Object token, GuideFlow flow, VoidCallback start) {
    _triggers[token] = (flow: flow, start: start);
  }

  void unregisterTrigger(Object token) => _triggers.remove(token);

  /// Re-offer every arc bound to [location].
  ///
  /// The tab shell is an `IndexedStack`: once a branch has been visited it
  /// stays mounted forever, so `initState` fires exactly once per session.
  /// Without this, a surface revisited later — or replayed from settings while
  /// standing on it — would never see its arc again. `maybeStart` still decides
  /// eligibility, so this only ever offers; it never repeats a spent arc.
  void _offerTriggersFor(String? location) {
    if (location == null) return;
    for (final trigger in _triggers.values.toList()) {
      final route = trigger.flow.route;
      if (route == null) continue;
      // '/' is the story shelf, not a prefix for every route in the app.
      final matches = route == '/'
          ? location == '/'
          : location.startsWith(route);
      if (matches) trigger.start();
    }
  }

  /// Router location changed. Arcs are screen-scoped, so the running one ends
  /// rather than trailing a tip onto the next surface. Modal sheets do not
  /// change location, so sheet-bound arcs survive.
  void onLocationChanged(String location) {
    final previous = _location;
    _location = location;
    if (previous == location) return;
    final flow = _flow;
    if (flow != null && previous != null) {
      // A flow that declared a route survives navigation within it (a query
      // change, a sub-path); anything else ends the arc.
      final route = flow.route;
      if (route == null || route == '/' || !location.startsWith(route)) {
        _end(GuideStatus.seen);
      }
    }
    _offerTriggersFor(location);
  }

  /// System back, while the guide is up.
  ///
  /// Everything else on screen is behind a scrim, so back is what a player
  /// reaches for to clear a tip — and letting it navigate instead sends them
  /// off the surface they were only trying to see. Returns false when there is
  /// nothing showing, which passes the press straight through to the router.
  Future<bool> handleSystemBack() async {
    if (_askingSkipAll) {
      await resolveSkipAll(silence: false);
      return true;
    }
    if (_flow == null) return false;
    await skip();
    return true;
  }

  /// Flush pending writes when the app goes to the background.
  Future<void> onAppPaused() => GuideStore.flush();

  /// Forget device state on logout. The account keeps its record.
  Future<void> onSignedOut() async {
    _cancelBeatWatch();
    _flow = null;
    _index = 0;
    _askingSkipAll = false;
    _startedThisSession.clear();
    _pending.clear();
    _held.clear();
    _gapTimer?.cancel();
    _gapTimer = null;
    _inArcGap = false;
    _progress = GuideProgress.empty;
    _ready = false;
    // Signing back in is a fresh rehearsal, which is what the flag promises.
    _rehearsalArmed = true;
    await GuideStore.clear();
    notifyListeners();
  }

  /// Walk [step] beats at a time until one can actually be shown.
  ///
  /// Beats whose target is absent are dropped rather than spotlighting empty
  /// space — an empty bond rail or a world without stats simply has nothing to
  /// point at. Targets that merely have not been laid out yet get a grace
  /// period first (see [_startBeatWatch]).
  void _advanceToResolvableBeat(int step) {
    final flow = _flow;
    if (flow == null) return;
    _cancelBeatWatch();

    final registry = GuideAnchorRegistry.instance;
    var next = _index + step;
    while (next >= 0 && next < flow.beats.length) {
      final beat = flow.beats[next];
      final anchors = beat.anchors;
      if (anchors.isEmpty) break;
      if (registry.firstResolvable(anchors) != null) break;
      final offscreen = registry.firstMounted(anchors);
      if (offscreen != null) {
        // Present but scrolled past — bring it into view rather than dropping
        // it, which is what makes arcs through long sheets work at all.
        _showBeat(flow, next);
        unawaited(_revealAnchor(offscreen));
        return;
      }
      if (!beat.requiresAnchor) {
        // Worth waiting on: it may simply be mid-transition.
        _showBeat(flow, next);
        return;
      }
      _dropped.add(next);
      next += step;
    }

    if (next < 0 || next >= flow.beats.length) {
      _end(step > 0 ? GuideStatus.done : GuideStatus.seen);
      return;
    }

    _showBeat(flow, next);
  }

  /// Commit to showing beat [index] and start watching its target.
  void _showBeat(GuideFlow flow, int index) {
    _index = index;
    final registry = GuideAnchorRegistry.instance;
    final anchor = registry.firstResolvable(flow.beats[index].anchors);
    _beatResolved = anchor != null;
    notifyListeners();
    // Resolvable but running off an edge: bring it properly into view rather
    // than cutting the opening at the screen edge. The same reveal the
    // scrolled-past case uses, so the opening tracks it on the way.
    if (anchor != null && registry.overflowsViewport(anchor)) {
      unawaited(_revealAnchor(anchor));
    }
    _record(flow, step: index, status: GuideStatus.seen, flush: false);
    _startBeatWatch(flow.beats[index]);
  }

  /// Scroll a mounted-but-offscreen target into view, then let the host pick
  /// the rect up on its next frame.
  Future<void> _revealAnchor(String anchor) async {
    _revealing = true;
    try {
      await GuideAnchorRegistry.instance.ensureVisible(anchor);
    } finally {
      _revealing = false;
    }
    if (_flow == null) return;
    notifyListeners();
  }

  /// Watch the running beat's target for as long as the beat is showing.
  ///
  /// Two jobs, and they are the same measurement taken from either side:
  ///
  ///  * **Before it appears** — a target mid-route or mid-transition gets a
  ///    grace period, after which the beat degrades to an unanchored card so
  ///    the guidance is still delivered.
  ///  * **After it appears** — a target that *goes away* means the surface
  ///    went with it: a sheet dismissed, a tab swapped, a dialog closed. None
  ///    of those move the router, so nothing else would end the arc, and the
  ///    Chronicler would sit there over an unrelated screen pointing at
  ///    nothing until the player navigated. That is the stale overlay, and
  ///    this is what ends it.
  void _startBeatWatch(GuideBeat beat) {
    _cancelBeatWatch();
    if (beat.anchors.isEmpty) return;

    const tick = Duration(milliseconds: 100);

    /// How long a target may be missing before its surface is presumed gone.
    /// Long enough to ride out a route transition (≈250 ms on this app's
    /// shell), short enough that a dismissed sheet/dialog does not leave
    /// the scrim hanging over the play screen. 320 ms is two frames past
    /// the shell's own transition and the bug-report threshold for "scale
    /// walkthroughs left over" when GUIDE_REHEARSAL=false.
    const lostLimit = Duration(milliseconds: 320);

    /// How long to wait for a target that has never appeared.
    const appearLimit = Duration(milliseconds: 960);

    var lost = Duration.zero;
    var waited = Duration.zero;

    _beatWatch = Timer.periodic(tick, (timer) {
      if (_flow == null) {
        _cancelBeatWatch();
        return;
      }
      final registry = GuideAnchorRegistry.instance;

      if (registry.firstResolvable(beat.anchors) != null) {
        lost = Duration.zero;
        if (!_beatResolved) {
          _beatResolved = true;
          notifyListeners();
        }
        return;
      }

      // Mounted but off screen, or being scrolled to: not gone, just moving.
      final moving = _revealing || registry.firstMounted(beat.anchors) != null;

      if (_beatResolved) {
        if (moving) {
          lost = Duration.zero;
          return;
        }
        lost += tick;
        if (lost >= lostLimit) _end(GuideStatus.seen);
        return;
      }

      // Never appeared. The clock runs even while the target is mounted:
      // something can be in the tree and still impossible to bring into view —
      // the bond rail inside a collapsed status panel is the case that bit —
      // and waiting on it forever leaves the screen dimmed around nothing.
      waited += tick;
      if (waited < appearLimit) return;
      _cancelBeatWatch();
      if (beat.requiresAnchor) {
        // It asked for a target and there is none. Dropping it is what
        // `requiresAnchor` means; showing the words over a dimmed screen with
        // nothing lit describes something the player cannot see.
        _dropped.add(_index);
        _advanceToResolvableBeat(1);
        return;
      }
      // Nothing to point at, and the beat did not insist on one: deliver it
      // as a plain card rather than dropping the guidance.
      notifyListeners();
    });
  }

  /// Start the quiet gap that keeps the next arc off the heels of this one.
  void _openArcGap() {
    _gapTimer?.cancel();
    _gapTimer = null;
    _inArcGap = false;
    // A zero gap is not a zero-length timer — it is no timer at all, so
    // nothing is left pending for a test to trip over.
    if (arcGap <= Duration.zero) return;
    _inArcGap = true;
    _gapTimer = Timer(arcGap, () {
      _gapTimer = null;
      _inArcGap = false;
      _onSurfaceChanged();
    });
  }

  void _cancelBeatWatch() {
    _beatWatch?.cancel();
    _beatWatch = null;
  }

  void _end(GuideStatus status) {
    final flow = _flow;
    final step = _index;
    _openArcGap();
    _cancelBeatWatch();
    _beatResolved = false;
    _revealing = false;
    _flow = null;
    _index = 0;
    // The overlay closes on this frame. Persistence follows; nothing the
    // player sees should ever wait on a keychain or a socket.
    notifyListeners();
    if (flow != null) {
      // Arc boundary — this is where the debounced server write is spent.
      _record(flow, step: step, status: status, flush: true);
    }
  }

  /// Update the in-memory record synchronously, then persist in the background.
  void _record(
    GuideFlow flow, {
    required int step,
    required GuideStatus status,
    required bool flush,
  }) {
    _progress = _progress.withFlow(
      flow.id,
      GuideFlowProgress(
        version: flow.version,
        step: step < 0 ? 0 : step,
        status: status,
        at: DateTime.now(),
      ),
    );
    unawaited(GuideStore.save(_progress, flush: flush));
  }
}

/// App-wide handle, mirroring the top-level `router`.
final guide = GuideController.instance;
