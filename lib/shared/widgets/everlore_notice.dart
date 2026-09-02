import 'dart:async';

import 'package:flutter/material.dart';
import '../../app/theme/nexus_theme.dart';

/// What a notice is telling the player. Only the accent and default icon
/// change — the shape is identical so they read as one system.
enum NoticeTone { success, error, info }

/// The app's single acknowledgement surface: a themed banner that slides in
/// under the status bar, can always be swiped up or tapped away, and retires
/// itself.
///
/// It replaces two older mechanisms that behaved differently on every screen:
/// raw Material `SnackBar`s (unstyled, floating over the nav bar) and an
/// `IgnorePointer` overlay toast that could not be dismissed at all — it sat
/// there for its full three seconds no matter what the player did.
void showEverloreNotice(
  BuildContext context,
  String message, {
  NoticeTone tone = NoticeTone.info,
  IconData? icon,
  Duration? duration,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null || message.trim().isEmpty) return;

  // One at a time. Stacked notices used to render exactly on top of each
  // other, so a second message looked like a rendering glitch.
  _NoticeController.instance.dismissCurrent();

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _NoticeBanner(
      message: message,
      tone: tone,
      icon: icon,
      duration:
          duration ??
          (tone == NoticeTone.error
              ? const Duration(seconds: 5)
              : const Duration(milliseconds: 3400)),
      onRetire: () => _NoticeController.instance.remove(entry),
    ),
  );
  _NoticeController.instance.adopt(entry);
  overlay.insert(entry);
}

/// Tracks the live notice so a new one can retire the old, and so removal is
/// idempotent (the timer and a swipe can both finish first).
class _NoticeController {
  _NoticeController._();
  static final instance = _NoticeController._();

  OverlayEntry? _current;

  void adopt(OverlayEntry entry) => _current = entry;

  void remove(OverlayEntry entry) {
    if (entry.mounted) entry.remove();
    if (identical(_current, entry)) _current = null;
  }

  void dismissCurrent() {
    final entry = _current;
    _current = null;
    if (entry != null && entry.mounted) entry.remove();
  }
}

class _NoticeBanner extends StatefulWidget {
  final String message;
  final NoticeTone tone;
  final IconData? icon;
  final Duration duration;
  final VoidCallback onRetire;

  const _NoticeBanner({
    required this.message,
    required this.tone,
    required this.icon,
    required this.duration,
    required this.onRetire,
  });

  @override
  State<_NoticeBanner> createState() => _NoticeBannerState();
}

class _NoticeBannerState extends State<_NoticeBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    reverseDuration: const Duration(milliseconds: 180),
  );
  Timer? _timer;
  bool _retiring = false;

  @override
  void initState() {
    super.initState();
    _anim.forward();
    _timer = Timer(widget.duration, _retire);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  Future<void> _retire() async {
    if (_retiring) return;
    _retiring = true;
    _timer?.cancel();
    if (mounted) await _anim.reverse();
    widget.onRetire();
  }

  Color get _accent => switch (widget.tone) {
    NoticeTone.success => EverloreTheme.verdant,
    NoticeTone.error => EverloreTheme.crimson,
    NoticeTone.info => EverloreTheme.gold,
  };

  IconData get _icon =>
      widget.icon ??
      switch (widget.tone) {
        NoticeTone.success => Icons.check_circle_outline_rounded,
        NoticeTone.error => Icons.error_outline_rounded,
        NoticeTone.info => Icons.auto_awesome_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(
      parent: _anim,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 10,
      left: 14,
      right: 14,
      child: FadeTransition(
        opacity: curve,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.55),
            end: Offset.zero,
          ).animate(curve),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Material(
                color: Colors.transparent,
                child: Semantics(
                  liveRegion: true,
                  label: widget.message,
                  child: Dismissible(
                    key: ValueKey(widget.message),
                    direction: DismissDirection.up,
                    onDismissed: (_) => widget.onRetire(),
                    child: GestureDetector(
                      onTap: _retire,
                      behavior: HitTestBehavior.opaque,
                      child: _card(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            EverloreTheme.void3,
            Color.alphaBlend(
              _accent.withValues(alpha: 0.10),
              EverloreTheme.void2,
            ),
          ],
        ),
        border: Border.all(color: _accent.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          BoxShadow(color: _accent.withValues(alpha: 0.12), blurRadius: 16),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _accent.withValues(alpha: 0.16),
            ),
            alignment: Alignment.center,
            child: Icon(_icon, color: _accent, size: 16),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                widget.message,
                style: EverloreTheme.ui(
                  size: 13,
                  color: EverloreTheme.parchment,
                  height: 1.35,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // An explicit out, for players who do not think to swipe.
          Semantics(
            button: true,
            label: 'Dismiss',
            child: GestureDetector(
              onTap: _retire,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: EverloreTheme.ash.withValues(alpha: 0.9),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
