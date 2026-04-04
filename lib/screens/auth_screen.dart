import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import '../core/auth/auth_service.dart';
import '../core/auth/google_auth_service.dart';
import '../core/network/api_client.dart';
import '../shared/models/user.dart';
import '../app/theme/nexus_theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.title});
  final String? title;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  final _googleAuthService = GoogleAuthService();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  late TabController _tabController;

  User? _currentUser;
  bool _googleReady = false;
  bool _isLoading = false;
  bool _codeSent = false;
  String? _errorMessage;
  String? _successMessage;

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
    setState(() => _currentUser = cachedUser);
  }

  void _clearMessages() {
    _errorMessage = null;
    _successMessage = null;
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
      _clearMessages();
    });
    try {
      if (!_googleReady) throw Exception('Google sign-in is not available.');
      final googleUser = await _googleAuthService.signIn();
      if (googleUser == null) throw Exception('Sign-in was cancelled.');
      final googleAuth = _googleAuthService.getAuthentication(googleUser);
      final idToken = googleAuth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception('Could not retrieve your Google credentials.');
      }
      final user = await AuthService.loginWithGoogle(idToken);
      if (!mounted) return;
      setState(() => _currentUser = user);
      context.go('/');
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage =
          e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSendCode() async {
    setState(() {
      _isLoading = true;
      _clearMessages();
    });
    try {
      final phone = _normalizePhone(_phoneController.text);
      await AuthService.sendOtp(phone);
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _successMessage = 'A verification code was sent to $phone';
      });
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage =
          e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleVerifyCode() async {
    setState(() {
      _isLoading = true;
      _clearMessages();
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
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage =
          e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSignOut() async {
    setState(() => _isLoading = true);
    try {
      try { await _googleAuthService.signOut(); } catch (_) {}
      await AuthService.logout();
      if (!mounted) return;
      setState(() {
        _currentUser = null;
        _codeSent = false;
        _phoneController.clear();
        _otpController.clear();
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EverloreTheme.void0,
      body: SafeArea(
        child: Stack(
          children: [
            // Ambient glow
            Positioned(
              top: -60,
              right: -60,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      EverloreTheme.violet.withValues(alpha: 0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            Column(
              children: [
                // Back button
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: EverloreTheme.ash, size: 20),
                      onPressed: () =>
                          context.canPop() ? context.pop() : context.go('/'),
                    ),
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: _currentUser != null
                        ? _buildProfile(_currentUser!)
                        : _buildSignIn(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfile(User user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 24),

        // Avatar circle
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [EverloreTheme.violet, EverloreTheme.violetDim],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
                color: EverloreTheme.goldDim.withValues(alpha: 0.4), width: 2),
          ),
          child: Center(
            child: Text(
              user.username.isNotEmpty
                  ? user.username[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: EverloreTheme.gold,
                fontSize: 32,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        Text(
          user.username,
          style: const TextStyle(
            color: EverloreTheme.parchment,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),

        const SizedBox(height: 6),

        if (user.email.isNotEmpty)
          Text(user.email, style: const TextStyle(color: EverloreTheme.ash)),
        if (user.phone != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(user.phone!,
                style: const TextStyle(color: EverloreTheme.ash)),
          ),

        const SizedBox(height: 8),

        // Tier badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: _tierColor(user.tier).withValues(alpha: 0.15),
            border: Border.all(
                color: _tierColor(user.tier).withValues(alpha: 0.4)),
          ),
          child: Text(
            user.tier.toUpperCase(),
            style: TextStyle(
              color: _tierColor(user.tier),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ),

        const SizedBox(height: 40),

        Container(
          decoration: EverloreTheme.cardDecoration,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _profileRow(Icons.explore, 'Browse Worlds',
                  () => context.push('/templates')),
              const Divider(color: EverloreTheme.white10, height: 24),
              _profileRow(Icons.auto_stories, 'Your Realms', () => context.go('/')),
            ],
          ),
        ),

        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isLoading ? null : _handleSignOut,
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.5, color: EverloreTheme.crimson),
                  )
                : const Icon(Icons.logout, size: 18),
            label: Text(_isLoading ? 'Signing out...' : 'Sign Out'),
            style: OutlinedButton.styleFrom(
              foregroundColor: EverloreTheme.crimson,
              side: BorderSide(
                  color: EverloreTheme.crimson.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _profileRow(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, color: EverloreTheme.gold, size: 20),
            const SizedBox(width: 14),
            Text(label, style: const TextStyle(color: EverloreTheme.parchment)),
            const Spacer(),
            const Icon(Icons.chevron_right, color: EverloreTheme.ash, size: 18),
          ],
        ),
      ),
    );
  }

  Color _tierColor(String tier) {
    return switch (tier) {
      'creator' => EverloreTheme.violet,
      'premium' => EverloreTheme.gold,
      _ => EverloreTheme.ash,
    };
  }

  Widget _buildSignIn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),

        // Header
        const Text(
          'Welcome, Traveller',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: EverloreTheme.gold,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Sign in to enter your realms and continue your story.',
          textAlign: TextAlign.center,
          style: TextStyle(color: EverloreTheme.ash, fontSize: 14, height: 1.5),
        ),

        const SizedBox(height: 36),

        // Tab selector
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: EverloreTheme.void2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: EverloreTheme.goldDim.withValues(alpha: 0.3)),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: EverloreTheme.void4,
              border: Border.all(
                  color: EverloreTheme.goldDim.withValues(alpha: 0.5)),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: EverloreTheme.gold,
            unselectedLabelColor: EverloreTheme.ash,
            labelStyle: const TextStyle(
                fontWeight: FontWeight.w600, letterSpacing: 0.3, fontSize: 13),
            tabs: const [
              Tab(text: 'Google'),
              Tab(text: 'Phone'),
            ],
          ),
        ),

        const SizedBox(height: 24),

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
                codeSent: _codeSent,
                onSendCode: _handleSendCode,
                onVerifyCode: _handleVerifyCode,
              ),
            ],
          ),
        ),

        // Messages
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: EverloreTheme.crimson.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: EverloreTheme.crimson.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline,
                    color: EverloreTheme.crimson, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                        color: EverloreTheme.crimson, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_successMessage != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: EverloreTheme.verdant.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: EverloreTheme.verdant.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    color: EverloreTheme.verdant, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _successMessage!,
                    style: const TextStyle(
                        color: EverloreTheme.verdant, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 32),
      ],
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
        // Google sign in card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: EverloreTheme.cardDecoration,
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: EverloreTheme.void4,
                  border: Border.all(
                      color: EverloreTheme.white20, width: 1),
                ),
                child: const Icon(Icons.g_mobiledata,
                    color: Colors.white70, size: 30),
              ),
              const SizedBox(height: 14),
              const Text(
                'Sign in with Google',
                style: TextStyle(
                  color: EverloreTheme.parchment,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Fast and secure — no password needed',
                style: TextStyle(color: EverloreTheme.ash, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: isLoading || !googleReady ? null : onPressed,
            icon: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: EverloreTheme.void1),
                  )
                : const Icon(Icons.g_mobiledata, size: 22),
            label: Text(isLoading ? 'Signing in...' : 'Continue with Google'),
            style: ElevatedButton.styleFrom(
              backgroundColor: EverloreTheme.gold,
              foregroundColor: EverloreTheme.void0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        if (!googleReady)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'Google sign-in is not configured for this build.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: EverloreTheme.ash.withValues(alpha: 0.6),
                  fontSize: 11),
            ),
          ),
      ],
    );
  }
}

class _PhoneTab extends StatelessWidget {
  const _PhoneTab({
    required this.phoneController,
    required this.otpController,
    required this.isLoading,
    required this.codeSent,
    required this.onSendCode,
    required this.onVerifyCode,
  });

  final TextEditingController phoneController;
  final TextEditingController otpController;
  final bool isLoading;
  final bool codeSent;
  final Future<void> Function() onSendCode;
  final Future<void> Function() onVerifyCode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          style: const TextStyle(color: EverloreTheme.parchment),
          decoration: const InputDecoration(
            hintText: '+1 555 000 0000',
            prefixIcon: Icon(Icons.phone_outlined,
                color: EverloreTheme.ash, size: 18),
            labelText: 'Phone number',
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: isLoading ? null : onSendCode,
            child: Text(isLoading && !codeSent
                ? 'Sending code...'
                : 'Send Verification Code'),
          ),
        ),
        if (codeSent) ...[
          const SizedBox(height: 20),
          TextField(
            controller: otpController,
            keyboardType: TextInputType.number,
            style: const TextStyle(
              color: EverloreTheme.parchment,
              fontSize: 22,
              letterSpacing: 8,
            ),
            textAlign: TextAlign.center,
            maxLength: 6,
            decoration: const InputDecoration(
              hintText: '— — — — — —',
              hintStyle: TextStyle(letterSpacing: 4, fontSize: 16),
              counterText: '',
              labelText: 'Verification code',
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: isLoading ? null : onVerifyCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: EverloreTheme.violet,
                foregroundColor: Colors.white,
              ),
              child: Text(isLoading ? 'Verifying...' : 'Enter the Realm'),
            ),
          ),
        ],
      ],
    );
  }
}
