import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import '../core/auth/auth_service.dart';
import '../core/auth/google_auth_service.dart';
import '../core/network/api_client.dart';
import '../shared/models/user.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.title});

  final String title;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  final _googleAuthService = GoogleAuthService();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  late final TabController _tabController;

  User? _currentUser;
  bool _googleReady = false;
  bool _isLoading = false;
  bool _otpSent = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _bootstrap();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final cachedUser = await AuthService.getCachedUser();

    try {
      await dotenv.load();
      final clientId = dotenv.env['GOOGLE_WEB_CLIENT_ID']?.trim();
      if (clientId != null && clientId.isNotEmpty) {
        await _googleAuthService.init(serverClientId: clientId);
        _googleReady = true;
      }
    } catch (_) {
      _googleReady = false;
    }

    if (!mounted) return;
    setState(() {
      _currentUser = cachedUser;
    });
  }

  void _setMessage(String message) {
    if (!mounted) return;
    setState(() => _message = message);
  }

  String _normalizePhone(String input) {
    final trimmed = input.trim();
    if (trimmed.startsWith('+')) {
      return '+${trimmed.substring(1).replaceAll(RegExp(r'\D'), '')}';
    }
    return '+${trimmed.replaceAll(RegExp(r'\D'), '')}';
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      if (!_googleReady) {
        throw Exception(
          'Google Sign-In is not configured in the Flutter .env file.',
        );
      }

      final googleUser = await _googleAuthService.signIn();
      if (googleUser == null) {
        throw Exception('Google Sign-In was cancelled.');
      }

      final googleAuth = _googleAuthService.getAuthentication(googleUser);
      final idToken = googleAuth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception('Google did not return an ID token.');
      }

      final user = await AuthService.loginWithGoogle(idToken);
      if (!mounted) return;
      setState(() => _currentUser = user);
      context.go('/');
    } on ApiException catch (e) {
      _setMessage(e.message);
    } catch (e) {
      _setMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleSendOtp() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      final phone = _normalizePhone(_phoneController.text);
      await AuthService.sendOtp(phone);
      if (!mounted) return;
      setState(() => _otpSent = true);
      _setMessage('Verification code sent to $phone');
    } on ApiException catch (e) {
      _setMessage(e.message);
    } catch (e) {
      _setMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleVerifyOtp() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      final user = await AuthService.verifyOtp(
        phone: _normalizePhone(_phoneController.text),
        code: _otpController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _currentUser = user);
      context.go('/');
    } on ApiException catch (e) {
      _setMessage(e.message);
    } catch (e) {
      _setMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleLogout() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      try {
        await _googleAuthService.signOut();
      } catch (_) {}

      await AuthService.logout();
      if (!mounted) return;
      setState(() {
        _currentUser = null;
        _otpSent = false;
        _phoneController.clear();
        _otpController.clear();
      });
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              if (user != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.username,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        if (user.email.isNotEmpty) Text(user.email),
                        if (user.phone != null) Text(user.phone!),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _isLoading ? null : _handleLogout,
                          child: const Text('Log Out'),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: 'Google'),
                    Tab(text: 'Phone OTP'),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 260,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _GoogleTab(
                        isLoading: _isLoading,
                        googleReady: _googleReady,
                        onPressed: _handleGoogleSignIn,
                      ),
                      _PhoneTab(
                        phoneController: _phoneController,
                        otpController: _otpController,
                        isLoading: _isLoading,
                        otpSent: _otpSent,
                        onSendOtp: _handleSendOtp,
                        onVerifyOtp: _handleVerifyOtp,
                      ),
                    ],
                  ),
                ),
              ],
              if (_message != null) ...[
                const SizedBox(height: 16),
                Text(
                  _message!,
                  style: TextStyle(
                    color: _message!.startsWith('Verification code sent')
                        ? Colors.greenAccent
                        : Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GoogleTab extends StatelessWidget {
  const _GoogleTab({
    required this.isLoading,
    required this.googleReady,
    required this.onPressed,
  });

  final bool isLoading;
  final bool googleReady;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Use Google Sign-In to get a backend JWT for Everlore.'),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: isLoading || !googleReady ? null : onPressed,
          icon: const Icon(Icons.login),
          label: Text(isLoading ? 'Signing In...' : 'Continue with Google'),
        ),
        if (!googleReady) ...[
          const SizedBox(height: 12),
          const Text(
            'Set GOOGLE_WEB_CLIENT_ID in everlore/.env to enable this flow.',
          ),
        ],
      ],
    );
  }
}

class _PhoneTab extends StatelessWidget {
  const _PhoneTab({
    required this.phoneController,
    required this.otpController,
    required this.isLoading,
    required this.otpSent,
    required this.onSendOtp,
    required this.onVerifyOtp,
  });

  final TextEditingController phoneController;
  final TextEditingController otpController;
  final bool isLoading;
  final bool otpSent;
  final Future<void> Function() onSendOtp;
  final Future<void> Function() onVerifyOtp;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Phone number',
            hintText: '+15551234567',
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: isLoading ? null : onSendOtp,
          child: Text(isLoading ? 'Sending...' : 'Send Verification Code'),
        ),
        if (otpSent) ...[
          const SizedBox(height: 16),
          TextField(
            controller: otpController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Verification code',
              hintText: '123456',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: isLoading ? null : onVerifyOtp,
            child: Text(isLoading ? 'Verifying...' : 'Verify and Sign In'),
          ),
        ],
      ],
    );
  }
}
