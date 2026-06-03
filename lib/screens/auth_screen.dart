import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/auth/auth_service.dart';
import '../core/auth/google_auth_service.dart';
import '../core/network/api_client.dart';
import '../shared/models/user.dart';
import '../app/theme/nexus_theme.dart';
import '../core/onboarding/interests_store.dart';
import '../shared/widgets/keyboard_aware_scroll.dart';
import '../shared/widgets/realm_backdrop.dart';
import '../shared/widgets/neu.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.title});
  final String? title;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _googleAuthService = GoogleAuthService();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  DialCode _dialCode = kDefaultDialCode; // United States +1

  User? _currentUser;
  bool _googleReady = false;
  bool _isLoading = false;
  bool _isUpdatingPreferences = false;
  bool _isDeletingAccount = false;
  bool _codeSent = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
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

  /// After a successful sign-in, send first-time players through the interests
  /// onboarding (once per device); everyone else lands on Discover (NOT their
  /// realms — that's reachable from Discover's top icons). Applies to creators
  /// too.
  Future<void> _routeAfterAuth() async {
    final onboarded = await InterestsStore.isOnboarded();
    if (!mounted) return;
    context.go(onboarded ? '/discover' : '/onboarding');
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
      await _routeAfterAuth();
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
      final phone =
          _normalizePhone('${_dialCode.code}${_phoneController.text}');
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
        phone: _normalizePhone('${_dialCode.code}${_phoneController.text}'),
        code: _otpController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _currentUser = user);
      await _routeAfterAuth();
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage =
          e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Return from the OTP step to phone entry to edit the number.
  void _handleEditPhone() {
    setState(() {
      _codeSent = false;
      _otpController.clear();
      _clearMessages();
    });
  }

  Future<void> _handleSignOut() async {
    setState(() {
      _currentUser = null;
      _codeSent = false;
      _phoneController.clear();
      _otpController.clear();
    });
    try {
      try {
        await _googleAuthService.signOut();
      } catch (_) {}
      await AuthService.logout();
    } catch (_) {
      // UI already shows signed-out state; session clear is best-effort.
    }
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: EverloreTheme.void2,
        title: Text(
          'Delete your account?',
          style: EverloreTheme.serifDisplay(
            size: 18,
            color: EverloreTheme.parchment,
          ),
        ),
        content: Text(
          'This permanently deletes your profile, all your realms and chats, '
          'and any worlds you created. This cannot be undone.',
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
              _handleDeleteAccount();
            },
            child: Text(
              'Delete',
              style: EverloreTheme.ui(color: EverloreTheme.crimson),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteAccount() async {
    setState(() => _isDeletingAccount = true);
    try {
      await AuthService.deleteAccount();
      try {
        await _googleAuthService.signOut();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _currentUser = null;
        _codeSent = false;
        _phoneController.clear();
        _otpController.clear();
        _isDeletingAccount = false;
      });
      context.go('/auth');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Your account was deleted.',
            style: EverloreTheme.ui(size: 13, color: EverloreTheme.parchment),
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isDeletingAccount = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete account: ${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _errorMessage = message;
        _isDeletingAccount = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete account: $message')),
      );
    }
  }

  Future<void> _handleNsfwToggle(bool enabled) async {
    if (_currentUser == null || _isUpdatingPreferences) return;

    setState(() {
      _isUpdatingPreferences = true;
      _clearMessages();
    });

    try {
      final updated = await AuthService.setNsfwEnabled(enabled);
      if (!mounted) return;
      setState(() {
        _currentUser = updated;
        _successMessage = enabled
            ? 'Mature content enabled for eligible worlds.'
            : 'Mature content disabled.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? 'NSFW preference enabled.'
                : 'NSFW preference disabled.',
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update preference: ${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      setState(() => _errorMessage = message);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update preference: $message')),
      );
    } finally {
      if (mounted) setState(() => _isUpdatingPreferences = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Shrink the scroll viewport with keyboard [viewInsets] (see [Padding]
      // on the scroll area) — avoids Android resize/viewport mismatches.
      resizeToAvoidBottomInset: false,
      backgroundColor: EverloreTheme.void0,
      body: RealmBackdrop(
        // Profile view doesn't need the gallery band — keep it focused.
        showPortraits: _currentUser == null,
        child: SafeArea(
          child: Column(
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
                child: KeyboardAwareScroll(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: _currentUser != null
                      ? _buildProfile(_currentUser!)
                      : _buildSignIn(),
                ),
              ),
            ],
          ),
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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 18,
                offset: const Offset(6, 8),
              ),
              BoxShadow(
                color: EverloreTheme.violet.withValues(alpha: 0.3),
                blurRadius: 22,
              ),
            ],
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
              const Divider(color: EverloreTheme.white10, height: 24),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: user.preferences.nsfwEnabled,
                onChanged: (_isUpdatingPreferences || _isLoading)
                    ? null
                    : _handleNsfwToggle,
                activeColor: EverloreTheme.crimson,
                activeTrackColor:
                    EverloreTheme.crimson.withValues(alpha: 0.35),
                title: const Text(
                  'Enable Mature Content (NSFW)',
                  style: TextStyle(
                    color: EverloreTheme.parchment,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  _isUpdatingPreferences
                      ? 'Updating...'
                      : 'Required to play mature, NSFW-capable worlds.',
                  style: const TextStyle(
                    color: EverloreTheme.ash,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        NeuButton(
          label: 'Sign Out',
          icon: Icons.logout,
          primary: false,
          accent: EverloreTheme.crimson,
          onTap: _handleSignOut,
        ),
        const SizedBox(height: 16),
        NeuButton(
          label: 'Delete Account',
          icon: Icons.delete_forever_outlined,
          primary: false,
          accent: EverloreTheme.crimson,
          onTap: _isDeletingAccount ? null : _confirmDeleteAccount,
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
        const SizedBox(height: 8),

        // Header
        const Center(child: ForgeMark(size: 76)),
        const SizedBox(height: 20),
        Text(
          'Cross the Threshold',
          textAlign: TextAlign.center,
          style: GoogleFonts.cinzel(
            color: EverloreTheme.gold,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Sign in to step back into your realms and continue your story.',
          textAlign: TextAlign.center,
          style: GoogleFonts.ebGaramond(
            color: EverloreTheme.ash,
            fontSize: 16,
            height: 1.5,
          ),
        ),

        const SizedBox(height: 32),

        _PhoneTab(
          phoneController: _phoneController,
          otpController: _otpController,
          isLoading: _isLoading,
          codeSent: _codeSent,
          dialCode: _dialCode,
          onDialCodeChanged: (c) => setState(() => _dialCode = c),
          onSendCode: _handleSendCode,
          onVerifyCode: _handleVerifyCode,
          onEditPhone: _handleEditPhone,
        ),

        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: Divider(
                color: EverloreTheme.ash.withValues(alpha: 0.35),
                height: 1,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                'or',
                style: TextStyle(
                  fontFamily: EverloreTheme.uiFamily,
                  color: EverloreTheme.ash,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: EverloreTheme.ash.withValues(alpha: 0.35),
                height: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        NeuButton(
          label: _isLoading ? 'Signing in…' : 'Continue with Google',
          icon: Icons.g_mobiledata,
          primary: false,
          loading: _isLoading,
          onTap: (_isLoading || !_googleReady) ? null : _handleGoogleSignIn,
        ),
        if (!_googleReady)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'Google sign-in is not configured for this build.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: EverloreTheme.uiFamily,
                color: EverloreTheme.ash.withValues(alpha: 0.6),
                fontSize: 11,
              ),
            ),
          ),

        // Messages
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          EngravedBanner(message: _errorMessage!, error: true),
        ],
        if (_successMessage != null) ...[
          const SizedBox(height: 16),
          EngravedBanner(message: _successMessage!),
        ],

        const SizedBox(height: 32),
      ],
    );
  }
}

class _PhoneTab extends StatefulWidget {
  const _PhoneTab({
    required this.phoneController,
    required this.otpController,
    required this.isLoading,
    required this.codeSent,
    required this.dialCode,
    required this.onDialCodeChanged,
    required this.onSendCode,
    required this.onVerifyCode,
    required this.onEditPhone,
  });

  final TextEditingController phoneController;
  final TextEditingController otpController;
  final bool isLoading;
  final bool codeSent;
  final DialCode dialCode;
  final ValueChanged<DialCode> onDialCodeChanged;
  final Future<void> Function() onSendCode;
  final Future<void> Function() onVerifyCode;
  final VoidCallback onEditPhone;

  @override
  State<_PhoneTab> createState() => _PhoneTabState();
}

class _PhoneTabState extends State<_PhoneTab> {
  static const int _resendSeconds = 30;
  Timer? _timer;
  int _cooldown = 0;
  final FocusNode _phoneFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.codeSent) _startCooldown();
  }

  @override
  void didUpdateWidget(_PhoneTab old) {
    super.didUpdateWidget(old);
    if (widget.codeSent && !old.codeSent) _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phoneFocus.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _cooldown--;
        if (_cooldown <= 0) t.cancel();
      });
    });
  }

  Future<void> _resend() async {
    _startCooldown(); // optimistic — blocks spamming even if the call 429s
    await widget.onSendCode();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.06, 0),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
      child: widget.codeSent ? _buildOtpStep() : _buildPhoneStep(),
    );
  }

  Widget _buildPhoneStep() {
    return Column(
      key: const ValueKey('phone-step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KeyboardAwareInputGroup(
          focusNode: _phoneFocus,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NeuField(
                controller: widget.phoneController,
                focusNode: _phoneFocus,
                scrollPadding: const EdgeInsets.symmetric(horizontal: 24),
                hintText: '555 000 0000',
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
                ],
                prefix: DialCodeButton(
                  value: widget.dialCode,
                  onChanged: widget.onDialCodeChanged,
                ),
              ),
              const SizedBox(height: 14),
              NeuButton(
                label: widget.isLoading ? 'Sending the code…' : 'Send the Code',
                loading: widget.isLoading,
                onTap: widget.isLoading ? null : widget.onSendCode,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOtpStep() {
    final fullNumber =
        '${widget.dialCode.code} ${widget.phoneController.text.trim()}';
    return Column(
      key: const ValueKey('otp-step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Speak the code we sent.',
          textAlign: TextAlign.center,
          style: GoogleFonts.ebGaramond(
              color: EverloreTheme.ash, fontSize: 15),
        ),
        const SizedBox(height: 6),
        // The number, with a Change affordance back to phone entry.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                fullNumber,
                style: TextStyle(
                  fontFamily: EverloreTheme.uiFamily,
                  color: EverloreTheme.parchment,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: widget.isLoading ? null : widget.onEditPhone,
              behavior: HitTestBehavior.opaque,
              child: Text(
                'Change',
                style: TextStyle(
                  fontFamily: EverloreTheme.uiFamily,
                  color: EverloreTheme.gold,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        KeyboardAwareInputGroup(
          active: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OtpField(
                controller: widget.otpController,
                length: 6,
                autofocus: true,
                scrollPadding: const EdgeInsets.symmetric(horizontal: 24),
                onCompleted: () {
                  if (!widget.isLoading) widget.onVerifyCode();
                },
              ),
              const SizedBox(height: 18),
              NeuButton(
                label: widget.isLoading ? 'Verifying…' : 'Enter the Realm',
                accent: EverloreTheme.aether,
                loading: widget.isLoading,
                onTap: widget.isLoading ? null : widget.onVerifyCode,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Resend, with a cooldown countdown.
        Center(
          child: _cooldown > 0
              ? Text(
                  'Resend code in 0:${_cooldown.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontFamily: EverloreTheme.uiFamily,
                    color: EverloreTheme.ash,
                    fontSize: 13,
                  ),
                )
              : GestureDetector(
                  onTap: widget.isLoading ? null : _resend,
                  behavior: HitTestBehavior.opaque,
                  child: Text(
                    'Resend code',
                    style: TextStyle(
                      fontFamily: EverloreTheme.uiFamily,
                      color: EverloreTheme.gold,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
