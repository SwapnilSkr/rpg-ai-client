import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// A Google sign-in attempt that ended without a session, for a reason that was
/// not the player's choice.
///
/// The player is never shown [code]; it exists so that a failure reported from
/// a device we cannot reach ("it just doesn't do anything") names the step that
/// actually broke instead of describing the symptom.
class GoogleSignInFailure implements Exception {
  /// A short, stable, hand-written identifier for the step that failed.
  final String code;
  final String? detail;

  const GoogleSignInFailure(this.code, [this.detail]);

  @override
  String toString() =>
      'GoogleSignInFailure($code)${detail == null ? '' : ': $detail'}';
}

/// Google sign-in, brokered through Firebase Auth.
///
/// The shape of this class is unchanged for callers, but what comes out of it
/// is different: [signIn] now returns a **Firebase** ID token rather than the
/// raw Google one. Google still runs the account chooser — that part cannot be
/// delegated — but the credential it returns is exchanged with Firebase, and
/// Firebase's token is what the server verifies.
///
/// Why route through Firebase at all, when the raw Google token also worked:
/// the server previously had to ask Google's `tokeninfo` endpoint to vouch for
/// every sign-in, a network round trip on the auth path that fails whenever
/// Google's endpoint is slow. A Firebase ID token is a signed JWT the server
/// verifies locally against published keys. It also gives us one account model
/// to hang Apple sign-in off later, which the App Store requires of any app
/// offering third-party sign-in.
class GoogleAuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  Future<void> init({required String serverClientId}) async {
    await _googleSignIn.initialize(serverClientId: serverClientId);
  }

  /// Runs the Google account chooser, exchanges the result with Firebase, and
  /// returns a Firebase ID token for the server.
  ///
  /// Returns null for exactly one outcome: the player closed the chooser. Every
  /// other way this can end without a token throws [GoogleSignInFailure].
  ///
  /// The distinction is the whole point. Four separate outcomes used to return
  /// null, and the caller — correctly reading null as "they changed their mind"
  /// — said nothing for all four. A sign-in that was actually broken looked
  /// exactly like a sign-in the player had walked away from: the button
  /// finished, no message appeared, and nothing happened. Silence is only the
  /// right answer when leaving was a choice.
  Future<String?> signIn() async {
    final GoogleSignInAccount? account;
    try {
      account = _googleSignIn.supportsAuthenticate()
          ? await _googleSignIn.authenticate(scopeHint: ['email', 'profile'])
          : await _googleSignIn.attemptLightweightAuthentication();
    } on GoogleSignInException catch (e) {
      // Backing out of the chooser is not a failure, and the plugin reports it
      // as an exception rather than a null account. Its message reads
      // "activity is cancelled by the user", which is developer wording that
      // should never reach a player — so it becomes a null return, and the
      // caller stays quiet.
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      throw GoogleSignInFailure('chooser-${e.code.name}', e.description);
    }

    // Only reachable on the lightweight path, which returns null when there is
    // no account it can resume without asking. Nobody chose anything here.
    if (account == null) {
      throw const GoogleSignInFailure('no-account');
    }

    final googleIdToken = account.authentication.idToken;
    if (googleIdToken == null || googleIdToken.isEmpty) {
      throw const GoogleSignInFailure('no-google-id-token');
    }

    final credential = GoogleAuthProvider.credential(idToken: googleIdToken);
    final UserCredential result;
    try {
      result = await _firebaseAuth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw GoogleSignInFailure('firebase-${e.code}', e.message);
    }

    final user = result.user;
    if (user == null) {
      throw const GoogleSignInFailure('no-firebase-user');
    }

    // Not `getIdToken(true)`: the token was minted by this exchange moments
    // ago, so forcing a refresh only adds a network round trip to the slowest
    // screen in the app.
    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw const GoogleSignInFailure('no-firebase-id-token');
    }
    return idToken;
  }

  /// Ends both sessions.
  ///
  /// Signing out of Google alone would leave the Firebase session live, and the
  /// next launch would silently restore an account the player believes they
  /// signed out of.
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    await _googleSignIn.signOut();
  }
}
