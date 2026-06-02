import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Scrolls [anchorKey]'s widget so it sits fully above the soft keyboard.
///
/// Prefer wrapping fields in [KeyboardAwareInputGroup] instead of calling this
/// directly.
void scrollIntoViewAboveKeyboard(
  BuildContext context,
  GlobalKey anchorKey, {
  double bottomMargin = 20,
}) {
  final mq = MediaQuery.of(context);
  final keyboard = mq.viewInsets.bottom;
  if (keyboard <= 0) return;

  final ctx = anchorKey.currentContext;
  if (ctx == null || !ctx.mounted) return;
  final groupBox = ctx.findRenderObject();
  final scrollable = Scrollable.maybeOf(ctx);
  if (groupBox is! RenderBox || !groupBox.hasSize || scrollable == null) {
    return;
  }

  final position = scrollable.position;
  final viewport = RenderAbstractViewport.of(groupBox);

  var target = viewport.getOffsetToReveal(groupBox, 1.0).offset;

  final visibleBottom = mq.size.height - keyboard - bottomMargin;
  final groupBottom =
      groupBox.localToGlobal(Offset(0, groupBox.size.height)).dy;
  final overflow = groupBottom - visibleBottom;
  if (overflow > 0) {
    target = position.pixels + overflow;
  }

  target = target.clamp(
    position.minScrollExtent,
    position.maxScrollExtent,
  );
  if ((position.pixels - target).abs() < 2) return;
  position.jumpTo(target);
}

/// A [SingleChildScrollView] whose viewport shrinks with the keyboard.
///
/// Pair with [KeyboardAwareInputGroup] around each field + action-button cluster
/// inside long forms (e.g. auth, forge screens).
class KeyboardAwareScroll extends StatelessWidget {
  const KeyboardAwareScroll({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.keyboardOpenBottomSlack = 160,
    this.closedBottomSlack = 28,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double keyboardOpenBottomSlack;
  final double closedBottomSlack;

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final resolved = padding.resolve(Directionality.of(context));
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: resolved.left,
          right: resolved.right,
          top: resolved.top,
          bottom: keyboard > 0 ? keyboardOpenBottomSlack : closedBottomSlack,
        ),
        child: child,
      ),
    );
  }
}

/// Keeps an input (and widgets below it, e.g. a primary button) above the
/// keyboard inside a [KeyboardAwareScroll] / [Scrollable] ancestor.
///
/// ```dart
/// KeyboardAwareInputGroup(
///   focusNode: _phoneFocus,
///   child: Column(
///     crossAxisAlignment: CrossAxisAlignment.stretch,
///     children: [
///       NeuField(focusNode: _phoneFocus, ...),
///       const SizedBox(height: 14),
///       NeuButton(...),
///     ],
///   ),
/// )
/// ```
///
/// For autofocus steps without an owned [FocusNode] (e.g. OTP), set
/// [active] to `true`.
class KeyboardAwareInputGroup extends StatefulWidget {
  const KeyboardAwareInputGroup({
    super.key,
    required this.child,
    this.focusNode,
    this.active = false,
    this.bottomMargin = 20,
  });

  final Widget child;

  /// When this node gains focus, the group scrolls above the keyboard.
  final FocusNode? focusNode;

  /// When `true`, scroll while the keyboard is open even without [focusNode]
  /// (use on autofocus-only steps).
  final bool active;

  final double bottomMargin;

  @override
  State<KeyboardAwareInputGroup> createState() => KeyboardAwareInputGroupState();
}

class KeyboardAwareInputGroupState extends State<KeyboardAwareInputGroup>
    with WidgetsBindingObserver {
  final GlobalKey _anchorKey = GlobalKey();
  Timer? _scrollFollowUp;
  bool _scrollFrameQueued = false;

  bool get _shouldTrack =>
      widget.active || (widget.focusNode?.hasFocus ?? false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.focusNode?.addListener(_onFocusChange);
    if (widget.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) => ensureVisible());
    }
  }

  @override
  void didUpdateWidget(KeyboardAwareInputGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode?.removeListener(_onFocusChange);
      widget.focusNode?.addListener(_onFocusChange);
    }
    if (!oldWidget.active && widget.active) {
      ensureVisible();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.focusNode?.removeListener(_onFocusChange);
    _scrollFollowUp?.cancel();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (_shouldTrack) ensureVisible();
  }

  void _onFocusChange() {
    if (widget.focusNode?.hasFocus ?? false) ensureVisibleAfterFocus();
  }

  /// Scrolls the group above the keyboard (safe to call after layout changes).
  void ensureVisible() {
    if (!_shouldTrack) return;
    if (_scrollFrameQueued) return;
    _scrollFrameQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollFrameQueued = false;
      if (!mounted) return;
      scrollIntoViewAboveKeyboard(
        context,
        _anchorKey,
        bottomMargin: widget.bottomMargin,
      );
    });
  }

  /// Call when focus is gained before [viewInsets] updates (Android).
  void ensureVisibleAfterFocus() {
    ensureVisible();
    _scrollFollowUp?.cancel();
    _scrollFollowUp = Timer(const Duration(milliseconds: 50), () {
      if (mounted) ensureVisible();
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _anchorKey,
      child: widget.child,
    );
  }
}
