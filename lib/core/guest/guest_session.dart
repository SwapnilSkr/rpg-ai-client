import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../auth/auth_service.dart';
import '../network/api_client.dart';
import '../storage/secure_storage.dart';
import '../telemetry/telemetry.dart';
import '../../shared/models/user.dart';
import 'guest_limit.dart';
import 'sign_in_required.dart';

/// A player who is playing without an account yet.
///
/// The guest is a real user on the server, so its token and user are stored
/// exactly like a signed-in session and every authenticated call just works.
/// The only difference the app sees is `user.guest`, which this class mirrors
/// into [isGuestListenable] and uses to decide when a sign-in must carry the
/// guest along (see [exchange]).
class GuestSession {
  GuestSession({
    Future<dynamic> Function(String path, {Map<String, dynamic>? body})? post,
    Future<dynamic> Function(String path)? get,
    Future<String?> Function()? readToken,
    Future<String?> Function()? readUser,
    Future<void> Function(Map<String, dynamic> session)? persist,
    Future<void> Function(Map<String, dynamic> user)? saveUser,
    Future<String> Function()? installId,
    void Function()? onStarted,
    Future<void> Function()? discard,
    Future<void> Function(Duration wait)? delay,
  }) : _post = post ?? ((path, {body}) => ApiClient.post(path, body: body)),
       _get = get ?? ApiClient.get,
       _readToken = readToken ?? SecureStore.getToken,
       _readUser = readUser ?? SecureStore.getUserData,
       _persist = persist ?? AuthService.persistSession,
       _saveUser =
           saveUser ??
           ((user) => SecureStore.saveUserData(jsonEncode(user))),
       _installId = installId ?? _telemetryInstallId,
       _onStarted =
           onStarted ?? (() => Telemetry.instance.track('guest_started')),
       _discard = discard ?? AuthService.logout,
       _delay = delay ?? Future<void>.delayed;

  static GuestSession instance = GuestSession();

  @visibleForTesting
  static void replaceInstance(GuestSession session) => instance = session;

  /// Google sign-in is retried this many times when the server says the
  /// guest's work is still settling.
  static const int transferRetries = 3;
  static const List<Duration> _transferBackoff = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
  ];

  final Future<dynamic> Function(String path, {Map<String, dynamic>? body})
  _post;
  final Future<dynamic> Function(String path) _get;
  final Future<String?> Function() _readToken;
  final Future<String?> Function() _readUser;
  final Future<void> Function(Map<String, dynamic> session) _persist;
  final Future<void> Function(Map<String, dynamic> user) _saveUser;
  final Future<String> Function() _installId;
  final void Function() _onStarted;
  final Future<void> Function() _discard;
  final Future<void> Function(Duration wait) _delay;

  final ValueNotifier<bool> _isGuest = ValueNotifier<bool>(false);

  /// Whether the stored session is a guest's. Follows [noteUser], which every
  /// path that saves the user calls, so it is current without a storage read.
  bool get isGuest => _isGuest.value;
  ValueListenable<bool> get isGuestListenable => _isGuest;

  /// Raised whenever the server refuses a guest for want of an account: a REST
  /// 403 `sign_in_required` or a play-socket `SIGN_IN_REQUIRED` frame. The
  /// "keep your story" sheet listens to this.
  ValueListenable<int> get signInRequired => SignInRequired.requests;

  /// Announces a refusal. REST refusals are raised by [ApiClient] itself; the
  /// play cubit calls this for its socket frame.
  void raiseSignInRequired() => SignInRequired.raise();

  int _turnsUsed = 0;
  bool _prompted = false;
  Timer? _promptTimer;

  /// Time to finish reading the last allowed reply before the sheet covers
  /// its closing lines; that reply is what should make keeping the story
  /// worth a sign-in.
  @visibleForTesting
  static Duration keepStoryReadingPause = const Duration(seconds: 4);

  /// Turns this guest has had answered, seeded from the stored user's
  /// `guestTurns` and advanced by [noteTurnCompleted]. Always 0 for an account.
  int get turnsUsed => _turnsUsed;

  /// Whether this guest has no turns left to play.
  bool get turnsSpent => isGuest && _turnsUsed >= kGuestTurnLimit;

  /// Mirrors the user just saved. A claim or merge returns a user without the
  /// guest flag, which is what turns this off.
  void noteUser(User? user) {
    final guest = user?.guest ?? false;
    _isGuest.value = guest;
    if (!guest) {
      _turnsUsed = 0;
      _prompted = false;
      _promptTimer?.cancel();
      return;
    }
    // A user saved mid-story can be older than the replies counted since, so
    // the count never goes backwards while the guest stays the same.
    final seeded = user?.guestTurns ?? 0;
    if (seeded > _turnsUsed) _turnsUsed = seeded;
  }

  /// A guest's reply finished successfully. Counts it and, when it was the
  /// last allowed one and nothing is still streaming, raises the sign-in sheet
  /// once. Failed or refused turns never reach here; the server gives those
  /// back too. Claimed or merged guests are neither counted nor prompted.
  void noteTurnCompleted({bool streaming = false}) {
    if (!isGuest) return;
    _turnsUsed++;
    if (shouldPromptKeepStory(
      used: _turnsUsed,
      limit: kGuestTurnLimit,
      streaming: streaming,
      alreadyPrompted: _prompted,
    )) {
      _prompted = true;
      _promptTimer?.cancel();
      _promptTimer = Timer(keepStoryReadingPause, () {
        if (isGuest) raiseSignInRequired();
      });
    }
  }

  /// Forgets the guest locally. The server purges an abandoned guest by itself
  /// after 30 days, so there is nothing to delete over the network.
  void clear() {
    _isGuest.value = false;
    _turnsUsed = 0;
    _prompted = false;
    _promptTimer?.cancel();
  }

  Future<User?> _storedUser() async {
    final raw = await _readUser();
    if (raw == null) return null;
    try {
      return User.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Reads the stored session into [isGuest]. Called when the app opens.
  Future<void> load() async {
    final token = await _readToken();
    noteUser(token == null ? null : await _storedUser());
  }

  /// The guest's token when one is waiting to be claimed or merged, else null.
  /// A signed-in account's token is never returned.
  Future<String?> pendingGuestToken() async {
    final token = await _readToken();
    if (token == null || token.isEmpty) return null;
    final user = await _storedUser();
    return user != null && user.guest ? token : null;
  }

  /// Creates the guest session, or resumes the stored one, and saves it
  /// through the normal session path. Emits `guest_started` only when the
  /// server made a new guest. A signed-in session is returned untouched.
  Future<User> start() async {
    final stored = await _storedUser();
    final token = await _readToken();
    final hasToken = token != null && token.isNotEmpty;
    if (hasToken && stored != null && !stored.guest) return stored;

    final resuming = hasToken && stored != null && stored.guest;
    // With a stored guest the bearer header is its token, which is what lets
    // the server hand the same session back instead of refusing the install.
    final response = await _post(
      '/auth/guest',
      body: {'install_id': await _installId()},
    );
    await _persist(Map<String, dynamic>.from(response as Map));
    final user = User.fromJson(
      Map<String, dynamic>.from(response['user'] as Map),
    );
    noteUser(user);
    if (!resuming) _onStarted();
    return user;
  }

  /// Opens a stored guest session when the app starts. The server is asked
  /// through the ordinary `/auth/me`; only a rejected token is answered with a
  /// resume. Offline, the stored user stands. Null means the guest could not be
  /// kept and the local session was dropped.
  Future<User?> resume() async {
    final stored = await _storedUser();
    if (stored == null || !stored.guest) return stored;
    try {
      final me = Map<String, dynamic>.from(await _get('/auth/me') as Map);
      await _saveUser(me);
      final user = User.fromJson(me);
      noteUser(user);
      return user;
    } on ApiException catch (e) {
      if (e.statusCode != 401) return stored;
      try {
        return await start();
      } catch (_) {
        await _discard();
        return null;
      }
    } catch (_) {
      return stored;
    }
  }

  /// Posts a sign-in carrying the pending guest, if there is one.
  ///
  /// The body gains `guest_token` only for a guest session, so a plain sign-in
  /// is byte-for-byte what it was. When the server answers
  /// `guest_transfer_pending` the guest token is kept and, when [retryTransfer]
  /// is set, the same request is sent again with a growing wait, up to
  /// [transferRetries] times, before the error is let through. Phone codes are
  /// one-time, so phone sign-in passes `false` and shows the server's words.
  Future<Map<String, dynamic>> exchange(
    String path,
    Map<String, dynamic> body, {
    bool retryTransfer = false,
  }) async {
    final guestToken = await pendingGuestToken();
    final payload = {...body, if (guestToken != null) 'guest_token': guestToken};
    for (var attempt = 0; ; attempt++) {
      try {
        final response = await _post(path, body: payload);
        return Map<String, dynamic>.from(response as Map);
      } on ApiException catch (e) {
        final pending = e.code == 'guest_transfer_pending';
        if (!pending || !retryTransfer || attempt >= transferRetries) rethrow;
        await _delay(_transferBackoff[attempt]);
      }
    }
  }
}

Future<String> _telemetryInstallId() async {
  // Sharing may be off, but the install id is minted regardless; init makes
  // sure it exists even if an earlier start-up failed part-way.
  await Telemetry.instance.init();
  final id = Telemetry.instance.installId;
  if (id.isEmpty) throw StateError('No install id yet.');
  return id;
}
