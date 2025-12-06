import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.title});

  final String title;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  String? _serverClientId;
  GoogleSignInAccount? _currentUser;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadEnvironmentVariables();
    await _initializeGoogleSignIn();
  }

  Future<void> _loadEnvironmentVariables() async {
    try {
      await dotenv.load();
      _serverClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID'];
    } catch (e) {
      debugPrint('Warning: Could not load .env file: $e');
      _serverClientId = 'your-default-client-id';
    }
  }

  Future<void> _initializeGoogleSignIn() async {
    if (_serverClientId == null) {
      debugPrint('Warning: GOOGLE_WEB_CLIENT_ID not found in .env file');
      return;
    }
    await GoogleSignIn.instance.initialize(serverClientId: _serverClientId!);
    GoogleSignIn.instance.authenticationEvents.listen((event) {
      if (mounted) {
        setState(() {
          _currentUser = switch (event) {
            GoogleSignInAuthenticationEventSignIn() => event.user,
            GoogleSignInAuthenticationEventSignOut() => null,
          };
        });
        if (_currentUser != null) {
          _getAuthTokens();
        }
      }
    });
  }

  Future<void> _getAuthTokens() async {
    if (_currentUser != null) {
      try {
        final auth = await _currentUser!.authentication;
        debugPrint(
          'Signed in as: ${_currentUser!.displayName} (${_currentUser!.email})',
        );
        debugPrint('ID token: ${auth.idToken}');
      } catch (e) {
        debugPrint('Error getting auth tokens: $e');
      }
    }
  }

  Future<void> _handleSignUp() async {
    setState(() => _isLoading = true);
    try {
      if (GoogleSignIn.instance.supportsAuthenticate()) {
        await GoogleSignIn.instance.authenticate(
          scopeHint: ['email', 'profile'],
        );
      } else {
        debugPrint('This platform requires platform-specific sign-in UI');
      }
    } catch (e) {
      debugPrint('Google sign-in error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _currentUser;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (user != null) ...[
              CircleAvatar(
                radius: 30,
                backgroundImage: user.photoUrl != null
                    ? NetworkImage(user.photoUrl!)
                    : null,
                child: user.photoUrl == null
                    ? Text(user.displayName?.substring(0, 1) ?? '?')
                    : null,
              ),
              const SizedBox(height: 8),
              Text(user.displayName ?? ''),
              Text(user.email),
              const SizedBox(height: 16),
            ],
            ElevatedButton(
              onPressed: _isLoading ? null : _handleSignUp,
              child: Text(_isLoading ? 'Signing in…' : 'Sign In with Google'),
            ),
          ],
        ),
      ),
    );
  }
}
