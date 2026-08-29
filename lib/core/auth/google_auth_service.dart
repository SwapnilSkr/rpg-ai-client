import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
  /// Returns null when the player backs out of the chooser, which is a normal
  /// outcome and not an error.
  Future<String?> signIn() async {
    final account = _googleSignIn.supportsAuthenticate()
        ? await _googleSignIn.authenticate(scopeHint: ['email', 'profile'])
        : await _googleSignIn.attemptLightweightAuthentication();
    if (account == null) return null;

    final googleIdToken = account.authentication.idToken;
    if (googleIdToken == null || googleIdToken.isEmpty) return null;

    final credential = GoogleAuthProvider.credential(idToken: googleIdToken);
    final result = await _firebaseAuth.signInWithCredential(credential);
    // Not `getIdToken(true)`: the token was minted by this exchange moments
    // ago, so forcing a refresh only adds a network round trip to the slowest
    // screen in the app.
    return result.user?.getIdToken();
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
