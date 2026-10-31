import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app_routes.dart';
import 'guest_session.dart';
import 'keep_story_sheet.dart';
import 'sign_in_required.dart';

/// Wraps the app to present [KeepStorySheet] whenever a guest hits a limit.
///
/// Mounted in `MaterialApp.builder` in `main.dart` alongside `GuideHost`.
/// Listens to [SignInRequired.requests] and presents the sheet on the root
/// navigator if the active session is a guest, suppressing further prompts
/// for 60 seconds if the player dismisses or taps "Not now".
class KeepStoryHost extends StatefulWidget {
  final Widget child;
  final Duration cooldown;

  /// True while the sheet is on screen, so a guide arc can hold back rather
  /// than open under it.
  static final ValueNotifier<bool> sheetShowing = ValueNotifier<bool>(false);

  const KeepStoryHost({
    super.key,
    required this.child,
    this.cooldown = const Duration(seconds: 60),
  });

  @override
  State<KeepStoryHost> createState() => _KeepStoryHostState();
}

class _KeepStoryHostState extends State<KeepStoryHost> {
  late int _lastCount;
  bool _showing = false;
  DateTime? _cooldownUntil;

  @visibleForTesting
  bool get isShowing => _showing;

  @visibleForTesting
  DateTime? get cooldownUntil => _cooldownUntil;

  @override
  void initState() {
    super.initState();
    _lastCount = SignInRequired.requests.value;
    SignInRequired.requests.addListener(_onSignInRequiredChanged);
  }

  @override
  void dispose() {
    SignInRequired.requests.removeListener(_onSignInRequiredChanged);
    super.dispose();
  }

  void _onSignInRequiredChanged() {
    final count = SignInRequired.requests.value;
    if (count <= _lastCount) return;
    _lastCount = count;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybeShowSheet();
    });
  }

  Future<void> _maybeShowSheet() async {
    if (_showing) return;
    if (!GuestSession.instance.isGuest) return;

    final now = DateTime.now();
    if (_cooldownUntil != null && now.isBefore(_cooldownUntil!)) {
      return;
    }

    final navContext = router.routerDelegate.navigatorKey.currentContext;
    if (navContext == null || !navContext.mounted) return;

    final location = _currentLocation();
    if (location == '/auth') return;

    _showing = true;
    KeepStoryHost.sheetShowing.value = true;
    try {
      final result = await KeepStorySheet.show(navContext);

      if (!mounted) return;

      if (result == KeepStoryResult.signIn) {
        final here = _currentLocation();
        final isStory =
            here != null && (here == '/play' || here.startsWith('/play/'));
        final target = isStory ? '/auth?from=story' : '/auth';
        router.push(target);
      } else {
        _cooldownUntil = DateTime.now().add(widget.cooldown);
      }
    } finally {
      _showing = false;
      KeepStoryHost.sheetShowing.value = false;
    }
  }

  String? _currentLocation() {
    try {
      final config = router.routerDelegate.currentConfiguration;
      final last = config.matches.isEmpty ? null : config.matches.last;
      if (last is ImperativeRouteMatch) return last.matches.uri.path;
      return config.uri.path;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
