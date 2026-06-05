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
import '../shared/widgets/everlore_session_loader.dart';
import '../shared/widgets/keyboard_aware_scroll.dart';
import '../shared/widgets/realm_backdrop.dart';
import '../shared/widgets/neu.dart';
import '../shared/widgets/player_avatar.dart';

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
  bool _sessionReady = false;
  bool _googleReady = false;
  bool _isLoading = false;
  bool _isUpdatingPreferences = false;
  bool _isSavingName = false;
  bool _editingName = false;
  final _nameEditCtrl = TextEditingController();
  final _nameEditFocus = FocusNode();
  bool _isDeletingAccount = false;
  bool _codeSent = false;
  String? _errorMessage;
  String? _successMessage;

  VoidCallback? _sessionListener;

  @override
  void initState() {
    super.initState();
    _sessionListener = () {
      if (mounted) _bootstrap();
    };
    AuthService.sessionEpoch.addListener(_sessionListener!);
    _bootstrap();
  }

  @override
  void dispose() {
    AuthService.sessionEpoch.removeListener(_sessionListener!);
    _phoneController.dispose();
    _otpController.dispose();
    _nameEditCtrl.dispose();
    _nameEditFocus.dispose();
    super.dispose();
  }

  bool _isProfileTab(BuildContext context) {
    return GoRouterState.of(context).matchedLocation == '/profile';
  }

  Future<void> _initGoogleSignIn() async {
    try {
      await dotenv.load();
      final clientId = dotenv.env['GOOGLE_WEB_CLIENT_ID']?.trim();
      if (clientId != null && clientId.isNotEmpty) {
        await _googleAuthService.init(serverClientId: clientId);
        if (mounted) setState(() => _googleReady = true);
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _googleReady = false);
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;

    final cachedUser = await AuthService.getCachedUser();
    if (!mounted) return;

    if (cachedUser != null) {
      setState(() {
        _currentUser = cachedUser;
        _sessionReady = true;
      });
      unawaited(_initGoogleSignIn());
      return;
    }

    // Avoid a loader flash when sign-out already cleared local state.
    final needsLoader = _currentUser != null || !_sessionReady;
    if (needsLoader) {
      setState(() => _sessionReady = false);
    }

    await _initGoogleSignIn();
    if (!mounted) return;
    setState(() {
      _currentUser = null;
      _sessionReady = true;
    });
  }

  void _clearMessages() {
    _errorMessage = null;
    _successMessage = null;
  }

  /// After sign-in: interests onboarding for new accounts; Discover otherwise.
  Future<void> _routeAfterAuth() async {
    final user = await AuthService.getCachedUser();
    final onboarded =
        await InterestsStore.hasCompletedOnboarding(user: user);
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
      _sessionReady = true;
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
        showPortraits: _sessionReady && _currentUser == null,
        child: SafeArea(
          child: Column(
            children: [
              // Back button — only in the sign-in flow. The profile is a nav
              // tab (no back) or pushed (OS/gesture back handles it).
              if (_sessionReady && _currentUser == null && !_isProfileTab(context))
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
                )
              else
                const SizedBox(height: 12),
              Expanded(child: _buildSessionBody(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionBody(BuildContext context) {
    if (!_sessionReady) {
      return EverloreSessionLoader(
        message: _isProfileTab(context)
            ? 'Opening your profile'
            : 'One moment',
      );
    }
    if (_currentUser != null) {
      return KeyboardAwareScroll(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        keyboardOpenBottomSlack: 120,
        closedBottomSlack: 0,
        child: _buildProfile(_currentUser!),
      );
    }
    return KeyboardAwareScroll(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: _buildSignIn(),
    );
  }

  String _displayName(User user) {
    final name = user.preferences.playerName.trim();
    return name.isNotEmpty ? name : 'Traveler';
  }

  void _beginNameEdit(User user) {
    _nameEditCtrl.text = user.preferences.playerName;
    setState(() => _editingName = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nameEditFocus.requestFocus();
    });
  }

  void _cancelNameEdit() {
    setState(() => _editingName = false);
    _nameEditCtrl.clear();
  }

  Future<void> _saveNameEdit() async {
    final name = _nameEditCtrl.text.trim();
    if (name.length < 2) return;
    setState(() {
      _isSavingName = true;
      _errorMessage = null;
    });
    try {
      final updated =
          await AuthService.updatePreferences({'player_name': name});
      if (!mounted) return;
      setState(() {
        _currentUser = updated;
        _editingName = false;
        _successMessage = 'Name updated.';
      });
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage =
          e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSavingName = false);
    }
  }

  Widget _buildProfile(User user) {
    final displayName = _displayName(user);
    final nameReady = _nameEditCtrl.text.trim().length >= 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 24),

        PlayerAvatar(gender: user.preferences.gender, size: 88),

        const SizedBox(height: 16),

        if (_editingName) ...[
          KeyboardAwareInputGroup(
            focusNode: _nameEditFocus,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: NeuField(
                controller: _nameEditCtrl,
                focusNode: _nameEditFocus,
                hintText: 'Your name',
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: NeuButton(
                  label: 'Cancel',
                  primary: false,
                  onTap: _isSavingName ? null : _cancelNameEdit,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: NeuButton(
                  label: _isSavingName ? 'Saving…' : 'Save',
                  loading: _isSavingName,
                  onTap: nameReady && !_isSavingName ? _saveNameEdit : null,
                ),
              ),
            ],
          ),
        ] else ...[
          GestureDetector(
            onTap: _isSavingName ? null : () => _beginNameEdit(user),
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    displayName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: EverloreTheme.parchment,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: EverloreTheme.goldDim.withValues(alpha: 0.85),
                ),
              ],
            ),
          ),
        ],

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

        const SizedBox(height: 28),

        Container(
          decoration: EverloreTheme.cardDecoration,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
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

        const SizedBox(height: 32),

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
        const SizedBox(height: 96), // clear the floating nav on the profile tab
      ],
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
