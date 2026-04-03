import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  Future<void> init({required String serverClientId}) async {
    await _googleSignIn.initialize(serverClientId: serverClientId);
  }

  Future<GoogleSignInAccount?> signIn() async {
    if (_googleSignIn.supportsAuthenticate()) {
      return _googleSignIn.authenticate(scopeHint: ['email', 'profile']);
    }
    return _googleSignIn.attemptLightweightAuthentication();
  }

  GoogleSignInAuthentication getAuthentication(GoogleSignInAccount account) {
    return account.authentication;
  }

  Future<void> signOut() => _googleSignIn.signOut();
}
